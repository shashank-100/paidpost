//
//  WorkspaceView.swift
//  Methods
//
//  Per-brand campaign hub: brief, contract, test videos, and posted content.
//  Sections unlock based on managed-creator status, mirroring 8x-mobile's
//  phase-aware workspace.
//

import SwiftUI

struct WorkspaceView: View {
    let brandSlug: String

    @State private var workspace: WorkspaceDTO?
    @State private var loading = true
    @State private var loadError: String?
    @State private var showContract = false

    var body: some View {
        ScrollView {
            if let workspace {
                content(workspace)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 40)
            } else if loading {
                ProgressView().tint(Theme.accent)
                    .frame(maxWidth: .infinity, minHeight: 300)
            } else {
                errorState
            }
        }
        .scrollIndicators(.hidden)
        .background(Theme.background)
        .navigationTitle(workspace?.org.name ?? "Campaign")
        .navigationBarTitleDisplayMode(.large)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .task { await load() }
        .refreshable { await load() }
    }

    private func load() async {
        loadError = nil
        do {
            workspace = try await WorkspaceAPI.fetchWorkspace(brandSlug: brandSlug)
        } catch {
            loadError = (error as? APIError)?.errorDescription ?? error.localizedDescription
        }
        loading = false
    }

    @ViewBuilder
    private func content(_ ws: WorkspaceDTO) -> some View {
        let status = ws.managedCreator.status ?? "applied"
        let unlocked = WorkspaceDTO.contentAccessibleStatuses.contains(status)

        VStack(alignment: .leading, spacing: 22) {
            statusCard(ws, status: status)

            if let brief = ws.portalConfig, brief.content?.isEmpty == false || brief.description?.isEmpty == false {
                briefSection(brief)
            }

            contractSection(ws)

            if let refs = ws.briefVideos ?? ws.referenceVideos, !refs.isEmpty {
                referenceSection(refs)
            }

            // Audition videos: shown until they're complete + screened.
            if !(ws.managedCreator.videosComplete ?? false) || ws.managedCreator.screeningStatus == nil {
                NavigationLink {
                    UploadVideosView(brandSlug: brandSlug)
                } label: {
                    actionRow(icon: "video.badge.plus",
                              title: "Audition videos",
                              subtitle: videosSubtitle(ws),
                              tint: Theme.gold)
                }
                .buttonStyle(PressableStyle())
            }

            // Warm-up: relevant once accepted / warming up.
            if status == "accepted" || status == "warming_up" {
                NavigationLink {
                    WarmupView(brandSlug: brandSlug)
                } label: {
                    actionRow(icon: "flame.fill",
                              title: "Warm-up",
                              subtitle: "Daily niche videos + screen-time check-ins",
                              tint: Theme.coral)
                }
                .buttonStyle(PressableStyle())
            }

            if unlocked {
                NavigationLink {
                    MyContentView(brandSlug: brandSlug, org: ws.org)
                } label: {
                    actionRow(icon: "play.rectangle.on.rectangle.fill",
                              title: "My content",
                              subtitle: "Track posts and earnings for this campaign")
                }
                .buttonStyle(PressableStyle())
            }
        }
        .padding(.top, 8)
        .sheet(isPresented: $showContract) {
            if let appId = ws.managedCreator.applicationId {
                ContractView(applicationId: appId, brand: ws.org.name ?? "this brand") {
                    Task { await load() }
                }
            }
        }
    }

    private func statusCard(_ ws: WorkspaceDTO, status: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Status")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.textSecondary)
            Text(Self.statusLabel(status))
                .font(.system(size: 22, weight: .heavy, design: .rounded))
                .foregroundStyle(Theme.accent)
            if let pay = ws.managedCreator.basePay, pay > 0 {
                Text("Base pay: $\(Int(pay))")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.textSecondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .methodCard()
    }

    @ViewBuilder
    private func briefSection(_ brief: PortalConfigDTO) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Campaign brief", systemImage: "doc.text.fill")
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(Theme.textPrimary)
            if let title = brief.title, !title.isEmpty {
                Text(title)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Theme.textPrimary)
            }
            Text(brief.content ?? brief.description ?? "")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Theme.textSecondary)
                .lineSpacing(4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .methodCard()
    }

    @ViewBuilder
    private func contractSection(_ ws: WorkspaceDTO) -> some View {
        let signed = ws.managedCreator.contractAcceptedAt != nil
        if let appId = ws.managedCreator.applicationId, !appId.isEmpty {
            Button {
                if !signed { showContract = true }
            } label: {
                actionRow(
                    icon: signed ? "checkmark.seal.fill" : "signature",
                    title: signed ? "Contract signed" : "Sign your contract",
                    subtitle: signed
                        ? "Signed by \(ws.managedCreator.contractSignerName ?? "you")"
                        : "Required before you start posting",
                    tint: signed ? Theme.accent : Theme.gold
                )
            }
            .buttonStyle(PressableStyle())
            .disabled(signed)
        }
    }

    private func referenceSection(_ refs: [ReferenceVideoDTO]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Reference videos", systemImage: "sparkles.tv.fill")
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(Theme.textPrimary)
            ForEach(refs) { ref in
                VStack(alignment: .leading, spacing: 6) {
                    if let cat = ref.category {
                        Text(cat.uppercased())
                            .font(.system(size: 11, weight: .heavy))
                            .foregroundStyle(Theme.accent)
                    }
                    if let notes = ref.notes ?? ref.transcript {
                        Text(notes)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(Theme.textSecondary)
                            .lineLimit(4)
                    }
                    if let urlStr = ref.video_url, let url = URL(string: urlStr) {
                        Link(destination: url) {
                            Label("Watch", systemImage: "play.circle.fill")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(Theme.accent)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(14)
                .background(Theme.surfaceElevated)
                .clipShape(.rect(cornerRadius: 14))
            }
        }
    }

    private func videosSubtitle(_ ws: WorkspaceDTO) -> String {
        switch ws.managedCreator.screeningStatus {
        case "pending", "screening": return "Submitted — under review"
        case "passed": return "Approved ✓"
        case "failed": return "Re-upload needed"
        default: return "Upload your audition clips to get approved"
        }
    }

    private func actionRow(icon: String, title: String, subtitle: String, tint: Color = Theme.accent) -> some View {
        HStack(spacing: 14) {
            ZStack {
                Circle().fill(tint.opacity(0.15)).frame(width: 40, height: 40)
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(tint)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Theme.textPrimary)
                Text(subtitle)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Theme.textSecondary)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(Theme.textTertiary)
        }
        .padding(14)
        .background(Theme.surface)
        .clipShape(.rect(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.stroke, lineWidth: 1))
    }

    private var errorState: some View {
        VStack(spacing: 12) {
            Image(systemName: "tray.fill")
                .font(.system(size: 40, weight: .light))
                .foregroundStyle(Theme.textTertiary)
            Text("Campaign not available")
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(Theme.textPrimary)
            Text(loadError ?? "You may not have an active campaign with this brand yet.")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 40)
        .frame(maxWidth: .infinity, minHeight: 300)
    }

    private static func statusLabel(_ raw: String) -> String {
        switch raw {
        case "applied": return "Applied"
        case "test_videos_submitted": return "Under review"
        case "accepted": return "Accepted"
        case "warming_up": return "Warming up"
        case "active": return "Active"
        case "ghosted": return "Active"
        default: return raw.replacingOccurrences(of: "_", with: " ").capitalized
        }
    }
}

#Preview {
    NavigationStack { WorkspaceView(brandSlug: "paidpost-studio") }
        .environment(AppStore())
        .preferredColorScheme(.dark)
}
