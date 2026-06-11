# Stripe Payouts — Setup Guide

How to configure Stripe so this backend can pay creators. Companion to `PAYOUTS.md` (which explains how the flow works); this is the checklist to make it work on **your** Stripe account.

## How the code uses Stripe (so the steps make sense)

- One **platform account** sends money; every creator gets a **Stripe Connect Express** account created via API in their own country (`lib/payments/stripe-connect.ts`).
- The router (`lib/payments/stripe-router.ts`) sends everything to the client configured by **`STRIPE_SECRET_KEY`** (`lib/payments/stripe-client.ts`). The `*_US` variants and `/api/stripe/webhook-us` exist for legacy dual-region accounts — point them at the same account.
- Money path: brand pays (Checkout) → platform balance → **transfer** to creator's Connect account → **payout** to creator's bank.

## Step 1 — Create and activate the Stripe account

1. Sign up at https://dashboard.stripe.com (one account; US-based is what the code assumes post-migration).
2. Complete business activation (legal entity, bank account) — required before live payouts.

## Step 2 — Enable Connect

1. Dashboard → **Connect** → Get started → choose **Express** accounts.
2. Complete the **platform profile** (Connect → Settings): describe the platform; for paying creators worldwide you are requesting **cross-border transfers to recipient accounts** — Stripe reviews this for live mode.
3. Under Connect → Settings, set **branding** (name, icon, color) — creators see this during Express onboarding.
4. Payout settings: leave creator payout schedule manual/standard — creators trigger their own payouts through the app (`stripe.payouts.create` on the connected account).

## Step 3 — Get API keys → env vars

Dashboard → Developers → API keys:

| Env var | Value |
|---|---|
| `STRIPE_SECRET_KEY` | Secret key (`sk_live_…` / `sk_test_…`) — **this is the operative one** |
| `STRIPE_SECRET_KEY_US` | Same value (legacy compatibility) |
| `STRIPE_PUBLISHABLE_KEY` / `STRIPE_PUBLISHABLE_KEY_US` / `NEXT_PUBLIC_STRIPE_PUBLISHABLE_KEY` | Publishable key (`pk_…`) |

## Step 4 — Webhooks

Dashboard → Developers → Webhooks → **Add endpoint**:

- URL: `https://<your-backend-domain>/api/stripe/webhook`
- Events to send (what the handler consumes — `app/api/stripe/webhook/route.ts`):
  - `account.updated` (Connect onboarding completion — stores the creator's account id)
  - `transfer.created`, `transfer.updated`, `transfer.reversed`
  - `payout.created`, `payout.updated`, `payout.paid`, `payout.failed`, `payout.canceled`
  - `checkout.session.completed`, `checkout.session.expired`, `checkout.session.async_payment_succeeded`, `checkout.session.async_payment_failed`
  - `customer.subscription.*` and `invoice.*` (brand-side billing)
  - Easiest: select all of the above categories, or "send all events" while testing.
- For Connect events, create the endpoint with **"Listen to events on Connected accounts"** enabled as well — payout events happen on the creators' accounts.
- Copy the **signing secret** (`whsec_…`) → `STRIPE_WEBHOOK_SECRET` (and the same into `STRIPE_WEBHOOK_SECRET_US`, or create a second endpoint at `/api/stripe/webhook-us` if you keep that route active).

## Step 5 — App URLs

Express onboarding bounces creators back to the app, and those links are built from the app URL env vars. Make sure these point at your deployed backend domain:

`APP_URL`, `BASE_URL`, `NEXT_PUBLIC_APP_URL`, `NEXT_PUBLIC_BASE_URL`, `NEXT_PUBLIC_SITE_URL`

## Step 6 — Fund the platform balance

Transfers to creators come out of your **platform's Stripe balance**. It fills up from brand payments (Checkout/subscriptions). In test mode, or before real brand revenue exists, top up manually: Dashboard → Balance → Add to balance (test mode offers instant test funding).

## Step 7 — Test the loop (test mode)

1. Use `sk_test_…` keys everywhere; webhook endpoint on test mode too (or `stripe listen --forward-to localhost:3000/api/stripe/webhook` for local dev).
2. In the app, hit the creator Stripe onboarding endpoint (`POST /api/mobile/creators/stripe-connect`) and complete Express onboarding with Stripe's test data (any name, `000-000` phone verification, test SSN `000-00-0000`, test bank `110000000` / `000123456789`).
3. Approve a post payment via the admin pay endpoint → verify a transfer lands on the connected account.
4. Request a payout (`POST /api/mobile/creators/stripe-payout`, min $1.00) → verify `payout.paid` arrives at the webhook and the dashboard shows it.

## Go-live checklist

- [ ] Account activated, Connect platform profile approved (incl. cross-border recipient transfers if paying creators outside US/UK/CA/CH/EEA)
- [ ] Live keys in `STRIPE_SECRET_KEY` (+`_US`), publishable keys set
- [ ] Live webhook endpoint(s) created with the event list above + connected-account events; `STRIPE_WEBHOOK_SECRET` (+`_US`) set
- [ ] App URL env vars point at the production domain
- [ ] Platform balance funded (or brand payments flowing)
- [ ] One real end-to-end test: onboard → pay → transfer → payout
