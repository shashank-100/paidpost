# API Reference

All HTTP endpoints exposed by the backend (`app/api/**`). Paths use `{param}` for dynamic segments. Generated 2026-06-10.

## Contents

- [Admin](#apiadmin) — internal admin console APIs
- [Auth, Users & Creators](#apiauth) — auth, profile, mobile (iOS), creator-side APIs
- [Brands, Jobs & Billing](#apibrand) — brand console, jobs, Stripe, subscriptions
- [Infrastructure & Integrations](#apicron) — cron, webhooks, analytics, social sync, public v1 API

## Admin

# Admin API Endpoints (Part 1: subdirectories a–i)

Auth legend:
- **Admin session** — `getUser()` Supabase session + `users.account_type = 'admin'` check (service-role client for queries).
- **Super admin** — Admin session plus `admin_members.admin_role = 'super_admin'` (or `ACCOUNTS_ROLES` via `hasAccess`).
- **Payouts role** — Admin session plus `getAdminRole` ∈ `PAYOUTS_ROLES` (`super_admin`, `senior_account_manager`).
- **Admin member** — session + row in `admin_members` (no explicit `account_type` check).
- Scoped roles = `account_manager`, `sales_rep` (`SCOPED_ROLES`); some routes filter or reject them.

### `/api/admin/accounts`

| Method | Path | Auth | Description |
|---|---|---|---|
| POST | `/api/admin/accounts/add` | Super admin | Adds an admin team member by email with a role; body: `{email, role}` (role must be in `ADMIN_ROLES_ORDERED`) |
| DELETE | `/api/admin/accounts/remove` | Super admin | Removes an admin member; body: `{userId}`; blocks self-removal |
| PATCH | `/api/admin/accounts/update-brands` | Super admin (`ACCOUNTS_ROLES`) | Sets the brand scope for an admin member; body: `{userId, brandIds[]}` (UUIDs, max 200); returns `{ok}` |
| PATCH | `/api/admin/accounts/update-jobs` | Super admin (`ACCOUNTS_ROLES`) | Sets the job scope (`admin_members.job_ids`) for an admin member; body: `{userId, jobIds[]}`; returns `{ok}` |
| PATCH | `/api/admin/accounts/update-role` | Super admin | Changes an admin member's role; body: `{userId, newRole}`; blocks self-role-change |

### `/api/admin/activity`

| Method | Path | Auth | Description |
|---|---|---|---|
| GET | `/api/admin/activity` | Admin session | User-activity dashboard: today/week/month active counts per account type plus a paginated user list; query: `account_type`, `period` (default `7d`), `page`, `limit` (max 100) |

### `/api/admin/attribution`

| Method | Path | Auth | Description |
|---|---|---|---|
| GET | `/api/admin/attribution` | Admin session | Signup-attribution (UTM) report with aggregates and per-user rows; query: `accountType` (`creator`/`brand_member`/`all`), `range` (e.g. `30d`/`all`), `search`, `from`, `to` |

### `/api/admin/brand-campaigns`

| Method | Path | Auth | Description |
|---|---|---|---|
| GET | `/api/admin/brand-campaigns` | Admin session (scoped roles see only their `job_ids`) | Lists brand campaigns with brand org + job joins; query: `brand_organization_id` |
| PATCH | `/api/admin/brand-campaigns/{campaignId}` | Admin session, scoped roles rejected | Updates campaign fields (allow-listed: `name`, `status`, `country`, `platforms`, `budget_cents`, `target_video_count`, `base_pay_per_video_cents`, `monthly_cap_cents`, bonus milestones, …) |
| DELETE | `/api/admin/brand-campaigns/{campaignId}` | Admin session, scoped roles rejected | Deletes a brand campaign; returns `{success}` |
| GET | `/api/admin/brand-campaigns/{campaignId}/detail` | Admin member (scoped roles only for campaigns in their `job_ids`) | Campaign detail with brand org, job, and per-creator rollup |

### `/api/admin/brands`

| Method | Path | Auth | Description |
|---|---|---|---|
| GET | `/api/admin/brands` | Admin session (scoped roles filtered by `job_ids`) | Lists brand organizations, or single-brand lookup via `?slug=` |
| POST | `/api/admin/brands` | Admin session (scoped creators stamp ownership) | Creates a brand organization; multipart form: `brandName` (required), `website`, `logo` file |
| POST | `/api/admin/brands/enrich` | Admin session (`verifyAdmin`) | Scrapes a brand website (Firecrawl) and summarizes it with Claude to enrich brand profile; body: `{url}` (zod-validated) |
| GET | `/api/admin/brands/{brandId}` | Admin session | Fetches basic brand org info (`id`, name, slug, logo) |
| PATCH | `/api/admin/brands/{brandId}` | Admin session | Updates brand org; JSON (e.g. `eight_x_managed`, admin fields) or multipart (logo upload) depending on content type |
| GET | `/api/admin/brands/{brandId}/details` | Admin session | Brand operations detail: wallet balances, jobs, tracked accounts, applications (parallel fetch) |
| GET | `/api/admin/brands/{brandId}/creators` | Admin session | Paginated creators (job applications) for a brand; query: `page`, `limit` (max 500) |
| GET | `/api/admin/brands/{brandId}/jobs` | Admin session (`verifyAdmin`) | Lists open/in-progress/draft jobs for a brand as option rows (title, type, CPM pay, country, platforms, milestones) |
| GET | `/api/admin/brands/{brandId}/invite` | Admin session | Lists brand invites with joined-member status |
| POST | `/api/admin/brands/{brandId}/invite` | Admin session | Creates a brand member invite; body: `{email, role='member', sendEmail=false, emailMessage?}` |
| GET | `/api/admin/brands/{brandId}/slack-channel` | Admin session | Gets the brand's admin Slack channel ID |
| PATCH | `/api/admin/brands/{brandId}/slack-channel` | Admin session | Sets/clears the Slack channel; body: `{channelId}` (format-validated, null to clear) |
| POST | `/api/admin/brands/{brandId}/slack-channel` | Admin session | Sends a test message to the (optionally provided) Slack channel; body: `{channelId?}` |
| GET | `/api/admin/brands/{brandId}/intro-videos` | Admin session | Paginated creator intro/onboarding videos for review; query: `page`, `limit` (max 100), `filter` (`to_review`/`accepted`/`rejected`), `jobId` |
| GET | `/api/admin/brands/{brandId}/posts-by-date` | Admin session | Posts grouped by date for a brand; query: `from`, `to` (default last 30d), `jobIds`, `countries`, `platforms` |
| GET | `/api/admin/brands/{brandId}/warmup-niche-videos` | Admin session | Paginated warmup niche-video submissions (activity-day rows); query: `page`, `limit` (max 100) |
| GET | `/api/admin/brands/{brandId}/actions/posts` | Admin session + origin validation | Action items (posts to review) for a brand; query: `limit` (max 100), `offset`, `platform`, `account`, `campaign`, `status` (`pending`/`reviewed`), `sort` |
| GET | `/api/admin/brands/{brandId}/reference-videos` | Admin session (local `verifyAdmin`) | Paginated/filterable brand reference videos; query: `page`, `limit` (max 500), `placement`, `archived`, `active_now`, `search`, `job_id`, `sort` |
| POST | `/api/admin/brands/{brandId}/reference-videos` | Admin session (local `verifyAdmin`) | Creates a reference video; zod body: `storage_path`/`video_url`, `transcript`, `notes`, `music`, `onscreen_text`, `disclaimer`, promotion flags, labels, `job_ids`, … |
| PATCH | `/api/admin/brands/{brandId}/reference-videos` | Admin session (local `verifyAdmin`) | Partially updates a reference video; zod body: `{id, ...fields}` (only keys explicitly sent are updated) |
| DELETE | `/api/admin/brands/{brandId}/reference-videos` | Admin session (local `verifyAdmin`) | Deletes a reference video (and its storage object); query: `?id=` |
| GET | `/api/admin/brands/{brandId}/reference-videos/upload-url` | Admin session (`verifyAdmin` re-exported from reference-videos route) | Returns a signed Supabase Storage upload URL; query: `ext` (`mp4`/`mov`/`webm`) |
| POST | `/api/admin/brands/{brandId}/analytics/fetch` | Admin session | Triggers metric refresh via Supabase edge functions; body: `{type: 'accounts'|'posts', ids[]}`; returns per-id results |
| GET | `/api/admin/brands/{brandId}/analytics/sync-status` | Admin session + origin validation | Sync status for the brand's tracked accounts (account IDs via query params) |
| GET | `/api/admin/brands/{brandId}/analytics/reference-videos` | Admin session | Reference-video performance heatmap; query: `window` (`7d`/`30d`/`90d`/`all`, default `30d`) |
| GET | `/api/admin/brands/{brandId}/analytics/posts/{postId}/metrics` | Admin session | Metrics history for a single post |
| DELETE | `/api/admin/brands/{brandId}/track/accounts/{accountId}` | Admin session | Untracks a social account from the brand (resolves platform first) |
| PUT | `/api/admin/brands/{brandId}/track/accounts/campaign` | Admin session | Bulk-assigns tracked accounts to a campaign; body: `{accountIds[], campaign}` |
| DELETE | `/api/admin/brands/{brandId}/track/accounts/campaign` | Admin session | Removes a tracked account's campaign assignment; body: `{accountId}` |

### `/api/admin/campaigns`

| Method | Path | Auth | Description |
|---|---|---|---|
| GET | `/api/admin/campaigns` | Admin session (`verifyAdmin`) | Campaign-ops list for 8x-managed brands: one row per `brand_campaign` plus live counts from `get_campaign_ops_counts` RPC |
| POST | `/api/admin/campaigns/setup` | Admin session (`verifyAdmin`) | Sets up campaigns for a brand (creates brand if needed, flags `eight_x_managed`); zod body: `{brand{id?|name}, countries[], platforms[], context?}` |
| PATCH | `/api/admin/campaigns/{brandCampaignId}` | Admin session (`verifyAdmin`) | Updates campaign-ops fields (phase/status, owner/AM/content-lead/comms/sourcer user IDs, notes, dates) and brand-level fields (`company_brief`, `context`, …) |

### `/api/admin/country-pricing`

| Method | Path | Auth | Description |
|---|---|---|---|
| GET | `/api/admin/country-pricing` | Admin member | Lists active `country_pricing_tiers` (base pay, suggested charge, monthly cap, bonus milestones) ordered by tier and country |

### `/api/admin/creator-enrichment`

| Method | Path | Auth | Description |
|---|---|---|---|
| GET | `/api/admin/creator-enrichment` | Admin session | Cross-brand enrichment for a creator: other job applications and posts; query: `creator_profile_id` or `managed_creator_id` (one required) |

### `/api/admin/creator-post-payments`

| Method | Path | Auth | Description |
|---|---|---|---|
| GET | `/api/admin/creator-post-payments` | Admin session | Paginated managed-creator post payments; query: `page`, `limit` (max 100), `status`, `brand_id`, `job_id`, `creator_id`, `search`, `hide_settled`, `review_status`, `group_by` |
| GET | `/api/admin/creator-post-payments/{id}` | Admin session | Payment detail for one `managed_creator_posts` row (nested creator + post data, pay/bonus breakdown) |
| POST | `/api/admin/creator-post-payments/pay` | Admin session + payouts role | Processes payments for selected posts (`process_post_payment` RPC → Stripe transfer → emails); body: `{managed_creator_post_ids[], offplatform_method?, override_contract_check?, override_disclosure_check?}` |
| POST | `/api/admin/creator-post-payments/update-base` | Admin session + payouts role | Batch-overrides `base_pay_cents` and/or `bonus_cents` and recomputes owed/status; body: `{managed_creator_post_ids[] (max 500), base_pay_cents?, bonus_cents?}` |
| POST | `/api/admin/creator-post-payments/verify` | Admin session + payouts role | Verifies posts are still live via TikTok/Instagram scraper APIs (auto-verify window 6h, max 500 posts); body: `{managed_creator_post_ids[]}`; per-post result `verified`/`not_found`/`error` |

### `/api/admin/creators`

| Method | Path | Auth | Description |
|---|---|---|---|
| GET | `/api/admin/creators` | Admin session | Lists creator profiles; query: `available_countries=true` (returns countries via RPC), `export=true` (full export), plus list filters |
| POST | `/api/admin/creators` | Admin session | Creates a creator profile; body: `{display_name (required), first_name, last_name, notes, user_id?, location, phone, email}` |
| GET | `/api/admin/creators/{id}` | Admin session | Full creator detail (profile or managed-creator fallback); query: `source` |
| PATCH | `/api/admin/creators/{id}` | Admin session | Updates a creator profile (allow-listed fields only) |
| POST | `/api/admin/creators/{id}/bonus` | Admin session + payouts role | Grants a one-off bonus payment; body: `{amount_cents (positive int), description, offplatform_method?}` |
| POST | `/api/admin/creators/{id}/managed-creator` | Admin session | Creates a managed-creator record linked to the creator profile; body: `{brand_organization_id, job_id}` (both required) |
| POST | `/api/admin/creators/{id}/assign-job` | Admin session | Assigns the creator to a job (creates application); body: `{job_id}` |
| GET | `/api/admin/creators/{id}/assign-job` | Admin session | Lists the creator's job applications with statuses |

### `/api/admin/dashboard`

| Method | Path | Auth | Description |
|---|---|---|---|
| GET | `/api/admin/dashboard/feed` | Admin session | Recent-activity feed (last 7 days): applications, CPM posts, new brands, new users, managed accounts |
| GET | `/api/admin/dashboard/managed-summary` | Admin session | Summary of 8x-managed brands (targets, budgets by market) |
| GET | `/api/admin/dashboard/video-breakdown` | Admin session | Per-managed-brand video count breakdown |

### `/api/admin/generate-otp`

| Method | Path | Auth | Description |
|---|---|---|---|
| POST | `/api/admin/generate-otp` | `requireAdminRole('account_manager')` (blocks `sales_rep`) | Generates a user-impersonation OTP link; body: `{email, reason (required, ≤500 chars)}`; blocks impersonating admins, posts a Slack audit alert; returns `{url}` |

### `/api/admin/inspector`

| Method | Path | Auth | Description |
|---|---|---|---|
| GET | `/api/admin/inspector/account/{id}` | Admin session | Resolves a social account and returns `{account, relationships, posts}` |
| POST | `/api/admin/inspector/actions` | Admin session; non-dry-run writes require `super_admin`/`senior_account_manager` | Runs an inspector data-repair action; body: `{action, dryRun=true, payload{}}` |
| GET | `/api/admin/inspector/post/{id}/engagement` | Admin session | Engagement history time series for a post; returns `{history}` |
| GET | `/api/admin/inspector/search-mcs` | Admin session | Searches managed creators with embedded social-account FK status; query: `q`, `platform` (`tiktok`/`instagram`/`youtube`), `linked_user_id` |

# Admin API Endpoints (Part 2: subgroups j–z)

Auth legend: **Admin session** = authenticated Supabase user (`getUser()`) with `users.account_type = 'admin'`, checked inline or via `verifyAdmin()` (`lib/modules/admin/api-middleware`) / `requireAdmin()` (`lib/admin/lookup/auth`). All handlers then use the Supabase service-role client.

### `/api/admin/jobs`

| Method | Path | Auth | Description |
|---|---|---|---|
| GET | `/api/admin/jobs` | Admin session | Paginated job list with brand org + applicant counts; query: `page`, `limit`, `brands`, `countries`, `search`, or `available_brands=true` / `available_countries=true` for filter dropdowns. Returns `{data, total, page, limit, totalPages}` |
| POST | `/api/admin/jobs` | Admin session; scoped roles (account_manager, sales_rep) must own the target brand | Creates a CPM job plus linked campaign via `admin_create_job_with_campaign` RPC; body: `{brand_organization_id, job_title, description, campaign{base_pay_per_video_cents,...}, platforms_required?, visibility?, status?, faqs?, media?, portal_config?, ...}`. Returns `{success, job_id, job_slug}` |
| GET | `/api/admin/jobs/{jobId}` | Admin session | Fetches a single job (title, slug, description, visibility) with its brand organization |
| POST | `/api/admin/jobs/{jobId}/ai-edit-portal-config` | Admin session | Edits an existing portal config JSON with Claude per admin instructions; body: `{instructions, currentConfig}` (handles legacy and v4 configs). Returns `{portalConfig}` |
| GET | `/api/admin/jobs/{jobId}/portal-config` | Admin session | Returns the job's stored `portal_config` JSON |
| PUT | `/api/admin/jobs/{jobId}/portal-config` | Admin session | Replaces the job's `portal_config`; body: `{portalConfig}`; auto-assigns the job to account-manager admins' `job_ids` |
| GET | `/api/admin/jobs/{jobId}/slack-channel` | Admin session | Returns the job's Slack channel ID and title: `{channelId, jobTitle}` |
| PATCH | `/api/admin/jobs/{jobId}/slack-channel` | Admin session | Sets or clears the job's Slack channel; body: `{channelId}` (format `C0123456789` or null) |
| PATCH | `/api/admin/jobs/{jobId}/transcript` | Admin session | Updates the job's sales-call transcript; body: `{transcript}` (empty string clears it) |
| GET | `/api/admin/jobs/eight-x-managed` | Admin session | Lists jobs belonging to 8x-managed brand organizations (`{jobs: [{id, job_title, status, brand_name, country}]}`) |
| POST | `/api/admin/jobs/generate-portal-config` | Admin session | Generates a full portal config from brand context using Claude, streamed as SSE (`progress`/`done`/`error` events); body: `{context, countries, mode, platforms, basePayDollars, bonusTiers?, currency?, accessCode?, referenceConfig?, version?}` |

### `/api/admin/jobs-with-managed-creators`

| Method | Path | Auth | Description |
|---|---|---|---|
| GET | `/api/admin/jobs-with-managed-creators` | Admin session | Filter data for the creator post payments page: all brands and jobs. Returns `{brands: [{id, name}], jobs: [{id, job_title, brand_id, status}]}` |

### `/api/admin/lookup`

| Method | Path | Auth | Description |
|---|---|---|---|
| POST | `/api/admin/lookup/account/{socialAccountId}/force-sync` | Admin session (`requireAdmin`) | Forces a full account sync: resolves linked platform account, creates a `sync_jobs` row, invokes the platform edge function. Returns `{ok, syncJobId, platform, username}` |
| POST | `/api/admin/lookup/post/{postId}/check-live` | Admin session (`requireAdmin`) | Re-fetches a post via edge function and reports whether it is still live: `{stillLive, viewCount, deltaViews, fetchedAt, edgeOk, unavailableReason}` |
| POST | `/api/admin/lookup/post/{postId}/force-sync` | Admin session (`requireAdmin`) | Forces a single-post sync (creates a `sync_jobs` row, invokes the post-data edge function). Returns `{ok, syncJobId, viewCount}` |
| POST | `/api/admin/lookup/post/{postId}/reprocess-media` | Admin session (`requireAdmin`) | Resets video processing/storage markers on a post and re-invokes the post-data edge function so media is re-downloaded and AI re-run |

### `/api/admin/managed-creators`

| Method | Path | Auth | Description |
|---|---|---|---|
| GET | `/api/admin/managed-creators` | Admin session | Paginated list of managed creators across all brands; query: `page`, `limit`, `status`, `brand_id`, `search` (name/email/social handles) |
| PATCH | `/api/admin/managed-creators` | Admin session | Bulk status update; body: `{ids: string[] (max 200), status}` (accepted/warming_up/active/ghosted/unclear). Returns `{success, updated}` |
| POST | `/api/admin/managed-creators/advance-balances` | Admin session | Returns advance balances for up to 100 creators; body: `{managed_creator_ids: string[]}` → `{[id]: advance_balance_cents}` |
| GET | `/api/admin/managed-creators/{id}` | Admin session | Fetches a single managed creator record (pay, payment status, onboarding flags, etc.) |
| PATCH | `/api/admin/managed-creators/{id}` | Admin session | Updates `advance_balance_cents`, `slack_user_id`, `notes`, and/or `job_id` (same-brand guard; snapshots job base pay/milestones); audit-logged, Slack-notified on advance change |
| POST | `/api/admin/managed-creators/{id}/cascade-pay` | Admin session | Cascades the creator's current pay config to all their posts via `cascade_pay_config_to_posts` RPC; returns updated count + undo snapshot |
| GET | `/api/admin/managed-creators/{id}/details` | Admin session | Full detail bundle: creator, profile, social accounts, recent posts with metrics, other campaigns, transactions, applications |
| POST | `/api/admin/managed-creators/{id}/invite` | Admin session | Generates a 7-day sign-up invite link for an unlinked creator; returns `{invite: {url, expiresAt, creatorName}}` |
| GET | `/api/admin/managed-creators/{id}/onboarding-videos` | Admin session | Lists onboarding videos (DB table first, then R2/Supabase storage fallback) with signed URLs |
| POST | `/api/admin/managed-creators/{id}/onboarding-videos` | Admin session | Registers an already-uploaded onboarding video; body: `{storage_path}` (file must be uploaded to R2 via presigned URL first) |
| DELETE | `/api/admin/managed-creators/{id}/onboarding-videos` | Admin session | Deletes a video from storage; query: `?path=...` (path must belong to the creator) |
| GET | `/api/admin/managed-creators/{id}/onboarding-videos/upload-url` | Admin session | Returns an R2 presigned upload URL; query: `?ext=mp4|mov|webm` → `{signedUrl, storagePath}` |
| GET | `/api/admin/managed-creators/{id}/posts` | Admin session (`verifyAdmin`) | Lists the creator's posts with metrics across their accounts; query: `limit` (max 100), `offset`. Returns `{data, base_pay, accounts, total?, hasMore?}` |
| POST | `/api/admin/managed-creators/{id}/reassign-job` | Admin session (`verifyAdmin`) | Reassigns the creator to another job via `reassign_managed_creator_job` RPC (re-prices posts, updates BTSA); body: `{target_job_id}`; audit-logged + notifies creator |
| POST | `/api/admin/managed-creators/{id}/reassign-job/preview` | Admin session (`verifyAdmin`) | Dry-run of a job reassignment via `preview_reassign_managed_creator_job` RPC; body: `{target_job_id}` |
| POST | `/api/admin/managed-creators/{id}/reprice-posts` | Admin session (`verifyAdmin`) | Re-prices unpaid/excluded posts to match the creator's current base pay and bonus milestones; returns `{updated}`; notifies creator |
| GET | `/api/admin/managed-creators/{id}/warmup-niche-videos` | Admin session (`verifyAdmin`) | Lists niche video URLs submitted during warmup, with detected platform per activity date |
| GET | `/api/admin/managed-creators/{id}/warmup-screenshots` | Admin session (`verifyAdmin`) | Lists warmup screenshot submissions split into `{flaggedForReview, others}` with AI verdicts |
| GET | `/api/admin/managed-creators/{id}/warmup-screenshots/{submissionId}/image` | Admin session (`verifyAdmin`) | Streams the screenshot image from the private R2 bucket (proxied, 5-min cache) |
| POST | `/api/admin/managed-creators/{id}/warmup-screenshots/{submissionId}/review` | Admin session (`verifyAdmin`) | Reviews a flagged screenshot; body: `{decision: 'approved'\|'rejected', note?}` (only `needs_review`/`unreviewed` rows) |
| GET | `/api/admin/managed-creators/{id}/warmup-summary` | Admin session (`verifyAdmin`) | Warmup overview: start date, current window, expected daily dates, and per-day activity (scrolled platforms, niche videos) |

### `/api/admin/messages`

| Method | Path | Auth | Description |
|---|---|---|---|
| GET | `/api/admin/messages` | Authenticated session; `admin_message_threads` RPC enforces admin internally | Admin inbox: one row per (user, brand) thread with preview and unanswered flag; query: `filter` (default `unanswered`), `limit` (max 500) |
| GET | `/api/admin/messages/{threadKey}` | Admin session | All messages in a thread, oldest first; `threadKey` = `<user_id>__<brand_organization_id\|"system">` |
| POST | `/api/admin/messages/{threadKey}/reply` | Admin session | Sends an admin reply into the thread (push/email/Slack fan-out after response) and marks prior creator messages read; body: `{body}` (1–4000 chars) |
| POST | `/api/admin/messages/bulk` | Admin session; scoped roles restricted to assigned campaigns/creators | Queues a bulk message via Inngest; body: `{userIds[], brandOrganizationId, body}` or `{filters: {statusIn, jobId?, country?}, brandOrganizationId, body}` (max 5000 recipients). Returns `{ok, total}` |

### `/api/admin/payouts`

| Method | Path | Auth | Description |
|---|---|---|---|
| POST | `/api/admin/payouts/{creatorId}/add-funds` | Admin session + payout-capable admin role (`PAYOUTS_ROLES`); per-role hourly rate limits | Transfers money to a creator's Stripe Connected Account and records the earning in the ledger; body: `{amount_cents, description?}`. Returns `{success, transfer: {id, amount, currency, ...}}` |

### `/api/admin/posts`

| Method | Path | Auth | Description |
|---|---|---|---|
| PATCH | `/api/admin/posts/{postId}` | Admin session (`verifyAdmin`) | Updates post ad/tracking fields; body: any of `{ad_code, cost, paid_views, ad_spend, tracking_status: 'active'\|'excluded'}` |

### `/api/admin/referrals`

| Method | Path | Auth | Description |
|---|---|---|---|
| GET | `/api/admin/referrals` | Admin session | Referral analytics: signups grouped by referral code with funnel stages, time series, UTM breakdown, and summary; query: `from`, `to`, `account_type` |

### `/api/admin/stats`

| Method | Path | Auth | Description |
|---|---|---|---|
| GET | `/api/admin/stats` | Admin session | Admin dashboard statistics (users, jobs, applications, tracked accounts/posts, brands, creators) plus time-bucketed dashboard metrics and 30-day series via `get_admin_stats` / `get_admin_dashboard_buckets` RPCs |

### `/api/admin/sync-health`

| Method | Path | Auth | Description |
|---|---|---|---|
| GET | `/api/admin/sync-health` | Admin session | Comprehensive sync health statistics (cron job configuration and status overview) |
| GET | `/api/admin/sync-health/account/{accountId}` | Admin session | Sync history for one account (TikTok/Instagram/YouTube): status, last sync, consecutive failures, recent sync jobs; query: `limit` (max 100) |
| PATCH | `/api/admin/sync-health/account/{accountId}` | Admin session | Sets account `tracking_status`; body: `{trackingStatus: 'active'\|'reduced'\|'disabled'}` (resets failure count when re-activating) |
| POST | `/api/admin/sync-health/account/{accountId}/trigger-sync` | Admin session | Manually triggers a TikTok account sync through an edge function; body: `{provider: 'scraptik'\|'tiktok-api23'}` |
| GET | `/api/admin/sync-health/cpm-posts` | Admin session | CPM submissions with sync state; query: `limit` (max 500), `platform`, `status`, `sync_status` (`needs_sync`/`recently_synced`/`error`/`never_synced`) |
| GET | `/api/admin/sync-health/failures` | Admin session | Recent sync failures; query: `limit` (max 100) |
| GET | `/api/admin/sync-health/jobs` | Admin session | Paginated sync jobs with joined account info; query: `limit` (max 200), `offset`, `platform`, `status`, `run_id` |
| GET | `/api/admin/sync-health/runs/{runId}` | Admin session | Detail for a specific cron run including all its sync jobs |
| GET | `/api/admin/sync-health/search` | Admin session | Searches tracked accounts by username across all platforms; query: `q` |
| GET | `/api/admin/sync-health/time-series` | Admin session | Sync job time series; query: `range: '24h'\|'7d'` (default `24h`) |
| GET | `/api/admin/sync-health/video-processing` | Admin session | Video AI-processing pipeline stats: progress counts, error breakdown, daily throughput |
| GET | `/api/admin/sync-health/video-storage` | Admin session | Video storage pipeline stats (TikTok video/carousel): progress, errors with retry averages, daily throughput, backlog by month |

### `/api/admin/team-members`

| Method | Path | Auth | Description |
|---|---|---|---|
| GET | `/api/admin/team-members` | Admin session (`verifyAdmin`) | Lists admin team members for dropdowns: `{members: [{user_id, email, label, admin_role}]}` |

### `/api/admin/track`

| Method | Path | Auth | Description |
|---|---|---|---|
| GET | `/api/admin/track/accounts` | Admin session | Tracked social accounts (TikTok + Instagram unified table); query: `limit`, `offset`, `sortBy`, `sortOrder`, `brand`, `campaign`, `account`, `platform`, `search` |
| GET | `/api/admin/track/posts` | Admin session | Posts from all tracked accounts with pagination/filtering/sorting; query: `limit` (max 250), `offset`, `sortBy`, `sortOrder`, `account`, `platform`, `brand`, `campaign`, `search` |

### `/api/admin/verify-otp`

| Method | Path | Auth | Description |
|---|---|---|---|
| POST | `/api/admin/verify-otp` | Single-use admin impersonation token (UUID, unexpired, atomically claimed) — no session required | Completes admin impersonation: verifies the stored OTP for the target email via Supabase Auth, sets session cookies, and sends a Slack audit alert (admin, target, IP, location); body: `{token}` |

### `/api/admin/video-reviews`

| Method | Path | Auth | Description |
|---|---|---|---|
| GET | `/api/admin/video-reviews` | Admin session | Lists managed-creator posts for review with post/creator data and review history; query: `tab` (`unreviewed`/`reviewed`/`feedback`), `brand_id`, `job_id`, `creator_id`, `post` (deep link), `page`, `limit` (max 50) |
| POST | `/api/admin/video-reviews/{id}/review` | Admin session | Submits a review for a managed creator post (`id` = managed_creator_post_id); body: `{status: 'approved'\|'needs_changes'\|'rejected', feedback?}`; sends system message to creator + Slack notification |

## Auth, Users & Creators

# API Endpoints — Part 3 (auth, me, mobile, user, phone-verification, creator*, applications)

### `/api/auth`

OAuth-style browser flows. All endpoints respond with redirects (not JSON). "Supabase session" = cookie-based session resolved via `getUser()`.

| Method | Path | Auth | Description |
|---|---|---|---|
| GET | `/api/auth/confirm` | Public (Supabase `token_hash` in query) | Applies a Supabase email-change confirmation (`verifyOtp` with `type=email_change`) and syncs `users.email`; redirects to sign-in or profile with status params. |
| GET | `/api/auth/ga4/connect` | Supabase session (brand member, accepted invite; max 5 GA4 connections per brand) | Initiates the Google OAuth flow for GA4 integration; sets a CSRF state cookie and redirects to Google. |
| GET | `/api/auth/ga4/callback` | Supabase session + state-cookie CSRF check | Handles the Google OAuth callback: exchanges `code` for tokens, lists GA4 properties, saves the connection (or stashes pending tokens in a cookie when multiple properties) and redirects to settings. |
| GET | `/api/auth/instagram/connect` | Supabase session (requires creator profile) | Initiates the Instagram Login OAuth flow; sets a CSRF state cookie and redirects to Instagram. |
| GET | `/api/auth/instagram/callback` | Supabase session + state-cookie CSRF check | Handles the Instagram OAuth callback: exchanges `code` for a long-lived token, fetches the IG profile, saves the connection, redirects to the demo page. |
| GET | `/api/auth/tiktok/connect` | Supabase session (requires creator profile) | Initiates the TikTok Login Kit OAuth flow; sets a CSRF state cookie and redirects to TikTok. |
| GET | `/api/auth/tiktok/callback` | Supabase session + state-cookie CSRF check | Handles the TikTok OAuth callback: exchanges `code` for tokens, fetches user info, saves the connection, redirects to the demo page. |

### `/api/me`

Creator-facing "my account" endpoints. All require a Supabase session (`getUser()`); 401 otherwise.

| Method | Path | Auth | Description |
|---|---|---|---|
| GET | `/api/me/inbox` | Supabase session | Lists message threads (one per brand org, via `me_inbox_threads` RPC) with brand name, last message and unread count. Response: `{ data: InboxThread[] }`. |
| GET | `/api/me/has-weekly-reference-videos` | Supabase session | Whether the creator's brand (`?brandSlug=`) has active weekly-feed (or fallback job-listing / recently removed) reference videos for their job. Response: `{ hasVideos }`. |
| PUT | `/api/me/push-tokens` | Supabase session | Upserts a push notification token. Body: `{ token, platform: 'expo'\|'ios'\|'android' }`. |
| DELETE | `/api/me/push-tokens/{token}` | Supabase session | Deactivates the given push token for the current user (`active=false`). |
| GET | `/api/me/reference-video-alerts` | Supabase session | Counts weekly-feed reference videos added/archived in the last 24h per brand the user is a managed creator for. Response: `{ byBrand: { [brandId]: { added, archived } } }`. |
| GET | `/api/me/threads/{brandId}` | Supabase session | Full message thread with a brand, oldest first; `brandId='system'` is the 8x system thread. Response: `{ data: Message[] }`. |
| POST | `/api/me/threads/{brandId}/messages` | Supabase session + thread membership (existing message or `managed_creators` row) | Creator sends a reply into their thread. Body: `{ body }` (1–4000 chars). Triggers async bot reply. Response: `{ ok, message_id }`. |
| POST | `/api/me/threads/{brandId}/read` | Supabase session | Marks all unread inbound messages in the thread as read (never the creator's own outbound messages). |

### `/api/mobile`

Single catch-all route (`app/api/mobile/[...path]/route.ts`) exporting GET/POST/PATCH/PUT/DELETE/OPTIONS — the API surface for the iOS app. Auth: `Authorization: Bearer <Supabase JWT>` verified via `supabase.auth.getUser(token)` (`getMobileUser`); first-time users are auto-provisioned as `account_type='creator'`. `brand_member` accounts get 403 on every endpoint except `DELETE creator/account`. CORS is restricted to known origins (requests with no Origin header — native apps — are allowed). Unmatched paths return 404.

| Method | Path | Auth | Description |
|---|---|---|---|
| OPTIONS | `/api/mobile/{...path}` | Public | CORS preflight (204 + CORS headers). |
| GET | `/api/mobile/version-check` | Public | Minimum app version check. Query: `platform`. Response: `{ minVersion, platform, updateUrl }`. |
| POST | `/api/mobile/auth/test-bypass` | Public (kill-switched via `APPLE_REVIEW_BYPASS_ENABLED`, gated to `is_test_account` profiles) | Apple App Store reviewer login bypass: accepts a fixed `{ email, code }` pair and returns a real Supabase session. Returns 404 when disabled. |
| POST | `/api/mobile/auth/check-email` | Public (per-email rate limit 10/min) | Pre-OTP email eligibility check. Body: `{ email }`. Response: `{ allowed: true }` or `{ allowed: false, reason: 'brand', message }` for brand accounts. Fails open. |
| GET | `/api/mobile/jobs` | Bearer JWT | Lists jobs. Query: `page`, `limit` (≤100), `countries` (csv), `country_iso`. Paginated when `page` is present. |
| GET | `/api/mobile/jobs/{idOrSlug}` | Bearer JWT | Job detail; accepts a UUID or a `job_slug` (universal-link support). 404 when not found. |
| POST | `/api/mobile/jobs/{id}/apply` | Bearer JWT | Applies to a job. Body: `{ cover_letter?, burner_account_id? }`. Only featured (portal-config) CPM jobs auto-approve. Response: `{ success, ... }`. |
| GET | `/api/mobile/applications` | Bearer JWT | Lists the creator's own job applications (`listMyApplications`). |
| GET | `/api/mobile/creator/profile` | Bearer JWT | Returns the creator profile. |
| PATCH | `/api/mobile/creator/profile` | Bearer JWT | Updates basic profile info (zod `updateCreatorProfileInputSchema`, upserts). Response: `{ success: true }`. |
| POST | `/api/mobile/creator/profile/picture` | Bearer JWT | Uploads a profile picture. multipart/form-data with `photo` (JPEG/PNG/WebP); stores in Supabase `profile-photos`. Response: `{ success, url }`. |
| DELETE | `/api/mobile/creator/account` | Bearer JWT (also allowed for brand_member) | Deletes the mobile user's account. |
| PUT | `/api/mobile/creator/languages` | Bearer JWT | Replaces the creator's languages. Body: `{ languages: string[] }` (1–10 items). |
| GET | `/api/mobile/creator/course` | Bearer JWT | Course progress: `{ completedAt, timeSpentSeconds, completedSteps }`. |
| PATCH | `/api/mobile/creator/course` | Bearer JWT | Course progress update. Body: `{ action: 'heartbeat'\|'complete-step'\|'complete', seconds?, stepId? }`; `complete` also marks `managed_creators.base_course_status='completed'`. |
| GET | `/api/mobile/creator/managed-status` | Bearer JWT | Whether the user is a managed creator and for which brands/campaigns. |
| GET | `/api/mobile/waitlist/me` | Bearer JWT | Current waitlist state for the user. |
| POST | `/api/mobile/waitlist/join` | Bearer JWT | Joins the waitlist. Body: `{ country_iso (ISO-3166 alpha-2), notifications_opted_in? }`. |
| GET | `/api/mobile/creators/wallet` | Bearer JWT | Wallet dashboard (balance, pending, transactions) — shared `getWalletDashboard` service. |
| POST | `/api/mobile/creators/stripe-payout` | Bearer JWT | Requests a Stripe payout. Body validated by `requestStripePayoutInputSchema` (`amount_cents`, `method`). Errors may include `available_balance`. |
| POST | `/api/mobile/creators/stripe-connect` | Bearer JWT | Creates/continues Stripe Connect Express onboarding; returns an onboarding link. |
| GET | `/api/mobile/creators/stripe-dashboard` | Bearer JWT | Stripe Express dashboard login link (mirror of web `/api/creators/stripe-dashboard`). |
| GET | `/api/mobile/creators/stripe-balance` | Bearer JWT | Real-time Stripe Connect balance + failed-payout info (mirror of web route). |
| GET | `/api/mobile/creators/wallet/paid-posts` | Bearer JWT | Posts the creator has been paid for (mirror of web route). |
| POST | `/api/mobile/notifications/push-token` | Bearer JWT | Registers a push token. Body: `{ token, platform? }` (default `expo`). Response: `{ success: true }`. |
| POST | `/api/mobile/notifications/push-token/deactivate` | Bearer JWT | Deactivates all of the user's push tokens (sign-out). |
| GET | `/api/mobile/notifications` | Bearer JWT | Notification feed from `messages`. Response: `{ data, unread_count }`. |
| GET | `/api/mobile/notifications/unread-count` | Bearer JWT | Unread inbound message count only. |
| POST | `/api/mobile/notifications/mark-read` | Bearer JWT | Marks notification(s) read. |
| GET | `/api/mobile/inbox` | Bearer JWT | Thread list: one entry per brand org with latest message + unread count. |
| GET | `/api/mobile/threads/{brandId}` | Bearer JWT | Paginated thread. Query: `limit` (≤100), `before` cursor. `brandId='system'` = 8x thread. |
| POST | `/api/mobile/threads/{brandId}/read` | Bearer JWT | Marks inbound unread messages in the thread as read. |
| POST | `/api/mobile/threads/{brandId}/messages` | Bearer JWT + thread membership | Sends a reply. Body: `{ body }` (1–4000 chars). Mirrors web `/api/me/threads/[brandId]/messages`. |
| GET | `/api/mobile/burner-accounts` | Bearer JWT | Lists the user's burner accounts. |
| POST | `/api/mobile/burner-accounts` | Bearer JWT | Creates a burner account. Body: `{ handle, platform, assignedCampaign? }`. |
| PATCH | `/api/mobile/burner-accounts/{id}` | Bearer JWT (own account) | Updates a burner account. Body: `{ status?, warmupScore?, postsCount?, followersCount?, assignedCampaign?, handle? }`. |
| DELETE | `/api/mobile/burner-accounts/{id}` | Bearer JWT (own account) | Deletes a burner account. |
| POST | `/api/mobile/creator/trust-gate` | Bearer JWT | Records ToS/trust-gate completion (`trust_gate_completed_at`, set once; idempotent). |
| GET | `/api/mobile/brands/{brandId}/reference-videos` | Bearer JWT | Brand reference videos for the creator. |
| GET | `/api/mobile/onboarding/intro-video` | Bearer JWT | Platform intro video for onboarding. |
| GET | `/api/mobile/creator/workspace/{brandSlug}` | Bearer JWT (managed creator for brand) | Creator workspace payload: managed-creator state, org info, portal config, reference/brief videos, tracked platforms, previous accounts. |
| GET | `/api/mobile/creator/posts` | Bearer JWT (managed creator) | Creator's tracked posts. Query: `brandSlug`, `limit`, `offset`. Response: `{ posts, hasMore }` with views/likes and pay fields. |
| POST | `/api/mobile/creator/posts/sync` | Bearer JWT (managed creator) | Triggers a social account post sync. Body: `{ brandSlug, platform }`. |
| PATCH | `/api/mobile/creator/posts/{postId}/ad-code` | Bearer JWT (post owner) | Sets a post's ad code. Body: `{ ad_code, brandSlug }`. |
| PATCH | `/api/mobile/creator/handles` | Bearer JWT (owner only) | Updates social handles. Body: `{ managedCreatorId, tiktokUsername?, instagramUsername?, youtubeUsername? }` (strips `@`, stamps `handles_completed_at`). |
| GET | `/api/mobile/creator/resources` | Bearer JWT | Brand resources merged with platform templates. Query: `brandSlug`. Mirrors web `/api/creator/resources`. |
| POST | `/api/mobile/creator/report-post` | Bearer JWT | Reports a posted content URL for a campaign. Body: `{ post_url, platform?, notes?, job_application_id? }`. Mirrors web `/api/creator/report-post`. |
| GET | `/api/mobile/creator/suggest-handles` | Bearer JWT (managed creator for brand) | Suggests available social handles. Query: `brandSlug`, `platform` (`tiktok`/`instagram`/`youtube`). |
| GET | `/api/mobile/creator/videos` | Bearer JWT (managed creator) | Lists active slot-based test videos with signed URLs. Query: `brandSlug`. Response: `{ videos, requiredCount, maxCount, managedCreatorId }`. |
| POST | `/api/mobile/creator/videos/upload-url` | Bearer JWT (managed creator) | R2 presigned PUT URL for a direct video upload. Body: `{ brandSlug, mime_type }`. Response: `{ uploadUrl, path }`. |
| POST | `/api/mobile/creator/videos` | Bearer JWT (managed creator; path must be under creator's prefix) | Saves the video record after a direct R2 upload (`upload_or_replace_video` RPC; replacing a slot resets screening). Body: `{ brandSlug, slotNumber, path }`. Response: `{ id, slotNumber, path, url, totalVideos, isComplete, replacedVideoPath }`. |
| POST | `/api/mobile/creator/submit-application` | Bearer JWT (managed creator) | Locks in uploaded audition videos and kicks off the AI screening pipeline (with reference-video hash dedup). Body: `{ brandSlug }`. Response: `{ success, screening_status }`. |
| POST | `/api/mobile/applications/{id}/contract/sign` | Bearer JWT (own application) | Signs the campaign contract. Body: `{ signerName }`. |
| GET | `/api/mobile/applications/{id}/warmup` | Bearer JWT (own application) | Reads warmup state (checklist, handles) for an application. |
| POST | `/api/mobile/applications/{id}/warmup` | Bearer JWT (own application) | Saves warmup state. Body: `{ checklist?, tiktokHandle?, instagramHandle? }`; computes `accounts_verified_at` / `warmup_completed_at`. |
| GET | `/api/mobile/creator/tasks` | Bearer JWT (managed creator) | Task completion state + guide URLs. Query: `brandSlug`. Mirrors web `/api/creator/tasks`. |
| PATCH | `/api/mobile/creator/tasks/{taskId}` | Bearer JWT (owner) | Toggles task completion. Body: `{ managedCreatorId, completed }`. Validates dependencies/timing. |
| POST | `/api/mobile/creator/tasks/request-extension` | Bearer JWT (owner) | Requests (auto-grants) a 6-hour deadline extension. Body: `{ managedCreatorId, taskId, reason }`. |
| GET | `/api/mobile/creator/warmup/{brandSlug}` | Bearer JWT (managed creator) | Evidence-based warmup timeline. |
| POST | `/api/mobile/creator/warmup/{brandSlug}/scroll` | Bearer JWT (managed creator) | Records a daily scroll activity. Body: `{ platform }`. |
| POST | `/api/mobile/creator/warmup/{brandSlug}/screenshot/upload-url` | Bearer JWT (managed creator, due window) | R2 presigned PUT URL for a screen-time screenshot. Body: `{ windowIndex, platform, contentType }`. Response: `{ uploadUrl, path, window }`. |
| POST | `/api/mobile/creator/warmup/{brandSlug}/screenshot` | Bearer JWT (managed creator, path ownership check) | Submits an uploaded screenshot; async AI verification of screen-time. Body: `{ windowIndex, platform, path }`. |
| POST | `/api/mobile/creator/warmup/{brandSlug}/daily-warmup-updates` | Bearer JWT (managed creator) | Upserts a daily warmup activity (incl. niche video URL). |

### `/api/user`

| Method | Path | Auth | Description |
|---|---|---|---|
| GET | `/api/user` | Supabase session (returns `null` body when signed out) | Returns the current `users` row (or null) — session bootstrap for the web app. |
| GET | `/api/user/posthog-identify` | Supabase session | Returns PostHog identity data: `{ user_id, account_type, creator_profile_id, brand_member_id, brand_organization_id, is_8x_managed_brand }`. |

### `/api/phone-verification`

Twilio Verify–backed phone verification. Both endpoints require a Supabase session and use DB-backed rate limits (records attempts in `phone_verification_attempts` before counting).

| Method | Path | Auth | Description |
|---|---|---|---|
| POST | `/api/phone-verification/send` | Supabase session (rate limits: 3/user/24h, 6/IP/1h, 5/phone/24h, 100 global/1h) | Validates the phone, sends a Twilio Verify SMS code and stores the E.164 number on `users.phone`. Body: `{ phone }`. Response: `{ success }` (429 with `Retry-After` when limited). |
| POST | `/api/phone-verification/verify` | Supabase session (rate limit: 5/user/10min; phone must match the one a code was sent to) | Checks the Twilio code and marks `users.phone_verified`; also copies the phone to the creator/brand profile. Body: `{ phone, code }`. Response: `{ success }`. |

### `/api/creator`

Creator-portal endpoints for the web app. Auth is a Supabase session (`getUser()` / `getAuthUserId()`); most endpoints additionally require a `managed_creators` row linking the user to the brand (resolved from `brandSlug`).

| Method | Path | Auth | Description |
|---|---|---|---|
| GET | `/api/creator/brands/{brandSlug}/weekly-reference-videos` | Supabase session + managed creator for brand | Active weekly-feed reference videos for the creator's job (`?mode=recently_removed` lists videos archived in the last 7 days), with per-video `replicated_count`. |
| GET | `/api/creator/course` | Supabase session | Course progress: `{ completedAt, timeSpentSeconds }`. |
| PATCH | `/api/creator/course` | Supabase session | Course progress update. Body: `{ action: 'heartbeat'\|'complete', seconds? }`; completing also sets `managed_creators.base_course_status`. |
| GET | `/api/creator/cpm-campaign/{jobSlug}` | n/a (deprecated) | CPM feature removed — always returns 410 Gone. |
| PATCH | `/api/creator/cpm-campaign/{jobSlug}` | n/a (deprecated) | CPM feature removed — always returns 410 Gone. |
| PATCH | `/api/creator/handles` | Supabase session (owner, platform admin, or brand owner/admin) | Updates the managed creator's social handles via `social_accounts`. Body: `{ managedCreatorId, tiktokUsername?, instagramUsername?, youtubeUsername? }`. |
| GET | `/api/creator/managed-status` | Supabase session | Whether the user is a managed creator. Response: `{ isManagedCreator, brands[], campaigns: [] }`. |
| GET | `/api/creator/posts` | Supabase session + managed creator for brand | Creator's tracked posts (incl. deleted ones, for payment history). Query: `brandSlug`, `limit` (≤100), `offset`. Response: `{ posts, hasMore }`. |
| POST | `/api/creator/posts/sync` | Supabase session + managed creator for brand | Triggers a post sync for the linked social account. Body: `{ brandSlug, platform: 'tiktok'\|'instagram'\|'youtube' }`. |
| PATCH | `/api/creator/posts/{postId}/ad-code` | Supabase session + post ownership (via managed-creator account filters) | Sets a post's ad code. Body: `{ ad_code, brandSlug }`. |
| GET | `/api/creator/profile` | Supabase session (creator context) | Minimal profile-completeness check: `{ profile_picture, intro_video_url, is_8x_employee, display_name, first_name, last_name, share_code }`. |
| PATCH | `/api/creator/profile` | Supabase session | Updates basic profile info (mobile JSON path). Body: `{ display_name, bio?, location? }`. |
| POST | `/api/creator/report-post` | Supabase session (creator profile required) | Reports a posted content URL; creates a `cpm_submissions` row. Body: `{ post_url, platform?, notes?, job_application_id? }` (a valid `job_application_id` is required). |
| GET | `/api/creator/resources` | Supabase session + brand lookup (resources lock until tasks complete) | Merged brand resources + platform templates for the creator. Query: `brandSlug`. Response: `{ resources, brandId }`. |
| GET | `/api/creator/suggest-handles` | Supabase session + managed creator for brand | Suggests an available handle on the platform (RapidAPI availability check). Query: `brandSlug`, `platform`. |
| GET | `/api/creator/tasks` | Supabase session + managed creator for brand | Task completion state, deadline extensions, resolved guide URLs and handles. Query: `brandSlug`. |
| PATCH | `/api/creator/tasks/{taskId}` | Supabase session (owner or platform admin) | Toggles task completion with dependency/min-time validation. Body: `{ managedCreatorId, completed }`. |
| POST | `/api/creator/tasks/request-extension` | Supabase session (owner) | Auto-grants a 6-hour deadline extension for a task. Body: `{ managedCreatorId, taskId, reason }`. |
| GET | `/api/creator/videos` | Supabase session + managed creator for brand | Lists active slot-based test videos with signed URLs (R2 with Supabase fallback). Query: `brandSlug`. |
| POST | `/api/creator/videos` | Supabase session + managed creator for brand | Saves a video record after direct R2 upload (`upload_or_replace_video` RPC). Body: `{ brandSlug, slotNumber, path, fileHash? }`. |
| GET | `/api/creator/videos/screening-status` | Supabase session | Polling endpoint for AI screening state. Query: `brandSlug`. Response: `{ screening_status, screening_stage }`. |
| POST | `/api/creator/videos/upload-url` | Supabase session + managed creator for brand | R2 presigned PUT URL for video upload; rejects (409) when `fileHash` matches a brand reference video. Body: `{ brandSlug, slotNumber, contentType, fileHash? }`. |
| GET | `/api/creator/warmup/{brandSlug}` | Supabase session + warmup creator context | Evidence-based warmup timeline for the creator. |
| POST | `/api/creator/warmup/{brandSlug}/scroll` | Supabase session + warmup creator context | Records a daily scroll activity. Body: `{ platform, activityDate? (YYYY-MM-DD) }`. |
| POST | `/api/creator/warmup/{brandSlug}/daily-warmup-updates` | Supabase session + warmup creator context | Upserts daily warmup activity / appends a niche video URL (zod `WarmupDailyActivityBodySchema`). |
| POST | `/api/creator/warmup/{brandSlug}/screenshot/upload-url` | Supabase session + warmup creator context (window must be due) | R2 presigned PUT URL for a screen-time screenshot. Body: `{ windowIndex, platform, contentType }`. |
| POST | `/api/creator/warmup/{brandSlug}/screenshot` | Supabase session + warmup creator context (path ownership check) | Records a screenshot submission and runs async AI screen-time verification. Body: `{ windowIndex, platform, path }`. 409 on duplicate window. |
| GET | `/api/creator/workspace/{brandSlug}` | Supabase session + managed creator for brand | Full creator-workspace payload: managed-creator state, org, portal config (access code stripped), reference/brief videos, tracked platforms, previous accounts. |

### `/api/creators`

Mix of brand-facing creator-database endpoints and creator-facing Stripe/wallet endpoints. All use `validateOrigin()` (blocks non-browser callers) plus a Supabase session.

| Method | Path | Auth | Description |
|---|---|---|---|
| GET | `/api/creators` | Supabase session + brand member (admin role) via `X-Brand-Organization-Id` header; details gated by Stripe subscription | Lists up to 50 creators for the brand's creator database; without a subscription returns locked mock data. |
| GET | `/api/creators/{id}` | Supabase session + brand member via `X-Brand-Organization-Id` header; requires active Stripe subscription (403 `locked` otherwise) | Single creator profile with mapped social accounts. |
| POST | `/api/creators/connect-stripe` | Supabase session (creator profile required) | Initiates Stripe Connect Express onboarding (creates account if missing, region-routed by country) and returns the onboarding URL. Body: `{ locale?, country? }`. |
| GET | `/api/creators/stripe-balance` | Supabase session (creator with `stripe_account_id`) | Real-time Stripe Connect balance + failed-payout info: `{ available_cents, pending_cents, currency, instant_available, payouts_enabled, has_failed_payouts, ... }`. |
| GET | `/api/creators/stripe-dashboard` | Supabase session (creator with `stripe_account_id`) | Stripe Express dashboard login link: `{ url }`. |
| POST | `/api/creators/stripe-dashboard-link` | Supabase session (creator with `stripe_account_id`) | Same as above via POST (region-aware): `{ url }`. |
| POST | `/api/creators/stripe-payout` | Supabase session (creator) | Requests a payout from the creator's Stripe balance. Body: `requestStripePayoutInputSchema` (`amount_cents`, `method`). Errors may include `available_balance` / `minimum_cents`. |
| GET | `/api/creators/wallet` | Supabase session (creator context) | Wallet dashboard (balance, pending balance, recent transactions) — shared service with the mobile catch-all. |
| GET | `/api/creators/wallet/paid-posts` | Supabase session (creator context) | Posts with paid/partially-paid payouts across the creator's managed-creator records: `{ posts[] }` with pay, views and job/brand info. |

### `/api/creator-application`

Public creator application funnel (no auth; service-role DB writes, IP rate-limited, honeypot `company` field).

| Method | Path | Auth | Description |
|---|---|---|---|
| POST | `/api/creator-application` | Public (5 leads/min/IP) | Step 1 — lead capture. Body: `{ id?, fullName, email, whatsappNumber, country, utm*… }`; updates the existing lead when `id` is supplied. Response: `{ success, id }`. |
| PATCH | `/api/creator-application` | Public | Step 2 — attaches the video and marks the application `submitted` (Slack notification). Body: `{ id, videoLink? \| videoStoragePath? }`. 409 when already submitted. |
| POST | `/api/creator-application/upload-url` | Public (signed-URL minting rate-limited per IP) | Mints a Supabase signed upload URL for the application video (≤100 MB; MP4/MOV/WebM/M4V). Body: `{ filename, contentType, size }`. Response: `{ path, signedUrl }`. |

### `/api/creator-invites`

| Method | Path | Auth | Description |
|---|---|---|---|
| GET | `/api/creator-invites` | Public (token in query; SECURITY DEFINER RPC) | Verifies a creator invite token during signup via `verify_creator_invite`. Query: `token`. Response: `{ valid, creatorProfile? }` (claimed/expired → 400). |

### `/api/managed-creators`

Brand-side managed-creator CRM. All endpoints (except invites, below) authenticate via `getBrandContext()`: Supabase session where the user is either a platform admin (optionally scoped with the `x-admin-view-as-brand` header) or a brand member with `owner`/`admin` role; access to a specific creator is verified against the caller's brand.

| Method | Path | Auth | Description |
|---|---|---|---|
| GET | `/api/managed-creators` | Brand context (admin or brand owner/admin) | Lists managed creators for the brand with resolved social usernames and per-creator analytics (`total_views`, `cpm`). Query: `platform=tiktok\|instagram\|all`. |
| POST | `/api/managed-creators/batch` | Brand context | Batch-updates managed creators (whitelisted fields only; platform-handle edits rejected) with audit logging and status-transition side effects. Body: `{ updates: [{ id, changes }] }`. |
| GET | `/api/managed-creators/aggregate-stats` | Brand context | Aggregate views/posts/CPM stats across the brand's managed creators. |
| GET | `/api/managed-creators/{id}` | Brand context + creator-brand match | Single managed creator with embedded transcripts. |
| PATCH | `/api/managed-creators/{id}` | Brand context + creator-brand match | Updates a managed creator (profile, status, pay, checklist, urls…); handles drop/reinstate side effects and social-account changes. |
| DELETE | `/api/managed-creators/{id}` | Brand context + creator-brand match | Deletes the managed creator and all their files in R2/Supabase storage. |
| GET | `/api/managed-creators/{id}/analytics` | Brand context + creator-brand match | Post analytics for the creator. Query: `startDate`, `endDate`, `mode=days\|posts`, `excludedPostIds`, `platforms`. |
| GET | `/api/managed-creators/{id}/transcripts` | Brand context + creator-brand match | Lists call transcripts (metadata only). |
| POST | `/api/managed-creators/{id}/transcripts` | Brand context + creator-brand match | Saves a transcript to R2 + DB record; marks the onboarding call complete. Body: `{ transcript, callDate? }`. |
| GET | `/api/managed-creators/{id}/transcripts/{transcriptId}` | Brand context + creator-brand match | Full transcript content (R2 with Supabase fallback). |
| DELETE | `/api/managed-creators/{id}/transcripts/{transcriptId}` | Brand context + creator-brand match | Deletes a transcript record and its storage file. |
| GET | `/api/managed-creators/{id}/videos` | Brand context + creator-brand match | Lists all test videos (including replaced ones) with signed URLs. |
| POST | `/api/managed-creators/{id}/videos` | Brand context + creator-brand match | Uploads/replaces a slot video. multipart/form-data: `file` (MP4/MOV/WebM ≤500 MB), `slotNumber` (1–10). |
| DELETE | `/api/managed-creators/{id}/videos` | Brand context, platform admin only | Hard-deletes a video from storage and DB. Body: `{ path, videoId? }`. |
| PATCH | `/api/managed-creators/{id}/videos/review` | Supabase session, platform admin or brand owner/admin (creator-brand match) | Accepts/rejects a creator test video; triggers status-transition notifications. Body: `{ video_id, review_status: 'accepted'\|'rejected', storage_path? }`. |

### `/api/managed-creator-invites`

| Method | Path | Auth | Description |
|---|---|---|---|
| GET | `/api/managed-creator-invites` | Public (token in query) | Verifies a managed-creator invite token during signup (unclaimed + unexpired). Query: `token`. Response: `{ valid, managedCreator? }`. |

### `/api/applications`

Job-application endpoints (origin-validated).

| Method | Path | Auth | Description |
|---|---|---|---|
| GET | `/api/applications` | Supabase session (creator context; returns `[]` when unauthenticated) | Lists the current creator's job applications with job details, media and an `onboarding_call_url` for 8x-managed brands. |
| PUT | `/api/applications/{id}` | Supabase session, platform admin or brand member whose org owns the job | Updates an application's status (`pending`/`under_review`/`accepted`/`rejected`/`withdrawn`, optional `rejection_reason`); fires creator notifications on accept/reject. |
| GET | `/api/applications/{id}/video` | Supabase session (creator context; application must belong to the creator) | Application details + job info + uploaded videos for the video-upload page. |

## Brands, Jobs & Billing

# API Endpoints — Part 4

Auth legend:

- **Brand context** — `getBrandContext(request)`: Supabase session + brand membership lookup, supports admin view-as via `x-admin-view-as-brand` header.
- **Session** — authenticated Supabase user (`getUser()` / `getAuthUserId()`).
- **Public** — no authentication.
- Many routes additionally call `validateOrigin()` to reject non-browser callers.

### `/api/brand`

| Method | Path | Auth | Description |
|---|---|---|---|
| GET | `/api/brand/settings` | Brand context + origin check | Fetch brand member profile, organization details, wallet, and transaction history. Returns `{ brandMember, wallet, transactions }`. |
| GET | `/api/brand/posts` | Brand context + origin check | Fetch content posts for the brand's tracked TikTok/Instagram accounts (via `brand_tracked_social_accounts`), with creator info. Returns post array. |
| GET | `/api/brand/guide-overrides` | Session + brand membership (or admin via `x-admin-view-as-brand`) | Fetch guide URL overrides for the brand, merged with platform defaults. Returns `{ guides: [{ key, title, url, defaultUrl, isCustomized }] }`. |
| PATCH | `/api/brand/guide-overrides` | Session + brand owner/admin role (or platform admin view-as) | Set or reset a guide URL override. Body: `{ guideKey, url \| null }`. |
| GET | `/api/brand/applicants` | Brand context + origin check | List all job applications for the brand with status counts and job list. Query: `status`, `job`. Returns `{ applications, jobs, statusCounts }`. |
| GET | `/api/brand/applicants/{id}` | Session + brand membership; verifies application belongs to brand's job | Fetch one application's full details (creator profile, job, videos). |
| GET | `/api/brand/account-usage` | Brand context | Return tracked-account usage vs plan limit: `{ currentCount, accountLimit, canAddMore }`. |
| GET | `/api/brand/creators` | Session + accepted brand membership + origin check | List creators with accepted applications to the brand's jobs. Returns `{ success, data: [{ user_id, display_name, profile_picture }] }`. |
| GET | `/api/brand/api-keys` | Brand context (roles: owner/admin) + origin check | List active (non-revoked) API keys for the brand. |
| POST | `/api/brand/api-keys` | Brand context (roles: owner/admin) + origin check | Create an API key. Body (zod): `{ name, scopes[], expires_at? }`. Returns key metadata plus the plaintext `token` (only shown once). |
| DELETE | `/api/brand/api-keys/{keyId}` | Brand context (roles: owner/admin) + origin check | Revoke an API key (sets `revoked_at`). |
| GET | `/api/brand/campaigns` | Session + brand membership (admins must pass `brandId` query param) + origin check | List campaign names with tracked-account counts from `brand_tracked_social_accounts`. |
| POST | `/api/brand/campaigns` | Session + brand membership (admins must pass `brandId`) + origin check | Validate/register a campaign name (campaigns exist implicitly as strings). Body: `{ name }`. |
| POST | `/api/brand/invites` | Session + brand owner/admin role + origin check | Create a team invite for an email (7-day token). Body: `{ email, role? }`. Returns `{ inviteUrl, expiresAt }`. |
| GET | `/api/brand/invites` | Public (token-based; service-role client) | Verify an invite token during signup. Query: `token`. Returns invite validity, email, org name/logo, role. |
| GET | `/api/brand/invites/pending` | Session (service-role lookup by user's email) | Check whether the current user has a pending (unused, unexpired) brand invite matching their email. |
| POST | `/api/brand/invites/request-support` | Session; invite email must match user's email | Mark an invite as "support contacted" (part of forced-acceptance flow). Body: `{ token, reason? }`. |
| GET | `/api/brand/resources` | Session + brand membership (or platform admin via header/`brandSlug` query) | List the brand's resources ordered by `order_index`. |
| POST | `/api/brand/resources` | Session + brand membership (or platform admin) | Create a resource. Body: `{ title, url, description?, resource_type?, icon?, is_required?, brandSlug? }`. |
| PATCH | `/api/brand/resources/{id}` | Session + brand owner/admin role (or platform admin); resource must belong to brand | Update a resource's fields. |
| DELETE | `/api/brand/resources/{id}` | Session + brand owner/admin role (or platform admin); resource must belong to brand | Delete a resource. |
| GET | `/api/brand/resources/templates` | Session + brand membership (or platform admin view-as) | List platform resource templates merged with the brand's customizations (`is_customized`, `customization_id`). |
| PATCH | `/api/brand/resources/templates/{id}` | Session + brand owner/admin role (or platform admin view-as) | Customize a platform template for the brand (upserts a `brand_resources` row with `from_template_id`). Body: `{ title?, description?, url?, resource_type?, is_required? }`. |
| DELETE | `/api/brand/resources/templates/{id}` | Session + brand owner/admin role (or platform admin view-as) | Reset a template to default by deleting the brand's customization. |
| GET | `/api/brand/network/applicants` | Brand context + `network_access_enabled` flag + origin check | Paginated list of applicants across all the brand's jobs, with video counts and emails. Query: `page`, `limit` (max 100). |
| PATCH | `/api/brand/network/applicants` | Brand context + origin check; application must belong to brand | Update an application's status. Body: `{ applicationId, status: pending\|messaged\|accepted\|rejected }`. |
| GET | `/api/brand/network/contact/{creatorId}` | Brand context + `network_access_enabled`; creator must have applied to brand's jobs | Lazy-load a creator's contact info: `{ email, phone }`. |
| GET | `/api/brand/network/videos/{applicationId}` | Brand context + `network_access_enabled`; application must belong to brand | Fetch application videos and the creator's intro video URL. |
| POST | `/api/brand/track/youtube-accounts` | Brand context + origin check + plan account-limit check | Add a single YouTube account to track (creates/reuses `youtube_accounts` row, links via `brand_tracked_social_accounts`, triggers sync). Body: `{ username }`. |
| POST | `/api/brand/track/youtube-accounts/bulk` | Brand context + origin check + plan account-limit check | Bulk-add up to 100 YouTube accounts. Body: `{ usernames[], campaign? }`. Returns per-username results. |
| POST | `/api/brand/track/instagram-accounts/bulk` | Brand context + origin check + plan account-limit check | Bulk-add up to 100 Instagram accounts. Body: `{ usernames[], campaign? }`. Returns per-username results. |
| DELETE | `/api/brand/track/instagram-accounts/{accountId}` | Session + brand membership + origin check | Remove a tracked Instagram account (unlinks brand-account connection). |
| POST | `/api/brand/track/accounts/bulk` | Brand context + origin check + plan account-limit check | Bulk-add up to 100 TikTok accounts to track (triggers edge-function sync; respects social-listening mode). Body: `{ usernames[], campaign? }`. |
| DELETE | `/api/brand/track/accounts/{accountId}` | Brand context + origin check; account must be tracked by brand | Remove a tracked social account (TikTok or Instagram) from the unified tracking table. |
| PUT | `/api/brand/track/accounts/campaign` | Brand context + origin check | Assign a campaign to multiple tracked accounts. Body: `{ accountIds[], campaign }`. Returns per-account results. |
| DELETE | `/api/brand/track/accounts/campaign` | Brand context | Reset an account's campaign back to `general`. Body: `{ accountId }`. |
| PUT | `/api/brand/track/accounts/freeze` | Brand context + origin check | Freeze/unfreeze tracking of accounts for this brand (per-brand freeze; preserves history). Body: `{ accountIds[], freeze: boolean }`. |

### `/api/brands`

| Method | Path | Auth | Description |
|---|---|---|---|
| GET | `/api/brands/by-slug/{slug}` | Public (service-role client; only safe fields exposed) | Fetch public brand info by organization slug (name, logo, description, industry, website). Used by `/join/[brandSlug]` landing page. |

### `/api/brand-member`

| Method | Path | Auth | Description |
|---|---|---|---|
| GET | `/api/brand-member` | Session (supports admin view-as) | Return the current user's brand membership: `{ brand_organization_id, first_name, last_name }` (nulls if not a member). |

### `/api/jobs`

| Method | Path | Auth | Description |
|---|---|---|---|
| GET | `/api/jobs` | Public (session optional; affects country-restricted visibility) + origin check | List public jobs with requirements/tags. Query: `countries` (comma-separated), `page`, `limit` (paginated response when `page` is set). |
| GET | `/api/jobs/{jobId}` | Public for open/public jobs; brand members/admins see their own jobs in any status; origin check | Fetch a single job by ID with requirements and CPM/budget details. |
| PUT | `/api/jobs/{jobId}` | Session + brand membership owning the job (or platform admin) + origin check | Update a job posting (title, description, budgets, CPM fields, requirements, dates, etc.). |
| DELETE | `/api/jobs/{jobId}` | Session + brand membership owning the job + origin check | Delete a job and its related data (applications, requirements, contracts). |
| GET | `/api/jobs/by-slug/{slug}` | Public for open/public jobs; brand members see own jobs in any status; origin check | Fetch a single job by slug with explicit safe column list (excludes internal fields like `portal_config`). |
| POST | `/api/jobs/{jobId}/apply` | Session (creator) + origin check | Submit a job application via the shared applications service. Body: `{ cover_letter? }`. Returns `{ application_id, auto_approved, onboarding_call_url, ... }`. |
| GET | `/api/jobs/{jobId}/applicants` | Session + brand membership owning the job (or platform admin) + origin check | List applicants for a job. Query: `status`. Returns creator profile summaries per application. |
| PATCH | `/api/jobs/{jobId}/applications/{applicationId}/media` | Session; application must belong to the requesting creator (service-role client) | Save an application video URL after client-side upload (bypasses Vercel 4.5MB body limit). FormData: `videoUrl`, `filename?`, `fileSize?`. |
| POST | `/api/jobs/media` | Session + brand membership or platform admin + origin check | Save a job media URL after client-side upload to Supabase Storage. FormData: `mediaUrl`, `type` (`image`/`video`), `jobId?`, `filename?`. |

### `/api/portal`

| Method | Path | Auth | Description |
|---|---|---|---|
| GET | `/api/portal/{brandSlug}` | Public | Fetch a brand's public campaign portal config (sanitized), org info, content (about/goal/compensation), and reference videos. Query: `country` to select a country-specific config. 404 if portal is unlisted. |

### `/api/team`

| Method | Path | Auth | Description |
|---|---|---|---|
| GET | `/api/team` | Session (returns `null` if unauthenticated) | Return the team/brand data with members for the current user (`getTeamForUser`). |
| GET | `/api/team/members` | Session + brand membership | List all team members of the user's brand organization. |

### `/api/stripe`

| Method | Path | Auth | Description |
|---|---|---|---|
| POST | `/api/stripe/webhook` | Stripe webhook signature (`stripe-signature` + `STRIPE_WEBHOOK_SECRET`) | Main Stripe webhook: handles subscription changes, deposits, invoices, transfers, payouts, account updates. |
| POST | `/api/stripe/webhook-us` | Stripe webhook signature (`STRIPE_WEBHOOK_SECRET_US`) | Legacy US-region Stripe webhook (transfers, payouts, account updates); kept for backwards compatibility. |
| POST | `/api/stripe/create-checkout` | Session | Create a Stripe Checkout session for a subscription. Body: `{ priceId? \| planId? \| priceData?, promotionCode?, skipTrial?, isOnboarding? }`; validates promo-code-only plans and promotion codes. |
| GET | `/api/stripe/checkout` | Public (Stripe redirect; validated by retrieving `session_id` from Stripe) | Post-checkout success callback: retrieves session/subscription, applies subscription change, tracks event, then redirects to the dashboard. |
| GET | `/api/stripe/deposit-success` | Public (Stripe redirect; verifies `session_id` payment status) | Post-deposit callback: verifies payment status (wallet credit happens in webhook) and redirects to dashboard or `return_to` URL. |
| POST | `/api/stripe/cancel-subscription` | Session + brand membership | Cancel the brand's subscription: trialing subs cancel immediately, active subs cancel at period end. |
| POST | `/api/stripe/resubscribe` | Session + brand membership | Reverse a pending cancellation (sets `cancel_at_period_end` back to false, idempotent per day). |
| POST | `/api/stripe/upgrade-subscription` | Session + brand membership | Mid-cycle plan change. Body: `{ targetPlanId }`. Upgrades invoice prorated charges immediately; downgrades apply at next cycle (checks account-limit fit). |

### `/api/subscription-history`

| Method | Path | Auth | Description |
|---|---|---|---|
| GET | `/api/subscription-history` | Session + brand membership | Return whether the brand's Stripe customer has ever had a subscription (including canceled): `{ hasPreviousSubscriptions }`. |

### `/api/subscription-plans`

| Method | Path | Auth | Description |
|---|---|---|---|
| GET | `/api/subscription-plans` | Public read (RLS limits to active plans) | List active subscription plans. Query: `promo`/`code` — promo-code-only plans are hidden unless the matching code is supplied. |

### `/api/subscription-status`

| Method | Path | Auth | Description |
|---|---|---|---|
| GET | `/api/subscription-status` | Session + brand membership | Return the current Stripe subscription status for the user's brand: `{ subscriptionStatus }` (null if no brand/customer). |

### `/api/cpm`

| Method | Path | Auth | Description |
|---|---|---|---|
| GET | `/api/cpm/enrollment` | Session (creator) | Return the creator's CPM enrollment status: enrollment flag, active job count, total/pending earnings, active campaigns. |
| GET | `/api/cpm/campaigns` | Session (any authenticated user) | List available CPM campaigns (intentionally visible to all authenticated users for discovery). |
| GET | `/api/cpm/campaigns/{jobId}` | Session (any authenticated user) | Fetch a single CPM campaign by job ID (no sensitive brand data exposed). |
| GET | `/api/cpm/jobs` | Brand context | List the brand's CPM jobs (including `pending_funding`) with rates, caps, and budget fields. |
| GET | `/api/cpm/jobs/{jobId}/submissions` | Brand context; job must belong to brand and be a CPM job | List CPM submissions for a specific job (brand review view). |
| GET | `/api/cpm/stats` | Brand context | Return aggregate CPM campaign statistics for the brand. |
| GET | `/api/cpm/submissions/pending` | Brand context | List pending CPM submissions awaiting brand review. |

### `/api/book-call`

| Method | Path | Auth | Description |
|---|---|---|---|
| POST | `/api/book-call` | Public | Submit a "book a call" / brand onboarding request. Body: `{ name, email, company, phone?, preferredDate?, preferredTime?, message? }`. Currently only logs the email content (email-service integration is a TODO). |

### `/api/waitlist`

| Method | Path | Auth | Description |
|---|---|---|---|
| POST | `/api/waitlist/join` | Session (creator profile required); zod-validated | Join a country waitlist. Body: `{ country_iso (ISO 3166-1 alpha-2), notifications_opted_in? }`. 409 if market is live or closed; idempotent on re-submit; sends welcome email on fresh insert. |
| GET | `/api/waitlist/me` | Session | Return the creator's market gate state (waitlist/live status for their country). |

### `/api/feedback`

| Method | Path | Auth | Description |
|---|---|---|---|
| POST | `/api/feedback` | Session | Submit user feedback. Body: `{ feedbackText, pageUrl?, userAgent? }`. Stores feedback with user metadata, then fires internal email + Slack notifications. Returns `{ success, feedback }` (201). |

## Infrastructure & Integrations

### `/api/cron`

All cron routes require `Authorization: Bearer <CRON_SECRET>` (`requireCronSecret`). Schedules are from `vercel.json`.

| Method | Path | Auth | Description |
|---|---|---|---|
| GET | `/api/cron/sync-tiktok-periodic` | Cron secret | Periodic TikTok account sync (schedule `0 1 * * *`): cleans stuck syncs, picks accounts with `backfill_status=complete` due for sync (4h regular / 48h listening-passive), dispatches full or quick sync to Supabase edge functions. Returns sync stats JSON. |
| GET | `/api/cron/sync-instagram-periodic` | Cron secret | Periodic Instagram account sync (schedule `10 1 * * *`): same pattern as TikTok with 6h interval and conservative rate limiting for Instagram's 50 req/min limit. |
| GET | `/api/cron/sync-youtube-periodic` | Cron secret | Periodic YouTube account sync (schedule `20 1 * * *`): same pattern, 6h regular interval, full vs quick sync per account. |
| GET | `/api/cron/sync-backfill` | Cron secret | Initial-backfill processor (schedule `30 1 * * *`): processes accounts with `backfill_status=in_progress` across TikTok/Instagram/YouTube via edge functions, with crash recovery for stuck runs (max 5 attempts). |
| GET | `/api/cron/detect-stale-posts` | Cron secret | Marks posts unavailable for >3 days as `tracking_status=deleted` (schedule `0 2 * * *`); sends a Slack summary. Response: `{ success, markedDeleted, byPlatform }`. |
| GET | `/api/cron/backfill-video-storage` | Cron secret | Downloads TikTok videos/carousel images to Cloudflare R2 (schedule `50 1 * * *`), up to 40 posts per run, prioritizing active campaigns; falls back to the ScrapTik RapidAPI for fresh download URLs. |
| GET | `/api/cron/backfill-managed-ig-yt-video` | Cron secret | Temporary backlog drainer (schedule `0 3 * * *`): finds unprocessed 8x-managed IG/YT video posts via RPC and fire-and-forget dispatches each to `/api/hooks/process-video` with `skip_notify=true`. |
| GET | `/api/cron/sync-cpm-views` | Cron secret | CPM submissions sync (schedule `40 1 * * *`): retries `pending_fetch`/`fetch_failed` submissions, refreshes post view counts via scraper edge function, updates submission views. |
| GET | `/api/cron/sync-ga4` | Cron secret | Daily GA4 sync (schedule `0 6 * * *`): syncs yesterday's data for all `brand_ga4_connections` (skipping expired-auth ones) in batches; tracks results in PostHog. |
| GET | `/api/cron/monitor-storage` | Cron secret | Storage quota monitor (schedule `0 0 * * *`): checks Supabase storage usage against tier limit (`?tier=free\|pro`, default pro) and sends Slack alerts at 80/90/95%. |

### `/api/webhooks`

| Method | Path | Auth | Description |
|---|---|---|---|
| POST | `/api/webhooks/new-managed-post` | Cron secret | Called by a Supabase DB webhook on `managed_creator_posts` INSERT (or manually); triggers Slack notifications for new managed posts pending review. |
| POST | `/api/webhooks/tiktok` | Public (no verification) | Receives TikTok webhook events (`authorization.removed`, `video.upload.failed`, …); currently just logs `body.event` and acknowledges with `ok`. |
| GET | `/api/webhooks/tiktok` | Public | URL-existence ping for the TikTok Developer Portal; returns `ok`. |
| POST | `/api/webhooks/instagram/data-deletion` | Public (signed_request not yet parsed) | Meta GDPR data-deletion callback; currently acknowledges with a status `url` and `confirmation_code` (deletion logic is a TODO). |
| GET | `/api/webhooks/instagram/data-deletion` | Public | Health/verification ping; returns `{ status: 'ok' }`. |
| POST | `/api/webhooks/instagram/deauthorize` | Public (signed_request not yet parsed) | Meta callback when a user removes the app from Instagram; currently acknowledges (deactivation logic is a TODO). |
| GET | `/api/webhooks/instagram/deauthorize` | Public | Health/verification ping; returns `{ status: 'ok' }`. |

### `/api/hooks`

Internal async-processing hooks, all protected by `Authorization: Bearer <CRON_SECRET>` and invoked fire-and-forget from pg_net triggers, crons, or other API routes.

| Method | Path | Auth | Description |
|---|---|---|---|
| POST | `/api/hooks/hash-video` | Cron secret | Computes SHA-256 of a managed-creator video in R2 for duplicate detection. Body: `{ video_id, storage_path }`. Processing errors return 200 (best-effort). |
| POST | `/api/hooks/process-video` | Cron secret | Full video AI pipeline triggered on post INSERT: download to R2, Groq Whisper transcription, Gemini analysis/hygiene checks, replication review vs brand reference videos. Body: `{ post_id, skip_notify? }`. |
| POST | `/api/hooks/screen-submission` | Cron secret | Screens creator application videos: atomically claims the `managed_creators` row (`pending` → `screening`), responds immediately, then runs Groq+Gemini screening via `after()` to a terminal `passed`/`failed` state. Body: `{ managed_creator_id }`. |
| POST | `/api/hooks/disclosure-check` | Cron secret | Checks a post for missing sponsorship disclosure (`is_sponsored === false`) and, if it belongs to a managed creator post, sends an admin Slack alert. Body: `{ post_id }`. |
| POST | `/api/hooks/process-reference-video` | Cron secret | Processes a brand reference video (download → transcribe → analyze); triggered on upload from the admin reference-videos API. Body: `{ reference_video_id }`. |

### `/api/inngest`

| Method | Path | Auth | Description |
|---|---|---|---|
| GET, POST, PUT | `/api/inngest` | Inngest signature (handled by `inngest/next` serve handler) | Inngest function endpoint serving registered functions (currently `bulkMessageFunction` for bulk messaging). |

### `/api/internal`

| Method | Path | Auth | Description |
|---|---|---|---|
| POST | `/api/internal/critical-error-alert` | Public, rate-limited (5/min + 20/hr per IP, 30/min global); disabled in development | Receives client-side error-boundary reports and forwards them to Slack (with noise filtering and text sanitization). Body: `{ message (required), stack?, digest?, url?, userAgent?, userId?, operation?, category? }`. |

### `/api/analytics`

Brand analytics endpoints. Auth: origin validation + `getBrandContext` (authenticated session, brand membership, admin view-as via `x-admin-view-as-brand`), except `sync-status` which uses `getUser` + brand-member check directly.

| Method | Path | Auth | Description |
|---|---|---|---|
| GET | `/api/analytics/posts` | Session (brand context) + origin check | Lists posts from the brand's tracked accounts with engagement metrics. Query: `limit`, `offset`, `sortBy`, `sortOrder`, `account`, `platform`, `campaign`, `viewTier`, `startDate`, `endDate`. |
| DELETE | `/api/analytics/posts` | Session (brand context) + origin check | Soft-deletes posts (`tracking_status=deleted`), scoped to the brand's tracked accounts to prevent IDOR. Body: `{ postIds: string[] }` (max 200). Response: `{ success, deleted }`. |
| GET | `/api/analytics/chart-data` | Session (brand context) + origin check | Daily engagement metrics for charts. Query: `startDate`, `endDate`, `allTime`, `campaign`, `account`, `platform`, `metricType` (`views_gained` default \| `views_by_post_date`). Response: `{ data: [...] }`. |
| POST | `/api/analytics/fetch` | Session (brand context) + origin check | Triggers on-demand data refresh for selected accounts or posts via Supabase edge functions. Body: `{ type: 'accounts' \| 'posts', ids: string[] }`. |
| GET | `/api/analytics/accounts` | Session (brand context) + origin check | Lists the brand's tracked social accounts (TikTok/Instagram/YouTube) with aggregated post stats. Query: `limit`, `offset`, `sortBy`, `sortOrder`, `account`, `platform`, `campaign`, `startDate`, `endDate`. |
| GET | `/api/analytics/sync-status` | Session + brand member + origin check | Lightweight polling endpoint for account sync status and new posts since account creation. Query: `accountIds=id1,id2,…` (required). |
| GET | `/api/analytics/posts/{postId}/metrics` | Session (brand context) + origin check | Time-series engagement history for one post (verifies the post belongs to a brand-tracked account). Response: `{ data: [{ date, views, likes, comments, shares, saves, engagementRate }] }`. |

### `/api/ga4`

| Method | Path | Auth | Description |
|---|---|---|---|
| GET | `/api/ga4/metrics` | Session (brand context) + origin check | Returns GA4 metrics and summary for a date range. Query: `startDate`, `endDate` (required, YYYY-MM-DD), `connectionId` (optional). |
| GET | `/api/ga4/connection` | Session (brand context) + origin check | Returns the brand's primary GA4 connection (falls back to first by `display_order`). Response: `{ connection }`. |
| POST | `/api/ga4/select-property` | Session (`getUser`) | Saves the selected GA4 property after OAuth, using pending tokens from the `GA4_PENDING_TOKENS` cookie. Body: `{ propertyId, propertyName }`. |
| GET | `/api/ga4/select-property` | Session (`getUser`) | Lists available GA4 properties from the pending OAuth session cookie. Response: `{ properties }`. |
| POST | `/api/ga4/backfill` | Internal: `x-internal-secret` must equal `CRON_SECRET` | Backfills the last `BACKFILL_DAYS` of GA4 data for one connection (called internally from `triggerHistoricalSync`). Body: `{ connectionId, userId, brandOrgId }`. Response: `{ success, days_synced, total_days, status }`. |
| GET | `/api/ga4/connections` | Session (brand context) + origin check | Lists all GA4 connections for the brand, ordered by `display_order`. Response: `{ connections }`. |

### `/api/instagram`

Creator-facing Instagram OAuth endpoints. Auth: `getCreatorContext` (authenticated creator profile); each refreshes the stored Instagram token before calling the Graph API.

| Method | Path | Auth | Description |
|---|---|---|---|
| GET | `/api/instagram/insights` | Session (creator context) | Fetches media insights for one media item. Query: `mediaId` (required), `mediaProductType` (default `REELS`). Response: `{ insights }`. |
| GET | `/api/instagram/comments` | Session (creator context) | Fetches comments on a media item. Query: `mediaId` (required). Response: `{ comments }`. |
| POST | `/api/instagram/comments` | Session (creator context) | Replies to or hides a comment. Body: `{ action: 'reply' \| 'hide', commentId, message?, hide? }`. |
| GET | `/api/instagram/messages` | Session (creator context) | Lists the creator's Instagram DM conversations. Response: `{ conversations }`. |
| POST | `/api/instagram/messages` | Session (creator context) | Sends an Instagram DM. Body: `{ recipientId, text }`. Response: `{ messageId }`. |
| GET | `/api/instagram/connection` | Session (creator context) | Returns the creator's Instagram OAuth connection (without tokens). Response: `{ connection }`. |
| POST | `/api/instagram/publish` | Session (creator context) | Publishes an image post via Graph API (create container → publish). Body: `{ imageUrl, caption }`. Response: `{ id }`. |
| GET | `/api/instagram/media` | Session (creator context) | Lists the creator's Instagram media with cursor pagination. Query: `after`. Response: `{ media, paging: { after, has_next } }`. |

### `/api/tiktok`

Creator-facing TikTok OAuth endpoints (`getCreatorContext` auth, token auto-refresh).

| Method | Path | Auth | Description |
|---|---|---|---|
| GET | `/api/tiktok/connection` | Session (creator context) | Returns the creator's TikTok OAuth connection (without tokens). Response: `{ connection }`. |
| GET | `/api/tiktok/videos` | Session (creator context) | Lists the creator's TikTok videos via the Display API. Query: `cursor`. Response: `{ videos, cursor, has_more }`. |
| POST | `/api/tiktok/post-video` | Session (creator context) | Uploads a video to the creator's TikTok inbox as a draft (init → upload bytes → poll status). Multipart form-data with `video` file field. Response: `{ success, publish_id, status }`. |

### `/api/storage`

| Method | Path | Auth | Description |
|---|---|---|---|
| POST | `/api/storage/upload-url` | Session (`getUser`) | Creates a signed upload URL (R2 for `intro-videos`, Supabase Storage for `job-media`) with extension/content-type allowlists and user-scoped path validation. Body: `{ bucket, fileExt, customPath?, contentType? }`. Response: `{ signedUrl, storagePath, publicUrl, contentType? }`. |

### `/api/proxy`

| Method | Path | Auth | Description |
|---|---|---|---|
| GET | `/api/proxy/image` | Session (`getUser`) + origin check | Proxies images from allowlisted CDNs (`cdninstagram.com`, `tiktokcdn.com`, `tiktokcdn-us.com`) to bypass hotlink restrictions; cached 24h. Query: `url` (required, URL-encoded). |

### `/api/r`

| Method | Path | Auth | Description |
|---|---|---|---|
| GET | `/api/r/stats` | Session + admin (`account_type === 'admin'`) | Referral-code signup stats by 4-char code prefix. Query: `code` (min 3 chars). Response: `{ prefix, totalSignups, codes, timeSeries, firstSignup, lastSignup }`. |

### `/api/resolve-tiktok-url`

| Method | Path | Auth | Description |
|---|---|---|---|
| POST | `/api/resolve-tiktok-url` | Session (`getUser`) | Resolves TikTok short URLs (`tiktok.com/t/…`, `vm.tiktok.com/…`) to full video URLs by following the redirect (HEAD, query params stripped). Body: `{ url }`. Response: `{ resolvedUrl, wasShortUrl, resolved? }`. |

### `/api/actions`

| Method | Path | Auth | Description |
|---|---|---|---|
| GET | `/api/actions/posts` | Session (brand context) + origin check | Lists the brand's action items (posts to review) with post details. Query: `limit` (max 100), `offset`, `platform`, `account`, `campaign`, `status` (`pending` default \| `reviewed`), `sort` (`newest` \| `oldest` \| `added`). |

### `/api/api`

No route files exist under `app/api/api/` (directory not present).

| Method | Path | Auth | Description |
|---|---|---|---|

### `/api/bot`

| Method | Path | Auth | Description |
|---|---|---|---|
| POST | `/api/bot/process-message` | Internal: `x-internal-secret` = `BOT_INTERNAL_SECRET` (timing-safe); DB access runs under the caller-supplied user JWT so RLS is enforced | Generates an AI bot reply for a creator message (LLM call with thread history/context, inserts reply, Slack-pings admins when no context). Body: `{ messageId (uuid), userJwt, brandOrganizationId? }`. |

### `/api/dev`

Dev/staging only — both routes return 404 on `VERCEL_ENV=production` and require an `x-dev-secret` header matching `DEV_OTP_SECRET` (timing-safe compare).

| Method | Path | Auth | Description |
|---|---|---|---|
| POST | `/api/dev/otp` | Dev secret header; non-prod only | Generates a Supabase magic-link OTP for an email without sending mail (optionally creating the user with `mode: 'sign-up'`). Body: `{ email, mode? }`. Response: `{ otp }`. |
| POST | `/api/dev/session` | Dev secret header; non-prod only | Creates a real authenticated Supabase session for an email and returns auth cookies via Set-Cookie (for curl/E2E testing). Body: `{ email }`. Response: `{ ok, user_id, email }` + cookies. |

### `/api/example-videos`

| Method | Path | Auth | Description |
|---|---|---|---|
| GET | `/api/example-videos` | Session (`getAuthUserId`); supports `x-admin-view-as-brand` | Returns example videos for the test-videos task: platform templates merged with brand-specific overrides. Query: `brandId?` (falls back to the user's brand membership). Response: `{ videos }`. |

### `/api/health`

| Method | Path | Auth | Description |
|---|---|---|---|
| GET | `/api/health` | Public | Health check for monitoring: parallel database, auth-grants, Stripe EU, and Stripe US checks. Response: `{ status: healthy\|degraded\|unhealthy, timestamp, checks, version? }`; 503 when unhealthy. |

### `/api/v1`

Public API. Auth: `Authorization: Bearer <api_key>` validated by `withPublicApi`, with per-key rate limiting (`X-RateLimit-*` headers) and scope checks; data is scoped to the key's brand organization.

| Method | Path | Auth | Description |
|---|---|---|---|
| GET | `/api/v1/posts` | API key (scope `read:posts`) | Lists posts from the brand's tracked accounts, newest first. Query: `limit`, `offset`, `campaign?`. Response: `{ data: [{ id, platform, post_type, post_url, posted_at, caption, campaign, creator_handle, metrics }], pagination }`. |
| GET | `/api/v1/accounts` | API key (scope `read:creators`) | Lists the brand's tracked social accounts joined with connector/platform details. Query: `limit`, `offset`. Response: `{ data, pagination }`. |
| GET | `/api/v1/posts/{postId}/metrics` | API key (scope `read:posts`) | Time-series engagement metrics for one post (404 unless the post belongs to a brand-tracked account). Response: `{ data: [metric rows ordered by tracked_at] }`. |
