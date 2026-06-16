# Sign in with Apple + Google — Implementation Plan

Replace email-OTP login with native **Sign in with Apple** and **Google Sign-In**.
This removes the magic-link 404, the email rate limit, and the OTP friction entirely.

> Apple Guideline 4.8: if you offer Google sign-in, you **must** also offer Sign in
> with Apple. We do both. This requires a new build + re-submission.

## How it works (both providers, same pattern)

1. User taps "Continue with Apple" / "Continue with Google" in the app.
2. The native SDK returns an **`id_token`** (a signed JWT identifying the user).
3. App sends it to Supabase: `POST /auth/v1/token?grant_type=id_token` with `{ provider, id_token, [nonce] }`.
4. Supabase verifies it, creates/loads the user, returns a session (access + refresh token).
5. App stores the session in Keychain — same as today.

No magic links, no emails, no codes.

---

## Checklist

### A. Supabase config (dashboard)
- [ ] **Auth → Providers → Apple** → enable. Add your Apple **Services ID** (client id) and the **secret key** (generated from the Apple key — see C).
- [ ] **Auth → Providers → Google** → enable. Add the Google **Client ID** and **Client Secret** (from B).
- [ ] **Auth → URL Configuration → Redirect URLs** → add `paidpost://login-callback` (and `https://paidpost.vercel.app/**`).

### B. Google Cloud (for Google Sign-In)
- [ ] console.cloud.google.com → create/select a project.
- [ ] **APIs & Services → Credentials → Create OAuth client ID**:
  - Create a **Web** client → gives the Client ID + Secret for **Supabase** (paste into A).
  - Create an **iOS** client → bundle id `com.paidpost.app` → gives the iOS Client ID + a **reversed client ID** for the app's URL scheme.
- [ ] Configure the OAuth consent screen (app name PaidPost, support email, logo).

### C. Apple Developer (for Sign in with Apple)
- [ ] developer.apple.com → **Certificates, IDs & Profiles**:
  - Your App ID (`com.paidpost.app`) → enable **Sign in with Apple** capability.
  - Create a **Services ID** (e.g. `com.paidpost.signin`) → this is the Supabase "client id".
  - Create a **Sign in with Apple Key** (.p8) → use it (with Team ID + Key ID) to generate the **client secret JWT** Supabase needs.
- [ ] In **Xcode** → target → Signing & Capabilities → **+ Capability → Sign in with Apple**.

### D. iOS app code
- [ ] Add the **Google Sign-In SDK** (Swift Package: `https://github.com/google/GoogleSignIn-iOS`).
- [ ] Add the Google **reversed client ID** as a URL scheme (Info → URL Types).
- [ ] Add `GIDClientID` to Info.plist (the iOS client id).
- [ ] `SignInView` → replace the email/code fields with two buttons: **Sign in with Apple** (`SignInWithAppleButton`) + **Continue with Google** (`GIDSignIn`).
- [ ] `AuthAPI` → add `signInWithIdToken(provider:idToken:nonce:)` calling Supabase's `id_token` grant. *(Code below — already added.)*
- [ ] Keep the Apple-reviewer **test-bypass** path (reviewers still use `test-user-0-apple@gmail.com` if needed).

### E. Verify
- [ ] Apple button → Face ID → logged in, session persists.
- [ ] Google button → account picker → logged in.
- [ ] Sign out → sign back in (both).
- [ ] New build → archive → re-submit to App Store.

---

## The Supabase token exchange (already implemented)

`AuthAPI.signInWithIdToken` (in `AuthAPI.swift`) posts the provider's `id_token` to
Supabase's `token?grant_type=id_token` endpoint and returns an `AuthSession`. The
SDK wiring (Apple/Google buttons that *produce* the id_token) is the remaining
iOS work in step D, plus the dashboard/credential steps A–C.

## Effort / order
1. **C + Apple capability** (Sign in with Apple is the simpler half — native, no SDK).
2. **B + Google SDK** (Google is the heavier half).
3. **D code** → **E build + resubmit**.

Estimated: ~half a day including the Apple/Google developer-console setup (most of the
time is credential creation, not code).
