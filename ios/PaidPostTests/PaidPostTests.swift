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

        // Test the pure optimistic-insert path (the network persist in
        // apply(to:) needs a backend; the local insert logic is split out).
        let inserted = store.insertOptimisticApplication(for: method)
        #expect(inserted != nil)
        #expect(store.hasApplied(to: method))
        #expect(store.applications.count == initialCount + 1)
        #expect(store.applications.first?.status == .underReview)

        // Applying again is a no-op.
        let again = store.insertOptimisticApplication(for: method)
        #expect(again == nil)
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

/// Covers the error-message parser that produces the string users see on every
/// failed request (`APIClient.errorMessage(from:)`).
struct ErrorMessageParsingTests {

    private func parse(_ json: String) -> String? {
        APIClient.errorMessage(from: Data(json.utf8))
    }

    @Test func flatErrorShape() {
        #expect(parse(#"{"error":"Boom"}"#) == "Boom")
    }

    @Test func messageShape() {
        #expect(parse(#"{"message":"Nope"}"#) == "Nope")
    }

    @Test func nestedErrorMessageShape() {
        #expect(parse(#"{"error":{"message":"Deep"}}"#) == "Deep")
    }

    @Test func errorPreferredOverMessage() {
        #expect(parse(#"{"error":"E","message":"M"}"#) == "E")
    }

    @Test func unparseableReturnsNil() {
        #expect(parse("not json") == nil)
        #expect(parse("[1,2,3]") == nil)          // array, not an object
        #expect(parse(#"{"other":"x"}"#) == nil)  // no error/message key
    }
}

/// Covers the earnings-chart bucketing + weekday-label alignment with an injected
/// `now` and a fixed UTC calendar, so it can't flake on the machine's timezone.
struct EarningsMathTests {

    /// A UTC calendar pinned to a known reference day so date math is deterministic.
    private var utc: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        return c
    }

    /// 2026-06-18 12:00:00 UTC (a Thursday).
    private var now: Date {
        DateComponents(calendar: utc, year: 2026, month: 6, day: 18, hour: 12).date!
    }

    /// Builds a credit transaction on the given UTC day, via JSON decoding
    /// (TransactionDTO is Decodable-only).
    private func tx(amount: Double, daysAgo: Int) -> TransactionDTO {
        let day = utc.date(byAdding: .day, value: -daysAgo, to: utc.startOfDay(for: now))!
        let iso = ISO8601DateFormatter().string(from: day)
        let json = #"{"id":"t-\#(daysAgo)","amount":\#(amount),"created_at":"\#(iso)"}"#
        return try! JSONDecoder().decode(TransactionDTO.self, from: Data(json.utf8))
    }

    @Test func todayLandsInLastBucket() {
        let data = EarningsMath.weekData(transactions: [tx(amount: 50, daysAgo: 0)], now: now, calendar: utc)
        #expect(data == [0, 0, 0, 0, 0, 0, 50])
    }

    @Test func sixDaysAgoLandsInFirstBucket() {
        let data = EarningsMath.weekData(transactions: [tx(amount: 30, daysAgo: 6)], now: now, calendar: utc)
        #expect(data == [30, 0, 0, 0, 0, 0, 0])
    }

    @Test func sevenDaysAgoIsExcluded() {
        let data = EarningsMath.weekData(transactions: [tx(amount: 99, daysAgo: 7)], now: now, calendar: utc)
        #expect(data == [0, 0, 0, 0, 0, 0, 0])
    }

    @Test func debitsAreIgnoredAndSameDayAccumulates() {
        let txs = [tx(amount: 20, daysAgo: 0), tx(amount: -5, daysAgo: 0), tx(amount: 10, daysAgo: 0)]
        let data = EarningsMath.weekData(transactions: txs, now: now, calendar: utc)
        #expect(data == [0, 0, 0, 0, 0, 0, 30])
    }

    @Test func dayLabelsEndOnTodayAndAlignWithData() {
        let labels = EarningsMath.dayLabels(now: now, calendar: utc)
        #expect(labels.count == 7)
        // 2026-06-18 is a Thursday → last label is Thursday's symbol.
        #expect(labels.last == utc.veryShortWeekdaySymbols[(utc.component(.weekday, from: now) - 1)])
    }
}
