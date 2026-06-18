# iOS App Flows

All user-facing flows in the PaidPost iOS SwiftUI app (`ios/PaidPost`). A "flow" is a multi-step user journey or feature area.

| # | Flow | Key Views | Primary API Calls |
|---|------|-----------|-------------------|
| 1 | Onboarding | `OnboardingView` | none (local state) |
| 2 | Sign In / Auth | `SignInView`, `AuthAPI`, `AppleSignIn`, `GoogleSignIn` | `AuthAPI.requestCode/verifyCode/signInWithIdToken` |
| 3 | Profile Setup | `ProfileSetupView` | `CreatorAPI.completeProfileSetup/uploadProfilePicture` |
| 4 | Discover / Browse | `DiscoverView`, `MethodDetailView`, `MethodCard` | `JobsAPI.fetchJobs` |
| 5 | Apply to Opportunity | `ApplySheet`, `MethodDetailView` | `CreatorAPI.apply` |
| 6 | Earnings / Dashboard | `EarningsView` | `CreatorAPI.fetchWallet/fetchApplications` |
| 7 | Profile / Account | `ProfileView`, `EditProfileView` | `CreatorAPI.fetchProfile/updateProfile/uploadProfilePicture/updateLanguages` |
| 8 | Notifications | `NotificationsView` | `CreatorAPI.fetchNotifications/markNotificationsRead` |
| 9 | Inbox / Messaging | `InboxView`, `InboxAPI` | `InboxAPI.fetchInbox/fetchThread/markThreadRead/sendMessage` |
| 10 | Campaigns | `CampaignsView` | `WorkspaceAPI.fetchManagedStatus` |
| 11 | Campaign Workspace | `WorkspaceView`, `UploadVideosView` | `WorkspaceAPI.fetchWorkspace/fetchVideos/uploadVideo/submitApplication` |
| 12 | Contract Signing | `ContractView` | `WorkspaceAPI.signContract` |
| 13 | Warm-Up | `WarmupView` | `WorkspaceAPI.fetchWarmup/addWarmupVideoURL/uploadWarmupScreenshot` |
| 14 | My Content | `MyContentView` | `WorkspaceAPI.fetchPosts/syncPosts/setAdCode` |
| 15 | Settings / Help | `SettingsDetailView` | `CreatorAPI.deleteAccount` |
| 16 | Today's Tasks | `TodaysTasksCard`, `AppStore` | computed from applications + campaigns |

---

## 1. Onboarding
**Views:** `OnboardingView.swift`

3-page intro carousel ("Get Paid to Create", "Track Your Earnings", "Cash Out Instantly") on first launch. Skip/Next navigation; sets `hasOnboarded` then routes to Sign In. No API.

## 2. Authentication / Sign In
**Views:** `SignInView.swift` · **Services:** `AuthAPI.swift`, `AppleSignIn.swift`, `GoogleSignIn.swift`

1. User enters email → `AuthAPI.requestCode(email)` sends OTP via Supabase Auth.
2. User enters 6-digit code → `AuthAPI.verifyCode(email, code)` returns a session.
3. Alternatively Apple/Google native sign-in returns an `id_token` → `AuthAPI.signInWithIdToken(provider, idToken, nonce)`.
4. Session persisted to Keychain via `SessionStore`; `isSignedIn` set.

Helpers: `AuthAPI.checkEmailAllowed()`, `AppleSignInCoordinator`, `GoogleSignInHelper`.

## 3. First-Run Profile Setup
**Views:** `ProfileSetupView.swift`

Conditional gate after sign-in when the creator has no display name. Multi-step form: name → DOB (18+ age gate) → location → optional photo. On finish: `CreatorAPI.completeProfileSetup(...)` and `CreatorAPI.uploadProfilePicture(...)` if a photo was chosen.

## 4. Discover / Browse Opportunities
**Views:** `DiscoverView.swift`, `MethodDetailView.swift`, `MethodCard.swift` · **Services:** `JobsAPI.swift`

Main feed with category filters, search, "Hot" trending section, and Today's Tasks card. `JobsAPI.fetchJobs(countryISO)` loads jobs filtered by device locale. Tapping a card opens `MethodDetailView` (brand, pay-per-post, budget remaining, claimed %, requirements, example hooks, reference videos) with an Apply button.

## 5. Apply to Opportunity
**Views:** `ApplySheet.swift`, `MethodDetailView.swift`

Tap "Apply for $X" → sheet explains the 3-step process (record → post → get paid) → `CreatorAPI.apply(jobId)` → success ("You're in!"). Button flips to "Application submitted".

## 6. Earnings / Dashboard
**Views:** `EarningsView.swift`

Balance card (available / lifetime / pending), stats row, 7-day weekly earnings chart, transactions ledger, and per-application earnings list. Loads via `CreatorAPI.fetchWallet()` and `CreatorAPI.fetchApplications()`. All metrics from real data.

## 7. Profile / Account Management
**Views:** `ProfileView.swift`, `EditProfileView.swift`

Profile header (avatar, name, handle, stats) with banners to Campaigns, Messages, Notifications, plus Settings entries and connected-accounts placeholders. `CreatorAPI.fetchProfile()` loads; edit sheet saves display name, location, bio, languages via `CreatorAPI.updateProfile(...)` / `updateLanguages(...)` / `uploadProfilePicture(...)`.

## 8. Notifications
**Views:** `NotificationsView.swift`

Bell badge in Profile toolbar shows unread count. `CreatorAPI.fetchNotifications()` lists typed notifications (application status, payout, milestone…); swipe or "Mark all read" → `CreatorAPI.markNotificationsRead(ids)`. Read state persists server-side.

## 9. Inbox / Messaging
**Views:** `InboxView.swift` · **Services:** `InboxAPI.swift`

Thread list (brands + system "PaidPost" thread) → conversation view with bubbles + composer. `InboxAPI.fetchInbox()`, `fetchThread(threadKey)`, `sendMessage(threadKey, body)`, `markThreadRead(threadKey)`. Auto-scrolls to latest; marks read on open.

## 10. Campaigns / Managed Status
**Views:** `CampaignsView.swift` · **Services:** `WorkspaceAPI.swift`

List of all brands the creator works with, filterable by status (All, Active, Under Review, To Do, Past). `WorkspaceAPI.fetchManagedStatus()`. Tapping a brand opens `WorkspaceView`.

## 11. Campaign Workspace / Brand Hub
**Views:** `WorkspaceView.swift`, `UploadVideosView.swift`, `ContractView.swift`, `WarmupView.swift`, `MyContentView.swift`

Status card (Applied → Under review → Accepted → Warming up → Active) plus brief, contract, reference videos, audition-upload, warm-up, and My-content sections that unlock by status. `WorkspaceAPI.fetchWorkspace(brandSlug)`, `fetchVideos`, `uploadVideo` (presigned R2 PUT + save slot), `submitApplication`.

**Sub-flow — Upload Audition Videos:** slot-based form (3–10 videos), per-slot picker with replace, upload progress, submit for AI screening.

## 12. Contract Signing
**Views:** `ContractView.swift`

Shown when accepted but unsigned. Read terms → check agreement toggle → enter full legal name → "Sign & Accept" → `WorkspaceAPI.signContract(applicationId, signerName)` → success. Workspace refreshes.

## 13. Warm-Up / Account Conditioning
**Views:** `WarmupView.swift`

Appears when campaign is `warming_up`/`active`. `WorkspaceAPI.fetchWarmup(brandSlug)` loads timeline. Daily: paste niche video URL → `addWarmupVideoURL(...)`; when a screenshot window is due, pick a photo → presigned `uploadWarmupScreenshot(...)`. Task status flips to submitted.

## 14. My Content / Post Tracking
**Views:** `MyContentView.swift`

Platform sync buttons (TikTok/Instagram/YouTube) + post list (caption, views, amount owed, ad code). `WorkspaceAPI.fetchPosts(...)`, `syncPosts(brandSlug, platform)`, and "Add ad code" → `setAdCode(postId, brandSlug, adCode)`.

## 15. Settings / Help & Support
**Views:** `SettingsDetailView.swift`

Notification toggles (UserDefaults), payout placeholder (managed on web), Help/Privacy/Terms links (open in Safari), sign out, and delete account (`CreatorAPI.deleteAccount()`, permanent).

## 16. Today's Tasks / Quick Action
**Views:** `TodaysTasksCard.swift` · **Services:** `AppStore.swift`

Card in Discover surfacing pending tasks ("Sign your [Brand] contract", "Upload videos for [Brand]") computed from applications + campaigns. Tapping deep-links to contract signing or upload; completing removes the task.
