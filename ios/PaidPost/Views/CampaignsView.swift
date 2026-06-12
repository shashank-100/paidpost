//
//  CampaignsView.swift
//  PaidPost
//
//  All brands the creator is working with, grouped by stage. Mirrors
//  8x-mobile's campaigns list + groupCampaigns logic. Each row opens the
//  per-brand WorkspaceView.
//

import SwiftUI

struct CampaignsView: View {
    @Environment(AppStore.self) private var store
    @State private var filter: CampaignFilter = .all
    @State private var loading = true

    enum CampaignFilter: String, CaseIterable, Identifiable {
        case all = "All"
        case active = "Active"
        case underReview = "Under review"
        case incomplete = "To do"
        case past = "Past"
        var id: String { rawValue }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                filterPills
                let shown = filtered
                if loading && store.campaigns.isEmpty {
                    ProgressView().tint(Theme.accent)
                        .frame(maxWidth: .infinity).padding(.top, 60)
                } else if shown.isEmpty {
                    emptyState
                } else {
                    ForEach(shown) { brand in
                        NavigationLink(value: DiscoverRoute.workspace(brandSlug: brand.slug ?? "")) {
                            CampaignRow(brand: brand)
                        }
                        .buttonStyle(PressableStyle())
                        .disabled(brand.slug == nil)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 40)
        }
        .scrollIndicators(.hidden)
        .background(Theme.background)
        .navigationTitle("Campaigns")
        .navigationBarTitleDisplayMode(.large)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .navigationDestination(for: DiscoverRoute.self) { route in
            if case .workspace(let slug) = route { WorkspaceView(brandSlug: slug) }
        }
        .task { await store.loadCampaigns(); loading = false }
        .refreshable { await store.loadCampaigns() }
    }

    private var filterPills: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 10) {
                ForEach(CampaignFilter.allCases) { f in
                    let selected = filter == f
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) { filter = f }
                    } label: {
                        Text(f.rawValue)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(selected ? Theme.background : Theme.textSecondary)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 9)
                            .background(selected ? AnyShapeStyle(Theme.accent) : AnyShapeStyle(Theme.surface))
                            .clipShape(.capsule)
                            .overlay(Capsule().stroke(Theme.stroke, lineWidth: selected ? 0 : 1))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .scrollIndicators(.hidden)
        .contentMargins(.horizontal, 0)
    }

    /// Ports 8x-mobile's groupCampaigns() status buckets.
    private var filtered: [ManagedStatusDTO.ManagedBrandDTO] {
        let brands = store.campaigns
        switch filter {
        case .all:
            return brands
        case .active:
            return brands.filter { ["warming_up", "active", "ghosted", "unclear"].contains($0.status ?? "") }
        case .underReview:
            return brands.filter {
                $0.status == "test_videos_submitted" || ($0.status == "applied" && $0.videosComplete == true)
            }
        case .incomplete:
            return brands.filter { $0.status == "applied" && $0.videosComplete != true }
        case .past:
            return brands.filter { ["dropped", "rejected"].contains($0.status ?? "") }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "rectangle.stack.badge.person.crop.fill")
                .font(.system(size: 40, weight: .light))
                .foregroundStyle(Theme.textTertiary)
            Text(filter == .all ? "No campaigns yet" : "Nothing here")
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(Theme.textPrimary)
            Text(filter == .all
                 ? "Apply to a method in Discover to start your first campaign."
                 : "No campaigns match this filter.")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
        .padding(.horizontal, 30)
    }
}

private struct CampaignRow: View {
    let brand: ManagedStatusDTO.ManagedBrandDTO

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle().fill(Theme.electric.opacity(0.15))
                if let logo = brand.logo, let url = URL(string: logo) {
                    AsyncImage(url: url) { $0.resizable().scaledToFill() } placeholder: { initials }
                        .frame(width: 46, height: 46).clipShape(.circle)
                } else {
                    initials
                }
            }
            .frame(width: 46, height: 46)

            VStack(alignment: .leading, spacing: 4) {
                Text(brand.name ?? "Brand")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Theme.textPrimary)
                statusBadge
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(Theme.textTertiary)
        }
        .methodCard(padding: 14)
    }

    private var initials: some View {
        Text(String((brand.name ?? "B").prefix(1)).uppercased())
            .font(.system(size: 18, weight: .heavy, design: .rounded))
            .foregroundStyle(Theme.electric)
    }

    private var statusBadge: some View {
        let (label, color) = Self.style(for: brand.status ?? "applied")
        return HStack(spacing: 4) {
            Circle().fill(color).frame(width: 6, height: 6)
            Text(label)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(color)
        }
    }

    private static func style(for status: String) -> (String, Color) {
        switch status {
        case "active", "ghosted", "unclear": return ("Active", Theme.accent)
        case "warming_up": return ("Warming up", Theme.gold)
        case "accepted": return ("Accepted", Theme.electric)
        case "test_videos_submitted": return ("Under review", Theme.gold)
        case "applied": return ("Applied", Theme.textSecondary)
        case "rejected": return ("Not selected", Theme.coral)
        case "dropped": return ("Ended", Theme.textTertiary)
        default: return (status.replacingOccurrences(of: "_", with: " ").capitalized, Theme.textSecondary)
        }
    }
}

#Preview {
    NavigationStack { CampaignsView() }
        .environment(AppStore())
        .preferredColorScheme(.dark)
}
