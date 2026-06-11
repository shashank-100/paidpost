# Creator Payouts

How the backend moves money from brands to creators' bank accounts, end to end. File paths refer to the backend repo (`paidpost-backend`).

## The big picture

```
Creator posts content → admin approves payment → Stripe transfer to creator's
Connect account → creator (or auto) triggers payout → creator's bank
```

Money is tracked in two layers that must agree:

1. **The platform ledger** — the `creator_transactions` table (created in `supabase/migrations/20250102000003_create_creator_tables.sql`). Append-only rows: earnings, withdrawals, bonuses, reversals. Balances are always derived from this ledger via the `get_creator_balance()` RPC, never cached on the user row.
2. **Stripe Connect** — each creator onboards onto a Stripe Connect Express account. Actual cash movement (transfers and bank payouts) happens here.

## 1. How creators earn

- **Post payments** — the core flow. Each approved social post is a `managed_creator_posts` row carrying `base_pay_cents`, `bonus_cents`, and a `payment_status` state machine (`pending` → review → processing → `completed`, or `excluded`).
- **CPM earnings** — view-based campaigns credit earnings through the `process_cpm_payout()` RPC.
- **Admin bonuses** — one-off grants via `POST /api/admin/creators/{id}/bonus`.

All ledger writes go through atomic RPCs — `record_earning_atomic()`, `record_withdrawal_atomic()`, `process_post_payment()` — which serialize concurrent writes per creator so a balance can never be double-spent by racing requests.

## 2. The wallet (what creators see)

`getWalletDashboard` in `lib/services/wallet.ts` powers both clients:

- Web: `GET /api/creators/wallet`
- iOS: `GET /api/mobile/creators/wallet` (handler in `lib/mobile/handlers.ts`)

It returns balance, pending amounts, and recent ledger transactions.

## 3. Admin approval & payment execution

Admins drive the actual paying via `POST /api/admin/creator-post-payments/pay` (`app/api/admin/creator-post-payments/pay/route.ts`):

- Restricted to payout-capable admin roles, with rate limits; `POST /api/admin/payouts/{creatorId}/add-funds` additionally enforces hourly limits.
- Posts can be re-verified as still live before paying (`POST /api/admin/creator-post-payments/verify`).
- Per-post amounts can be adjusted first (`POST /api/admin/creator-post-payments/update-base`).
- Payment runs through the `process_post_payment()` RPC (atomic ledger write), then a **Stripe transfer** moves funds from the platform account to the creator's Connect account (`lib/payments/stripe-connect.ts`).
- **Off-platform payments**: the pay route accepts an optional `offplatform_method` string (e.g. "paypal"). When set, the payment is recorded in the ledger but **no Stripe transfer is made** — the admin settles it manually outside the platform.
- Payout events post Slack notifications (`lib/notifications/slack/payouts.ts`).

### Dual-region Stripe

There are two Stripe platform accounts (EU and US). `lib/payments/stripe-router.ts` picks the right one from the creator's `stripe_region` (EU is the default/legacy). Each region has its own keys (`STRIPE_SECRET_KEY` / `STRIPE_SECRET_KEY_US`) and webhook endpoint (`/api/stripe/webhook`, `/api/stripe/webhook-us`).

## 4. Creator-initiated payout (Connect balance → bank)

Endpoints (same service, `requestStripePayout` in `lib/services/wallet.ts`):

- Web: `POST /api/creators/stripe-payout`
- iOS: `POST /api/mobile/creators/stripe-payout`

Verified behavior of the service:

| Rule | Value |
|---|---|
| Source of funds | The creator's **Stripe Connect available balance** (queried live from Stripe — not the DB ledger) |
| Methods | `standard` (free, ~days) or `instant` (where Stripe supports it) |
| Amount | `amount_cents` optional — omitted means "pay out everything available" |
| Minimum | **$1.00** (`MINIMUM_PAYOUT_CENTS = 100`); errors return `minimum_cents` |
| Over-balance | Rejected with `available_balance` in the error payload |
| Idempotency | Key of `creator-payout:{creatorId}:{amount}:{currency}:{minute}` — a double-tap inside the same minute can't create two payouts |

The call creates `stripe.payouts.create(...)` **on the connected account** and returns the payout id, status, and `arrival_date`.

## 5. Safety mechanisms

- **Append-only ledger** — corrections are new reversal rows, never updates/deletes.
- **Atomic RPCs with per-creator serialization** — no concurrent double-pay.
- **Stripe idempotency keys** on both transfers and payouts.
- **Status state machine** on `managed_creator_posts.payment_status` prevents re-paying a completed post.
- **Webhook reconciliation** — the two Stripe webhook routes ingest transfer/payout events so platform state converges with Stripe even if a response was lost.
- **Role + rate-limit gates** on every admin money endpoint; Slack alerts on payout activity.

## What the iOS app needs (paidpost)

For the wallet/earnings feature, the client only touches three authenticated endpoints:

1. `GET /api/mobile/creators/wallet` — balance + transactions for the wallet screen
2. `POST /api/mobile/creators/stripe-connect` — start Stripe onboarding (returns a URL to open)
3. `POST /api/mobile/creators/stripe-payout` — body `{ amount_cents?, method: "standard" | "instant" }`; handle the `minimum_cents` / `available_balance` error payloads

All with `Authorization: Bearer <Supabase JWT>`. See `docs/API.md` for the full mobile surface.
