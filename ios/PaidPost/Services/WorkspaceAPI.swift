//
//  WorkspaceAPI.swift
//  Methods
//
//  Per-brand campaign workspace, contract signing, managed-status, and the
//  brief/reference-video data. DTO shapes mirror the the reference app clients
//  (lib/api/workspace.ts, creator.ts, applications.ts) — same backend.
//

import Foundation

// MARK: - Managed status (campaign list)

/// `GET /api/mobile/creator/managed-status`
struct ManagedStatusDTO: Decodable {
    let isManagedCreator: Bool?
    let brands: [ManagedBrandDTO]?

    struct ManagedBrandDTO: Decodable, Identifiable, Hashable {
        let id: String
        let name: String?
        let slug: String?
        let logo: String?
        let status: String?
        let videosComplete: Bool?
    }
}

// MARK: - Workspace

/// `GET /api/mobile/creator/workspace/{brandSlug}`
struct WorkspaceDTO: Decodable {
    let managedCreator: ManagedCreator
    let org: Org
    let portalConfig: PortalConfigDTO?
    let referenceVideos: [ReferenceVideoDTO]?
    let briefVideos: [ReferenceVideoDTO]?
    let currency: String?

    struct ManagedCreator: Decodable {
        let id: String
        let applicationId: String?
        let status: String?
        let videosComplete: Bool?
        let screeningStatus: String?
        let contractAcceptedAt: String?
        let contractSignerName: String?
        let basePay: Double?
    }

    struct Org: Decodable {
        let id: String
        let name: String?
        let slug: String?
        let logo: String?
        let website: String?
    }

    /// Statuses that unlock brief / contract / content tabs (from the reference app
    /// CONTENT_ACCESSIBLE_STATUSES).
    static let contentAccessibleStatuses: Set<String> =
        ["accepted", "warming_up", "active", "ghosted", "unclear"]
}

/// Portal config carries the brand brief. The structure is brand-authored and
/// version-dependent (v2 structured / v3+ markdown); we surface the markdown
/// body and a flat title when present and ignore the rest.
struct PortalConfigDTO: Decodable {
    let title: String?
    let description: String?
    let content: String?

    enum CodingKeys: String, CodingKey { case title, description, content, body, markdown }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        title = try? c.decodeIfPresent(String.self, forKey: .title)
        description = try? c.decodeIfPresent(String.self, forKey: .description)
        // Different portal versions name the markdown body differently.
        content = (try? c.decodeIfPresent(String.self, forKey: .content))
            ?? (try? c.decodeIfPresent(String.self, forKey: .body))
            ?? (try? c.decodeIfPresent(String.self, forKey: .markdown))
    }
}

struct ReferenceVideoDTO: Decodable, Identifiable, Hashable {
    let id: String
    let video_url: String?
    let transcript: String?
    let notes: String?
    let onscreen_text: String?
    let category: String?
}

// MARK: - Test videos

/// `GET /api/mobile/creator/videos?brandSlug=`
struct CreatorVideosDTO: Decodable {
    let videos: [VideoSlot]
    let requiredCount: Int?
    let maxCount: Int?

    // A missing or null `videos` (nothing uploaded yet) decodes to [] rather
    // than failing the whole response.
    enum CodingKeys: String, CodingKey { case videos, requiredCount, maxCount }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        videos = (try? c.decode([VideoSlot].self, forKey: .videos)) ?? []
        requiredCount = try? c.decodeIfPresent(Int.self, forKey: .requiredCount)
        maxCount = try? c.decodeIfPresent(Int.self, forKey: .maxCount)
    }

    struct VideoSlot: Decodable, Identifiable, Hashable {
        let id: String
        let slotNumber: Int
        let url: String?
        let path: String?
    }
}

// MARK: - Posts (My Content)

/// `GET /api/mobile/creator/posts?brandSlug=`
struct CreatorPostsDTO: Decodable {
    let posts: [CreatorPostDTO]
    let hasMore: Bool?

    // A missing or null `posts` (none yet) decodes to [] rather than failing.
    enum CodingKeys: String, CodingKey { case posts, hasMore }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        posts = (try? c.decode([CreatorPostDTO].self, forKey: .posts)) ?? []
        hasMore = try? c.decodeIfPresent(Bool.self, forKey: .hasMore)
    }
}

struct CreatorPostDTO: Decodable, Identifiable, Hashable {
    let id: String
    let platform: String?
    let post_url: String?
    let thumbnail_url: String?
    let caption: String?
    let posted_at: String?
    let latest_views: Int?
    let ad_code: String?
    let total_owed_cents: Int?
}

// MARK: - Warmup

/// `GET /api/mobile/creator/warmup/{brandSlug}` — evidence-based warmup state.
struct WarmupTimelineDTO: Decodable {
    let managedCreatorId: String?
    let warmupStartDate: String?
    let currentWindowIndex: Int?
    let expectedDailyDates: [String]?
    let screenshotTasks: [ScreenshotTask]?

    struct DailyActivity: Decodable, Hashable {
        let scrolledPlatforms: [String]?
        let nicheVideoUrls: [String]?
    }

    struct ScreenshotTask: Decodable, Identifiable, Hashable {
        let platform: String
        let windowIndex: Int
        let periodStart: String?
        let periodEnd: String?
        let status: String?          // submitted | due | upcoming
        var id: String { "\(platform)-\(windowIndex)" }

        // Tolerate a missing platform/windowIndex on a single task rather than
        // failing the entire timeline decode.
        enum CodingKeys: String, CodingKey {
            case platform, windowIndex, periodStart, periodEnd, status
        }
        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            platform = (try? c.decodeIfPresent(String.self, forKey: .platform)) ?? "unknown"
            windowIndex = (try? c.decodeIfPresent(Int.self, forKey: .windowIndex)) ?? 0
            periodStart = try? c.decodeIfPresent(String.self, forKey: .periodStart)
            periodEnd = try? c.decodeIfPresent(String.self, forKey: .periodEnd)
            status = try? c.decodeIfPresent(String.self, forKey: .status)
        }
    }
}

// MARK: - API surface

enum WorkspaceAPI {
    static func fetchManagedStatus() async throws -> ManagedStatusDTO {
        try await APIClient.shared.get("creator/managed-status")
    }

    static func fetchWorkspace(brandSlug: String) async throws -> WorkspaceDTO {
        try await APIClient.shared.get("creator/workspace/\(encode(brandSlug))")
    }

    static func fetchReferenceVideos(brandOrgId: String) async throws -> [ReferenceVideoDTO] {
        struct Envelope: Decodable { let data: [ReferenceVideoDTO] }
        let env: Envelope = try await APIClient.shared.get("brands/\(brandOrgId)/reference-videos")
        return env.data
    }

    static func fetchVideos(brandSlug: String) async throws -> CreatorVideosDTO {
        try await APIClient.shared.get("creator/videos", query: [.init(name: "brandSlug", value: brandSlug)])
    }

    static func fetchPosts(brandSlug: String, limit: Int = 30, offset: Int = 0) async throws -> CreatorPostsDTO {
        try await APIClient.shared.get("creator/posts", query: [
            .init(name: "brandSlug", value: brandSlug),
            .init(name: "limit", value: "\(limit)"),
            .init(name: "offset", value: "\(offset)"),
        ])
    }

    // MARK: Test-video upload (presigned R2 PUT)

    struct SaveVideoResult: Decodable {
        let id: String?
        let slotNumber: Int?
        let url: String?
        let totalVideos: Int?
        let isComplete: Bool?
    }

    /// Full audition-video upload: get a presigned R2 URL → PUT the file
    /// straight to R2 → save the slot record. Mirrors the reference
    /// `uploadCreatorVideo`. `mimeType` is one of video/mp4|quicktime|webm.
    @discardableResult
    static func uploadVideo(
        brandSlug: String, slotNumber: Int, fileData: Data, mimeType: String = "video/mp4"
    ) async throws -> SaveVideoResult {
        struct UrlBody: Encodable { let brandSlug: String; let mime_type: String }
        struct UrlResult: Decodable { let uploadUrl: String; let path: String }
        let urlRes: UrlResult = try await APIClient.shared.send(
            "creator/videos/upload-url", method: "POST",
            body: UrlBody(brandSlug: brandSlug, mime_type: mimeType)
        )
        guard let putURL = URL(string: urlRes.uploadUrl) else { throw APIError.invalidResponse }
        try await APIClient.shared.putFile(to: putURL, contentType: mimeType, data: fileData)

        struct SaveBody: Encodable { let brandSlug: String; let slotNumber: Int; let path: String }
        return try await APIClient.shared.send(
            "creator/videos", method: "POST",
            body: SaveBody(brandSlug: brandSlug, slotNumber: slotNumber, path: urlRes.path)
        )
    }

    /// Submits uploaded audition videos for AI screening. `screening_status`
    /// goes `pending` (or stays null if already past the gate).
    @discardableResult
    static func submitApplication(brandSlug: String) async throws -> String? {
        struct Body: Encodable { let brandSlug: String }
        struct Result: Decodable { let success: Bool?; let screening_status: String? }
        let r: Result = try await APIClient.shared.send(
            "creator/submit-application", method: "POST", body: Body(brandSlug: brandSlug)
        )
        return r.screening_status
    }

    // MARK: Warmup (evidence-based)

    static func fetchWarmup(brandSlug: String) async throws -> WarmupTimelineDTO {
        try await APIClient.shared.get("creator/warmup/\(encode(brandSlug))")
    }

    /// Adds a niche-video URL for a warmup day. `activityDate` is `yyyy-MM-dd`.
    static func addWarmupVideoURL(brandSlug: String, activityDate: String, url: String) async throws {
        struct Body: Encodable { let activityDate: String; let nicheVideoUrl: String }
        struct Ack: Decodable { let activity: WarmupTimelineDTO.DailyActivity? }
        _ = try await APIClient.shared.send(
            "creator/warmup/\(encode(brandSlug))/daily-warmup-updates", method: "POST",
            body: Body(activityDate: activityDate, nicheVideoUrl: url)
        ) as Ack
    }

    /// Uploads a screen-time screenshot for a warmup window via presigned R2 PUT.
    static func uploadWarmupScreenshot(
        brandSlug: String, platform: String, windowIndex: Int, imageData: Data, contentType: String = "image/png"
    ) async throws {
        struct UrlBody: Encodable { let platform: String; let windowIndex: Int; let contentType: String }
        struct UrlResult: Decodable { let uploadUrl: String; let path: String }
        let urlRes: UrlResult = try await APIClient.shared.send(
            "creator/warmup/\(encode(brandSlug))/screenshot/upload-url", method: "POST",
            body: UrlBody(platform: platform, windowIndex: windowIndex, contentType: contentType)
        )
        guard let putURL = URL(string: urlRes.uploadUrl) else { throw APIError.invalidResponse }
        try await APIClient.shared.putFile(to: putURL, contentType: contentType, data: imageData)

        struct SubmitBody: Encodable { let platform: String; let windowIndex: Int; let path: String }
        struct Ack: Decodable { let submission: SubmissionRef? }
        struct SubmissionRef: Decodable { let id: String? }
        _ = try await APIClient.shared.send(
            "creator/warmup/\(encode(brandSlug))/screenshot", method: "POST",
            body: SubmitBody(platform: platform, windowIndex: windowIndex, path: urlRes.path)
        ) as Ack
    }

    /// Kicks off a social-platform post sync (returns 429 if rate-limited).
    @discardableResult
    static func syncPosts(brandSlug: String, platform: String) async throws -> Bool {
        struct Body: Encodable { let brandSlug: String; let platform: String }
        struct Ack: Decodable { let success: Bool? }
        let ack: Ack = try await APIClient.shared.send(
            "creator/posts/sync", method: "POST", body: Body(brandSlug: brandSlug, platform: platform)
        )
        return ack.success ?? false
    }

    static func setAdCode(postId: String, brandSlug: String, adCode: String) async throws {
        struct Body: Encodable { let ad_code: String; let brandSlug: String }
        struct Ack: Decodable { let success: Bool? }
        _ = try await APIClient.shared.send(
            "creator/posts/\(encode(postId))/ad-code", method: "PATCH",
            body: Body(ad_code: adCode, brandSlug: brandSlug)
        ) as Ack
    }

    // MARK: Handles

    /// Updates the creator's social handles for a campaign (write-once on the
    /// backend). `PATCH creator/handles`.
    static func updateHandles(
        managedCreatorId: String,
        tiktok: String? = nil, instagram: String? = nil, youtube: String? = nil
    ) async throws {
        struct Body: Encodable {
            let managedCreatorId: String
            let tiktokUsername: String?
            let instagramUsername: String?
            let youtubeUsername: String?
        }
        struct Ack: Decodable { let success: Bool? }
        _ = try await APIClient.shared.send(
            "creator/handles", method: "PATCH",
            body: Body(managedCreatorId: managedCreatorId, tiktokUsername: tiktok,
                       instagramUsername: instagram, youtubeUsername: youtube)
        ) as Ack
    }

    /// Suggests available usernames for a campaign account. `GET suggest-handles`.
    static func suggestHandles(brandSlug: String, platform: String) async throws -> [String] {
        struct Result: Decodable { let suggestions: [String]? }
        let r: Result = try await APIClient.shared.get("creator/suggest-handles", query: [
            .init(name: "brandSlug", value: brandSlug),
            .init(name: "platform", value: platform),
        ])
        return r.suggestions ?? []
    }

    // MARK: Contract

    /// `POST applications/{id}/contract/sign`
    static func signContract(applicationId: String, signerName: String) async throws {
        struct Body: Encodable { let signerName: String }
        struct Ack: Decodable { let success: Bool? }
        _ = try await APIClient.shared.send(
            "applications/\(encode(applicationId))/contract/sign", method: "POST",
            body: Body(signerName: signerName)
        ) as Ack
    }

    private static func encode(_ s: String) -> String {
        s.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? s
    }
}
