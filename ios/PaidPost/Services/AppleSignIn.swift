//
//  AppleSignIn.swift
//  PaidPost
//
//  Native Sign in with Apple → produces an id_token (+ raw nonce) that
//  AuthAPI.signInWithIdToken exchanges for a Supabase session.
//

import AuthenticationServices
import CryptoKit
import Foundation
import UIKit

/// Drives the native Sign in with Apple flow and returns the identity token
/// plus the raw nonce Supabase needs to verify it.
@MainActor
final class AppleSignInCoordinator: NSObject, ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {

    struct Result {
        let idToken: String
        let rawNonce: String
    }

    private var continuation: CheckedContinuation<Result, Error>?
    private var currentNonce: String?

    /// Presents the Apple sign-in sheet and resolves with the id_token + nonce.
    func signIn() async throws -> Result {
        let nonce = Self.randomNonce()
        currentNonce = nonce

        let request = ASAuthorizationAppleIDProvider().createRequest()
        request.requestedScopes = [.fullName, .email]
        request.nonce = Self.sha256(nonce) // Apple gets the hashed nonce; Supabase gets the raw one.

        return try await withCheckedThrowingContinuation { cont in
            self.continuation = cont
            let controller = ASAuthorizationController(authorizationRequests: [request])
            controller.delegate = self
            controller.presentationContextProvider = self
            controller.performRequests()
        }
    }

    // MARK: - Delegate

    func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithAuthorization authorization: ASAuthorization
    ) {
        guard
            let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
            let tokenData = credential.identityToken,
            let idToken = String(data: tokenData, encoding: .utf8),
            let rawNonce = currentNonce
        else {
            continuation?.resume(throwing: AuthAPI.AuthError.server("Apple sign-in failed."))
            continuation = nil
            return
        }
        continuation?.resume(returning: Result(idToken: idToken, rawNonce: rawNonce))
        continuation = nil
    }

    func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithError error: Error
    ) {
        // User cancel is not an error worth surfacing.
        if (error as? ASAuthorizationError)?.code == .canceled {
            continuation?.resume(throwing: CancellationError())
        } else {
            continuation?.resume(throwing: error)
        }
        continuation = nil
    }

    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        // Prefer the active foreground scene's key window; fall back to any
        // window across scenes before the empty-anchor last resort.
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        if let active = scenes.first(where: { $0.activationState == .foregroundActive }),
           let window = active.keyWindow ?? active.windows.first {
            return window
        }
        if let anyWindow = scenes.flatMap(\.windows).first {
            return anyWindow
        }
        // No window scene available — Apple's sheet can't anchor. Log so this
        // isn't a silent failure if it ever happens.
        print("[AppleSignIn] No window scene available to present the sign-in sheet.")
        return ASPresentationAnchor()
    }

    // MARK: - Nonce helpers

    private static func randomNonce(length: Int = 32) -> String {
        let charset = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        var remaining = length
        while remaining > 0 {
            var random: UInt8 = 0
            _ = SecRandomCopyBytes(kSecRandomDefault, 1, &random)
            if random < charset.count {
                result.append(charset[Int(random)])
                remaining -= 1
            }
        }
        return result
    }

    private static func sha256(_ input: String) -> String {
        SHA256.hash(data: Data(input.utf8)).map { String(format: "%02x", $0) }.joined()
    }
}
