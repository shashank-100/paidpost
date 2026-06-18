//
//  ProfileView.swift
//  Methods
//

import SwiftUI

struct ProfileView: View {
    @Environment(AppStore.self) private var store
    @State private var path: [ProfileDestination] = []

    enum ProfileDestination: Hashable {
        case notifications
        case inbox
        case campaigns
        case settings(SettingsDetailView.Kind)
    }

    @State private var showEditProfile = false

    private let socials: [(String, String, Color)] = [
        ("TikTok", "music.note", Theme.coral),
        ("Instagram", "camera.fill", Theme.electric),
        ("YouTube", "play.rectangle.fill", Theme.gold)
    ]

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(spacing: 22) {
                    header
                    statsRow
                    campaignsBanner
                    notificationBanner
                    messagesBanner
                    socialSection
                    settingsSection
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 120)
            }
            .scrollIndicators(.hidden)
            .background(Theme.background)
            .task { await store.loadProfile(); await store.loadNotifications(); await store.loadCampaigns() }
            .refreshable { await store.loadProfile(); await store.loadNotifications() }
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.large)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showEditProfile = true
                    } label: {
                        Image(systemName: "pencil.circle.fill")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(Theme.textSecondary)
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        path.append(.notifications)
                    } label: {
                        ZStack(alignment: .topTrailing) {
                            Image(systemName: "bell.fill")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundStyle(Theme.textSecondary)

                            if store.unreadNotificationCount > 0 {
                                Text("\(store.unreadNotificationCount)")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(.white)
                                    .frame(width: 18, height: 18)
                                    .background(Theme.coral)
                                    .clipShape(.circle)
                                    .offset(x: 8, y: -8)
                            }
                        }
                    }
                }
            }
            .navigationDestination(for: ProfileDestination.self) { destination in
                switch destination {
                case .notifications:
                    NotificationsView()
                case .inbox:
                    InboxView()
                case .campaigns:
                    CampaignsView()
                case .settings(let kind):
                    SettingsDetailView(kind: kind)
                }
            }
            .sheet(isPresented: $showEditProfile) {
                EditProfileView()
                    .presentationDetents([.large])
            }
        }
        .tint(Theme.accent)
    }

    /// Subtitle for the campaigns banner. Counts only active-status brands so
    /// "N active" is truthful — `store.campaigns` also holds rejected/dropped/
    /// past brands, which shouldn't inflate the count.
    private var campaignsSubtitle: String {
        if store.campaigns.isEmpty { return "Brands you're working with" }
        let active = store.campaigns.filter {
            ["warming_up", "active", "ghosted", "unclear"].contains($0.status ?? "")
        }.count
        return active > 0 ? "\(active) active" : "\(store.campaigns.count) campaigns"
    }

    private var campaignsBanner: some View {
        Button {
            path.append(.campaigns)
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Theme.gold.opacity(0.15))
                        .frame(width: 40, height: 40)
                    Image(systemName: "rectangle.stack.fill")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(Theme.gold)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text("Campaigns")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(Theme.textPrimary)
                    Text(campaignsSubtitle)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Theme.textSecondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Theme.textTertiary)
            }
            .padding(14)
            .background(Theme.surface)
            .clipShape(.rect(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Theme.stroke, lineWidth: 1)
            )
        }
        .buttonStyle(PressableStyle())
    }

    private var messagesBanner: some View {
        Button {
            path.append(.inbox)
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Theme.accent.opacity(0.15))
                        .frame(width: 40, height: 40)
                    Image(systemName: "bubble.left.and.bubble.right.fill")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(Theme.accent)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text("Messages")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(Theme.textPrimary)
                    Text("Chat with brands you work with")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Theme.textSecondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Theme.textTertiary)
            }
            .padding(14)
            .background(Theme.surface)
            .clipShape(.rect(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Theme.stroke, lineWidth: 1)
            )
        }
        .buttonStyle(PressableStyle())
    }

    private var header: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Theme.accent, Theme.accentDim],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                Text(initials)
                    .font(.system(size: 32, weight: .heavy, design: .rounded))
                    .foregroundStyle(Theme.background)
            }
            .frame(width: 92, height: 92)
            .shadow(color: Theme.accentGlow, radius: 16)

            VStack(spacing: 4) {
                Text(store.creatorName)
                    .font(.system(size: 22, weight: .heavy, design: .rounded))
                    .foregroundStyle(Theme.textPrimary)
                Text(store.handle)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.textSecondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 8)
    }

    private var statsRow: some View {
        HStack(spacing: 0) {
            profileStat(value: store.followers.shortFormatted, label: "Followers")
            divider
            profileStat(value: "\(store.applications.count)", label: "Applied")
            divider
            profileStat(value: "$\(Int(store.totalEarned))", label: "Earned")
        }
        .methodCard(padding: 18)
    }

    private var notificationBanner: some View {
        Button {
            path.append(.notifications)
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Theme.electric.opacity(0.15))
                        .frame(width: 40, height: 40)
                    Image(systemName: "bell.badge.fill")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(Theme.electric)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text("Notifications")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(Theme.textPrimary)
                    Text(store.unreadNotificationCount > 0
                         ? "\(store.unreadNotificationCount) unread"
                         : "All caught up")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(store.unreadNotificationCount > 0 ? Theme.accent : Theme.textSecondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Theme.textTertiary)
            }
            .padding(14)
            .background(Theme.surface)
            .clipShape(.rect(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Theme.stroke, lineWidth: 1)
            )
        }
        .buttonStyle(PressableStyle())
    }

    private var divider: some View {
        Rectangle()
            .fill(Theme.stroke)
            .frame(width: 1, height: 38)
    }

    private func profileStat(value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 20, weight: .heavy, design: .rounded))
                .foregroundStyle(Theme.textPrimary)
            Text(label)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Theme.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }

    private var socialSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Connected accounts")
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(Theme.textPrimary)
            VStack(spacing: 10) {
                ForEach(socials, id: \.0) { social in
                    HStack(spacing: 14) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(social.2.opacity(0.18))
                            Image(systemName: social.1)
                                .font(.system(size: 16, weight: .bold))
                                .foregroundStyle(social.2)
                        }
                        .frame(width: 40, height: 40)
                        Text(social.0)
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(Theme.textPrimary)
                        Spacer()
                        Text("Soon")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(Theme.textTertiary)
                    }
                    .methodCard(padding: 12)
                }
            }
        }
    }

    private var settingsSection: some View {
        VStack(spacing: 10) {
            settingsRow(icon: "bell.fill", title: "Notifications", kind: .notifications)
            settingsRow(icon: "creditcard.fill", title: "Payout method", kind: .payout)
            settingsRow(icon: "questionmark.circle.fill", title: "Help & support", kind: .help)
        }
    }

    private func settingsRow(icon: String, title: String, kind: SettingsDetailView.Kind) -> some View {
        Button {
            path.append(.settings(kind))
        } label: {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Theme.textSecondary)
                    .frame(width: 28)
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.textPrimary)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Theme.textTertiary)
            }
            .methodCard(padding: 16)
        }
        .buttonStyle(PressableStyle())
    }

    private var initials: String {
        let parts = store.creatorName.split(separator: " ")
        let letters = parts.prefix(2).compactMap { $0.first }
        return String(letters).uppercased()
    }
}

#Preview {
    ProfileView()
        .environment(AppStore())
        .preferredColorScheme(.dark)
}
