//
//  MethodDetailView.swift
//  Methods
//

import SwiftUI

struct MethodDetailView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let method: Method

    @State private var showApplySheet = false

    private var applied: Bool { store.hasApplied(to: method) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                hero
                payRow
                section(title: "What you'll do", systemImage: "list.bullet.clipboard.fill") {
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(method.requirements, id: \.self) { req in
                            HStack(alignment: .top, spacing: 10) {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 16))
                                    .foregroundStyle(method.accent)
                                Text(req)
                                    .font(.system(size: 15, weight: .medium))
                                    .foregroundStyle(Theme.textPrimary)
                                Spacer()
                            }
                        }
                    }
                }
                section(title: "Hooks that go viral", systemImage: "quote.bubble.fill") {
                    VStack(spacing: 10) {
                        ForEach(method.exampleHooks, id: \.self) { hook in
                            HStack {
                                Text("\u{201C}\(hook)\u{201D}")
                                    .font(.system(size: 14, weight: .medium, design: .rounded))
                                    .foregroundStyle(Theme.textSecondary)
                                Spacer()
                            }
                            .padding(14)
                            .background(Theme.surfaceElevated)
                            .clipShape(.rect(cornerRadius: 14))
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 140)
        }
        .scrollIndicators(.hidden)
        .background(Theme.background)
        .navigationTitle(method.brand)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .safeAreaInset(edge: .bottom) {
            applyBar
        }
        .sheet(isPresented: $showApplySheet) {
            ApplySheet(method: method)
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
        }
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 20)
                    .fill(method.accent.opacity(0.18))
                Image(systemName: method.logoSymbol)
                    .font(.system(size: 32, weight: .bold))
                    .foregroundStyle(method.accent)
            }
            .frame(width: 72, height: 72)

            Text(method.title)
                .font(.system(size: 28, weight: .heavy, design: .rounded))
                .foregroundStyle(Theme.textPrimary)
            Text(method.tagline)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(Theme.textSecondary)

            HStack(spacing: 8) {
                Pill(text: method.lengthLabel, icon: "timer", tint: Theme.textSecondary)
                Pill(text: method.difficulty.rawValue, icon: "gauge.medium", tint: method.difficulty.color)
                Pill(text: method.category.rawValue, icon: method.category.icon, tint: Theme.textSecondary)
            }
        }
        .padding(.top, 8)
    }

    private var payRow: some View {
        HStack(spacing: 14) {
            statBlock(value: "$\(Int(method.payPerPost))", label: "per post", tint: Theme.accent)
            statBlock(value: "$\(Int(method.budgetRemaining).formatted())", label: "pool left", tint: Theme.textPrimary)
            statBlock(value: "\(Int(method.budgetProgress * 100))%", label: "claimed", tint: Theme.textPrimary)
        }
    }

    private func statBlock(value: String, label: String, tint: Color) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 20, weight: .heavy, design: .rounded))
                .foregroundStyle(tint)
            Text(label)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Theme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(Theme.surface)
        .clipShape(.rect(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.stroke, lineWidth: 1))
    }

    private func section<Content: View>(
        title: String,
        systemImage: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Label(title, systemImage: systemImage)
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(Theme.textPrimary)
            content()
        }
    }

    private var applyBar: some View {
        Button {
            if !applied {
                let generator = UIImpactFeedbackGenerator(style: .medium)
                generator.impactOccurred()
                showApplySheet = true
            }
        } label: {
            HStack {
                Image(systemName: applied ? "checkmark.circle.fill" : "paperplane.fill")
                Text(applied ? "Application submitted" : "Apply for $\(Int(method.payPerPost))")
            }
            .font(.system(size: 17, weight: .bold))
            .foregroundStyle(applied ? Theme.textSecondary : Theme.background)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 17)
            .background(applied ? AnyShapeStyle(Theme.surfaceElevated) : AnyShapeStyle(Theme.accent))
            .clipShape(.rect(cornerRadius: 18))
        }
        .buttonStyle(.plain)
        .disabled(applied)
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 8)
        .background(.ultraThinMaterial)
    }
}

#Preview {
    NavigationStack {
        MethodDetailView(method: SampleData.methods[0])
    }
    .environment(AppStore())
    .preferredColorScheme(.dark)
}
