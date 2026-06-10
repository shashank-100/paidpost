//
//  SettingsDetailView.swift
//  Methods
//

import SwiftUI

/// Reusable settings detail screen used for Notifications, Payout, Help.
struct SettingsDetailView: View {
    @Environment(AppStore.self) private var store
    let kind: Kind

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
        VStack(spacing: 14) {
            payoutMethod(icon: "creditcard.fill", name: "Visa ending in 4242", isDefault: true)
            payoutMethod(icon: "building.columns.fill", name: "Bank account (Chase)", isDefault: false)
            payoutMethod(icon: "wallet.pass.fill", name: "Apple Pay", isDefault: false)

            Button {
                let generator = UIImpactFeedbackGenerator(style: .soft)
                generator.impactOccurred()
            } label: {
                HStack {
                    Image(systemName: "plus.circle.fill")
                    Text("Add payment method")
                }
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(Theme.accent)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Theme.accent.opacity(0.08))
                .clipShape(.rect(cornerRadius: 14))
            }
        }
    }

    private func payoutMethod(icon: String, name: String, isDefault: Bool) -> some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Theme.accent.opacity(0.12))
                    .frame(width: 40, height: 40)
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Theme.accent)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(name)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Theme.textPrimary)
                if isDefault {
                    Text("Default")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Theme.accent)
                }
            }

            Spacer()

            if isDefault {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(Theme.accent)
            }
        }
        .padding(14)
        .background(Theme.surface)
        .clipShape(.rect(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Theme.stroke, lineWidth: 1)
        )
    }

    // MARK: - Help

    private var helpContent: some View {
        VStack(spacing: 14) {
            helpRow(icon: "envelope.fill", title: "Contact support", detail: "We reply within 2 hours")
            helpRow(icon: "doc.text.fill", title: "Creator guidelines", detail: "Brand requirements & tips")
            helpRow(icon: "questionmark.circle.fill", title: "FAQ", detail: "Common questions answered")
            helpRow(icon: "lock.shield.fill", title: "Privacy policy", detail: "How we handle your data")
            helpRow(icon: "doc.plaintext.fill", title: "Terms of service", detail: "Updated June 2026")
        }
    }

    private func helpRow(icon: String, title: String, detail: String) -> some View {
        Button {
            let generator = UIImpactFeedbackGenerator(style: .soft)
            generator.impactOccurred()
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

    private let notificationToggles: [(label: String, detail: String, icon: String, tint: Color, binding: Binding<Bool>)] = [
        (
            "New methods",
            "When brands post new opportunities",
            "sparkles",
            Theme.coral,
            Binding.constant(true)
        ),
        (
            "Application updates",
            "Approvals, rejections, and review status",
            "checkmark.seal.fill",
            Theme.electric,
            Binding.constant(true)
        ),
        (
            "Payouts",
            "When earnings are deposited",
            "dollarsign.circle.fill",
            Theme.accent,
            Binding.constant(true)
        ),
        (
            "Milestones",
            "View count and earnings milestones",
            "trophy.fill",
            Theme.gold,
            Binding.constant(true)
        ),
        (
            "Tips & tricks",
            "Creator guides to boost your reach",
            "lightbulb.fill",
            Theme.gold,
            Binding.constant(false)
        )
    ]
}

#Preview {
    NavigationStack {
        SettingsDetailView(kind: .notifications)
    }
    .environment(AppStore())
    .preferredColorScheme(.dark)
}
