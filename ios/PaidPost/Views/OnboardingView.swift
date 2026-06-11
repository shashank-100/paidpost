//
//  OnboardingView.swift
//  Methods
//

import SwiftUI

struct OnboardingView: View {
    @Environment(AppStore.self) private var store
    @State private var currentPage = 0
    @State private var showContent = false

    private let pages: [OnboardingPage] = [
        OnboardingPage(
            accent: Theme.accent,
            icon: "bolt.fill",
            title: "Get Paid to Create",
            subtitle: "Brands post paid gigs. You make 20–40 second videos. It's that simple."
        ),
        OnboardingPage(
            accent: Theme.electric,
            icon: "chart.line.uptrend.xyaxis",
            title: "Track Your Earnings",
            subtitle: "Real-time analytics on every post. Watch your views and income grow."
        ),
        OnboardingPage(
            accent: Theme.coral,
            icon: "dollarsign.circle.fill",
            title: "Cash Out Instantly",
            subtitle: "No waiting. Post your video and get paid the same day."
        )
    ]

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            VStack(spacing: 0) {
                TabView(selection: $currentPage) {
                    ForEach(pages.indices, id: \.self) { index in
                        pageView(pages[index])
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .frame(maxHeight: .infinity)

                bottomSection
            }

            // Decorative background glow
            Circle()
                .fill(pages[currentPage].accent.opacity(0.08))
                .frame(width: 300, height: 300)
                .blur(radius: 80)
                .offset(y: -180)
                .allowsHitTesting(false)
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.2)) {
                showContent = true
            }
        }
    }

    private func pageView(_ page: OnboardingPage) -> some View {
        VStack(spacing: 0) {
            Spacer()

            // Icon
            ZStack {
                Circle()
                    .fill(page.accent.opacity(0.12))
                    .frame(width: 140, height: 140)

                Image(systemName: page.icon)
                    .font(.system(size: 52, weight: .bold))
                    .foregroundStyle(page.accent)
                    .shadow(color: page.accent.opacity(0.4), radius: 20)
            }
            .scaleEffect(showContent ? 1 : 0.7)
            .opacity(showContent ? 1 : 0)

            Spacer().frame(height: 48)

            Text(page.title)
                .font(.system(size: 32, weight: .heavy, design: .rounded))
                .foregroundStyle(Theme.textPrimary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
                .opacity(showContent ? 1 : 0)
                .offset(y: showContent ? 0 : 20)

            Spacer().frame(height: 16)

            Text(page.subtitle)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 44)
                .opacity(showContent ? 1 : 0)
                .offset(y: showContent ? 0 : 20)

            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private var bottomSection: some View {
        VStack(spacing: 24) {
            // Page dots
            HStack(spacing: 8) {
                ForEach(pages.indices, id: \.self) { index in
                    Capsule()
                        .fill(
                            currentPage == index
                                ? AnyShapeStyle(pages[index].accent)
                                : AnyShapeStyle(Theme.surfaceElevated)
                        )
                        .frame(
                            width: currentPage == index ? 24 : 8,
                            height: 8
                        )
                        .animation(.spring(response: 0.35, dampingFraction: 0.7), value: currentPage)
                }
            }

            Button {
                let generator = UIImpactFeedbackGenerator(style: .medium)
                generator.impactOccurred()
                if currentPage < pages.count - 1 {
                    withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) {
                        currentPage += 1
                    }
                } else {
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                        store.hasOnboarded = true
                    }
                }
            } label: {
                HStack(spacing: 8) {
                    Text(currentPage < pages.count - 1 ? "Next" : "Start Earning")
                        .font(.system(size: 17, weight: .bold))
                    Image(systemName: currentPage < pages.count - 1 ? "arrow.right" : "bolt.fill")
                        .font(.system(size: 15, weight: .bold))
                }
                .foregroundStyle(Theme.background)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
                .background(
                    LinearGradient(
                        colors: [pages[currentPage].accent, pages[currentPage].accent.opacity(0.7)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .clipShape(.rect(cornerRadius: 18))
                .shadow(color: pages[currentPage].accent.opacity(0.3), radius: 16, y: 6)
            }
            .buttonStyle(PressableStyle())

            Button {
                let generator = UIImpactFeedbackGenerator(style: .soft)
                generator.impactOccurred()
                withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                    store.hasOnboarded = true
                }
            } label: {
                Text("Skip")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.textTertiary)
            }
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 50)
        .opacity(showContent ? 1 : 0)
    }
}

private struct OnboardingPage {
    let accent: Color
    let icon: String
    let title: String
    let subtitle: String
}

#Preview {
    OnboardingView()
        .environment(AppStore())
        .preferredColorScheme(.dark)
}
