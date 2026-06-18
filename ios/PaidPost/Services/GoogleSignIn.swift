//
//  GoogleSignIn.swift
//  PaidPost
//
//  Native Google Sign-In → returns the Google id_token that
//  AuthAPI.signInWithIdToken exchanges for a Supabase session.
//
//  Compiles with OR without the GoogleSignIn SPM package: the real flow is
//  guarded by `#if canImport(GoogleSignIn)`. Add the package
//  (https://github.com/google/GoogleSignIn-iOS) and the real path activates
//  automatically — no further code change needed. GIDClientID + the reversed-
//  client-id URL scheme are configured in Info.plist.
//

import Foundation
import UIKit

#if canImport(GoogleSignIn)
import GoogleSignIn
#endif

enum GoogleSignInHelper {

    enum GoogleError: LocalizedError {
        case sdkMissing
        case noPresenter
        case noIdToken
        var errorDescription: String? {
            switch self {
            case .sdkMissing: return "Google sign-in isn't available in this build."
            case .noPresenter: return "Couldn't present Google sign-in."
            case .noIdToken: return "Google didn't return a valid token."
            }
        }
    }

    /// Presents Google Sign-In and returns the id_token for Supabase.
    ///
    /// A user cancel is re-thrown as `CancellationError` so callers can treat it
    /// as a no-op — the GoogleSignIn SDK reports cancel as a `GIDSignInError`
    /// with code `.canceled` (not `CancellationError`), so it must be translated
    /// here or the cancel would surface as a spurious error alert.
    @MainActor
    static func signIn() async throws -> String {
        #if canImport(GoogleSignIn)
        guard let presenter = topViewController() else { throw GoogleError.noPresenter }
        let result: GIDSignInResult
        do {
            result = try await GIDSignIn.sharedInstance.signIn(withPresenting: presenter)
        } catch {
            if (error as NSError).code == GIDSignInError.canceled.rawValue {
                throw CancellationError()
            }
            throw error
        }
        guard let idToken = result.user.idToken?.tokenString else { throw GoogleError.noIdToken }
        return idToken
        #else
        throw GoogleError.sdkMissing
        #endif
    }

    @MainActor
    private static func topViewController() -> UIViewController? {
        let scene = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first(where: { $0.activationState == .foregroundActive })
            ?? UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first
        var top = scene?.keyWindow?.rootViewController
            ?? scene?.windows.first?.rootViewController
        while let presented = top?.presentedViewController { top = presented }
        return top
    }
}
