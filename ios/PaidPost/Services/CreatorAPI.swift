//
//  CreatorAPI.swift
//  Methods
//
//  Live data for Earnings, Profile, and Notifications screens.
//  DTO field names match the deployed backend responses exactly
//  (verified against /api/mobile on 2026-06-11).
//

import SwiftUI

// MARK: - Wallet (Earnings)

/// `GET /api/mobile/creators/wallet`
struct WalletDTO: Decodable {
    let balance_cents: Int?
    let pending_earnings_cents: Int?
    let total_earned_cents: Int?
    /// Whether Stripe payouts are actually enabled for this creator. When
    /// false (the default until Stripe Connect is set up), cash-out is not
    /// available and the UI must not pretend otherwise.
    let stripe_payouts_enabled: Bool?
    let stripe_connected: Bool?
    let recent_transactions: [TransactionDTO]?

    var availableBalance: Double { Double(balance_cents ?? 0) / 100 }
    var pendingEarnings: Double { Double(pending_earnings_cents ?? 0) / 100 }
    var totalEarned: Double { Double(total_earned_cents ?? 0) / 100 }
    var payoutsEnabled: Bool { stripe_payouts_enabled ?? false }
}

/// Entry in the wallet's `recent_transactions` ledger.
struct TransactionDTO: Decodable, Identifiable, Hashable {
    let id: String
    let transaction_type: String?
    let amount: Double?
    let description: String?
    let stripe_transfer_status: String?
    let created_at: String?
}

// MARK: - Profile

/// `GET /api/mobile/creator/profile`
struct CreatorProfileDTO: Decodable {
    let display_name: String?
    let email: String?
    let share_code: String?
    let total_jobs_completed: Int?
    let profile_picture: String?
    let bio: String?
    let location: String?
}

// MARK: - Notifications

/// `GET /api/mobile/notifications`
struct NotificationsResponse: Decodable {
    let data: [NotificationDTO]
    let unread_count: Int
}

/// The backend maps `event_type` into `type` and always sends `title: ""` —
/// the client derives a display title from `type`.
struct NotificationDTO: Decodable {
    let id: String
    let type: String?
    let title: String?
    let body: String?
    let read_at: String?
    let created_at: String?
}

// MARK: - Applications

/// Item in `GET /api/mobile/applications` (subset the app uses).
struct ApplicationDTO: Decodable {
    let id: String
    let application_status: String?
    let job_title: String?
    let brand_name: String?
    let brand_slug: String?
    let budget_per_creator: Double?
    let applied_at: String?
    // Per-application contract state — drives the "sign contract" task.
    let contract_accepted_at: String?
    let contract_signer_name: String?
}

// MARK: - API surface

enum CreatorAPI {
    /// Returns nil when the creator has no profile yet (backend 404s with
    /// "Creator not found" until onboarding creates one).
    static func fetchWallet() async throws -> WalletDTO? {
        do {
            return try await APIClient.shared.get("creators/wallet")
        } catch APIError.server(let status, _) where status == 404 {
            return nil
        }
    }

    static func fetchProfile() async throws -> CreatorProfileDTO {
        try await APIClient.shared.get("creator/profile")
    }

    /// Creates (or updates) the creator profile. The backend requires one
    /// before a user can apply to jobs or see a wallet.
    static func upsertProfile(displayName: String) async throws {
        struct Body: Encodable { let display_name: String }
        struct Ack: Decodable { let success: Bool? }
        _ = try await APIClient.shared.send(
            "creator/profile", method: "PATCH", body: Body(display_name: displayName)
        ) as Ack
    }

    static func fetchNotifications() async throws -> NotificationsResponse {
        try await APIClient.shared.get("notifications")
    }

    /// Lightweight unread badge count — avoids pulling the full list.
    static func fetchUnreadCount() async throws -> Int {
        struct Result: Decodable { let unread_count: Int? }
        let r: Result = try await APIClient.shared.get("notifications/unread-count")
        return r.unread_count ?? 0
    }

    /// Sets the creator's spoken languages. `PUT creator/languages`.
    static func updateLanguages(_ languages: [String]) async throws {
        struct Body: Encodable { let languages: [String] }
        struct Ack: Decodable { let success: Bool? }
        _ = try await APIClient.shared.send(
            "creator/languages", method: "PUT", body: Body(languages: languages)
        ) as Ack
    }

    static func fetchApplications() async throws -> [ApplicationDTO] {
        try await APIClient.shared.get("applications")
    }

    /// Marks notifications read on the server. Empty array = mark all read.
    static func markNotificationsRead(ids: [String]) async {
        struct Body: Encodable { let notification_ids: [String] }
        struct Ack: Decodable { let success: Bool? }
        _ = try? await APIClient.shared.send(
            "notifications/mark-read", method: "POST", body: Body(notification_ids: ids)
        ) as Ack
    }

    /// Applies to a job. `POST /api/mobile/jobs/{id}/apply`
    @discardableResult
    static func apply(jobId: String) async throws -> Bool {
        struct Ack: Decodable { let success: Bool?; let error: String? }
        let ack: Ack = try await APIClient.shared.send("jobs/\(jobId.lowercased())/apply", method: "POST")
        return ack.success ?? (ack.error == nil)
    }

    /// Permanently deletes the creator's account.
    /// `DELETE /api/mobile/creator/account` → `{ success: true }`.
    static func deleteAccount() async -> Bool {
        struct Ack: Decodable { let success: Bool? }
        let ack: Ack? = try? await APIClient.shared.send("creator/account", method: "DELETE")
        return ack?.success ?? false
    }

    /// Updates editable profile fields. Nil fields are left untouched.
    static func updateProfile(displayName: String?, bio: String?, location: String?) async throws {
        struct Body: Encodable {
            let display_name: String?
            let bio: String?
            let location: String?
        }
        struct Ack: Decodable { let success: Bool? }
        _ = try await APIClient.shared.send(
            "creator/profile", method: "PATCH",
            body: Body(display_name: displayName, bio: bio, location: location)
        ) as Ack
    }

    /// First-run profile setup. Writes the fuller field set the onboarding
    /// flow collects (name parts, DOB, location). `PATCH creator/profile`.
    static func completeProfileSetup(
        firstName: String, lastName: String, location: String?, dateOfBirth: String?
    ) async throws {
        struct Body: Encodable {
            let display_name: String
            let first_name: String
            let last_name: String?
            let location: String?
            let date_of_birth: String?
        }
        struct Ack: Decodable { let success: Bool? }
        let display = [firstName, lastName].filter { !$0.isEmpty }.joined(separator: " ")
        _ = try await APIClient.shared.send(
            "creator/profile", method: "PATCH",
            body: Body(display_name: display, first_name: firstName,
                       last_name: lastName.isEmpty ? nil : lastName,
                       location: location, date_of_birth: dateOfBirth)
        ) as Ack
    }

    /// Uploads a profile photo (JPEG). Returns the public URL.
    static func uploadProfilePicture(jpegData: Data) async throws -> String? {
        struct Result: Decodable { let success: Bool?; let url: String? }
        let result: Result = try await APIClient.shared.uploadMultipart(
            "creator/profile/picture",
            fieldName: "photo",
            filename: "photo.jpg",
            mimeType: "image/jpeg",
            fileData: jpegData
        )
        return result.url
    }

    // MARK: Payouts

    /// Stripe Connect onboarding link to open in Safari. Return/refresh land
    /// on our web URL rather than the 8x app's `eightx://` scheme.
    static func createStripeConnectLink() async throws -> URL {
        struct Body: Encodable { let return_url: String; let refresh_url: String }
        struct Result: Decodable { let url: String? }
        let base = APIConfig.baseURL.absoluteString
        let result: Result = try await APIClient.shared.send(
            "creators/stripe-connect", method: "POST",
            body: Body(return_url: base + "?stripe=return", refresh_url: base + "?stripe=refresh")
        )
        guard let raw = result.url, let url = URL(string: raw) else {
            throw APIError.invalidResponse
        }
        return url
    }

    /// Requests a standard payout of the available balance.
    /// Failures surface a user-facing message via `APIError.server`.
    static func requestPayout() async throws {
        struct Body: Encodable { let method = "standard" }
        struct Ack: Decodable { let success: Bool?; let error: String? }
        let ack: Ack = try await APIClient.shared.send(
            "creators/stripe-payout", method: "POST", body: Body()
        )
        if ack.success == false {
            throw APIError.server(status: 400, message: ack.error ?? "Payout failed.")
        }
    }
}

// MARK: - Mapping to app models

extension NotificationDTO {
    func toNotification() -> Notification {
        let kind = Self.kind(for: type ?? "")
        return Notification(
            id: UUID(uuidString: id) ?? UUID(),
            type: kind,
            title: (title?.isEmpty == false) ? title! : Self.defaultTitle(for: kind),
            body: body ?? "",
            timestamp: BackendDate.parse(created_at) ?? Date(),
            isRead: read_at != nil
        )
    }

    private static func kind(for raw: String) -> Notification.NotificationType {
        let value = raw.lowercased()
        if value.contains("approv") || value.contains("accept") || value.contains("application") { return .approved }
        if value.contains("pay") || value.contains("payout") { return .paid }
        if value.contains("job") || value.contains("method") || value.contains("general") { return .newMethod }
        if value.contains("milestone") || value.contains("view") { return .milestone }
        return .reminder
    }

    private static func defaultTitle(for kind: Notification.NotificationType) -> String {
        switch kind {
        case .approved: return "Application update"
        case .paid: return "Payment update"
        case .newMethod: return "What's new"
        case .milestone: return "Milestone reached"
        case .reminder: return "New message"
        }
    }
}

extension ApplicationDTO {
    /// Builds a self-contained `Application` (with a stub `Method`) so the
    /// Earnings list renders even when the job isn't in the current feed.
    func toApplication() -> Application {
        let method = Method(
            id: UUID(uuidString: id) ?? UUID(),
            brand: brand_name ?? "Brand",
            title: job_title ?? "Application",
            tagline: "",
            payPerPost: budget_per_creator ?? 0,
            totalBudget: 0,
            claimedBudget: 0,
            category: .all,
            videoLengthSeconds: 20...40,
            difficulty: .easy,
            isHot: false,
            accent: Theme.accent,
            logoSymbol: "sparkle",
            requirements: [],
            exampleHooks: []
        )
        return Application(
            id: UUID(uuidString: id) ?? UUID(),
            method: method,
            status: Self.status(for: application_status ?? "pending"),
            appliedAt: BackendDate.parse(applied_at) ?? Date(),
            earned: 0,
            views: 0,
            backendId: id,
            brandSlug: brand_slug,
            contractAcceptedAt: BackendDate.parse(contract_accepted_at),
            contractSignerName: contract_signer_name
        )
    }

    private static func status(for raw: String) -> Application.Status {
        switch raw.lowercased() {
        case "approved", "accepted", "auto_approved": return .approved
        case "completed", "paid": return .paid
        case "posted", "submitted": return .posted
        default: return .underReview
        }
    }
}

/// Backend timestamps are ISO-8601, usually with fractional seconds
/// ("2026-06-11T02:42:35.88956+00:00") — plain ISO8601DateFormatter rejects
/// those, so try fractional first.
nonisolated enum BackendDate {
    static func parse(_ string: String?) -> Date? {
        guard let string else { return nil }
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = fractional.date(from: string) { return date }
        return ISO8601DateFormatter().date(from: string)
    }
}
