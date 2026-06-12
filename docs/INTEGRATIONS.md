# Integrations Status

Live status of every external service the backend depends on, and exactly how to finish the ones that aren't done. Backend is deployed at **https://paidpost.vercel.app** (alias the iOS app points at).

Last verified: 2026-06-11 via `GET /api/health`.

## Status at a glance

| Integration | Purpose | Status | Blocks if missing |
|---|---|---|---|
| **Vercel** | Hosts the backend | ✅ Live | Everything |
| **Supabase** | Database + auth (email OTP) | ✅ Live | Everything |
| **Cloudflare R2** | Video storage | ✅ Live (buckets + keys set, seeded & playback-verified) | Video upload/playback |
| **Stripe** | Payments + creator payouts | 🔴 Placeholder (`mock-dev`) — *payout batch* | Deposits, payouts |
| **Resend** | Transactional email | 🔴 Placeholder — *deferred* | Email delivery |
| **Twilio** | SMS / phone verification (fraud gate) | 🔴 Placeholder — *payout batch* | Phone verify |
| **RapidAPI** | TikTok/IG/YouTube stats sync | 🔴 Placeholder | Social metrics |
| **Slack** | Internal alerts | 🔴 Placeholder | Ops alerts only |
| **PostHog** | Analytics | 🔴 Placeholder | Analytics only |

Legend: ✅ working · 🟡 partially configured · 🔴 placeholder (feature errors at runtime, but build/app still run).

> The core stack (Vercel + Supabase) is fully live — sign-in, jobs, profile, and wallet-read all work today. The 🔴 items only break their specific feature; the app runs without them.

---

## ✅ Vercel — DONE

- Project: `shashank100s-projects/paidpost`
- Production alias: `paidpost.vercel.app` (stable across redeploys; the iOS app hardcodes this in `APIConfig.swift`)
- Health: `GET /api/health` → 200, DB + auth `ok`
- Source: GitHub `shashank-100/paidpost-backend`
- **To redeploy after env changes:** `vercel deploy --prod` from the backend repo (env changes don't apply until a new build).

## ✅ Supabase — DONE

- Project: **paidpost** (`jmlnyuwlrbxhxckuuhxw`, East US)
- All 606 migrations applied; DB + auth verified live in the health check
- Env vars set: `NEXT_PUBLIC_SUPABASE_URL`, `SUPABASE_URL`, `SUPABASE_SECRET_KEY`/`SUPABASE_SERVICE_ROLE_KEY`, `NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY`
- Dashboard: https://supabase.com/dashboard/project/jmlnyuwlrbxhxckuuhxw
- DB password: `~/Desktop/GitHub/8x/.paidpost-db-password` (gitignored)

## 🟡 Cloudflare R2 — buckets ready, API keys pending

Storage for creator videos (`lib/storage/r2.ts`, used by `/api/creator/videos/*` and mobile handlers).

**Done:**
- Account ID: `0dee0ac43d70ed3a42654a4cf4960571`
- Buckets created: `paidpost-videos` (all videos) + `intro-videos` (hardcoded in code)
- Public URL enabled: `https://pub-22b7648b8965454293478b8aa8831f44.r2.dev`
- Env set: `R2_ACCOUNT_ID`, `R2_BUCKET_NAME=paidpost-videos`, `R2_MANAGED_CREATORS_BUCKET=paidpost-videos`, `R2_PUBLIC_URL`

**Remaining — set the S3 API keys and redeploy:**
An R2 API token was created (dashboard → R2 → API Tokens → "Object Read & Write"). Set its credentials:
```bash
cd ~/Desktop/GitHub/8x   # backend repo, linked to the paidpost Vercel project
printf '%s' "<ACCESS_KEY_ID>"     | vercel env add R2_ACCESS_KEY_ID production
printf '%s' "<SECRET_ACCESS_KEY>" | vercel env add R2_SECRET_ACCESS_KEY production
vercel deploy --prod
```
> S3 keys can only be minted from the Cloudflare dashboard (not wrangler/OAuth). The token value (`cfat_…`) is for the Cloudflare REST API and is **not** used here — only the Access Key ID + Secret Access Key go into the env.

---

## 🔴 Stripe — placeholder (do later)

Payments and creator payouts. Currently `STRIPE_SECRET_KEY=mock-dev`, so the health check shows `stripe_eu: error`.

**To finish:** follow `docs/STRIPE_SETUP.md` (full step-by-step), then set the real keys:
`STRIPE_SECRET_KEY` (+`_US`), `STRIPE_PUBLISHABLE_KEY` (+`_US`), `NEXT_PUBLIC_STRIPE_PUBLISHABLE_KEY`, `STRIPE_WEBHOOK_SECRET` (+`_US`). See `docs/PAYOUTS.md` for how the money flow works.

## 🔴 Resend — placeholder

Transactional email (`RESEND_API_KEY`). **Priority** — note that Supabase email OTP login uses Supabase's own email by default, so sign-in works without this; Resend is for app-sent emails (receipts, notifications).
**To finish:** sign up at resend.com → verify a sending domain → create an API key → `vercel env add RESEND_API_KEY production`.

## 🔴 Twilio — placeholder (do in the payout batch)

SMS phone verification (`TWILIO_ACCOUNT_SID`, `TWILIO_AUTH_TOKEN`, `TWILIO_PHONE_NUMBER`, `TWILIO_VERIFY_SERVICE_SID`). Not a login method — it's an **anti-fraud gate** (one-account-per-person) tied to payouts, so it's set up together with Stripe, not before. Not required to use the app today.
**To finish:** Twilio console → create a Verify service → copy Account SID, Auth Token, Verify Service SID → set the four env vars.

> **Payout batch:** Stripe + Twilio are configured together when enabling real creator cash-out — both are "real accounts + real money" concerns. See `docs/STRIPE_SETUP.md` and `docs/PAYOUTS.md`.

## 🔴 RapidAPI — placeholder

TikTok/Instagram/YouTube stats sync (`RAPIDAPI_KEY_TIKTOK`, `_INSTAGRAM`, `_YOUTUBE`).
**To finish:** rapidapi.com → subscribe to the scraping APIs the backend uses → set the per-platform keys. Only needed once you sync real creator post metrics.

## 🔴 Slack / PostHog — placeholder (optional)

Internal ops alerts and product analytics. Not user-facing; safe to leave as placeholders indefinitely. Set `SLACK_BOT_TOKEN`/`SLACK_CHANNEL_ID_*` and `POSTHOG_KEY`/`NEXT_PUBLIC_POSTHOG_KEY` if/when you want them.

---

## How to set any env var (pattern)

All from the backend repo (`~/Desktop/GitHub/8x`, linked to the Vercel `paidpost` project):
```bash
printf '%s' "<value>" | vercel env add <NAME> production   # add
vercel env rm <NAME> production --yes                       # remove (before re-adding to change)
vercel env ls production                                    # list (shows "Encrypted", not values)
vercel deploy --prod                                        # apply — REQUIRED after any change
```
Verify the result with `curl -s https://paidpost.vercel.app/api/health`.
