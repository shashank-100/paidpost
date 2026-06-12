//
//  RootView.swift
//  Methods
//

import SwiftUI

struct RootView: View {
    @Environment(AppStore.self) private var store
    @State private var selectedTab: Tab = .discover

    enum Tab: Int, CaseIterable {
        case discover, earnings, profile

        var title: String {
            switch self {
            case .discover: return "Discover"
            case .earnings: return "Earnings"
            case .profile: return "Profile"
            }
        }
        var icon: String {
            switch self {
            case .discover: return "bolt.fill"
            case .earnings: return "chart.bar.fill"
            case .profile: return "person.fill"
            }
        }
    }

    var body: some View {
        ZStack {
            Group {
                if !store.hasOnboarded {
                    OnboardingView()
                        .transition(.opacity.combined(with: .scale(scale: 1.05)))
                } else if !store.isSignedIn {
                    SignInView()
                        .transition(.opacity)
                } else if store.needsProfileSetup {
                    ProfileSetupView()
                        .transition(.opacity)
                } else {
                    mainApp
                        .transition(.opacity)
                }
            }
            .animation(.spring(response: 0.5, dampingFraction: 0.8), value: store.hasOnboarded)
            .animation(.spring(response: 0.5, dampingFraction: 0.8), value: store.isSignedIn)
            .animation(.spring(response: 0.5, dampingFraction: 0.8), value: store.needsProfileSetup)
        }
    }

    private var mainApp: some View {
        ZStack(alignment: .bottom) {
            Theme.background.ignoresSafeArea()

            ZStack {
                Group {
                    switch selectedTab {
                    case .discover: DiscoverView()
                    case .earnings: EarningsView()
                    case .profile: ProfileView()
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .transition(.opacity.combined(with: .scale(scale: 0.98)))
            }
            .animation(.spring(response: 0.35, dampingFraction: 0.8), value: selectedTab)

            TabBar(selectedTab: $selectedTab)
        }
    }
}

private struct TabBar: View {
    @Binding var selectedTab: RootView.Tab
    @Environment(AppStore.self) private var store

    var body: some View {
        HStack(spacing: 0) {
            ForEach(RootView.Tab.allCases, id: \.rawValue) { tab in
                tabButton(tab)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 10)
        .background(
            .ultraThinMaterial,
            in: .rect(cornerRadius: 28)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 28)
                .stroke(Theme.stroke, lineWidth: 1)
        )
        .padding(.horizontal, 24)
        .padding(.bottom, 6)
    }

    private func tabButton(_ tab: RootView.Tab) -> some View {
        let isSelected = selectedTab == tab
        return Button {
            let generator = UIImpactFeedbackGenerator(style: .soft)
            generator.impactOccurred()
            withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                selectedTab = tab
            }
        } label: {
            VStack(spacing: 4) {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: tab.icon)
                        .font(.system(size: 18, weight: .semibold))

                    // Notification badge on profile tab
                    if tab == .profile && store.unreadNotificationCount > 0 {
                        Circle()
                            .fill(Theme.coral)
                            .frame(width: 8, height: 8)
                            .overlay(
                                Circle()
                                    .stroke(Theme.background, lineWidth: 1.5)
                            )
                            .offset(x: 8, y: -4)
                    }
                }
                Text(tab.title)
                    .font(.system(size: 10, weight: .semibold))
            }
            .foregroundStyle(isSelected ? Theme.background : Theme.textSecondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background {
                if isSelected {
                    Capsule()
                        .fill(Theme.accent)
                        .shadow(color: Theme.accentGlow, radius: 12, y: 4)
                }
            }
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    RootView()
        .environment(AppStore())
        .preferredColorScheme(.dark)
}
