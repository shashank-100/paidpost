# PaidPost ↔ 8x-mobile Catch-up Doc

_Last updated: 2026-06-11. Source: full exploration of `~/Desktop/GitHub/8x-mobile` (the official Expo/React Native client for the same backend)._

Purpose: what the 8x team built in their mobile app, what PaidPost (SwiftUI) already covers, and a ranked roadmap of what to add next. All listed backend endpoints are **already live** on our deployment (`https://paidpost-shashank100s-projects.vercel.app/api/mobile`).

---

## 1. Where we stand today

| Capability | 8x-mobile (Expo) | PaidPost (SwiftUI) |
|---|---|---|
| Email-OTP sign-in + keychain session | ✅ | ✅ |
| Apple-review test bypass | ✅ | ✅ (config present) |
| Jobs feed / Discover | ✅ (country filters) | ✅ |
| Job detail + apply | ✅ (cover letter) | ✅ |
| Earnings: wallet summary | ✅ | ✅ |
| Earnings: payout / Stripe Connect / ledger | ✅ | ✅ (UI live; inert until Stripe keys set) |
| Applications list | ✅ | ✅ |
| Notifications | ✅ | ✅ |
| Brand↔creator message threads | ✅ | ✅ (list + conversation + composer) |
| Profile view/edit + photo upload | ✅ | ✅ |
| Delete account | ✅ | ✅ |
| Campaign workspace (per-brand hub) | ✅ | ✅ (`WorkspaceView`: status, brief, contract, content) |
| Today's-tasks card | ✅ | ✅ (Discover home, derived from apps + campaigns) |
| Campaigns list (all brands, status-grouped + filters) | ✅ | ✅ (`CampaignsView`, entry from Profile) |
| Warmup evidence (niche URLs + AI-verified screenshots) | ✅ | ✅ (`WarmupView` — niche-URL log + screenshot PUT; R2 live) |
| Test-video auditions (R2 slots + AI screening) | ✅ | ✅ (`UploadVideosView` — slot upload → submit; R2 PUT verified live) |
| Contract e-signing | ✅ | ✅ (`ContractView`, verified live) |
| Posts sync + ad-code tagging | ✅ | ✅ (`MyContentView`; sync needs RapidAPI keys to return data) |
| Push notifications | ✅ (Expo push, channeled) | 🚫 out of scope (won't build) |
| Deep links / universal links | ✅ (`app.8x.social` + pending-route queue) | ❌ |
| Analytics / error reporting | ✅ (PostHog + Sentry) | ❌ |
| Remote force-update policy | ✅ (`app-update-policy.json`) | ❌ (backend `version-check` exists) |

Their app is a *managed-creator workflow platform* (phase gates: applied → warming up → active). Ours has now caught up on the workflow surfaces too.

### ✅ Done — at parity (built + live-verified where possible)
Sign-in/session · Discover feed · job detail + apply · earnings/wallet · **payout UI** (inert until Stripe keys) · applications · notifications · **brand message threads** (list + chat + composer) · **profile view/edit + photo upload** · delete account · **campaign workspace** (status, brief, contract, content) · **contract e-signing** (verified live end-to-end) · **today's-tasks card** · **campaigns list** (status-grouped + filter pills) · **My Content** (posts, ad codes, sync) · API client hardening (401-retry, cross-project guard).

### ✅ R2 now live (2026-06-11) — uploads fully working
- Cloudflare R2 set up end-to-end: buckets `managed-creators` + `paidpost-videos` created, CORS (GET/PUT) configured, S3 keys in Vercel, redeployed.
- **Verified live**: `creator/videos/upload-url` → 200 presigned URL → real `PUT` to R2 → **200 (upload accepted)**.
- Built the UIs that consume it:
  - **`UploadVideosView`** — slot-based audition upload (presigned PUT → save slot → submit for AI screening), wired into `WorkspaceView`.
  - **`WarmupView`** — daily niche-video URL logging + screen-time screenshot upload for due windows, wired into `WorkspaceView` (accepted/warming_up).
  - Added `APIClient.putFile` (raw R2 PUT) and the upload/warmup/submit methods in `WorkspaceAPI`.

### ⏸ Still keyed-off — light up when keys are added (no code change)
- **Payouts** → Stripe keys (UI built, inert)
- **Posts sync** → RapidAPI keys (My Content UI shows, sync returns empty until then)

### ✅ Closed after direct codebase diff (2026-06-11)
- **Country filter on jobs feed** — `JobsAPI.fetchJobs` now sends `country_iso` (defaults to device region; pass nil for global). Was the one feed-param gap vs. theirs.
- **Languages** — added a Languages field to `EditProfileView` → `PUT creator/languages`.
- **Handle management + suggestions** — `WorkspaceAPI.updateHandles` (`PATCH creator/handles`) and `suggestHandles` (`GET creator/suggest-handles`) added.
- **Unread-count endpoint** — `CreatorAPI.fetchUnreadCount` (`GET notifications/unread-count`) added for a cheap badge.

### 🚫 Out of scope (will not build)
- **Push notifications** — dropped per Shashank. No iOS code, no APNs capability, no `push-token` calls. (Backend endpoints still exist but go unused.)

### ❌ Not done (platform / App-Store work)
- **Deep links / universal links** — needs associated-domain entitlement (pairs with App Store Connect setup)
- **Analytics / error reporting** (PostHog + Sentry) — not wired on the iOS side
- **Remote force-update gate** — backend `version-check` exists, no client gate yet
- **Full warmup/test-video UIs** — see keyed-off above
- **Backend-only endpoints neither app surfaces**: creator course, languages, waitlist, standalone burner-account management, handle suggestions, paid-posts breakdown

---

## 2. Ranked roadmap

### Tier 1 — low effort, endpoints live

1. ✅ **DONE — Real cash-out (payout UI)** — `EarningsView` now has a 3-state button (set up payouts → finish setup → cash out instantly) wired to `creators/stripe-connect` (opens in `SafariView`) and `creators/stripe-payout`, plus a `recent_transactions` ledger. Verified live; the connect call returns the expected `mock-dev` key error until real Stripe keys are set, handled gracefully.
2. ✅ **DONE — Inbox threads (brand messages)** — `InboxAPI` + `InboxView`/`ThreadView` (thread list w/ unread badges, conversation bubbles, composer). Entry point added to `ProfileView`. Verified live against `GET inbox` / `threads/{id}` / `…/read` / `…/messages`.
3. ✅ **DONE — Profile editing + photo** — `EditProfileView` sheet (name/bio/location + `PhotosPicker` → JPEG resize → multipart `creator/profile/picture`). `APIClient` gained multipart support. Verified bio/location round-trip live.
4. ✅ **DONE — Today's-tasks card** — `TodaysTasksCard` on Discover home; derives "sign contract" / "upload videos" actions from `applications` + `managed-status`, deep-links into ContractView / WorkspaceView. Hidden when empty.

Also done in this pass:
- **API client hardening** — 401 → refresh-and-retry-once + cross-project session guard.
- ✅ **Campaign workspace** (`WorkspaceView`) — per-brand hub showing status, brief (portal_config), contract section, reference videos, and a "My content" entry; unlocks tabs by managed-creator status. Verified live: managed-status → workspace → portalConfig present.
- ✅ **Contract e-signing** (`ContractView`) — read + signer-name signature → `applications/{id}/contract/sign`. **Verified live end-to-end** (signature persisted with timestamp + signer name).
- ✅ **Campaign brief reader** — rendered inside WorkspaceView from `portalConfig.content` + reference videos.
- ✅ **My content** (`MyContentView`) — posts list with views/earnings, ad-code entry (`PATCH posts/{id}/ad-code`), and per-platform sync (`posts/sync`). Sync returns data once RapidAPI keys are set.

### Tier 3 status — still deferred (need keys)

- **Warmup evidence** & **test-video auditions** — `WorkspaceAPI` has the endpoints typed, but the upload UIs are deferred until R2 keys exist (presigned-PUT flow can't work without them). The "upload videos" task routes to the workspace as a placeholder for now.
- **Posts sync** surfaces in `MyContentView` but returns empty until RapidAPI keys are set.

### Tier 2 — medium effort, high product value

5. **Campaign brief reader** — render the job's `portal_config` content (V2 structured / V3 markdown) + reference videos in job detail. `GET creator/workspace/{brandSlug}`, `GET brands/{orgId}/reference-videos`.
6. **Contract e-signing** — one screen: contract text + signer-name field. `POST applications/{id}/contract/sign`.
7. ~~Push notifications~~ — **dropped, out of scope.**
8. **Universal links** — associated domain + route translation (`/job/{slug}` → job detail, `/portal/{slug}` → workspace). They queue the route if signed out and consume it after sign-in (`lib/pending-route.ts`) — copy that pattern.
9. **Analytics + crash reporting** — PostHog iOS SDK with their event names (`USER_SIGNED_IN`, `JOB_APPLY_SUBMITTED`, …, see `8x-mobile/lib/analytics/`) so funnels match web; Sentry for crashes.

### Tier 3 — the big lifts (their moat; ~1–2 weeks each)

10. **Campaign workspace** — per-brand hub with phase-aware tabs (Overview / Content / Details). `GET creator/managed-status` (campaign list), `GET creator/workspace/{brandSlug}` (everything: status, contract, portal config, tracked platforms, resources).
11. **Warmup evidence** — daily niche-video URL + screen-time screenshot uploads, AI-verified server-side. `GET creator/warmup/{brandSlug}`, `POST …/daily-warmup-updates`, `POST …/screenshot/upload-url` → direct PUT to R2 → `POST …/screenshot`. Needs **R2 keys**.
12. **Test-video auditions** — 3 slots, presigned R2 PUT, then `POST creator/videos` (save slot) and `POST creator/submit-application` (kicks AI screening). Needs **R2 keys**.
13. **Posts sync + ad codes** — `GET creator/posts?brandSlug=`, `POST creator/posts/sync` (rate-limited 3/min), `PATCH creator/posts/{id}/ad-code`. Needs **RapidAPI keys** for sync to return anything.

---

## 3. Patterns worth copying from their codebase

- **401 → refresh → retry once** in the API client (`8x-mobile/lib/api/client.ts`) — ours refreshes pre-flight on expiry; add the 401-retry too.
- **Cross-project session guard** — they decode the JWT's project `ref` and drop sessions from a different Supabase project. Cheap safety for us after env changes.
- **Pending deep-link route** stored until after sign-in.
- **Per-user cache clearing on sign-out** (we do the in-memory part; they also clear disk caches).
- **Remote update policy JSON** (`/mobile/app-update-policy.json` served by the web app) instead of hardcoding min versions — pairs with our backend's `version-check`.
- **Presigned-upload helper** with one retry on 5xx and a 120s timeout for videos.

## 4. Their app config (reference)

- Bundle: `social.eightx.app`, scheme `eightx://`, universal links via `applinks:app.8x.social`
- Expo SDK w/ EAS builds; ASC app ID 6762701631; v1.5.0 (build 16)
- Android push channels: `default`, `gigs`, `messages`, `payments`
- Sentry project `8x-creators`; PostHog shared event taxonomy with web

---

## 5. Suggested order of attack for PaidPost

1. Tier 1 items 1–3 (a focused day: payout UI, inbox threads, profile edit)
2. Deep links / universal links (needs App Store Connect / associated-domain entitlement — do alongside the App Store record)
3. Brief reader + contract signing (unlocks the "managed creator" journey end-to-end)
4. Workspace/warmup/test-videos only after R2 keys exist and real campaigns need them
