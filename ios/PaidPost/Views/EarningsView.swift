//
//  EarningsView.swift
//  Methods
//

import SwiftUI

struct EarningsView: View {
    @Environment(AppStore.self) private var store

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 22) {
                    balanceCard
                    statsRow
                    // Only show the weekly chart when we have real ledger data
                    // to plot — never fabricated bars.
                    if weekData.contains(where: { $0 > 0 }) {
                        weeklyChart
                    }
                    if !store.transactions.isEmpty {
                        ledgerSection
                    }
                    activitySection
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 120)
            }
            .scrollIndicators(.hidden)
            .background(Theme.background)
            .task { await store.loadWallet(); await store.loadApplications() }
            .refreshable { await store.loadWallet(); await store.loadApplications() }
            .navigationTitle("Earnings")
            .navigationBarTitleDisplayMode(.large)
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
        .tint(Theme.accent)
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

            // Payouts are managed on the web. The app shows balance read-only;
            // creators cash out through the PaidPost web dashboard.
            Text("Manage payouts and cash out from your PaidPost dashboard on the web.")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.background.opacity(0.8))
                .fixedSize(horizontal: false, vertical: true)
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

    private var ledgerSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Recent transactions")
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(Theme.textPrimary)
            ForEach(store.transactions) { tx in
                TransactionRow(tx: tx)
            }
        }
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
                Text("+$\(Int(weekData.reduce(0, +)))")
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

    /// Real per-day earnings for the last 7 days, derived from the wallet
    /// ledger (credits only). Index 0 is six days ago, index 6 is today —
    /// matching `dayLabels`, which is rebuilt from the current weekday.
    private var weekData: [Double] {
        EarningsMath.weekData(transactions: store.transactions, now: Date())
    }

    /// Single-letter weekday labels ending on today, aligned with `weekData`.
    private var dayLabels: [String] {
        EarningsMath.dayLabels(now: Date())
    }
}

/// Pure earnings-chart math, factored out of the view so the date bucketing and
/// weekday-label alignment can be unit-tested with injected `now`/`calendar`.
enum EarningsMath {
    /// Per-day credit totals for the 7 days ending on `now`. Index 0 is six days
    /// ago, index 6 is `now`. Debits (amount <= 0) and out-of-window entries are
    /// ignored.
    static func weekData(
        transactions: [TransactionDTO],
        now: Date,
        calendar: Calendar = .current
    ) -> [Double] {
        let today = calendar.startOfDay(for: now)
        var totals = [Double](repeating: 0, count: 7)
        for tx in transactions {
            guard let amount = tx.amount, amount > 0,
                  let date = BackendDate.parse(tx.created_at) else { continue }
            let day = calendar.startOfDay(for: date)
            let offset = calendar.dateComponents([.day], from: day, to: today).day ?? -1
            if (0...6).contains(offset) {
                totals[6 - offset] += amount
            }
        }
        return totals
    }

    /// Single-letter weekday labels for the 7 days ending on `now`, aligned with
    /// `weekData` (index 6 == today).
    static func dayLabels(now: Date, calendar: Calendar = .current) -> [String] {
        let symbols = calendar.veryShortWeekdaySymbols   // ["S","M","T",...] index = weekday-1
        let todayWeekday = calendar.component(.weekday, from: now) - 1
        return (0..<7).map { i in
            symbols[(todayWeekday - (6 - i) + 7 * 2) % 7]
        }
    }
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

private struct TransactionRow: View {
    let tx: TransactionDTO

    private var amount: Double { tx.amount ?? 0 }
    private var isCredit: Bool { amount >= 0 }

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill((isCredit ? Theme.accent : Theme.coral).opacity(0.18))
                Image(systemName: isCredit ? "arrow.down.left" : "arrow.up.right")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(isCredit ? Theme.accent : Theme.coral)
            }
            .frame(width: 44, height: 44)

            VStack(alignment: .leading, spacing: 3) {
                Text(tx.description ?? (tx.transaction_type ?? "Transaction").capitalized)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Theme.textPrimary)
                    .lineLimit(1)
                if let status = tx.stripe_transfer_status {
                    Text(status.capitalized)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Theme.textTertiary)
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 3) {
                Text("\(isCredit ? "+" : "-")$\(abs(amount), specifier: "%.2f")")
                    .font(.system(size: 15, weight: .heavy, design: .rounded))
                    .foregroundStyle(isCredit ? Theme.accent : Theme.textSecondary)
                if let at = BackendDate.parse(tx.created_at) {
                    Text(at.relativeFormatted)
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
