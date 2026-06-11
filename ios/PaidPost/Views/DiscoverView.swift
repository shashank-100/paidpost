//
//  DiscoverView.swift
//  Methods
//

import SwiftUI

struct DiscoverView: View {
    @Environment(AppStore.self) private var store
    @State private var path: [Method] = []

    var body: some View {
        @Bindable var store = store
        NavigationStack(path: $path) {
            ScrollView {
                VStack(spacing: 22) {
                    earningsBanner
                    if !store.hotMethods.isEmpty {
                        hotSection
                    }
                    categoryStrip
                    feed
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 120)
            }
            .scrollIndicators(.hidden)
            .background(Theme.background)
            .refreshable {
                try? await Task.sleep(for: .milliseconds(800))
            }
            .navigationDestination(for: Method.self) { method in
                MethodDetailView(method: method)
            }
            .navigationTitle("Discover")
            .navigationBarTitleDisplayMode(.large)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .searchable(text: $store.searchText, prompt: "Search brands & methods")
        }
        .tint(Theme.accent)
    }

    // MARK: - Earnings Banner

    private var earningsBanner: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Available to post")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.background.opacity(0.7))
                Text("\(store.filteredMethods.count) methods")
                    .font(.system(size: 26, weight: .heavy, design: .rounded))
                    .foregroundStyle(Theme.background)
                Text("Earn up to $\(Int(store.methods.map(\.payPerPost).max() ?? 0)) per video")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.background.opacity(0.7))
            }
            Spacer()
            Image(systemName: "dollarsign.circle.fill")
                .font(.system(size: 52))
                .foregroundStyle(Theme.background.opacity(0.18))
        }
        .padding(20)
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

    // MARK: - Hot Section

    private var hotSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 6) {
                Image(systemName: "flame.fill")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Theme.coral)
                Text("Hot now")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(Theme.textPrimary)
                Spacer()
            }

            ScrollView(.horizontal) {
                HStack(spacing: 12) {
                    ForEach(store.hotMethods) { method in
                        NavigationLink(value: method) {
                            HotMethodCard(method: method)
                        }
                        .buttonStyle(PressableStyle())
                    }
                }
                .padding(.horizontal, 2)
            }
            .scrollIndicators(.hidden)
            .contentMargins(.horizontal, 0)
        }
    }

    // MARK: - Category Strip

    private var categoryStrip: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 10) {
                ForEach(Method.Category.allCases) { category in
                    categoryChip(category)
                }
            }
        }
        .scrollIndicators(.hidden)
        .contentMargins(.horizontal, 0)
    }

    private func categoryChip(_ category: Method.Category) -> some View {
        let isSelected = store.selectedCategory == category
        return Button {
            let generator = UISelectionFeedbackGenerator()
            generator.selectionChanged()
            withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                store.selectedCategory = category
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: category.icon)
                    .font(.system(size: 12, weight: .bold))
                Text(category.rawValue)
                    .font(.system(size: 14, weight: .semibold))
            }
            .foregroundStyle(isSelected ? Theme.background : Theme.textSecondary)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(isSelected ? AnyShapeStyle(Theme.accent) : AnyShapeStyle(Theme.surface))
            .clipShape(.capsule)
            .overlay(
                Capsule().stroke(Theme.stroke, lineWidth: isSelected ? 0 : 1)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Feed

    @ViewBuilder
    private var feed: some View {
        if store.filteredMethods.isEmpty {
            emptyState
        } else {
            LazyVStack(spacing: 16) {
                ForEach(store.filteredMethods) { method in
                    NavigationLink(value: method) {
                        MethodCard(method: method, applied: store.hasApplied(to: method))
                    }
                    .buttonStyle(PressableStyle())
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 40, weight: .light))
                .foregroundStyle(Theme.textTertiary)
            Text("No methods here yet")
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(Theme.textPrimary)
            Text("Try a different category or search.")
                .font(.system(size: 14))
                .foregroundStyle(Theme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }
}

// MARK: - Hot Method Card

private struct HotMethodCard: View {
    let method: Method

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 14)
                    .fill(method.accent.opacity(0.18))
                Image(systemName: method.logoSymbol)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(method.accent)
            }
            .frame(width: 50, height: 50)

            Text(method.brand)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(Theme.textPrimary)

            Text(method.title)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Theme.textSecondary)
                .lineLimit(2)

            Text("$\(Int(method.payPerPost))/post")
                .font(.system(size: 20, weight: .heavy, design: .rounded))
                .foregroundStyle(method.accent)
        }
        .frame(width: 170)
        .padding(16)
        .methodCard()
    }
}

/// Subtle scale-down press effect for tappable cards.
struct PressableStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

#Preview {
    DiscoverView()
        .environment(AppStore())
        .preferredColorScheme(.dark)
}
