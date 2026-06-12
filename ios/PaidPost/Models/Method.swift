//
//  Method.swift
//  Methods
//

import SwiftUI

/// A paid content opportunity that creators can apply to.
struct Method: Identifiable, Hashable {
    let id: UUID
    let brand: String
    let title: String
    let tagline: String
    let payPerPost: Double
    let totalBudget: Double
    let claimedBudget: Double
    let category: Category
    let videoLengthSeconds: ClosedRange<Int>
    let difficulty: Difficulty
    let isHot: Bool
    let accent: Color
    let logoSymbol: String
    let requirements: [String]
    let exampleHooks: [String]

    var budgetRemaining: Double { max(0, totalBudget - claimedBudget) }
    var budgetProgress: Double {
        guard totalBudget > 0 else { return 0 }
        return min(1, claimedBudget / totalBudget)
    }

    var lengthLabel: String {
        "\(videoLengthSeconds.lowerBound)–\(videoLengthSeconds.upperBound)s"
    }

    init(
        id: UUID = UUID(),
        brand: String,
        title: String,
        tagline: String,
        payPerPost: Double,
        totalBudget: Double,
        claimedBudget: Double,
        category: Category,
        videoLengthSeconds: ClosedRange<Int>,
        difficulty: Difficulty,
        isHot: Bool,
        accent: Color,
        logoSymbol: String,
        requirements: [String],
        exampleHooks: [String]
    ) {
        self.id = id
        self.brand = brand
        self.title = title
        self.tagline = tagline
        self.payPerPost = payPerPost
        self.totalBudget = totalBudget
        self.claimedBudget = claimedBudget
        self.category = category
        self.videoLengthSeconds = videoLengthSeconds
        self.difficulty = difficulty
        self.isHot = isHot
        self.accent = accent
        self.logoSymbol = logoSymbol
        self.requirements = requirements
        self.exampleHooks = exampleHooks
    }

    enum Category: String, CaseIterable, Identifiable {
        case all = "All"
        case tech = "Tech"
        case finance = "Finance"
        case beauty = "Beauty"
        case gaming = "Gaming"
        case fitness = "Fitness"
        case food = "Food"

        var id: String { rawValue }
        var icon: String {
            switch self {
            case .all: return "square.grid.2x2.fill"
            case .tech: return "cpu.fill"
            case .finance: return "chart.line.uptrend.xyaxis"
            case .beauty: return "sparkles"
            case .gaming: return "gamecontroller.fill"
            case .fitness: return "figure.run"
            case .food: return "fork.knife"
            }
        }
    }

    enum Difficulty: String {
        case easy = "Easy"
        case medium = "Medium"
        case pro = "Pro"

        var color: Color {
            switch self {
            case .easy: return Theme.accent
            case .medium: return Theme.gold
            case .pro: return Theme.coral
            }
        }
    }
}

/// A notification for the creator.
struct Notification: Identifiable, Hashable {
    let id: UUID
    let type: NotificationType
    let title: String
    let body: String
    let timestamp: Date
    var isRead: Bool

    enum NotificationType: String {
        case approved = "Approved"
        case paid = "Paid"
        case newMethod = "New Method"
        case reminder = "Reminder"
        case milestone = "Milestone"

        var icon: String {
            switch self {
            case .approved: return "checkmark.seal.fill"
            case .paid: return "dollarsign.circle.fill"
            case .newMethod: return "sparkles"
            case .reminder: return "bell.fill"
            case .milestone: return "trophy.fill"
            }
        }

        var color: Color {
            switch self {
            case .approved: return Theme.electric
            case .paid: return Theme.accent
            case .newMethod: return Theme.coral
            case .reminder: return Theme.gold
            case .milestone: return Theme.gold
            }
        }
    }
}

/// State of a creator's application to a Method.
struct Application: Identifiable, Hashable {
    let id: UUID
    var method: Method
    var status: Status
    let appliedAt: Date
    var earned: Double
    var views: Int
    /// Backend ids/state for campaign flows (contract signing, workspace).
    /// Default nil so existing call sites and previews compile unchanged.
    var backendId: String? = nil
    var brandSlug: String? = nil
    var contractAcceptedAt: Date? = nil
    var contractSignerName: String? = nil

    var contractSigned: Bool { contractAcceptedAt != nil }

    enum Status: String {
        case underReview = "Under Review"
        case approved = "Approved"
        case posted = "Posted"
        case paid = "Paid"

        var color: Color {
            switch self {
            case .underReview: return Theme.gold
            case .approved: return Theme.electric
            case .posted: return Theme.accent
            case .paid: return Theme.accent
            }
        }
        var icon: String {
            switch self {
            case .underReview: return "clock.fill"
            case .approved: return "checkmark.seal.fill"
            case .posted: return "paperplane.fill"
            case .paid: return "dollarsign.circle.fill"
            }
        }
    }
}
