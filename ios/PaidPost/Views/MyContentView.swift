//
//  MyContentView.swift
//  Methods
//
//  Posts the creator made for a campaign: views, earnings owed, ad-code entry,
//  and a manual platform sync. Backs onto /mobile/creator/posts*.
//

import SwiftUI

struct MyContentView: View {
    let brandSlug: String
    let org: WorkspaceDTO.Org

    @State private var posts: [CreatorPostDTO] = []
    @State private var loading = true
    @State private var loadError: String?
    @State private var syncing = false
    @State private var syncNote: String?
    @State private var adCodeTarget: CreatorPostDTO?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                syncBar
                if let syncNote {
                    Text(syncNote)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Theme.textSecondary)
                }
                if loading {
                    ProgressView().tint(Theme.accent).frame(maxWidth: .infinity).padding(.top, 40)
                } else if let loadError, posts.isEmpty {
                    errorState(loadError)
                } else if posts.isEmpty {
                    emptyState
                } else {
                    ForEach(posts) { post in
                        PostCard(post: post) { adCodeTarget = post }
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 40)
        }
        .scrollIndicators(.hidden)
        .background(Theme.background)
        .navigationTitle("My content")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .task { await load() }
        .refreshable { await load() }
        .sheet(item: $adCodeTarget) { post in
            AdCodeSheet(post: post, brandSlug: brandSlug) { await load() }
        }
    }

    private func load() async {
        do {
            let result = try await WorkspaceAPI.fetchPosts(brandSlug: brandSlug)
            posts = result.posts
            loadError = nil
        } catch {
            // Don't let a network failure look like "no posts yet".
            loadError = (error as? APIError)?.errorDescription ?? error.localizedDescription
        }
        loading = false
    }

    private var syncBar: some View {
        HStack(spacing: 10) {
            ForEach(["tiktok", "instagram", "youtube"], id: \.self) { platform in
                Button {
                    Task { await sync(platform) }
                } label: {
                    Text(platform.capitalized)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Theme.accent)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Theme.accent.opacity(0.1))
                        .clipShape(.rect(cornerRadius: 12))
                }
                .disabled(syncing)
            }
        }
    }

    private func sync(_ platform: String) async {
        syncing = true
        syncNote = nil
        defer { syncing = false }
        do {
            _ = try await WorkspaceAPI.syncPosts(brandSlug: brandSlug, platform: platform)
            syncNote = "Syncing \(platform.capitalized)… pull to refresh in a moment."
        } catch let APIError.server(status, message) {
            syncNote = status == 429 ? "Please wait before syncing again." : (message ?? "Sync failed.")
        } catch {
            syncNote = "Sync failed — check your connection."
        }
    }

    private func errorState(_ message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "wifi.exclamationmark")
                .font(.system(size: 36, weight: .light))
                .foregroundStyle(Theme.textTertiary)
            Text("Couldn't load your posts")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(Theme.textPrimary)
            Text(message)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)
            Button("Try again") { Task { await load() } }
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(Theme.accent)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .padding(.horizontal, 30)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "video.slash.fill")
                .font(.system(size: 36, weight: .light))
                .foregroundStyle(Theme.textTertiary)
            Text("No posts yet")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(Theme.textPrimary)
            Text("Post your campaign content, then sync a platform to pull it in.")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .padding(.horizontal, 30)
    }
}

private struct PostCard: View {
    let post: CreatorPostDTO
    let onAddCode: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: platformIcon)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Theme.accent)
                Text((post.platform ?? "post").capitalized)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Theme.textPrimary)
                Spacer()
                if let owed = post.total_owed_cents, owed > 0 {
                    // Format cents as dollars-and-cents — integer division would
                    // silently drop the cents (e.g. 1599¢ → "$15" not "$15.99").
                    Text(String(format: "$%.2f owed", Double(owed) / 100))
                        .font(.system(size: 13, weight: .heavy, design: .rounded))
                        .foregroundStyle(Theme.accent)
                }
            }

            if let caption = post.caption, !caption.isEmpty {
                Text(caption)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Theme.textSecondary)
                    .lineLimit(2)
            }

            HStack(spacing: 16) {
                metric("eye.fill", post.latest_views ?? 0)
                Spacer()
                if let code = post.ad_code, !code.isEmpty {
                    Label(code, systemImage: "tag.fill")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Theme.textSecondary)
                } else {
                    Button(action: onAddCode) {
                        Label("Add ad code", systemImage: "plus.circle.fill")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(Theme.accent)
                    }
                }
            }
        }
        .methodCard(padding: 14)
    }

    private func metric(_ icon: String, _ value: Int) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon).font(.system(size: 11, weight: .bold))
            Text(value.shortFormatted).font(.system(size: 12, weight: .semibold))
        }
        .foregroundStyle(Theme.textTertiary)
    }

    private var platformIcon: String {
        switch post.platform {
        case "tiktok": return "music.note"
        case "instagram": return "camera.fill"
        case "youtube": return "play.rectangle.fill"
        default: return "video.fill"
        }
    }
}

private struct AdCodeSheet: View {
    @Environment(\.dismiss) private var dismiss
    let post: CreatorPostDTO
    let brandSlug: String
    var onSaved: () async -> Void

    @State private var code = ""
    @State private var saving = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                Text("Add the brand's ad code to this post so views count toward payment.")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Theme.textSecondary)
                TextField("Ad code", text: $code)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(Theme.textPrimary)
                    .padding(14)
                    .background(Theme.surface)
                    .clipShape(.rect(cornerRadius: 14))
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.stroke, lineWidth: 1))
                if let errorMessage {
                    Text(errorMessage)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Theme.coral)
                }
                Spacer()
            }
            .padding(20)
            .background(Theme.background)
            .navigationTitle("Ad code")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }.foregroundStyle(Theme.textSecondary)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { Task { await save() } }
                        .bold().foregroundStyle(Theme.accent)
                        .disabled(saving || code.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private func save() async {
        saving = true
        errorMessage = nil
        defer { saving = false }
        do {
            try await WorkspaceAPI.setAdCode(
                postId: post.id, brandSlug: brandSlug,
                adCode: code.trimmingCharacters(in: .whitespaces)
            )
            await onSaved()
            dismiss()
        } catch {
            errorMessage = (error as? APIError)?.errorDescription ?? error.localizedDescription
        }
    }
}
