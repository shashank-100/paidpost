//
//  MethodCard.swift
//  Methods
//

import SwiftUI

/// Large feature card used in the discover feed.
struct MethodCard: View {
    let method: Method
    let applied: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header
            Text(method.title)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(Theme.textPrimary)
                .lineLimit(2)
            Text(method.tagline)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Theme.textSecondary)
                .lineLimit(2)

            HStack(spacing: 8) {
                Pill(text: method.lengthLabel, icon: "timer", tint: Theme.textSecondary)
                Pill(text: method.difficulty.rawValue, icon: "gauge.medium", tint: method.difficulty.color)
                Pill(text: method.category.rawValue, icon: method.category.icon, tint: Theme.textSecondary)
            }

            budgetBar

            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("$\(Int(method.payPerPost))")
                    .font(.system(size: 30, weight: .heavy, design: .rounded))
                    .foregroundStyle(Theme.accent)
                Text("/ post")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.textSecondary)
                Spacer()
                Text(applied ? "Applied" : "Apply")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(applied ? Theme.textSecondary : Theme.background)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 11)
                    .background(
                        applied
                            ? AnyShapeStyle(Theme.surfaceElevated)
                            : AnyShapeStyle(Theme.accent)
                    )
                    .clipShape(.capsule)
            }
        }
        .methodCard()
        .overlay(alignment: .topTrailing) {
            if method.isHot {
                HotBadge()
                    .padding(14)
            }
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 14)
                    .fill(method.accent.opacity(0.18))
                Image(systemName: method.logoSymbol)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(method.accent)
            }
            .frame(width: 46, height: 46)

            VStack(alignment: .leading, spacing: 2) {
                Text(method.brand)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Theme.textPrimary)
                Text("Paid partnership")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Theme.textTertiary)
            }
            Spacer()
        }
    }

    private var budgetBar: some View {
        VStack(alignment: .leading, spacing: 7) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Theme.surfaceElevated)
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [method.accent.opacity(0.7), method.accent],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: max(8, geo.size.width * method.budgetProgress))
                }
            }
            .frame(height: 7)

            HStack {
                Text("$\(Int(method.budgetRemaining).formatted()) left in pool")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.textSecondary)
                Spacer()
                Text("\(Int(method.budgetProgress * 100))% claimed")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.textTertiary)
            }
        }
    }
}

struct Pill: View {
    let text: String
    let icon: String
    let tint: Color

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .bold))
            Text(text)
                .font(.system(size: 12, weight: .semibold))
        }
        .foregroundStyle(tint)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Theme.surfaceElevated)
        .clipShape(.capsule)
    }
}

struct HotBadge: View {
    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: "flame.fill")
                .font(.system(size: 10, weight: .bold))
            Text("HOT")
                .font(.system(size: 11, weight: .heavy))
        }
        .foregroundStyle(Theme.background)
        .padding(.horizontal, 9)
        .padding(.vertical, 5)
        .background(Theme.coral)
        .clipShape(.capsule)
    }
}
