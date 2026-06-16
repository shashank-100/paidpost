# Sign-In Flow — Fix Checklist

How email sign-in works today, what's broken, and the exact steps to fix it in the Supabase dashboard. No code changes needed — all fixes are Supabase config.

## How it works now (the flow)

The iOS app uses **Supabase email OTP** (`AuthAPI.swift`):

1. User enters email → app calls `POST /auth/v1/otp` with `{ email, create_user: true }` → Supabase emails a code.
2. User enters the 6-digit code → app calls `POST /auth/v1/verify` → Supabase returns a session (access + refresh token).
3. App stores the session in the Keychain.

The Apple reviewer path bypasses email entirely (test account + `000000` via the backend).

## What's broken

| # | Problem | Symptom | Fix location |
|---|---|---|---|
| 1 | **Site URL points at a dead domain** | Magic-link email → `paidpost-shashank100s-projects.vercel.app` → **404** | Supabase dashboard |
| 2 | **Email shows a magic LINK, not a clean code** | User clicks link (404) instead of typing the code | Supabase email template |
| 3 | **Built-in email is rate-limited (~2–4/hour)** | 3rd+ signup in an hour gets no email → can't log in | Supabase SMTP (custom) |

> Note: the app only needs the **6-digit code**, not the link. Fixes #1 and #2 make the email match the app; #3 is required before real launch traffic.

---

## Checklist

### ☐ Fix 1 — Set the correct Site URL (stops the 404)
Supabase Dashboard → **Authentication → URL Configuration**
- **Site URL:** `https://paidpost.vercel.app`
- **Redirect URLs:** add `https://paidpost.vercel.app/**` and the app scheme `paidpost://**`
- Save.

*Why:* magic links and redirects build off Site URL. The old value was a per-deployment URL that no longer resolves.

### ☐ Fix 2 — Make the email send a clean OTP code
Supabase Dashboard → **Authentication → Email Templates → Magic Link** (this template is reused for OTP)
- Ensure the template includes the token: the body should prominently show **`{{ .Token }}`** (the 6-digit code), e.g.:
  > Your PaidPost code is: **{{ .Token }}**
- You can keep `{{ .ConfirmationURL }}` as a fallback, but lead with the code since the app expects a typed code.
- Save.

*Why:* the default template emphasizes a clickable link. The native app needs the code, not the link.

### ☐ Fix 3 — Add custom SMTP (removes the ~2/hr limit) — REQUIRED before launch
Supabase Dashboard → **Project Settings → Authentication → SMTP Settings → Enable Custom SMTP**

Easiest provider = **Resend** (you're already planning it):
1. Sign up at resend.com → verify a sending domain (or use `onboarding@resend.dev` to test).
2. Create an API key.
3. In Supabase SMTP settings enter:
   - **Host:** `smtp.resend.com`
   - **Port:** `465` (SSL) or `587` (TLS)
   - **Username:** `resend`
   - **Password:** your Resend API key
   - **Sender email:** `no-reply@yourdomain` (must be a verified Resend domain) or `onboarding@resend.dev` for testing
   - **Sender name:** `PaidPost`
4. Save. Send yourself a test sign-in to confirm delivery.

*Why:* Supabase's built-in email is rate-limited (a few per hour) and meant only for development. Real users will hit the wall without custom SMTP.

### ☐ Verify end-to-end
- [ ] Request a code in the app with a **real** email → email arrives within seconds
- [ ] Email shows a **6-digit code** (not just a link)
- [ ] Entering the code logs you in
- [ ] Sign out → sign back in works
- [ ] (If you click the email link) it lands on a real page, not a 404

---

## Optional next step (better UX, later) — Sign in with Apple + Google

Email OTP works but has friction (wait for email, copy code) and depends on email delivery. For v1.1, consider **Sign in with Apple + Google** (Supabase supports both natively):
- ✅ Removes the email dependency entirely (no Resend/SMTP needed for login)
- ✅ One-tap sign-in, higher conversion
- ⚠️ Apple **requires** Sign in with Apple if you offer any third-party social login
- ⚠️ More setup (OAuth credentials + iOS SDK wiring + new build) — not for the current submission

Decision: ship v1.0 with email OTP (fixes above), add Apple/Google in v1.1.

---

## Summary

| Fix | Priority | Effort | Blocks |
|---|---|---|---|
| 1. Site URL | High | 30 sec | Magic-link 404 |
| 2. Email template (code) | Medium | 2 min | Confusing email |
| 3. Custom SMTP (Resend) | **Required pre-launch** | ~10 min | Real-user login at scale |

The reviewer can already log in (bypass), so these don't block App **review** — but #3 blocks real **launch**.
