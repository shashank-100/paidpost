//
//  JobsAPI.swift
//  Methods
//
//  Maps the backend `/api/mobile/jobs` response to the app's `Method` model.
//

import SwiftUI

/// A job item as returned by `GET /api/mobile/jobs`.
///
/// The backend spreads a `creator_feed_jobs` row plus a few computed fields, so
/// only the fields the app actually uses are decoded here; the rest are ignored.
struct JobDTO: Decodable {
    let id: String
    let job_title: String?
    let description: String?
    let budget_per_creator: Double?
    /// Pay-per-1k-views for CPM campaigns. Used when there's no flat per-post pay.
    let cpm_rate: Double?
    let brand_name: String?
    let brand_logo: String?
    let tags: [String]?
    let platforms_required: [String]?
    let content_guidelines: String?
}

/// `GET /api/mobile/jobs` returns either a bare array (no `page` param) or a
/// paginated envelope. We always request without pagination, so expect an array.
enum JobsAPI {
    /// Fetches the feed. When `countryISO` is set, the backend returns only
    /// public + country_restricted jobs targeting that country (matches
    /// 8x-mobile's `country_iso` filter). Defaults to the device region so a
    /// creator sees location-relevant gigs; pass nil for the global feed.
    static func fetchJobs(countryISO: String? = deviceRegion) async throws -> [Method] {
        var query: [URLQueryItem] = []
        if let iso = countryISO, !iso.isEmpty {
            query.append(URLQueryItem(name: "country_iso", value: iso))
        }
        let dtos: [JobDTO] = try await APIClient.shared.get("jobs", query: query)
        return dtos.map { $0.toMethod() }
    }

    /// Best-effort ISO-3166 alpha-2 from the device locale (e.g. "US").
    static var deviceRegion: String? {
        if #available(iOS 16, *) {
            return Locale.current.region?.identifier
        }
        return Locale.current.regionCode
    }
}

extension JobDTO {
    /// Bridges a backend job into the local `Method` model used by the UI.
    /// Fields the backend doesn't provide get sensible defaults so the existing
    /// views render unchanged.
    func toMethod() -> Method {
        let methodId: UUID = UUID(uuidString: id) ?? UUID()
        // Flat per-post pay when set; otherwise fall back to the CPM rate so the
        // card never shows "$0" for a real (pay-per-view) opportunity.
        let flat = budget_per_creator ?? 0
        let pay: Double = flat > 0 ? flat : (cpm_rate ?? 0)
        let resolvedCategory: Method.Category = Self.category(for: tags ?? [])
        let length: ClosedRange<Int> = 20...40
        let reqs: [String] = Self.requirements(from: content_guidelines)

        return Method(
            id: methodId,
            brand: brand_name ?? "Brand",
            title: job_title ?? "Untitled opportunity",
            tagline: Self.cleanText(description),
            payPerPost: pay,
            totalBudget: 0,
            claimedBudget: 0,
            category: resolvedCategory,
            videoLengthSeconds: length,
            difficulty: .easy,
            isHot: false,
            accent: Theme.accent,
            logoSymbol: "sparkle",
            requirements: reqs,
            exampleHooks: []
        )
    }

    private static func category(for tags: [String]) -> Method.Category {
        let lower = tags.map { $0.lowercased() }
        for category in Method.Category.allCases where category != .all {
            if lower.contains(category.rawValue.lowercased()) { return category }
        }
        return .all
    }

    private static func requirements(from guidelines: String?) -> [String] {
        guard let guidelines, !guidelines.isEmpty else { return [] }
        return guidelines
            .split(whereSeparator: { $0 == "\n" || $0 == "•" })
            .map { cleanText($0.trimmingCharacters(in: .whitespaces)) }
            .filter { !$0.isEmpty }
    }

    /// Strips common markdown so backend copy renders as plain text in the UI
    /// (e.g. "## Swipe Right" → "Swipe Right", "**bold**" → "bold").
    static func cleanText(_ raw: String?) -> String {
        guard var s = raw else { return "" }
        // Use the first non-empty line as the tagline.
        if let firstLine = s.split(separator: "\n").first(where: { !$0.trimmingCharacters(in: .whitespaces).isEmpty }) {
            s = String(firstLine)
        }
        s = s.replacingOccurrences(of: "**", with: "")
            .replacingOccurrences(of: "__", with: "")
            .replacingOccurrences(of: "`", with: "")
        // Drop leading markdown markers (#, >, -, *) and surrounding whitespace.
        while let f = s.first, "#>-*".contains(f) || f == " " {
            s.removeFirst()
        }
        return s.trimmingCharacters(in: .whitespaces)
    }
}
