//
//  WarmupView.swift
//  PaidPost
//
//  Evidence-based warmup: add a daily niche-video URL and upload screen-time
//  screenshots for due windows. Mirrors the reference warmup screen.
//  Requires R2 keys on the backend (screenshots upload via presigned PUT).
//

import SwiftUI
import PhotosUI

struct WarmupView: View {
    let brandSlug: String

    @State private var timeline: WarmupTimelineDTO?
    @State private var loading = true
    @State private var nicheURL = ""
    @State private var busy = false
    @State private var note: String?
    @State private var shotItem: PhotosPickerItem?
    @State private var shotTask: WarmupTimelineDTO.ScreenshotTask?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                if loading {
                    ProgressView().tint(Theme.accent).frame(maxWidth: .infinity).padding(.top, 40)
                } else {
                    intro
                    nicheVideoCard
                    screenshotSection
                    if let note {
                        Text(note)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Theme.textSecondary)
                    }
                }
            }
            .padding(20)
        }
        .scrollIndicators(.hidden)
        .background(Theme.background)
        .navigationTitle("Warm-up")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .task { await load() }
        .onChange(of: shotItem) { Task { await handleScreenshot() } }
    }

    private var intro: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Warm up your account")
                .font(.system(size: 20, weight: .heavy, design: .rounded))
                .foregroundStyle(Theme.textPrimary)
            Text("Each day, watch a niche video and log it, then upload your screen-time screenshot when a window is due.")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Theme.textSecondary)
        }
    }

    private var nicheVideoCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Today's niche video", systemImage: "play.rectangle.fill")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(Theme.textPrimary)
            TextField("Paste a TikTok / Instagram / YouTube URL", text: $nicheURL)
                .keyboardType(.URL)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Theme.textPrimary)
                .padding(12)
                .background(Theme.surfaceElevated)
                .clipShape(.rect(cornerRadius: 12))
            Button {
                Task { await addURL() }
            } label: {
                Text(busy ? "Saving…" : "Log video")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Theme.background)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 11)
                    .background(canAddURL ? AnyShapeStyle(Theme.accent) : AnyShapeStyle(Theme.surfaceElevated))
                    .clipShape(.capsule)
            }
            .buttonStyle(.plain)
            .disabled(!canAddURL || busy)
        }
        .methodCard()
    }

    @ViewBuilder
    private var screenshotSection: some View {
        let tasks = timeline?.screenshotTasks ?? []
        if !tasks.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Label("Screen-time check-ins", systemImage: "camera.viewfinder")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Theme.textPrimary)
                ForEach(tasks) { task in
                    screenshotRow(task)
                }
            }
        }
    }

    private func screenshotRow(_ task: WarmupTimelineDTO.ScreenshotTask) -> some View {
        let submitted = task.status == "submitted"
        let due = task.status == "due"
        return HStack(spacing: 14) {
            Image(systemName: submitted ? "checkmark.circle.fill" : (due ? "exclamationmark.circle.fill" : "clock.fill"))
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(submitted ? Theme.accent : (due ? Theme.gold : Theme.textTertiary))
            VStack(alignment: .leading, spacing: 3) {
                Text(task.platform.capitalized)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Theme.textPrimary)
                Text(submitted ? "Submitted" : (due ? "Due now" : "Upcoming"))
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Theme.textSecondary)
            }
            Spacer()
            if due {
                PhotosPicker(selection: $shotItem, matching: .images) {
                    Text("Upload")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Theme.background)
                        .padding(.horizontal, 16).padding(.vertical, 9)
                        .background(Theme.accent).clipShape(.capsule)
                }
                .disabled(busy)
                .simultaneousGesture(TapGesture().onEnded { shotTask = task })
            }
        }
        .methodCard(padding: 14)
    }

    private var canAddURL: Bool {
        let t = nicheURL.trimmingCharacters(in: .whitespaces)
        // Require a real host, not just the "https://" prefix (a bare scheme
        // would otherwise pass and get submitted as a broken URL).
        guard let url = URL(string: t), url.scheme == "https", let host = url.host else {
            return false
        }
        return host.contains(".")
    }

    private func load() async {
        do {
            timeline = try await WorkspaceAPI.fetchWarmup(brandSlug: brandSlug)
            note = nil
        } catch {
            // Surface the failure rather than showing an empty intro silently.
            note = (error as? APIError)?.errorDescription ?? error.localizedDescription
        }
        loading = false
    }

    private func addURL() async {
        busy = true; note = nil
        defer { busy = false }
        let date = Self.todayKey()
        do {
            try await WorkspaceAPI.addWarmupVideoURL(
                brandSlug: brandSlug, activityDate: date,
                url: nicheURL.trimmingCharacters(in: .whitespaces)
            )
            nicheURL = ""
            note = "Logged. Keep it up daily."
            await load()
        } catch {
            note = (error as? APIError)?.errorDescription ?? error.localizedDescription
        }
    }

    private func handleScreenshot() async {
        guard let item = shotItem, let task = shotTask else { return }
        busy = true; note = nil
        defer { busy = false; shotItem = nil; shotTask = nil }
        do {
            guard let data = try await item.loadTransferable(type: Data.self) else { return }
            try await WorkspaceAPI.uploadWarmupScreenshot(
                brandSlug: brandSlug, platform: task.platform,
                windowIndex: task.windowIndex, imageData: data, contentType: "image/png"
            )
            note = "Screenshot uploaded — we'll verify it shortly."
            await load()
        } catch {
            note = (error as? APIError)?.errorDescription ?? error.localizedDescription
        }
    }

    /// `yyyy-MM-dd` in the current calendar — the backend keys days this way.
    private static func todayKey() -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: Date())
    }
}
