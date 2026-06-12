# PaidPost — TestFlight Release Steps

The app is code-complete, builds clean, and is reviewer-safe. The only remaining
step is **signing + archiving**, which must be done in Xcode with your Apple
Developer account (cannot be automated).

## Prerequisites
- An **Apple Developer Program** membership ($99/yr) — enroll at developer.apple.com if not already.
- Xcode 26.5 (already installed).

## Steps

1. **Add your Apple ID to Xcode**
   - Xcode → Settings (⌘,) → **Accounts** → **+** → **Apple ID** → sign in.

2. **Open the project**
   - Open `ios/PaidPost.xcodeproj` in Xcode.

3. **Set signing**
   - Select the **PaidPost** target → **Signing & Capabilities** tab.
   - Check **Automatically manage signing**.
   - Pick your **Team** from the dropdown.
   - Bundle ID is `com.paidpost.app`. If it's taken, change to something unique
     (e.g. `com.<yourname>.paidpost`) here and it auto-registers.

4. **Select archive destination**
   - Top device bar → **Any iOS Device (arm64)** (not a simulator).

5. **Archive**
   - Menu → **Product → Archive**. Wait ~2-3 min.
   - The **Organizer** window opens when done.

6. **Upload to TestFlight**
   - In Organizer: **Distribute App → TestFlight & App Store → Upload** → follow prompts.
   - First upload also creates the app record in **App Store Connect** (or create it
     first at appstoreconnect.apple.com with bundle ID `com.paidpost.app`).

7. **Add testers**
   - App Store Connect → your app → **TestFlight** → add yourself as an internal tester.
   - Install the **TestFlight** app on your iPhone → accept invite → install.

## App Store Connect metadata
- **Support URL:** `https://paidpost.vercel.app/support`
- **Marketing URL:** leave blank (optional)
- **Privacy Policy URL:** `https://paidpost.vercel.app/privacy`

## Notes / follow-ups (not blockers)
- **Login** uses email OTP (Supabase). Confirmed delivering. Supabase's built-in
  email is rate-limited (~3-4/hr) — set up a provider (Resend) before a wide launch.
- **Payouts** show "Coming soon." Wire Stripe Connect when ready (creators are
  paid out individually; your India company pays out to creators abroad).
- **Backend** is API-only: `paidpost.vercel.app` serves `/api/*`, `/privacy`,
  `/terms`, `/support`, and Stripe callbacks. All other routes 404 by design.
