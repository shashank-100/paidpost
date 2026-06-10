//
//  AppStore.swift
//  Methods
//

import SwiftUI
import Observation

/// Global observable state for the Methods app.
@MainActor
@Observable
final class AppStore {
    var methods: [Method] = SampleData.methods
    var applications: [Application] = SampleData.sampleApplications
    var notifications: [Notification] = SampleData.sampleNotifications
    var selectedCategory: Method.Category = .all
    var searchText: String = ""

    // Onboarding
    var hasOnboarded: Bool = false

    // Creator profile
    var creatorName: String = "Jordan Rivera"
    var handle: String = "@jordancreates"
    var followers: Int = 18_400
    var availableBalance: Double = 320

    var unreadNotificationCount: Int {
        notifications.filter { !$0.isRead }.count
    }

    var filteredMethods: [Method] {
        methods.filter { method in
            let matchesCategory = selectedCategory == .all || method.category == selectedCategory
            let matchesSearch = searchText.isEmpty
                || method.brand.localizedCaseInsensitiveContains(searchText)
                || method.title.localizedCaseInsensitiveContains(searchText)
            return matchesCategory && matchesSearch
        }
    }

    var hotMethods: [Method] {
        methods.filter { $0.isHot }
    }

    var totalEarned: Double {
        applications.reduce(0) { $0 + $1.earned } + 0
    }

    var pendingEarnings: Double {
        applications
            .filter { $0.status == .approved || $0.status == .posted }
            .reduce(0) { $0 + $1.method.payPerPost }
    }

    var totalViews: Int {
        applications.reduce(0) { $0 + $1.views }
    }

    func hasApplied(to method: Method) -> Bool {
        applications.contains { $0.method.id == method.id }
    }

    func apply(to method: Method) {
        guard !hasApplied(to: method) else { return }
        let application = Application(
            id: UUID(),
            method: method,
            status: .underReview,
            appliedAt: Date(),
            earned: 0,
            views: 0
        )
        applications.insert(application, at: 0)
    }

    func cashOut() {
        availableBalance = 0
    }

    func markNotificationRead(_ notification: Notification) {
        guard let index = notifications.firstIndex(where: { $0.id == notification.id }) else { return }
        notifications[index].isRead = true
    }

    func markAllNotificationsRead() {
        for i in notifications.indices {
            notifications[i].isRead = true
        }
    }
}
