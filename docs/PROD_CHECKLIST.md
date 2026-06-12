# PaidPost — Production Checklist

_Last updated: 2026-06-11_

Stack: SwiftUI iOS app (`ios/Methods.xcodeproj`) → Next.js backend (`shashank-100/paidpost-backend`, deployed on personal Vercel) → Supabase project `paidpost` (`jmlnyuwlrbxhxckuuhxw`).

- **API base:** `https://paidpost-shashank100s-projects.vercel.app/api/mobile`
- **Vercel project:** `shashank100s-projects/paidpost` (git push to `main` auto-deploys)
- **DB:** Supabase `paidpost`, region East US

---

## ✅ Done

### Backend / infra
- [x] Backend deployed to personal Vercel account (off the 8x org)
- [x] Code pushed to `github.com/shashank-100/paidpost-backend` (private, secrets-scrubbed history)
- [x] GitHub → Vercel connected; auto-deploy from `main` enabled and verified
- [x] Supabase project created on personal account; all 606 migrations applied
- [x] **Supabase env vars wired in Vercel** (`SUPABASE_URL`, `SUPABASE_SECRET_KEY`, publishable key, app URLs) — verified with a real DB round-trip through the live API
- [x] Strong random `CRON_SECRET` set (authorizes internal video-hash/screening hooks)
- [x] Storage buckets exist (`profile-photos`, `managed-creators`, `intro-videos`, + 6 more from migrations)
- [x] Supabase Auth: email OTP enabled, `site_url` set to prod URL
- [x] Seed data: PaidPost Studio brand + live job; feed serves 12 jobs total (incl. Sprout demo jobs)
- [x] Live smoke test passed: create user → password/OTP sign-in → JWT → `GET /jobs` returns seeded data
- [x] `maxDuration` capped at 300s and crons converted to daily (Hobby-plan limits)

### iOS app
- [x] Onboarding persists (`hasOnboarded` in UserDefaults) — no more replay every launch
- [x] Settings notification toggles persist via `@AppStorage` (were `Binding.constant` no-ops)
- [x] Crash guards: `budgetProgress` divide-by-zero, negative `budgetRemaining`
- [x] Removed fake pull-to-refresh; removed dead code in `totalEarned`
- [x] Bundle ID `com.shashank.methods` (was Rork placeholder); iPhone locked to portrait
- [x] `PrivacyInfo.xcprivacy` (UserDefaults, reason CA92.1)
- [x] Real unit tests for AppStore/model logic (12 tests, replacing empty placeholder)
- [x] Networking layer: `APIClient` (actor, Bearer auth + transparent token refresh), `APIConfig`, `JobsAPI` → Discover feed
- [x] Email-OTP sign-in flow: `AuthAPI` + `SessionStore` (Keychain), `SignInView`, sign-out + delete-account in Settings
- [x] Duplicate auth layers merged (deleted `AuthService`/`TokenStore`; single `AuthSession` in `AuthAPI.swift`)
- [x] `CreatorAPI.swift` DTOs fixed to match live API (`type`, `application_status`, `budget_per_creator`, wallet-404→empty, fractional-second dates)
- [x] **Creator profile auto-created on first sign-in** (`PATCH creator/profile`) — without it, apply returns 400 and wallet 404s forever; verified live end-to-end (profile → apply → application listed `pending` $150 → wallet zeros)
- [x] All demo/sample data removed from signed-in state (App Store 2.1); notifications sync read-state to server
- [x] **Payout flow** — Earnings has a 3-state button (set up → finish setup → cash out) wired to `stripe-connect` (opens in-app Safari) + `stripe-payout`, plus a recent-transactions ledger. Inert until Stripe keys exist; degrades gracefully.
- [x] **Inbox / brand messages** — `InboxView`/`ThreadView` (thread list, unread badges, conversation, composer) on `GET inbox` / `threads/*`. Entry from Profile.
- [x] **Profile editing + photo** — `EditProfileView` (name/bio/location + photo picker → multipart upload). Verified live.
- [x] **API client hardened** — 401 refresh-and-retry-once; cross-project session guard (drops sessions from a different Supabase project)
- [x] **Campaign workspace** (`WorkspaceView`) — per-brand hub: status, brief, contract, reference videos, My Content entry. Verified live (managed-status → workspace → portalConfig).
- [x] **Contract e-signing** (`ContractView`) — verified live end-to-end (signature persisted with timestamp + signer).
- [x] **Today's-tasks card** (`TodaysTasksCard`) on Discover home — derives sign-contract / upload-videos actions from apps + campaigns.
- [x] **My Content** (`MyContentView`) — posts list, ad-code entry, per-platform sync (sync needs RapidAPI keys to return data).
- [x] All Swift files pass `swiftc -parse` (full type-check still needs Xcode — see your tasks)

### ⏸ Built-but-keyed-off (UI/plumbing ready, light up when keys land)
- Test-video auditions & warmup screenshot uploads: presigned-PUT flow needs **R2 keys**.
- Posts sync: needs **RapidAPI keys**.
- Payouts: need **Stripe keys**.

---

## 🔧 Claude — nothing in flight

- ~~Seed the AiApply campaign data~~ — **cancelled by Shashank mid-load** (2026-06-11). Rolled back
  cleanly; no partial data. The base seed already provides 20+ brand rows (incl. AiApply) and the
  Sprout + PaidPost Studio jobs in the feed. If wanted later: a schema-patched copy of the 65 MB
  dump is the process — strip the 23 columns dropped by post-April migrations, run via psql/pooler
  with `SET statement_timeout = 0`.

---

## 👤 You — today (~30 min)

- [ ] Open `ios/Methods.xcodeproj` in Xcode → Signing & Capabilities → set your team → build & run (this machine has no Xcode; nothing is compile-verified yet)
- [ ] On-device test: sign in with a real email (OTP arrives by email — **max ~2 emails/hour** until custom SMTP is set), browse jobs, apply, check Earnings / Notifications / Profile

## 👤 You — before public launch

- [ ] App Store Connect: register bundle ID `com.shashank.methods`, create the app record → yields the real App Store ID
- [ ] Update `handleVersionCheck` in backend `lib/mobile/handlers.ts` with the real App Store URL (currently `id0000000000` placeholder)
- [ ] App Store submission: screenshots, description, privacy labels → submit (review 1–3 days)
- [ ] At review time only: set `APPLE_REVIEW_BYPASS_ENABLED=true` and seed the reviewer account (`is_test_account=true` on its creator profile); disable after approval

---

## ⏸ Deferred (decided to skip for now)

- **All third-party service keys** — explicitly deferred by Shashank ("will do later"); placeholders remain in Vercel env (`vercel env add <NAME> production` when ready):
  Stripe US+EU (wallet/payouts dead without it) · R2/Cloudflare (video uploads 500) · Resend/SMTP (⚠️ OTP limited to ~2 emails/hour until set) · Twilio (phone verify) · RapidAPI (social sync) · Sentry (error monitoring)
- **Vercel Pro upgrade** — crons run daily instead of every 5 min and functions cap at 300s (was 800s); social-sync data will lag up to a day until upgraded
- **Custom API domain** — `paidpost-shashank100s-projects.vercel.app` alias is hardcoded in `APIConfig.swift:16`; swap when a domain exists (also add it to CORS `ALLOWED_ORIGINS` in the backend router)
- **Push notifications** — backend `push-token` endpoints exist; needs APNs key + app capability + Expo/APNs sender
- **iOS screens beyond MVP** — workspace/warmup/contract/test-video flows exist in the backend but have no iOS UI yet (web + 8x-mobile Expo app cover them)
- **8x repo divergence** — local clone at `~/Desktop/GitHub/8x` has pre-scrub history; pull/reset to `personal/main` before future backend work, don't push local `main`

## 📌 Known quirks / notes

- `GET /api/mobile/applications` returns `[]` with HTTP 200 even on server error (deliberate fail-soft)
- `GET notifications` sends `title: ""` — client derives titles from `type`
- `check-email` fails open (returns `allowed: true` on any error) by design
- In-memory rate limiters reset per Lambda cold start — best-effort only
- Smoke-test account exists in prod: `smoke-test-creator@paidpost.app` (delete before launch — it has a creator profile "Smoke Test" and one pending application to the seeded job)
- Seed system user: `user_seed_system` / brand `paidpost-studio` / job `paidpost-launch-ugc`
- The seeded campaigns (PaidPost Studio, Sprout, AiApply) are the live feed content for now — swap in real brand campaigns whenever they exist, no code change needed (insert via the same `jobs` table shape)
- **Direct-DB password was reset** (2026-06-11, needed for seeding) — saved as `SUPABASE_DB_PASSWORD` in the gitignored `.env.vercel`; treat as a secret. Backend is unaffected (it uses HTTPS APIs, not direct connections)
- Pooler auth is intermittently flaky right after a password reset (some nodes cache the old hash) — retry on "password authentication failed"
