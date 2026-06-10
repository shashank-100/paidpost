//
//  EarningsView.swift
//  Methods
//

import SwiftUI

struct EarningsView: View {
    @Environment(AppStore.self) private var store
    @State private var showCashOut = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 22) {
                    balanceCard
                    statsRow
                    weeklyChart
                    activitySection
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 120)
            }
            .scrollIndicators(.hidden)
            .background(Theme.background)
            .navigationTitle("Earnings")
            .navigationBarTitleDisplayMode(.large)
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
        .tint(Theme.accent)
        .alert("Cash out $\(Int(store.availableBalance).formatted())?", isPresented: $showCashOut) {
            Button("Cancel", role: .cancel) {}
            Button("Cash out") {
                let generator = UINotificationFeedbackGenerator()
                generator.notificationOccurred(.success)
                withAnimation { store.cashOut() }
            }
        } message: {
            Text("Funds arrive instantly to your linked account.")
        }
    }

    private var balanceCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Available balance")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Theme.background.opacity(0.7))
            Text("$\(store.availableBalance, specifier: "%.2f")")
                .font(.system(size: 44, weight: .heavy, design: .rounded))
                .foregroundStyle(Theme.background)
                .contentTransition(.numericText())

            Button {
                let generator = UIImpactFeedbackGenerator(style: .medium)
                generator.impactOccurred()
                showCashOut = true
            } label: {
                HStack {
                    Image(systemName: "bolt.fill")
                    Text("Cash out instantly")
                }
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(Theme.accent)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Theme.background)
                .clipShape(.capsule)
            }
            .buttonStyle(PressableStyle())
            .disabled(store.availableBalance <= 0)
            .opacity(store.availableBalance <= 0 ? 0.5 : 1)
        }
        .padding(22)
        .background(
            LinearGradient(
                colors: [Theme.accent, Theme.accentDim],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(.rect(cornerRadius: Theme.cardCorner))
        .shadow(color: Theme.accentGlow, radius: 20, y: 8)
    }

    private var statsRow: some View {
        HStack(spacing: 14) {
            stat(value: "$\(Int(store.totalEarned))", label: "Lifetime", icon: "dollarsign.circle.fill", tint: Theme.accent)
            stat(value: "$\(Int(store.pendingEarnings))", label: "Pending", icon: "clock.fill", tint: Theme.gold)
            stat(value: store.totalViews.shortFormatted, label: "Views", icon: "eye.fill", tint: Theme.electric)
        }
    }

    private func stat(value: String, label: String, icon: String, tint: Color) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(tint)
            Text(value)
                .font(.system(size: 18, weight: .heavy, design: .rounded))
                .foregroundStyle(Theme.textPrimary)
            Text(label)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Theme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .methodCard(padding: 0)
    }

    private var weeklyChart: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("This week")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(Theme.textPrimary)
                Spacer()
                Text("+$\(Int(store.availableBalance))")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Theme.accent)
            }
            HStack(alignment: .bottom, spacing: 10) {
                ForEach(Array(weekData.enumerated()), id: \.offset) { index, value in
                    BarColumn(value: value, max: weekData.max() ?? 1, label: dayLabels[index])
                }
            }
            .frame(height: 130)
        }
        .methodCard()
    }

    private var activitySection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Your applications")
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(Theme.textPrimary)
            if store.applications.isEmpty {
                Text("Apply to a method to start earning.")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Theme.textSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 30)
            } else {
                ForEach(store.applications) { application in
                    ApplicationRow(application: application)
                }
            }
        }
    }

    private let weekData: [Double] = [40, 0, 90, 60, 180, 120, 80]
    private let dayLabels = ["M", "T", "W", "T", "F", "S", "S"]
}

private struct BarColumn: View {
    let value: Double
    let max: Double
    let label: String
    @State private var animate = false

    var body: some View {
        VStack(spacing: 8) {
            GeometryReader { geo in
                VStack {
                    Spacer(minLength: 0)
                    RoundedRectangle(cornerRadius: 6)
                        .fill(
                            value >= max
                                ? AnyShapeStyle(LinearGradient(colors: [Theme.accent, Theme.accentDim], startPoint: .top, endPoint: .bottom))
                                : AnyShapeStyle(Theme.surfaceElevated)
                        )
                        .frame(height: animate ? max == 0 ? 4 : geo.size.height * (value / max) + 4 : 4)
                }
            }
            Text(label)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Theme.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.05)) {
                animate = true
            }
        }
    }
}

private struct ApplicationRow: View {
    let application: Application

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(application.method.accent.opacity(0.18))
                Image(systemName: application.method.logoSymbol)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(application.method.accent)
            }
            .frame(width: 44, height: 44)

            VStack(alignment: .leading, spacing: 3) {
                Text(application.method.brand)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Theme.textPrimary)
                HStack(spacing: 4) {
                    Image(systemName: application.status.icon)
                        .font(.system(size: 10, weight: .bold))
                    Text(application.status.rawValue)
                        .font(.system(size: 12, weight: .semibold))
                }
                .foregroundStyle(application.status.color)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 3) {
                Text(application.earned > 0 ? "+$\(Int(application.earned))" : "$\(Int(application.method.payPerPost))")
                    .font(.system(size: 16, weight: .heavy, design: .rounded))
                    .foregroundStyle(application.earned > 0 ? Theme.accent : Theme.textSecondary)
                if application.views > 0 {
                    Text("\(application.views.shortFormatted) views")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Theme.textTertiary)
                }
            }
        }
        .methodCard(padding: 14)
    }
}

extension Int {
    /// Compact number like 42.3K, 1.2M.
    var shortFormatted: String {
        let number = Double(self)
        if number >= 1_000_000 {
            return String(format: "%.1fM", number / 1_000_000)
        } else if number >= 1_000 {
            return String(format: "%.1fK", number / 1_000)
        }
        return "\(self)"
    }
}

#Preview {
    EarningsView()
        .environment(AppStore())
        .preferredColorScheme(.dark)
}
