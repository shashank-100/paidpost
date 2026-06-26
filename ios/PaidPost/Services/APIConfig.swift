//
//  APIConfig.swift
//  Methods
//

import Foundation

/// Backend connection settings.
///
/// `nonisolated` so the `APIClient` actor can read these without crossing
/// the main actor (avoids Swift 6 actor-isolation errors).
nonisolated enum APIConfig {
    /// Base URL of the deployed PaidPost backend. The mobile API lives under `/api/mobile`.
    /// Uses the project's stable production alias so it survives redeploys
    /// (per-deployment URLs like `paidpost-<hash>.vercel.app` rotate every push).
    static let baseURL = URL(string: "https://paidpost.vercel.app")!

    static var mobileBaseURL: URL { baseURL.appendingPathComponent("api/mobile") }

    /// Supabase project used for authentication (email OTP).
    enum Supabase {
        static let url = URL(string: "https://jmlnyuwlrbxhxckuuhxw.supabase.co")!
        static let publishableKey = "sb_publishable_UN8AyG18fzvD000Vd2SwNw_oGNSv1fh"
    }

    /// Apple-review test account used by the `auth/test-bypass` route.
    ///
    /// These credentials ship in release builds ON PURPOSE: the App Store
    /// reviewer runs a release build and must be able to sign in with them.
    /// They are NOT a security hole on their own — the bypass only works when
    /// the backend has `APPLE_REVIEW_BYPASS_ENABLED=true`. The real control is
    /// that server flag: keep it ON during review, turn it OFF afterward.
    enum TestAccount {
        static let email = "test-user-0-apple@gmail.com"
        static let code = "000000"
    }
}
