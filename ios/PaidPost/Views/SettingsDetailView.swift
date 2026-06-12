//
//  SettingsDetailView.swift
//  Methods
//

import SwiftUI

/// Reusable settings detail screen used for Notifications, Payout, Help.
struct SettingsDetailView: View {
    @Environment(AppStore.self) private var store
    let kind: Kind

    @AppStorage("notify.newMethods") private var notifyNewMethods = true
    @AppStorage("notify.applicationUpdates") private var notifyApplicationUpdates = true
    @AppStorage("notify.payouts") private var notifyPayouts = true
    @AppStorage("notify.milestones") private var notifyMilestones = true
    @AppStorage("notify.tips") private var notifyTips = false

    @State private var showDeleteConfirm = false
    @Environment(\.openURL) private var openURL

    enum Kind: String, CaseIterable {
        case notifications = "Notifications"
        case payout = "Payout Method"
        case help = "Help & Support"

        var icon: String {
            switch self {
            case .notifications: return "bell.fill"
            case .payout: return "creditcard.fill"
            case .help: return "questionmark.circle.fill"
            }
        }

        var tint: Color {
            switch self {
            case .notifications: return Theme.accent
            case .payout: return Theme.accent
            case .help: return Theme.electric
            }
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                switch kind {
                case .notifications:
                    notificationsContent
                case .payout:
                    payoutContent
                case .help:
                    helpContent
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 40)
        }
        .scrollIndicators(.hidden)
        .background(Theme.background)
        .navigationTitle(kind.rawValue)
        .navigationBarTitleDisplayMode(.large)
        .toolbarColorScheme(.dark, for: .navigationBar)
    }

    // MARK: - Notifications

    private var notificationsContent: some View {
        VStack(spacing: 14) {
            ForEach(notificationToggles, id: \.label) { toggle in
                HStack(spacing: 14) {
                    Image(systemName: toggle.icon)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(toggle.tint)
                        .frame(width: 28)

                    VStack(alignment: .leading, spacing: 3) {
                        Text(toggle.label)
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(Theme.textPrimary)
                        Text(toggle.detail)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(Theme.textSecondary)
                    }

                    Spacer()

                    Toggle("", isOn: toggle.binding)
                        .tint(Theme.accent)
                        .labelsHidden()
                }
                .padding(16)
                .background(Theme.surface)
                .clipShape(.rect(cornerRadius: 16))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Theme.stroke, lineWidth: 1)
                )
            }
        }
    }

    // MARK: - Payout

    private var payoutContent: some View {
        VStack(spacing: 16) {
            VStack(spacing: 12) {
                Image(systemName: "creditcard")
                    .font(.system(size: 36, weight: .light))
                    .foregroundStyle(Theme.textTertiary)
                Text("No payout method yet")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Theme.textPrimary)
                Text("Connecting a payout account is coming soon. You'll be able to add your details and cash out your earnings here.")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Theme.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 8)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 32)
            .padding(.horizontal, 16)
            .background(Theme.surface)
            .clipShape(.rect(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.stroke, lineWidth: 1))
        }
    }


    // MARK: - Help

    private var helpContent: some View {
        VStack(spacing: 14) {
            helpRow(icon: "envelope.fill", title: "Contact support", detail: "Email our team",
                    url: URL(string: "mailto:support@paidpost.app"))
            helpRow(icon: "lock.shield.fill", title: "Privacy policy", detail: "How we handle your data",
                    url: URL(string: "https://paidpost.vercel.app/privacy"))
            helpRow(icon: "doc.plaintext.fill", title: "Terms of service", detail: "The rules of using PaidPost",
                    url: URL(string: "https://paidpost.vercel.app/terms"))

            Button {
                Task { await store.signOut() }
            } label: {
                accountActionRow(icon: "rectangle.portrait.and.arrow.right", title: "Sign out", tint: Theme.textSecondary)
            }
            .buttonStyle(PressableStyle())

            Button(role: .destructive) {
                showDeleteConfirm = true
            } label: {
                accountActionRow(icon: "trash.fill", title: "Delete account", tint: Theme.coral)
            }
            .buttonStyle(PressableStyle())
            .alert("Delete your account?", isPresented: $showDeleteConfirm) {
                Button("Cancel", role: .cancel) {}
                Button("Delete", role: .destructive) {
                    Task { await store.deleteAccount() }
                }
            } message: {
                Text("This permanently deletes your account, applications, and earnings history. This can't be undone.")
            }
        }
    }

    private func accountActionRow(icon: String, title: String, tint: Color) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(tint)
                .frame(width: 28)
            Text(title)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(tint)
            Spacer()
        }
        .padding(16)
        .background(Theme.surface)
        .clipShape(.rect(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.stroke, lineWidth: 1))
    }

    private func helpRow(icon: String, title: String, detail: String, url: URL? = nil) -> some View {
        Button {
            let generator = UIImpactFeedbackGenerator(style: .soft)
            generator.impactOccurred()
            if let url { openURL(url) }
        } label: {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Theme.electric)
                    .frame(width: 28)

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(Theme.textPrimary)
                    Text(detail)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Theme.textSecondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Theme.textTertiary)
            }
            .padding(16)
            .background(Theme.surface)
            .clipShape(.rect(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Theme.stroke, lineWidth: 1)
            )
        }
        .buttonStyle(PressableStyle())
    }

    // MARK: - Toggle data

    private var notificationToggles: [(label: String, detail: String, icon: String, tint: Color, binding: Binding<Bool>)] {
        [
            (
                "New methods",
                "When brands post new opportunities",
                "sparkles",
                Theme.coral,
                $notifyNewMethods
            ),
            (
                "Application updates",
                "Approvals, rejections, and review status",
                "checkmark.seal.fill",
                Theme.electric,
                $notifyApplicationUpdates
            ),
            (
                "Payouts",
                "When earnings are deposited",
                "dollarsign.circle.fill",
                Theme.accent,
                $notifyPayouts
            ),
            (
                "Milestones",
                "View count and earnings milestones",
                "trophy.fill",
                Theme.gold,
                $notifyMilestones
            ),
            (
                "Tips & tricks",
                "Creator guides to boost your reach",
                "lightbulb.fill",
                Theme.gold,
                $notifyTips
            )
        ]
    }
}

#Preview {
    NavigationStack {
        SettingsDetailView(kind: .notifications)
    }
    .environment(AppStore())
    .preferredColorScheme(.dark)
}
