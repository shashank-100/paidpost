# Mobile API Coverage

Inventory of every `/api/mobile/*` endpoint the backend exposes, whether the
iOS app uses it, and what's worth adding. Generated 2026-06-12.

**Summary:** the backend exposes **~60 mobile endpoints**. The iOS app currently
uses **~30** of them. The rest are features inherited from the reference backend
that aren't wired into the app yet.

Legend: ✅ used by app · ⚪️ not used · ⚠️ should consider adding

---

## Auth & Account
| Method | Endpoint | App | Notes |
|---|---|---|---|
| GET | `version-check` | ✅ | force-update check |
| POST | `auth/test-bypass` | ✅ | Apple-review login |
| POST | `auth/check-email` | ✅ | blocks brand accounts on mobile |
| DELETE | `creator/account` | ✅ | delete account (App Store req.) |

## Jobs & Applications
| Method | Endpoint | App | Notes |
|---|---|---|---|
| GET | `jobs` | ✅ | discover feed |
| GET | `jobs/{id}` | ✅ | job detail |
| POST | `jobs/{id}/apply` | ✅ | apply |
| GET | `applications` | ✅ | my applications |
| POST | `creator/submit-application` | ✅ | two-step apply |
| POST | `applications/{id}/contract/sign` | ✅ | sign contract |

## Profile
| Method | Endpoint | App | Notes |
|---|---|---|---|
| GET | `creator/profile` | ✅ | |
| PATCH | `creator/profile` | ✅ | edit profile |
| POST | `creator/profile/picture` | ✅ | avatar upload |
| PUT | `creator/languages` | ✅ | |
| GET | `creator/managed-status` | ✅ | |
| PATCH | `creator/handles` | ✅ | social handles |
| GET | `creator/suggest-handles` | ✅ | |

## Money / Payouts
| Method | Endpoint | App | Notes |
|---|---|---|---|
| GET | `creators/wallet` | ✅ | balance/earnings |
| POST | `creators/stripe-connect` | ⚠️ | gated "coming soon"; needs `STRIPE_SECRET_KEY` |
| POST | `creators/stripe-payout` | ⚠️ | gated "coming soon" |
| GET | `creators/stripe-dashboard` | ⚪️ | deeper Stripe view — not wired |
| GET | `creators/stripe-balance` | ⚪️ | not wired |
| GET | `creators/wallet/paid-posts` | ⚪️ | per-post payout history — not wired |

## Notifications & Messaging
| Method | Endpoint | App | Notes |
|---|---|---|---|
| GET | `notifications` | ✅ | |
| GET | `notifications/unread-count` | ✅ | |
| POST | `notifications/mark-read` | ✅ | |
| GET | `inbox` | ✅ | message threads |
| GET | `threads/{key}` | ✅ | thread detail |
| POST | `threads/{key}/read` | ✅ | |
| POST | `threads/{key}/messages` | ✅ | send message |
| POST | `notifications/push-token` | ⚠️ | push not wired (no APNs in app) |
| POST | `notifications/push-token/deactivate` | ⚪️ | push not wired |

## Content — Posts & Videos
| Method | Endpoint | App | Notes |
|---|---|---|---|
| GET | `creator/posts` | ✅ | brand-scoped |
| POST | `creator/posts/sync` | ✅ | |
| PATCH | `creator/posts/{id}/ad-code` | ✅ | |
| GET | `creator/videos` | ✅ | brand-scoped |
| POST | `creator/videos` | ✅ | |
| POST | `creator/videos/upload-url` | ✅ | presigned R2 upload |

## Campaign Workspace & Warmup
| Method | Endpoint | App | Notes |
|---|---|---|---|
| GET | `creator/workspace/{slug}` | ✅ | |
| GET | `applications/{id}/warmup` | ✅ | |
| POST | `applications/{id}/warmup` | ✅ | |
| GET | `creator/warmup/{slug}` | ✅ | timeline |
| POST | `creator/warmup/{slug}/scroll` | ✅ | |
| POST | `creator/warmup/{slug}/screenshot` | ✅ | |
| POST | `creator/warmup/{slug}/screenshot-upload-url` | ✅ | |
| POST | `creator/warmup/{slug}/daily-warmup-updates` | ✅ | |
| GET | `brands/{slug}/reference-videos` | ✅ | |

## Moderation / Safety
| Method | Endpoint | App | Notes |
|---|---|---|---|
| POST | `creator/report-post` | ⚠️ **SHOULD ADD** | UGC reporting — see below |

## Not wired (reference-backend features the app doesn't use)
| Method | Endpoint | Why unused |
|---|---|---|
| GET/POST/PATCH/DELETE | `burner-accounts` | secondary-account management — out of scope |
| GET/PATCH | `creator/course` | in-app learning course — not built |
| GET | `creator/tasks` · POST `request-extension` · PATCH `{id}` | task system — not built |
| POST | `creator/trust-gate` | trust verification flow — not built |
| GET | `creator/resources` | creator resource library — not built |
| GET | `onboarding/intro-video` | onboarding video — app uses its own |
| GET/POST | `waitlist/me` · `waitlist/join` | waitlist — app skips straight to sign-in |

---

## Do we need to add any?

**For App Store submission — one matters:**

- ⚠️ **`creator/report-post` (report UGC).** The app declares **User-Generated
  Content + Messaging** in its age rating. Apple Guideline 1.2 then **requires** a
  way to report objectionable content and block users. The backend endpoint
  exists; the app should expose a **Report** action on user content / messages.
  **Without it, rejection is likely.** This is the only must-add for review.

**Everything else is optional / future:**
- **Push notifications** (`push-token`) — nice-to-have; needs APNs setup. Not
  required for launch.
- **Stripe dashboard/balance/paid-posts** — wire these when real payouts ship.
- **Course / tasks / resources / burner-accounts / waitlist / trust-gate** —
  features from the reference app that aren't part of this product's scope. Skip
  unless you decide to build them.

## Bottom line
- **Used:** ~30 endpoints — all core flows work (verified by `tests/functionaltest/test_mobile_api.py`).
- **Must add before review:** report/block UI (uses existing `creator/report-post`).
- **Optional later:** push, full payouts, course/tasks.
