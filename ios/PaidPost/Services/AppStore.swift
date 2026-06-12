//
//  AppStore.swift
//  Methods
//

import SwiftUI
import Observation

/// Global observable state for the Methods app.
@MainActor
@Observable
final class AppStore {
    private static let hasOnboardedKey = "hasOnboarded"

    @ObservationIgnored
    private let defaults: UserDefaults

    // Live data only — populated from the backend after sign-in. Empty until
    // then so a real user never sees placeholder/demo content (App Store 2.1).
    var methods: [Method] = []
    var applications: [Application] = []
    var notifications: [Notification] = []
    var selectedCategory: Method.Category = .all
    var searchText: String = ""

    /// Whether the live job feed is currently loading from the backend.
    var isLoadingMethods = false
    /// Set when the last live load failed; the UI keeps showing the prior
    /// (or sample) methods so the feed never goes blank.
    var loadError: String?

    // Onboarding
    var hasOnboarded: Bool {
        didSet { defaults.set(hasOnboarded, forKey: Self.hasOnboardedKey) }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.hasOnboarded = defaults.bool(forKey: Self.hasOnboardedKey)
    }

    // MARK: - Auth / session

    /// Whether a signed-in session exists. Drives the sign-in gate.
    var isSignedIn = false
    var authInProgress = false
    var authError: String?

    /// Loads any persisted session at launch and reflects it in `isSignedIn`.
    func restoreSession() async {
        await APIClient.shared.restoreSession()
        isSignedIn = await APIClient.shared.isAuthenticated
        if isSignedIn { await loadAll() }
    }

    /// Test/screenshot-only: skip onboarding and sign in via the Apple-review
    /// bypass so automation lands directly in the app. Invoked from a launch
    /// argument; never runs in normal use.
    func uiTestAutoLogin() async {
        hasOnboarded = true
        do {
            try await APIClient.shared.authenticateTestBypass()
            isSignedIn = true
            needsProfileSetup = false
            await loadAll()
        } catch {
            authError = error.localizedDescription
        }
    }

    /// Requests an email OTP code.
    func sendSignInCode(email: String) async -> Bool {
        authInProgress = true; authError = nil
        defer { authInProgress = false }
        do {
            try await AuthAPI.checkEmailAllowed(email)
            try await AuthAPI.requestCode(email: email)
            return true
        } catch {
            authError = (error as? AuthAPI.AuthError)?.errorDescription ?? error.localizedDescription
            return false
        }
    }

    /// Verifies the OTP code, establishes the session, and loads data.
    func verifySignInCode(email: String, code: String) async -> Bool {
        authInProgress = true; authError = nil
        defer { authInProgress = false }

        // App Review path: the reviewer signs in with the fixed test account.
        // That mailbox can't receive a live OTP, so route it through the
        // backend's review bypass instead of Supabase OTP verification.
        if email.lowercased() == APIConfig.TestAccount.email.lowercased(),
           code == APIConfig.TestAccount.code {
            do {
                try await APIClient.shared.authenticateTestBypass()
                isSignedIn = true
                needsProfileSetup = false
                await loadAll()
                return true
            } catch {
                authError = (error as? APIError)?.errorDescription ?? error.localizedDescription
                return false
            }
        }

        do {
            let session = try await AuthAPI.verifyCode(email: email, code: code)
            await APIClient.shared.setSession(session)
            isSignedIn = true
            await loadAll()
            return true
        } catch {
            authError = (error as? AuthAPI.AuthError)?.errorDescription ?? error.localizedDescription
            return false
        }
    }

    func signOut() async {
        await APIClient.shared.signOut()
        isSignedIn = false
        clearUserData()
    }

    /// Permanently deletes the signed-in creator's account, then signs out.
    /// Backend: `DELETE /api/mobile/creator/account`.
    @discardableResult
    func deleteAccount() async -> Bool {
        let ok = await CreatorAPI.deleteAccount()
        await APIClient.shared.signOut()
        isSignedIn = false
        clearUserData()
        return ok
    }

    /// Wipes all per-user state back to empty (no demo content).
    private func clearUserData() {
        methods = []
        applications = []
        notifications = []
        creatorName = ""
        handle = ""
        followers = 0
        availableBalance = 0
        walletTotalEarned = nil
        walletPendingEarnings = nil
        payoutsEnabled = false
        stripeConnected = false
        transactions = []
        payoutError = nil
        bio = ""
        location = ""
        profilePictureURL = nil
        needsProfileSetup = false
        creatorEmail = nil
    }

    /// Loads everything the signed-in app needs. Profile first — it creates
    /// the creator profile on first sign-in, which wallet/apply depend on.
    func loadAll() async {
        await loadProfile()
        await loadJobs()
        await loadWallet()
        await loadNotifications()
        await loadApplications()
    }

    // Creator profile — empty until loaded from the backend.
    var creatorName: String = ""
    var handle: String = ""
    var followers: Int = 0
    var availableBalance: Double = 0

    // Wallet totals from the backend; when present they override the
    // application-derived figures below.
    var walletTotalEarned: Double?
    var walletPendingEarnings: Double?
    /// True only when Stripe payouts are actually enabled for this creator.
    /// Until real payments are wired this stays false, so the UI shows
    /// "payouts coming soon" rather than a fake instant cash-out.
    var payoutsEnabled = false
    /// Whether a Stripe account exists at all (drives "Set up payouts" CTA).
    var stripeConnected = false
    /// Recent wallet transactions for the Earnings ledger.
    var transactions: [TransactionDTO] = []
    var payoutInProgress = false
    var payoutError: String?

    // Editable profile fields (loaded from the backend).
    var bio: String = ""
    var location: String = ""
    var profilePictureURL: String?

    var unreadNotificationCount: Int {
        notifications.filter { !$0.isRead }.count
    }

    var filteredMethods: [Method] {
        methods.filter { method in
            let matchesCategory = selectedCategory == .all || method.category == selectedCategory
            let matchesSearch = searchText.isEmpty
                || method.brand.localizedCaseInsensitiveContains(searchText)
                || method.title.localizedCaseInsensitiveContains(searchText)
            return matchesCategory && matchesSearch
        }
    }

    var hotMethods: [Method] {
        methods.filter { $0.isHot }
    }

    var totalEarned: Double {
        walletTotalEarned ?? applications.reduce(0) { $0 + $1.earned }
    }

    var pendingEarnings: Double {
        walletPendingEarnings ?? applications
            .filter { $0.status == .approved || $0.status == .posted }
            .reduce(0) { $0 + $1.method.payPerPost }
    }

    var totalViews: Int {
        applications.reduce(0) { $0 + $1.views }
    }

    /// Authenticates (if needed) and loads the live job feed from the backend.
    /// On any failure the current `methods` are kept so the feed never empties,
    /// and `loadError` is surfaced for an optional banner.
    func loadJobs() async {
        isLoadingMethods = true
        loadError = nil
        defer { isLoadingMethods = false }
        do {
            let live = try await JobsAPI.fetchJobs()
            if !live.isEmpty { methods = live }
        } catch {
            loadError = (error as? APIError)?.errorDescription ?? error.localizedDescription
        }
    }

    /// True when the signed-in user has no display name yet — drives the
    /// first-run profile-setup flow (name / DOB / country / photo).
    var needsProfileSetup = false
    /// Email from the backend profile, used to prefill / fall back.
    var creatorEmail: String?

    func loadProfile() async {
        guard let p = try? await CreatorAPI.fetchProfile() else { return }
        creatorEmail = p.email
        if let name = p.display_name, !name.isEmpty {
            creatorName = name
            needsProfileSetup = false
        } else {
            // No profile yet → run guided setup instead of silently creating one.
            needsProfileSetup = true
        }
        if let code = p.share_code { handle = "@\(code)" }
        bio = p.bio ?? ""
        location = p.location ?? ""
        profilePictureURL = p.profile_picture
        // Backend has no follower count; never show the sample number to a real user.
        followers = 0
    }

    /// Persists first-run profile setup and clears the gate.
    func completeProfileSetup(
        firstName: String, lastName: String, location: String?,
        dateOfBirth: String?, photoData: Data?
    ) async throws {
        try await CreatorAPI.completeProfileSetup(
            firstName: firstName, lastName: lastName, location: location, dateOfBirth: dateOfBirth
        )
        if let photoData {
            _ = try? await CreatorAPI.uploadProfilePicture(jpegData: photoData)
        }
        await loadProfile()
        needsProfileSetup = false
    }

    func loadWallet() async {
        // A thrown error means the request failed — keep current state.
        // A nil wallet means the creator has no profile yet → genuine zero.
        let wallet: WalletDTO?
        do {
            wallet = try await CreatorAPI.fetchWallet()
        } catch {
            return
        }
        availableBalance = wallet?.availableBalance ?? 0
        walletTotalEarned = wallet?.totalEarned
        walletPendingEarnings = wallet?.pendingEarnings
        payoutsEnabled = wallet?.payoutsEnabled ?? false
        stripeConnected = wallet?.stripe_connected ?? false
        transactions = wallet?.recent_transactions ?? []
    }

    // MARK: - Payouts

    /// Fetches a Stripe Connect onboarding link to open in the browser.
    func startPayoutSetup() async -> URL? {
        payoutError = nil
        do {
            return try await CreatorAPI.createStripeConnectLink()
        } catch {
            payoutError = (error as? APIError)?.errorDescription ?? error.localizedDescription
            return nil
        }
    }

    /// Requests a real payout, then refreshes the wallet. Returns success.
    func requestPayout() async -> Bool {
        payoutInProgress = true
        payoutError = nil
        defer { payoutInProgress = false }
        do {
            try await CreatorAPI.requestPayout()
            await loadWallet()
            return true
        } catch {
            payoutError = (error as? APIError)?.errorDescription ?? error.localizedDescription
            return false
        }
    }

    func loadNotifications() async {
        // Replace, never merge — an empty live list means "no notifications",
        // not "keep showing the demo ones".
        guard let resp = try? await CreatorAPI.fetchNotifications() else { return }
        notifications = resp.data.map { $0.toNotification() }
    }

    func loadApplications() async {
        // Each DTO builds a self-contained Application (with a stub Method) so
        // the Earnings list renders even when the job isn't in the current feed.
        guard let dtos = try? await CreatorAPI.fetchApplications() else { return }
        applications = dtos.map { $0.toApplication() }
    }

    // MARK: - Campaigns (managed status)

    /// Brands the creator is managed by, for the campaigns list + workspace entry.
    var campaigns: [ManagedStatusDTO.ManagedBrandDTO] = []

    func loadCampaigns() async {
        guard let status = try? await WorkspaceAPI.fetchManagedStatus() else { return }
        campaigns = status.brands ?? []
    }

    /// Actionable items derived from current applications/campaigns — drives
    /// the home "Today's tasks" card. Computed, so it stays in sync with state.
    var todaysTasks: [CreatorTask] {
        var tasks: [CreatorTask] = []
        for app in applications {
            // Approved/accepted but contract not signed → sign it.
            if (app.status == .approved) && !app.contractSigned, let appId = app.backendId {
                tasks.append(CreatorTask(
                    id: "contract-\(appId)",
                    title: "Sign your \(app.method.brand) contract",
                    subtitle: "Required before you start posting",
                    icon: "signature",
                    kind: .contract(applicationId: appId, brand: app.method.brand)
                ))
            }
        }
        for brand in campaigns where (brand.videosComplete == false)
            && (brand.status == "accepted" || brand.status == "warming_up") {
            if let slug = brand.slug {
                tasks.append(CreatorTask(
                    id: "videos-\(brand.id)",
                    title: "Upload videos for \(brand.name ?? "your campaign")",
                    subtitle: "Finish your audition to get approved",
                    icon: "video.badge.plus",
                    kind: .workspace(brandSlug: slug)
                ))
            }
        }
        return tasks
    }

    func hasApplied(to method: Method) -> Bool {
        applications.contains { $0.method.id == method.id }
    }

    func apply(to method: Method) {
        guard !hasApplied(to: method) else { return }
        // Optimistic local insert for instant UI feedback.
        let application = Application(
            id: UUID(),
            method: method,
            status: .underReview,
            appliedAt: Date(),
            earned: 0,
            views: 0
        )
        applications.insert(application, at: 0)
        // Persist to the backend in the background. The job id is the Method id.
        Task { try? await CreatorAPI.apply(jobId: method.id.uuidString) }
    }

    // Cash-out is intentionally not implemented locally: payouts only happen
    // through Stripe on the backend once `payoutsEnabled` is true. The UI
    // disables the action until then rather than faking a balance change.

    func markNotificationRead(_ notification: Notification) {
        guard let index = notifications.firstIndex(where: { $0.id == notification.id }) else { return }
        notifications[index].isRead = true
        if isSignedIn {
            let backendId = notification.id.uuidString.lowercased()
            Task { await CreatorAPI.markNotificationsRead(ids: [backendId]) }
        }
    }

    func markAllNotificationsRead() {
        for i in notifications.indices {
            notifications[i].isRead = true
        }
        if isSignedIn {
            // Empty array = mark everything read on the server.
            Task { await CreatorAPI.markNotificationsRead(ids: []) }
        }
    }
}
