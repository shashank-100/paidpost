//
//  AuthAPI.swift
//  Methods
//
//  Email-OTP sign-in against Supabase Auth, plus session persistence.
//

import Foundation
import Security

/// A signed-in Supabase session. Persisted to the Keychain across launches.
nonisolated struct AuthSession: Codable {
    var accessToken: String
    var refreshToken: String
    var expiresAt: Date
    var email: String

    var isExpired: Bool { Date() >= expiresAt.addingTimeInterval(-60) }
}

/// Supabase Auth REST calls (OTP request/verify, token refresh) and the
/// backend's public email precheck.
nonisolated enum AuthAPI {

    enum AuthError: LocalizedError {
        case brandAccount(message: String)
        case invalidCode
        case server(String)

        var errorDescription: String? {
            switch self {
            case .brandAccount(let message): return message
            case .invalidCode: return "That code didn't work. Check it and try again."
            case .server(let message): return message
            }
        }
    }

    /// Backend precheck: brand accounts must use the web app. Fails open.
    static func checkEmailAllowed(_ email: String) async throws {
        struct Eligibility: Decodable { let allowed: Bool?; let message: String? }
        var request = URLRequest(url: APIConfig.mobileBaseURL.appendingPathComponent("auth/check-email"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(["email": email])
        guard let (data, _) = try? await URLSession.shared.data(for: request) else { return }
        if let result = try? JSONDecoder().decode(Eligibility.self, from: data),
           result.allowed == false {
            throw AuthError.brandAccount(message: result.message ?? "This account can't use the mobile app.")
        }
    }

    /// Sends a 6-digit OTP to the email. Creates the auth user when new.
    static func requestCode(email: String) async throws {
        let body = ["email": email, "create_user": true] as [String: Any]
        let (status, payload) = try await supabaseAuth("otp", json: body)
        guard (200...299).contains(status) else {
            throw AuthError.server(errorMessage(from: payload) ?? "Couldn't send the code. Try again.")
        }
    }

    /// Exchanges the emailed code for a session.
    static func verifyCode(email: String, code: String) async throws -> AuthSession {
        let body = ["type": "email", "email": email, "token": code]
        let (status, payload) = try await supabaseAuth("verify", json: body)
        guard (200...299).contains(status) else {
            if status == 401 || status == 403 || status == 400 { throw AuthError.invalidCode }
            throw AuthError.server(errorMessage(from: payload) ?? "Verification failed.")
        }
        return try session(from: payload, email: email)
    }

    /// Refreshes an expired session.
    static func refresh(_ session: AuthSession) async throws -> AuthSession {
        let body = ["refresh_token": session.refreshToken]
        let (status, payload) = try await supabaseAuth("token?grant_type=refresh_token", json: body)
        guard (200...299).contains(status) else {
            throw AuthError.server(errorMessage(from: payload) ?? "Session expired.")
        }
        return try self.session(from: payload, email: session.email)
    }

    // MARK: - Internals

    private static func supabaseAuth(_ path: String, json: [String: Any]) async throws -> (Int, Data) {
        let url = APIConfig.Supabase.url.appendingPathComponent("auth/v1").absoluteString + "/" + path
        var request = URLRequest(url: URL(string: url)!)
        request.httpMethod = "POST"
        request.setValue(APIConfig.Supabase.publishableKey, forHTTPHeaderField: "apikey")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: json)
        let (data, response) = try await URLSession.shared.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        return (status, data)
    }

    private static func session(from data: Data, email: String) throws -> AuthSession {
        struct TokenResponse: Decodable {
            let access_token: String
            let refresh_token: String
            let expires_in: Double?
        }
        let token = try JSONDecoder().decode(TokenResponse.self, from: data)
        return AuthSession(
            accessToken: token.access_token,
            refreshToken: token.refresh_token,
            expiresAt: Date().addingTimeInterval(token.expires_in ?? 3600),
            email: email
        )
    }

    private static func errorMessage(from data: Data) -> String? {
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        return (object["msg"] ?? object["message"] ?? object["error_description"] ?? object["error"]) as? String
    }
}

/// Keychain persistence for the auth session.
nonisolated enum SessionStore {
    private static let service = "app.paidpost.session"

    static func save(_ session: AuthSession) {
        guard let data = try? JSONEncoder().encode(session) else { return }
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
        ]
        SecItemDelete(query as CFDictionary)
        var attributes = query
        attributes[kSecValueData as String] = data
        attributes[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        SecItemAdd(attributes as CFDictionary, nil)
    }

    static func load() -> AuthSession? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data else { return nil }
        return try? JSONDecoder().decode(AuthSession.self, from: data)
    }

    static func clear() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
        ]
        SecItemDelete(query as CFDictionary)
    }
}
