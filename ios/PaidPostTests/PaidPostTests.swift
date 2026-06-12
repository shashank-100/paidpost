//
//  PaidPostTests.swift
//  PaidPostTests
//

import Testing
import Foundation
import SwiftUI
@testable import PaidPost

@MainActor
struct AppStoreTests {

    /// A store seeded with sample content. The production store starts empty
    /// (it loads live data after sign-in), so tests inject `SampleData` to
    /// exercise the pure logic (filtering, apply, notifications, totals).
    private func makeStore() -> AppStore {
        let suiteName = "PaidPostTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        let store = AppStore(defaults: defaults)
        store.methods = SampleData.methods
        store.applications = SampleData.sampleApplications
        store.notifications = SampleData.sampleNotifications
        return store
    }

    @Test func applyCreatesApplicationOnce() {
        let store = makeStore()
        let method = store.methods.first { !store.hasApplied(to: $0) }!
        let initialCount = store.applications.count

        store.apply(to: method)
        #expect(store.hasApplied(to: method))
        #expect(store.applications.count == initialCount + 1)
        #expect(store.applications.first?.status == .underReview)

        // Applying again is a no-op
        store.apply(to: method)
        #expect(store.applications.count == initialCount + 1)
    }

    @Test func filteringByCategory() {
        let store = makeStore()
        store.selectedCategory = .gaming
        #expect(!store.filteredMethods.isEmpty)
        #expect(store.filteredMethods.allSatisfy { $0.category == .gaming })
    }

    @Test func filteringBySearchMatchesBrandAndTitle() {
        let store = makeStore()
        store.searchText = "vault"
        #expect(store.filteredMethods.contains { $0.brand == "Vault" })

        store.searchText = "zzz-no-match"
        #expect(store.filteredMethods.isEmpty)
    }

    @Test func unreadCountAndMarkAllRead() {
        let store = makeStore()
        #expect(store.unreadNotificationCount > 0)

        store.markAllNotificationsRead()
        #expect(store.unreadNotificationCount == 0)
    }

    @Test func markSingleNotificationRead() {
        let store = makeStore()
        let unread = store.notifications.first { !$0.isRead }!
        let before = store.unreadNotificationCount

        store.markNotificationRead(unread)
        #expect(store.unreadNotificationCount == before - 1)
    }

    @Test func onboardingFlagPersistsAcrossLaunches() {
        let suiteName = "PaidPostTests-onboarding-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)

        let store = AppStore(defaults: defaults)
        #expect(!store.hasOnboarded)
        store.hasOnboarded = true

        // A fresh store reading the same defaults sees the flag
        let relaunched = AppStore(defaults: defaults)
        #expect(relaunched.hasOnboarded)
    }

    @Test func totalEarnedSumsApplications() {
        let store = makeStore()
        let expected = store.applications.reduce(0) { $0 + $1.earned }
        #expect(store.totalEarned == expected)
    }
}

struct MethodModelTests {

    @Test func budgetProgressIsClampedAndSafe() {
        let base = SampleData.methods[0]

        let overClaimed = Method(
            brand: base.brand, title: base.title, tagline: base.tagline,
            payPerPost: 100, totalBudget: 1_000, claimedBudget: 2_000,
            category: .tech, videoLengthSeconds: 20...40, difficulty: .easy,
            isHot: false, accent: .green, logoSymbol: "sparkle",
            requirements: [], exampleHooks: []
        )
        #expect(overClaimed.budgetProgress == 1)
        #expect(overClaimed.budgetRemaining == 0)

        let zeroBudget = Method(
            brand: base.brand, title: base.title, tagline: base.tagline,
            payPerPost: 100, totalBudget: 0, claimedBudget: 0,
            category: .tech, videoLengthSeconds: 20...40, difficulty: .easy,
            isHot: false, accent: .green, logoSymbol: "sparkle",
            requirements: [], exampleHooks: []
        )
        #expect(zeroBudget.budgetProgress == 0)
    }

    @Test func lengthLabelFormatsRange() {
        #expect(SampleData.methods[0].lengthLabel == "20–40s")
    }
}

struct FormattingTests {

    @Test func shortFormattedCompactsLargeNumbers() {
        #expect(950.shortFormatted == "950")
        #expect(42_300.shortFormatted == "42.3K")
        #expect(1_200_000.shortFormatted == "1.2M")
    }
}
