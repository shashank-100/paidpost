//
//  SampleData.swift
//  Methods
//

import SwiftUI

/// Seed content powering the discover feed and demo earnings.
enum SampleData {
    static let methods: [Method] = [
        Method(
            brand: "Nova AI",
            title: "Show off your AI workflow",
            tagline: "Film yourself using Nova to automate a boring task.",
            payPerPost: 240,
            totalBudget: 60_000,
            claimedBudget: 38_400,
            category: .tech,
            videoLengthSeconds: 20...40,
            difficulty: .easy,
            isHot: true,
            accent: Theme.electric,
            logoSymbol: "sparkle",
            requirements: [
                "Show the Nova app on screen",
                "Mention it saved you time",
                "Vertical video, no watermark"
            ],
            exampleHooks: [
                "POV: you stopped doing this manually…",
                "This app does my whole job in 30 seconds",
                "I was today years old when I found Nova"
            ]
        ),
        Method(
            brand: "Vault",
            title: "Your first $1 in Vault",
            tagline: "React to investing your spare change.",
            payPerPost: 180,
            totalBudget: 45_000,
            claimedBudget: 12_300,
            category: .finance,
            videoLengthSeconds: 25...40,
            difficulty: .easy,
            isHot: true,
            accent: Theme.accent,
            logoSymbol: "lock.fill",
            requirements: [
                "Show the round-up feature",
                "Use #VaultPartner in caption",
                "Authentic reaction encouraged"
            ],
            exampleHooks: [
                "I invested my coffee money for a year…",
                "Nobody told me about this money app",
                "Watch my spare change turn into this"
            ]
        ),
        Method(
            brand: "Glow Lab",
            title: "Glow Lab 7-day glow up",
            tagline: "Document a week of the Glow Lab routine.",
            payPerPost: 320,
            totalBudget: 80_000,
            claimedBudget: 71_500,
            category: .beauty,
            videoLengthSeconds: 30...40,
            difficulty: .medium,
            isHot: false,
            accent: Theme.coral,
            logoSymbol: "sparkles",
            requirements: [
                "Before & after shots",
                "Tag @glowlab",
                "Good lighting required"
            ],
            exampleHooks: [
                "Day 1 vs Day 7 and I'm shook",
                "My skin has never looked like this",
                "The glow up is unreal"
            ]
        ),
        Method(
            brand: "Pixel Arena",
            title: "Clutch moment in Pixel Arena",
            tagline: "Post your best clip from the new battle royale.",
            payPerPost: 150,
            totalBudget: 30_000,
            claimedBudget: 8_900,
            category: .gaming,
            videoLengthSeconds: 20...35,
            difficulty: .easy,
            isHot: true,
            accent: Theme.gold,
            logoSymbol: "gamecontroller.fill",
            requirements: [
                "Show gameplay footage",
                "Link in bio to download",
                "Energetic edit"
            ],
            exampleHooks: [
                "This 1v4 clutch went crazy",
                "New favorite mobile game fr",
                "Rate this play 1-10"
            ]
        ),
        Method(
            brand: "FuelFit",
            title: "FuelFit morning routine",
            tagline: "Show how FuelFit fits your workout.",
            payPerPost: 210,
            totalBudget: 50_000,
            claimedBudget: 26_700,
            category: .fitness,
            videoLengthSeconds: 25...40,
            difficulty: .medium,
            isHot: false,
            accent: Theme.accent,
            logoSymbol: "figure.run",
            requirements: [
                "Show the product in use",
                "Mention your goal",
                "Daylight footage"
            ],
            exampleHooks: [
                "My 5am routine that changed everything",
                "POV: you finally have energy",
                "Gym girlies you need this"
            ]
        ),
        Method(
            brand: "Crave",
            title: "Order something on Crave",
            tagline: "Film an unboxing of your Crave delivery.",
            payPerPost: 130,
            totalBudget: 25_000,
            claimedBudget: 19_800,
            category: .food,
            videoLengthSeconds: 20...30,
            difficulty: .easy,
            isHot: false,
            accent: Theme.coral,
            logoSymbol: "fork.knife",
            requirements: [
                "Show the unboxing",
                "Use promo code in caption",
                "Tasty close-ups"
            ],
            exampleHooks: [
                "Trying the most ordered meal on Crave",
                "This arrived in 12 minutes??",
                "Rating my late night order"
            ]
        ),
        Method(
            brand: "ZenSpace",
            title: "Your ZenSpace setup",
            tagline: "Show your meditation corner with the ZenSpace app.",
            payPerPost: 200,
            totalBudget: 35_000,
            claimedBudget: 14_500,
            category: .fitness,
            videoLengthSeconds: 25...40,
            difficulty: .easy,
            isHot: true,
            accent: Theme.electric,
            logoSymbol: "leaf.fill",
            requirements: [
                "Show the app in use",
                "Calm, aesthetic lighting",
                "Mention your streak"
            ],
            exampleHooks: [
                "I tried meditating every day for a month",
                "POV: you finally found inner peace",
                "This app changed my mornings"
            ]
        ),
        Method(
            brand: "Wardrobe",
            title: "Style a look with Wardrobe",
            tagline: "Pick an outfit using the Wardrobe AI stylist.",
            payPerPost: 280,
            totalBudget: 55_000,
            claimedBudget: 21_000,
            category: .beauty,
            videoLengthSeconds: 25...40,
            difficulty: .medium,
            isHot: false,
            accent: Theme.gold,
            logoSymbol: "tshirt.fill",
            requirements: [
                "Show the outfit building feature",
                "Before & after styling",
                "Natural lighting"
            ],
            exampleHooks: [
                "AI picked my outfit for a week",
                "My closet but make it aesthetic",
                "Rate my AI-styled fit"
            ]
        ),
        Method(
            brand: "BytePay",
            title: "Send money with BytePay",
            tagline: "Film a peer-to-peer transfer reaction.",
            payPerPost: 160,
            totalBudget: 40_000,
            claimedBudget: 31_200,
            category: .finance,
            videoLengthSeconds: 20...30,
            difficulty: .easy,
            isHot: false,
            accent: Theme.electric,
            logoSymbol: "arrow.left.arrow.right",
            requirements: [
                "Show a real transfer",
                "Mention transaction speed",
                "Use #BytePayFast"
            ],
            exampleHooks: [
                "Sent money and it arrived in 2 seconds",
                "The fastest way to split a bill",
                "I paid my friend and their reaction"
            ]
        ),
        Method(
            brand: "SnapLearn",
            title: "Learn something on SnapLearn",
            tagline: "Show a micro-lesson from the learning app.",
            payPerPost: 190,
            totalBudget: 48_000,
            claimedBudget: 9_600,
            category: .tech,
            videoLengthSeconds: 25...40,
            difficulty: .easy,
            isHot: false,
            accent: Theme.accent,
            logoSymbol: "book.fill",
            requirements: [
                "Show a completed lesson",
                "Screen recording allowed",
                "Mention what you learned"
            ],
            exampleHooks: [
                "Learned this skill in 30 seconds",
                "Duolingo but for everything",
                "My brain expanded watching this"
            ]
        ),
        Method(
            brand: "Raid Legends",
            title: "Epic Raid Legends boss kill",
            tagline: "Share your best raid boss takedown.",
            payPerPost: 220,
            totalBudget: 60_000,
            claimedBudget: 43_500,
            category: .gaming,
            videoLengthSeconds: 25...40,
            difficulty: .pro,
            isHot: true,
            accent: Theme.coral,
            logoSymbol: "shield.fill",
            requirements: [
                "Show the boss fight",
                "High-quality screen recording",
                "End screen with character stats"
            ],
            exampleHooks: [
                "Solo'd this boss on hard mode",
                "My most insane build yet",
                "This boss never stood a chance"
            ]
        )
    ]

    static var sampleApplications: [Application] {
        [
            Application(
                id: UUID(),
                method: methods[1],
                status: .paid,
                appliedAt: Date().addingTimeInterval(-86_400 * 6),
                earned: 180,
                views: 42_300
            ),
            Application(
                id: UUID(),
                method: methods[3],
                status: .posted,
                appliedAt: Date().addingTimeInterval(-86_400 * 2),
                earned: 0,
                views: 11_700
            ),
            Application(
                id: UUID(),
                method: methods[0],
                status: .approved,
                appliedAt: Date().addingTimeInterval(-86_400),
                earned: 0,
                views: 0
            )
        ]
    }

    static var sampleNotifications: [Notification] {
        [
            Notification(
                id: UUID(),
                type: .approved,
                title: "Application approved",
                body: "Your application for Nova AI has been approved. Start creating!",
                timestamp: Date().addingTimeInterval(-3_600),
                isRead: false
            ),
            Notification(
                id: UUID(),
                type: .paid,
                title: "$180 payout received",
                body: "Your Vault post payment of $180 has been deposited to your balance.",
                timestamp: Date().addingTimeInterval(-86_400),
                isRead: false
            ),
            Notification(
                id: UUID(),
                type: .newMethod,
                title: "New brand: Crave",
                body: "Crave is looking for food creators. $130 per post.",
                timestamp: Date().addingTimeInterval(-86_400 * 2),
                isRead: false
            ),
            Notification(
                id: UUID(),
                type: .milestone,
                title: "10K views milestone",
                body: "Your Pixel Arena post just crossed 10,000 views. Keep it up!",
                timestamp: Date().addingTimeInterval(-86_400 * 2.5),
                isRead: true
            ),
            Notification(
                id: UUID(),
                type: .reminder,
                title: "Don't forget to post",
                body: "Your approved Pixel Arena method is waiting for your video.",
                timestamp: Date().addingTimeInterval(-86_400 * 3),
                isRead: true
            ),
            Notification(
                id: UUID(),
                type: .paid,
                title: "$140 bonus earned",
                body: "You earned a performance bonus on your Glow Lab post.",
                timestamp: Date().addingTimeInterval(-86_400 * 5),
                isRead: true
            )
        ]
    }
}
