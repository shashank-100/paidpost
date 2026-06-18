//
//  APIClient.swift
//  Methods
//

import Foundation

/// Errors surfaced by the networking layer.
enum APIError: Error, LocalizedError {
    case invalidResponse
    case unauthorized
    case server(status: Int, message: String?)
    case decoding(Error)
    case transport(Error)

    var errorDescription: String? {
        switch self {
        case .invalidResponse: return "Invalid server response."
        case .unauthorized: return "Your session has expired. Please sign in again."
        case .server(let status, let message): return message ?? "Server error (\(status))."
        case .decoding: return "Couldn't read the server response."
        case .transport(let error): return error.localizedDescription
        }
    }
}

/// Thin async HTTP client for the PaidPost mobile API.
///
/// Holds the Supabase access token and attaches it as a Bearer header.
actor APIClient {
    static let shared = APIClient()

    private let session: URLSession
    private let decoder: JSONDecoder
    private var current: AuthSession?
    /// In-flight refresh, shared so concurrent 401s/expired-token callers await
    /// one refresh instead of each firing their own. Supabase refresh tokens
    /// rotate (single-use), so parallel refreshes would invalidate each other
    /// and log the user out mid-session.
    private var refreshTask: Task<AuthSession, Error>?

    init(session: URLSession = .shared) {
        self.session = session
        self.decoder = JSONDecoder()
        self.decoder.keyDecodingStrategy = .useDefaultKeys
    }

    /// Loads any persisted session from the Keychain. Call once at launch.
    /// Sessions minted by a different Supabase project (e.g. after an env
    /// change) are dropped instead of producing confusing 401s.
    func restoreSession() {
        guard let session = SessionStore.load() else { return }
        if let issuer = Self.jwtIssuer(session.accessToken),
           !issuer.contains(APIConfig.Supabase.url.host ?? "") {
            SessionStore.clear()
            return
        }
        current = session
    }

    /// Extracts a string claim from a JWT without verifying the signature
    /// (verification happens server-side; this is only a sanity check).
    private static func jwtClaim(_ jwt: String, _ claim: String) -> String? {
        let parts = jwt.split(separator: ".")
        guard parts.count == 3 else { return nil }
        var base64 = String(parts[1]).replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        while base64.count % 4 != 0 { base64 += "=" }
        guard let data = Data(base64Encoded: base64),
              let payload = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        return payload[claim] as? String
    }

    private static func jwtIssuer(_ jwt: String) -> String? { jwtClaim(jwt, "iss") }

    /// Pulls a human-readable message out of an error response, tolerating the
    /// common shapes: `{"error":"..."}`, `{"message":"..."}`, and a nested
    /// `{"error":{"message":"..."}}`. Returns nil when nothing usable is found.
    /// `internal` so it can be unit-tested (it's the string users see on every
    /// failed request).
    static func errorMessage(from data: Data) -> String? {
        guard let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        if let s = obj["error"] as? String { return s }
        if let s = obj["message"] as? String { return s }
        if let nested = obj["error"] as? [String: Any], let s = nested["message"] as? String {
            return s
        }
        return nil
    }

    /// Adopts a freshly minted session (after sign-in) and persists it.
    func setSession(_ session: AuthSession) {
        current = session
        SessionStore.save(session)
    }

    func signOut() {
        current = nil
        SessionStore.clear()
    }

    var isAuthenticated: Bool { current != nil }

    /// The signed-in user's id (JWT `sub`) — used to tell own messages apart.
    var currentUserId: String? {
        guard let token = current?.accessToken else { return nil }
        return Self.jwtClaim(token, "sub")
    }

    /// Returns a valid access token, refreshing transparently if expired.
    private func validAccessToken() async throws -> String? {
        guard let session = current else { return nil }
        if session.isExpired {
            do {
                return try await refreshSession(from: session).accessToken
            } catch {
                // Refresh failed → session is dead; force re-login.
                signOut()
                throw APIError.unauthorized
            }
        }
        return session.accessToken
    }

    /// Refreshes the session, coalescing concurrent callers onto a single
    /// in-flight refresh so the rotating refresh token is only spent once.
    /// `expected` is the session the caller observed; if another refresh has
    /// already produced a newer session, that newer one is returned instead of
    /// starting a redundant refresh.
    private func refreshSession(from expected: AuthSession) async throws -> AuthSession {
        // A concurrent refresh already finished and replaced the session — use it.
        if let current, current.accessToken != expected.accessToken, !current.isExpired {
            return current
        }
        if let refreshTask {
            return try await refreshTask.value
        }
        let task = Task { () throws -> AuthSession in
            try await AuthAPI.refresh(expected)
        }
        refreshTask = task
        defer { refreshTask = nil }
        do {
            let refreshed = try await task.value
            current = refreshed
            SessionStore.save(refreshed)
            return refreshed
        } catch {
            throw error
        }
    }

    // MARK: - Auth

    #if DEBUG
    /// Authenticates with the Apple-review bypass route and persists the
    /// session, exactly like a normal sign-in. Requires
    /// `APPLE_REVIEW_BYPASS_ENABLED=true` on the backend.
    /// DEBUG-only so this code path and the test credentials never ship in a
    /// release build.
    @discardableResult
    func authenticateTestBypass() async throws -> String {
        struct Body: Encodable { let email: String; let code: String }
        struct TokenResponse: Decodable {
            let access_token: String
            let refresh_token: String?
            let expires_in: Double?
        }
        let response: TokenResponse = try await send(
            "auth/test-bypass",
            method: "POST",
            body: Body(email: APIConfig.TestAccount.email, code: APIConfig.TestAccount.code),
            authenticated: false
        )
        let session = AuthSession(
            accessToken: response.access_token,
            refreshToken: response.refresh_token ?? "",
            expiresAt: Date().addingTimeInterval(response.expires_in ?? 3600),
            email: APIConfig.TestAccount.email
        )
        setSession(session)
        return response.access_token
    }
    #endif

    // MARK: - Requests

    /// GET a Decodable resource from `/api/mobile/<path>`.
    func get<T: Decodable>(_ path: String, query: [URLQueryItem] = []) async throws -> T {
        try await send(path, method: "GET", query: query)
    }

    /// Raw PUT of bytes to an absolute URL (an R2 presigned upload URL). No
    /// auth header — the signature is in the URL. `contentType` MUST match the
    /// type the URL was signed with or R2 rejects it. 2-minute timeout.
    func putFile(to url: URL, contentType: String, data: Data) async throws {
        var request = URLRequest(url: url, timeoutInterval: 120)
        request.httpMethod = "PUT"
        request.setValue(contentType, forHTTPHeaderField: "Content-Type")
        request.httpBody = data
        let body: Data
        let response: URLResponse
        do {
            (body, response) = try await session.data(for: request)
        } catch {
            throw APIError.transport(error)
        }
        guard let http = response as? HTTPURLResponse else { throw APIError.invalidResponse }
        guard (200...299).contains(http.statusCode) else {
            // R2 returns an XML/JSON error body (signature mismatch, content-type
            // mismatch, etc.). Include a snippet so upload failures are diagnosable.
            let detail = String(data: body.prefix(500), encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let message = (detail?.isEmpty == false)
                ? "Upload failed (\(http.statusCode)): \(detail!)"
                : "Upload failed (\(http.statusCode))"
            throw APIError.server(status: http.statusCode, message: message)
        }
    }

    /// Core request. `body` is JSON-encoded when present. On a 401 the client
    /// refreshes the session once and retries before giving up.
    func send<T: Decodable>(
        _ path: String,
        method: String,
        query: [URLQueryItem] = [],
        body: Encodable? = nil,
        authenticated: Bool = true,
        retryOn401: Bool = true
    ) async throws -> T {
        // Build the URL defensively: `path` can carry backend-controlled
        // segments (slugs, ids), so a malformed component must throw rather
        // than crash on a force-unwrap.
        guard var components = URLComponents(
            url: APIConfig.mobileBaseURL.appendingPathComponent(path),
            resolvingAgainstBaseURL: false
        ) else {
            throw APIError.invalidResponse
        }
        if !query.isEmpty { components.queryItems = query }

        guard let url = components.url else { throw APIError.invalidResponse }
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        if authenticated, let token = try await validAccessToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        if let body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONEncoder().encode(AnyEncodable(body))
        }
        return try await perform(request, authenticated: authenticated, retryOn401: retryOn401) {
            try await self.send(path, method: method, query: query, body: body,
                                authenticated: authenticated, retryOn401: false)
        }
    }

    /// Multipart file upload to `/api/mobile/<path>`.
    func uploadMultipart<T: Decodable>(
        _ path: String,
        fieldName: String,
        filename: String,
        mimeType: String,
        fileData: Data,
        retryOn401: Bool = true
    ) async throws -> T {
        let boundary = "paidpost-\(UUID().uuidString)"
        var request = URLRequest(url: APIConfig.mobileBaseURL.appendingPathComponent(path))
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        if let token = try await validAccessToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        var bodyData = Data()
        bodyData.append("--\(boundary)\r\n".data(using: .utf8)!)
        bodyData.append("Content-Disposition: form-data; name=\"\(fieldName)\"; filename=\"\(filename)\"\r\n".data(using: .utf8)!)
        bodyData.append("Content-Type: \(mimeType)\r\n\r\n".data(using: .utf8)!)
        bodyData.append(fileData)
        bodyData.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)
        request.httpBody = bodyData

        return try await perform(request, authenticated: true, retryOn401: retryOn401) {
            try await self.uploadMultipart(path, fieldName: fieldName, filename: filename,
                                           mimeType: mimeType, fileData: fileData, retryOn401: false)
        }
    }

    /// Shared response handling with a single refresh-and-retry on 401.
    private func perform<T: Decodable>(
        _ request: URLRequest,
        authenticated: Bool,
        retryOn401: Bool,
        retry: () async throws -> T
    ) async throws -> T {
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw APIError.transport(error)
        }

        guard let http = response as? HTTPURLResponse else { throw APIError.invalidResponse }

        switch http.statusCode {
        case 200...299:
            do {
                return try decoder.decode(T.self, from: data)
            } catch {
                throw APIError.decoding(error)
            }
        case 401:
            // Token may have been revoked while still unexpired — refresh once,
            // coalescing concurrent 401s onto a single shared refresh.
            if authenticated, retryOn401, let session = current {
                if (try? await refreshSession(from: session)) != nil {
                    return try await retry()
                }
                signOut()
            }
            throw APIError.unauthorized
        default:
            throw APIError.server(status: http.statusCode, message: Self.errorMessage(from: data))
        }
    }
}

/// Type-erasing wrapper so `Encodable` existentials can be JSON-encoded.
/// `nonisolated` so it can be constructed inside the `APIClient` actor.
private nonisolated struct AnyEncodable: Encodable {
    private let encode: (Encoder) throws -> Void
    init(_ wrapped: Encodable) { encode = wrapped.encode }
    func encode(to encoder: Encoder) throws { try encode(encoder) }
}
