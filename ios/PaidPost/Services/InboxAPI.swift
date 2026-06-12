//
//  InboxAPI.swift
//  Methods
//
//  Brand↔creator message threads. Mirrors the 8x-mobile inbox:
//  one thread per brand plus a "system" thread for official messages.
//

import Foundation

/// Row in `GET /api/mobile/inbox`.
struct ThreadDTO: Decodable, Identifiable, Hashable {
    let brand_organization_id: String?
    let brand_name: String?
    let brand_slug: String?
    let brand_logo: String?
    let last_message_id: String
    let last_message_body: String
    let last_message_at: String?
    let last_sender_was_me: Bool?
    let unread_count: Int?

    /// Path parameter for the thread endpoints; nil brand = the system thread.
    var threadKey: String { brand_organization_id ?? "system" }
    var displayName: String { brand_name ?? "PaidPost" }
    var id: String { threadKey }
}

/// Message in `GET /api/mobile/threads/{brandId}`.
struct MessageDTO: Decodable, Identifiable, Hashable {
    let id: String
    let sender_user_id: String?
    let event_type: String?
    let body: String
    let created_at: String?
    let read_at: String?
}

enum InboxAPI {
    static func fetchInbox() async throws -> [ThreadDTO] {
        struct Envelope: Decodable { let data: [ThreadDTO] }
        let envelope: Envelope = try await APIClient.shared.get("inbox")
        return envelope.data
    }

    /// Oldest-first page of messages. `before` is the cursor from a prior page.
    static func fetchThread(_ threadKey: String, before: String? = nil) async throws -> [MessageDTO] {
        struct Envelope: Decodable { let data: [MessageDTO] }
        var query: [URLQueryItem] = []
        if let before { query.append(URLQueryItem(name: "before", value: before)) }
        let envelope: Envelope = try await APIClient.shared.get("threads/\(threadKey)", query: query)
        return envelope.data
    }

    /// Marks the thread's inbound messages read. Fire-and-forget.
    static func markThreadRead(_ threadKey: String) async {
        struct Ack: Decodable { let ok: Bool? }
        _ = try? await APIClient.shared.send("threads/\(threadKey)/read", method: "POST") as Ack
    }

    /// Sends a reply into the thread (max 4000 chars, enforced server-side).
    static func sendMessage(_ threadKey: String, body: String) async throws {
        struct Body: Encodable { let body: String }
        struct Ack: Decodable { let ok: Bool?; let message_id: String? }
        _ = try await APIClient.shared.send(
            "threads/\(threadKey)/messages", method: "POST", body: Body(body: body)
        ) as Ack
    }
}
