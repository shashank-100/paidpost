# Integrations Status

Live status of every external service the backend depends on, and exactly how to finish the ones that aren't done. Backend is deployed at **https://paidpost.vercel.app** (alias the iOS app points at).

Last verified: 2026-06-18 (Stripe row updated — test keys set; Connect/webhook pending).

## Status at a glance

| Integration | Purpose | Status | Blocks if missing |
|---|---|---|---|
| **Vercel** | Hosts the backend | ✅ Live | Everything |
| **Supabase** | Database + auth (email OTP) | ✅ Live | Everything |
| **Cloudflare R2** | Video storage | ✅ Live (buckets + S3 API keys set) | Video upload/playback |
| **Stripe** | Payments + creator payouts | 🟡 Test keys set, deployed; Connect + webhook pending | Deposits, payouts |
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

## ✅ Cloudflare R2 — DONE (verified 2026-06-18)

Storage for creator videos (`lib/storage/r2.ts`, used by `/api/creator/videos/*` and mobile handlers).

- Account ID: `0dee0ac43d70ed3a42654a4cf4960571`
- Buckets: `paidpost-videos` (all videos) + `intro-videos` (hardcoded in code)
- Public URL: `https://pub-22b7648b8965454293478b8aa8831f44.r2.dev`
- All 6 env vars set in Vercel Production: `R2_ACCOUNT_ID`, `R2_BUCKET_NAME`, `R2_MANAGED_CREATORS_BUCKET`, `R2_PUBLIC_URL`, **`R2_ACCESS_KEY_ID`, `R2_SECRET_ACCESS_KEY`** (S3 API keys — confirmed present).

> The S3 API keys ARE set — an earlier version of this doc incorrectly listed them as pending. Confirmed via `vercel env ls` on 2026-06-18.

---

## 🟡 Stripe — test keys live, Connect + webhook remain (updated 2026-06-18)

Payments and creator payouts. **Test-mode** keys are now set in Vercel Production and deployed; the key authenticates against the Stripe API (`livemode: false`).

**Done:**
- `STRIPE_SECRET_KEY`, `STRIPE_SECRET_KEY_US` (test secret), `STRIPE_PUBLISHABLE_KEY`, `NEXT_PUBLIC_STRIPE_PUBLISHABLE_KEY` (test publishable) — all set + deployed, verified valid.
- Backend Stripe Connect + payout code is complete (`lib/payments/stripe-connect.ts`, mobile `creators/stripe-connect|stripe-payout|stripe-balance|stripe-dashboard|wallet` routes).

**Remaining (in order):**
1. **Enable Connect** on the Stripe account (dashboard → Connect → Express). Currently NOT enabled — creating a Connect account fails with *"You can only create new accounts if you've signed up for Connect."* This blocks all creator onboarding/payouts.
   - ⛔ Live activation needs the business **EIN** (expected ~Jul 8–22 via Stripe Atlas) + bank account. Test-mode enablement normally doesn't need an SSN; if the dashboard demands one, it's bundling Connect signup with full live activation.
2. **Webhook** — create `https://paidpost.vercel.app/api/stripe/webhook` (with "Listen to events on Connected accounts" on), then set `STRIPE_WEBHOOK_SECRET` (+`_US`). Until this exists, finished onboarding won't flip `stripe_payouts_enabled`.
3. **Live keys** — swap test `sk_test_…`/`pk_test_…` for `sk_live_…`/`pk_live_…` after activation, redeploy.
4. ⚠️ **Roll the current test secret key** — it was exposed in a chat transcript. Roll it in the dashboard and re-set `STRIPE_SECRET_KEY`(+`_US`).

See `docs/STRIPE_SETUP.md` (step-by-step) and `docs/PAYOUTS.md` (money flow).

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
