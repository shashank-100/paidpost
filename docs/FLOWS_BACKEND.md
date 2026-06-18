# Backend Flows

All distinct flows in the PaidPost backend (`paidpost-backend`, repo: `github.com/shashank-100/paidpost-backend`). Stack: **Next.js App Router + Supabase + Stripe**, deployed on Vercel. A "flow" is a coherent set of API routes / server actions / background jobs serving one user journey or system process.

> Note: route paths and tables below are derived from the actual code under `app/api/**`, `lib/**`, and `supabase/**` (see the local checkout). External-integration and table lists reflect the dominant case per flow.

| # | Flow | Primary Routes | Key Tables | External Integrations |
|---|------|----------------|------------|-----------------------|
| 1 | Auth & Session | `/api/auth/**`, middleware | users, user_identities, admin_members | Supabase Auth, TikTok/IG/GA4 OAuth |
| 2 | Creator Platform Onboarding | `/api/creator-application/**`, `/api/phone-verification/**` | creator_profiles, creator_wallet, phone_verification_attempts | Twilio Verify |
| 3 | Creator Brand Onboarding (Portal) | `/api/portal/**`, `/api/creator/workspace/**` | managed_creators, managed_creator_videos | Anthropic Claude |
| 4 | Social Account Linking | `/api/creator/handles`, `/api/managed-creators/batch` | tiktok/instagram/youtube_accounts, social_accounts, brand_tracked_social_accounts | — |
| 5 | Social Sync Pipeline | `/api/cron/sync-*-periodic`, `supabase/functions/fetch-*` | posts, post_engagement_metrics, managed_creator_posts | RapidAPI, ScrapTik, Apify |
| 6 | Video Processing & AI | `/api/hooks/process-video`, `hash-video` | posts, managed_creator_videos, reference_videos | R2, Groq, Gemini, Anthropic |
| 7 | Warmup Workflow | `/api/creator/warmup/**`, `/api/admin/managed-creators/*/warmup-*` | warmup_activities, warmup_screenshot_submissions | Anthropic Claude |
| 8 | Job/Campaign Creation | `/api/admin/jobs/**`, `/api/admin/campaigns/**` | jobs, brand_campaigns, portal_config | Anthropic Claude, Slack |
| 9 | Applications / Managed Creators | `/api/jobs/**`, `/api/managed-creators/**` | managed_creators, managed_creator_posts, jobs | Anthropic Claude |
| 10 | Payments & Payouts | `/api/stripe/**`, `/api/admin/creator-post-payments/**` | brand_wallet, creator_transactions, managed_creator_posts | Stripe (EU+US), Stripe Connect |
| 11 | Wallet & Subscriptions | `/api/subscription-*`, `/api/creators/wallet` | creator_wallet, creator_transactions, subscription_plans | Stripe |
| 12 | CPM Submission | `/api/cpm/**` | cpm_submissions, cpm_job_enrollments | RapidAPI, ScrapTik, Apify |
| 13 | Analytics & Metrics | `/api/analytics/**`, `/api/cron/sync-ga4`, `detect-stale-posts` | post_engagement_metrics, brand_ga4_connections | GA4, PostHog, RapidAPI/ScrapTik |
| 14 | Messaging & Inbox | `/api/me/inbox`, `/api/admin/messages/**` | messages, admin_message_threads, push_tokens | Inngest, Resend, Slack |
| 15 | Notifications & Alerts | `/api/me/push-tokens`, `/api/webhooks/new-managed-post` | push_tokens, reference_video_alerts | Resend, Slack |
| 16 | Reference Videos | `/api/admin/brands/*/reference-videos/**` | reference_videos, brand_reference_videos_placements | R2, Supabase Storage, Google GenAI |
| 17 | Creator Network & Discovery | `/api/brand/network/**`, `/api/resolve-tiktok-url` | managed_creators, managed_creator_videos | Anthropic Claude |
| 18 | Admin Console Ops | `/api/admin/**` (90+ endpoints) | admin_members, creators, managed_creators, jobs, posts | Anthropic, Slack, Firecrawl |
| 19 | Cron / Background Jobs | `/api/cron/**` | cron_runs, sync_jobs | Vercel Cron, Supabase Edge Functions |
| 20 | Inbound Webhooks | `/api/stripe/**`, `/api/webhooks/**` | brand_wallet, creator_transactions, posts | Stripe, Instagram, TikTok, Slack |
| 21 | Mobile API (iOS) | `/api/mobile/[...path]` | users, push_tokens, managed_creators, posts | Supabase Auth, Stripe |
| 22 | Public API (v1) | `/api/v1/**` | brand_api_keys, brand_tracked_social_accounts, posts | — |
| 23 | Bot Messaging & AI Chat | `/api/bot/process-message` | messages, managed_creators | Anthropic, Gemini, Groq |
| 24 | Content Tracking & Actions | `/api/actions/**`, `/api/admin/track/**`, `/api/brand/track/**` | brand_tracked_social_accounts, posts | — |
| 25 | Health & Monitoring | `/api/health`, `/api/admin/sync-health/**` | cron_runs, sync_jobs, posts | — |
| 26 | Brand Management & Settings | `/api/brand/**` | brand_organizations, brand_members, brand_api_keys | — |
| 27 | User & Profile Management | `/api/user`, `/api/creators/**`, `/api/brands/**` | users, creator_profiles, brand_organizations | PostHog |
| 28 | Discovery & Waitlist | `/api/waitlist/**`, `/api/feedback`, `/api/book-call` | waitlist_signups, feedback | — |
| 29 | Dev & Testing | `/api/dev/**`, `/.well-known/**` | users | — |

---

## 1. Authentication & Session Management
**Routes:** `/api/auth/{tiktok,instagram,ga4}/{connect,callback}`, `/api/auth/confirm` · **Libs:** `lib/supabase/server.ts`, `lib/auth/middleware.ts`

OAuth for TikTok/Instagram/YouTube/GA4 with CSRF state tokens; session refresh & JWT verification (Supabase cookies on web, raw JWT on mobile); identity mapping via `user_identities` (legacy Clerk→Supabase migration); admin impersonation via OTP tokens with Slack audit logging.

## 2. Creator Platform Onboarding
**Routes:** `/api/creator-application/**`, `/api/phone-verification/{send,verify}` · **Libs:** `lib/modules/onboarding/*`, `lib/modules/phone-verification/*`

2–3 step onboarding (user-type → personal-info → terms; discovery optional). Phone verification via Twilio Verify with rate limits (3/24h per user, 6/1h per IP, 5/24h per phone). Creates `creator_profiles` + `creator_wallet`, country detection, referral tracking, auto-linking to jobs by email/referral.

## 3. Creator Brand Onboarding (Portal)
**Routes:** `/api/portal/[brandSlug]`, `/api/creator/workspace/[brandSlug]` · **Libs:** `lib/modules/portal/{actions,queries}.ts`, `lib/modules/managed-creators/*`

`initOnboarding()` creates a `managed_creators` row (`applied`, sourced `portal`); creator watches intro video, picks reference format, uploads test videos to `managed_creator_videos`. `submitApplication()` runs video-hash validation (blocks duplicates vs reference videos) and triggers AI screening (`/api/hooks/screen-submission`). Status advances `applied → test_videos_submitted → warming_up`; Slack notifies admins.

## 4. Social Account Linking
**Routes:** `/api/creator/handles`, `/api/managed-creators/batch`, `/api/creator/posts/sync` · **Libs:** `lib/db/social-accounts.ts`, `lib/db/tracked-social-accounts.ts`

Three entry points: (1) portal saves usernames as plain text (no platform FK, invisible to sync until admin batch-adds); (2) admin batch create builds the full chain — platform account → `social_accounts` connector → MC platform FK → `brand_tracked_social_accounts`; (3) brand UI tracking auto-creates a connector + BTSA. Initial backfill triggered immediately.

## 5. Social Account Sync Pipeline
**Routes:** `/api/cron/sync-backfill`, `/api/cron/sync-{tiktok,instagram,youtube}-periodic` · **Edge fns:** `supabase/functions/fetch-{tiktok,instagram,youtube}-*`

**Backfill:** picks `backfill_status='in_progress'` accounts, paginates full history (≈140s timeout, cursor resumption). **Periodic:** tiers by frequency (active TikTok 4h / IG-YT 6h; passive 48h; reduced 24h), full or quick mode. Edge functions call RapidAPI/ScrapTik/Apify and UPSERT `posts` + `post_engagement_metrics`; a DB trigger auto-creates `managed_creator_posts` with snapshotted pay config. Tracks `consecutive_sync_failures` and alerts via Slack past a threshold.

## 6. Video Processing & AI Analysis
**Routes:** `/api/hooks/{process-video,hash-video,process-reference-video,screen-submission}` · **Libs:** `lib/video/*`, `lib/storage/r2.ts`

Reactive (pg_net on post INSERT): download → R2; transcribe (Groq Whisper) → `posts.transcript`; analyze (Gemini hygiene + summary) → `posts.video_summary`/`video_hygiene_checks`; replication review vs top-5 brand reference videos. Up to 5 retries, per-step progress saved, creator notified of AI feedback (skipped during backfill).

## 7. Creator Warmup Workflow
**Routes:** `/api/creator/warmup/[brandSlug]/{route,screenshot,scroll,daily-warmup-updates}`, `/api/admin/managed-creators/[id]/warmup-*` · **Libs:** `lib/modules/warmup/*`

Post-test-videos, pre-active audience-building. Daily: scroll feeds, submit niche video URLs, post screenshots (AI-verified via Anthropic for authenticity/compliance). Flagged screenshots go to an admin approve/reject queue. Auto-advance to `active` once the warmup window completes.

## 8. Job / Campaign Creation & Management
**Routes:** `/api/admin/jobs/{create,generate-portal-config,ai-edit-portal-config,...}`, `/api/admin/campaigns/**`, `/api/jobs/{route,by-slug}` · **Libs:** `lib/modules/jobs/*`, `lib/modules/portal/config.ts`

Admin sets title/description/countries/platforms/pay (flat or CPM)/bonus milestones/visibility. Claude generates and refines per-locale portal configs (SSE streaming). CPM pay = rate×views/1000; flat splits base pay across platforms. Optional per-job Slack channel.

## 9. Applications (legacy) / Managed Creators (primary)
**Routes:** `/api/jobs/[jobId]/{apply,applicants,applications}` (sunsetting), `/api/managed-creators/{batch,[id]/...}`, `/api/managed-creator-invites` · **Libs:** `lib/modules/managed-creators/*`

`managed_creators` is the primary creator↔brand relationship. Lifecycle `applied → test_videos_submitted → warming_up → active` (→ ghosted/unclear/dropped). Entry via portal apply, admin batch (`8x_feed`), invite token, or email auto-link. Per-MC pay snapshot (`base_pay_cents`, `cpm_rate`, `max_pay_cents`, `bonus_milestones`); job reassignment reprices all posts; advance balance deducted from earnings.

## 10. Payment & Payout Processing
**Routes:** `/api/stripe/{checkout,webhook,webhook-us,...}`, `/api/admin/creator-post-payments/{list,pay,verify,update-base}`, `/api/admin/payouts/[creatorId]/add-funds`, `/api/creators/stripe-*` · **Libs:** `lib/payments/*`

**Deposit:** brand → Stripe Checkout (fee pass-through `(desired+$0.40)/(1−0.035)`), webhook → idempotent `brand_transactions` → `atomic_wallet_deposit()` credits `brand_wallet`. **Calc:** sync trigger → `create_managed_creator_post()` computes CPM/flat + snapshots. **Pay:** admin selects approved posts → `process_post_payment()` (applies advance, creates Stripe Transfer to Connect account, writes `creator_transactions` IOU), batched per creator. **Receive:** Stripe payout → `transfer.created`/`payout.created` webhooks update `payout_status`. Dual region: EU (default) + US (`webhook-us`).

## 11. Creator Wallet & Subscriptions
**Routes:** `/api/subscription-{plans,status,history}`, `/api/stripe/checkout`, `/api/creators/wallet`, `/api/creators/wallet/paid-posts` · **Libs:** `lib/modules/billing/*`, `lib/payments/*`

`creator_transactions` is the single-source earnings ledger (earnings/advance/bonus/withdrawal). Balance via `get_creator_balance()` RPC. Brand subscriptions (legacy recurring billing) + wallet top-ups → `brand_wallet`.

## 12. CPM Submission Workflow
**Routes:** `/api/cpm/{campaigns,jobs,submissions,stats,enrollment}` · **Libs:** `lib/modules/cpm/*`

Pay-per-view alternative to managed creators. Creator enrolls and submits multiple video URLs (`cpm_submissions`); edge functions fetch post data → views → `projected_earnings`. Creator dashboard shows pending/past submissions; admin tracks sync + view counts.

## 13. Analytics & Metrics Tracking
**Routes:** `/api/analytics/**`, `/api/admin/brands/[brandId]/analytics/**`, `/api/cron/{sync-cpm-views,detect-stale-posts,backfill-video-storage}` · **Libs:** `lib/modules/analytics/*`, `lib/modules/ga4/*`

`post_engagement_metrics` time-series (views/likes/comments/shares/saves) aggregated per creator and brand; chart windows 7/30/90d; stale-post detection; video backfill to R2; daily GA4 website sync; PostHog product analytics proxied via `/ph/*`.

## 14. Messaging & Inbox
**Routes:** `/api/me/inbox`, `/api/me/threads/[brandId]/{messages,read}`, `/api/admin/messages/{list,[threadKey],[threadKey]/reply,bulk}` · **Libs:** `lib/messaging/*`, `lib/modules/messaging/*`

One thread per (user, brand). Message types: creator-sent, admin-reply, system events (APPLICATION/ACCEPTED/PAID…). Per-thread unread counts. Admin bulk messaging fans out via Inngest (≤5000 recipients). Messages trigger push (`push_tokens`), email (Resend), Slack admin alerts.

## 15. Notifications & Alerts
**Routes:** `/api/me/push-tokens/[token]`, `/api/me/{reference-video-alerts,has-weekly-reference-videos}`, `/api/webhooks/new-managed-post` · **Libs:** `lib/notifications/*`

Push tokens stored & sent via Resend/Slack; weekly reference-video digest; new-managed-post DB webhook → Slack; sync-failure & critical-error alerts; video-review notifications.

## 16. Reference Videos Management
**Routes:** `/api/admin/brands/[brandId]/reference-videos/{list,create,update,delete,upload-url}`, `/api/hooks/process-reference-video` · **Libs:** `lib/video/process-reference-video.ts`

Admin uploads brand reference videos (transcript, music, on-screen text, disclaimer, labels, job assignments) to R2/Supabase Storage; processing generates BLIP captions into `reference_videos`. Used in portal format-picking and the replication check.

## 17. Creator Network & Discovery
**Routes:** `/api/brand/network/{applicants,videos,contact}`, `/api/creator/suggest-handles`, `/api/resolve-tiktok-url`, `/api/example-videos`

Brand browses applicants/videos/contacts; AI handle suggestions; TikTok/Instagram URL→username resolution for batch import; curated example videos.

## 18. Admin Console Operations
**Routes:** `/api/admin/**` (~90+ endpoints across ~28 subgroups: accounts, creators, managed-creators, creator-post-payments, brands, jobs, sync-health, video-reviews, dashboard, lookup, team-members, attribution, referrals, stats)

Team management & roles (super_admin > senior_account_manager > account_manager > sales_rep); creator/managed-creator ops (invites, videos, warmup, reassign, cascade-pay); payment review/pay/verify/override; brand create/enrich (Firecrawl)/invite/Slack; job creation + Claude portal config; sync-health monitoring; video-review queue; dashboards; data-repair tools; OTP impersonation (Slack-audited).

## 19. Cron Jobs & Background Processing
**Routes:** `/api/cron/{sync-*-periodic,sync-backfill,sync-ga4,sync-cpm-views,monitor-storage,detect-stale-posts,backfill-video-storage,backfill-managed-ig-yt-video}` (schedules in `vercel.json`)

Batch social fetches via Edge Functions; daily GA4; CPM view sync; R2 storage monitoring; stale-post detection; video backfill. `cron_runs` tracks execution/timeouts/failures with stuck-run recovery and Slack alerts.

## 20. Inbound Webhooks
**Routes:** `/api/stripe/{webhook,webhook-us}`, `/api/webhooks/{instagram,tiktok,new-managed-post}`

Stripe: `checkout.session.completed` (deposit), `account.updated` (Connect), `customer.subscription.*`, `invoice.*`, `transfer.*`, `payout.*`. Platform: IG data-deletion/deauth, TikTok verification. DB: new managed post → Slack.

## 21. Mobile API (iOS)
**Routes:** `/api/mobile/[...path]` (single catch-all, ~70 handlers) · **Libs:** `lib/mobile/handlers.ts`, `lib/mobile/auth.ts`

Bearer Supabase JWT verified server-side; auto-provisions `users` + `user_identities` on first login; fixed test email/code for Apple review (gated by `is_test_account`). Handlers cover jobs feed/apply/applications, profile & wallet, push tokens, notifications & inbox, posts & ad codes, tasks, warmup timeline & screenshots, burner accounts, version check, account deletion. CORS restricted to known origins; native (no Origin) passes.

## 22. Public API (v1)
**Routes:** `/api/v1/{posts,accounts,posts/[postId]/metrics}` · **Libs:** `lib/api/v1.ts`

`brand_api_keys` auth + request signing; per-key rate limits in `brand_api_rate_limit_counters`. Lists posts/accounts for tracked accounts and post metrics history with standard pagination.

## 23. Bot Messaging & AI Chat
**Routes:** `/api/bot/process-message` (internal, `BOT_INTERNAL_SECRET`) · **Libs:** `lib/bot/{llm,context,history}.ts`

Triggered by creator messages via `after()`. Fetches brand context + MC status + recent messages, routes to Anthropic/Gemini/Groq, inserts reply into the thread, notifies brand.

## 24. Content Tracking & Actions
**Routes:** `/api/actions/posts`, `/api/admin/track/{accounts,posts}`, `/api/brand/track/**`

Bulk approve/reject posts and change tracking status; track/untrack/freeze accounts, assign to campaigns; platform-specific TikTok/IG/YouTube tracking endpoints.

## 25. Health & Monitoring
**Routes:** `/api/health`, `/api/admin/sync-health/**`, `/api/admin/dashboard/{feed,managed-summary,video-breakdown}`

Liveness 200; sync-pipeline stats (failures, account/post processing, video throughput, storage backlog, daily stats); admin dashboards.

## 26. Brand Management & Settings
**Routes:** `/api/brand/{settings,applicants,invites/*,guide-overrides,api-keys/*,posts,resources/*}`

Invite roles & onboarding config; applicant lists; brand member invites & support requests; portal guide overrides; API-key management (v1); brand resource templates.

## 27. User & Profile Management
**Routes:** `/api/user`, `/api/user/posthog-identify`, `/api/creators/[id]`, `/api/brands/by-slug/[slug]`, `/api/team/*`

Current-user profile get/update; public creator/brand lookups; PostHog identify; brand team membership.

## 28. Discovery & Waitlist
**Routes:** `/api/waitlist/{join,me}`, `/api/feedback`, `/api/book-call`

Pre-launch waitlist signup/status; anonymous feedback; demo-call booking.

## 29. Development & Testing
**Routes:** `/api/dev/{otp,session}`, `/.well-known/{apple-app-site-association,assetlinks.json}`

Dev-only OTP/session generation; Apple/Android App Links for mobile verification.

---

## Cross-cutting Architecture Notes
- **DB-driven workflows:** triggers auto-create related rows (e.g. `managed_creator_posts` on post INSERT).
- **Cron + Edge Functions:** Vercel Cron schedules; Supabase Edge Functions scrape platforms.
- **Async:** Inngest for bulk messaging; `after()` for fire-and-forget bot replies.
- **Atomicity:** payment/balance logic enforced in Postgres RPCs.
- **Feature flags:** PostHog selects scraper/provider per account.
- **Dual-region payments:** separate Stripe EU + US accounts with independent webhooks.
- **RLS:** Supabase Row-Level Security across the schema; service-role clients enforce authorization in application code.
