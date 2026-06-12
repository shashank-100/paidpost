//
//  UploadVideosView.swift
//  PaidPost
//
//  Slot-based audition-video upload for a campaign: pick a video → presigned
//  R2 PUT → save slot → submit for AI screening. Mirrors 8x-mobile's upload
//  screen. Requires R2 keys on the backend.
//

import SwiftUI
import PhotosUI

struct UploadVideosView: View {
    let brandSlug: String

    @Environment(\.dismiss) private var dismiss
    @State private var slots: [CreatorVideosDTO.VideoSlot] = []
    @State private var requiredCount = 3
    @State private var maxCount = 10
    @State private var loading = true
    @State private var uploadingSlot: Int?
    @State private var pickerItem: PhotosPickerItem?
    @State private var targetSlot = 1
    @State private var errorMessage: String?
    @State private var submitting = false
    @State private var submittedStatus: String?

    private var uploadedCount: Int { slots.count }
    private var canSubmit: Bool { uploadedCount >= 1 && submittedStatus == nil }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header
                ForEach(1...requiredCount, id: \.self) { slot in
                    slotRow(slot)
                }
                if let errorMessage {
                    Text(errorMessage)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Theme.coral)
                }
                submitButton
            }
            .padding(20)
        }
        .scrollIndicators(.hidden)
        .background(Theme.background)
        .navigationTitle("Audition videos")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .task { await load() }
        .onChange(of: pickerItem) {
            Task { await handlePicked() }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Upload \(requiredCount) short videos")
                .font(.system(size: 20, weight: .heavy, design: .rounded))
                .foregroundStyle(Theme.textPrimary)
            Text("These are reviewed before you're approved to post. \(uploadedCount)/\(requiredCount) uploaded.")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Theme.textSecondary)
        }
    }

    private func slotRow(_ slot: Int) -> some View {
        let existing = slots.first { $0.slotNumber == slot }
        let isUploading = uploadingSlot == slot
        return HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill((existing != nil ? Theme.accent : Theme.surfaceElevated).opacity(existing != nil ? 0.18 : 1))
                if isUploading {
                    ProgressView().tint(Theme.accent)
                } else {
                    Image(systemName: existing != nil ? "checkmark.circle.fill" : "video.badge.plus")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(existing != nil ? Theme.accent : Theme.textTertiary)
                }
            }
            .frame(width: 50, height: 50)

            VStack(alignment: .leading, spacing: 3) {
                Text("Video \(slot)")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Theme.textPrimary)
                Text(existing != nil ? "Uploaded" : (isUploading ? "Uploading…" : "Tap to choose"))
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(existing != nil ? Theme.accent : Theme.textSecondary)
            }
            Spacer()
            PhotosPicker(selection: $pickerItem, matching: .videos) {
                Text(existing != nil ? "Replace" : "Choose")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Theme.background)
                    .padding(.horizontal, 16).padding(.vertical, 9)
                    .background(Theme.accent)
                    .clipShape(.capsule)
            }
            .disabled(isUploading || submitting)
            .simultaneousGesture(TapGesture().onEnded { targetSlot = slot })
        }
        .methodCard(padding: 14)
    }

    @ViewBuilder
    private var submitButton: some View {
        if let status = submittedStatus {
            Label(status == "pending" ? "Submitted for review" : "Already submitted",
                  systemImage: "checkmark.seal.fill")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(Theme.accent)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
        } else {
            Button {
                Task { await submit() }
            } label: {
                Group {
                    if submitting { ProgressView().tint(Theme.background) }
                    else { Text("Submit for review").font(.system(size: 17, weight: .bold)) }
                }
                .foregroundStyle(Theme.background)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(canSubmit ? AnyShapeStyle(Theme.accent) : AnyShapeStyle(Theme.surfaceElevated))
                .clipShape(.rect(cornerRadius: 16))
            }
            .buttonStyle(.plain)
            .disabled(!canSubmit || submitting)
        }
    }

    private func load() async {
        if let data = try? await WorkspaceAPI.fetchVideos(brandSlug: brandSlug) {
            slots = data.videos
            requiredCount = data.requiredCount ?? 3
            maxCount = data.maxCount ?? 10
        }
        loading = false
    }

    private func handlePicked() async {
        guard let item = pickerItem else { return }
        errorMessage = nil
        uploadingSlot = targetSlot
        defer { uploadingSlot = nil; pickerItem = nil }
        do {
            guard let data = try await item.loadTransferable(type: Data.self) else {
                errorMessage = "Couldn't read that video."; return
            }
            _ = try await WorkspaceAPI.uploadVideo(
                brandSlug: brandSlug, slotNumber: targetSlot, fileData: data, mimeType: "video/mp4"
            )
            await load()
        } catch {
            errorMessage = (error as? APIError)?.errorDescription ?? error.localizedDescription
        }
    }

    private func submit() async {
        submitting = true
        errorMessage = nil
        defer { submitting = false }
        do {
            submittedStatus = try await WorkspaceAPI.submitApplication(brandSlug: brandSlug) ?? "pending"
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        } catch {
            errorMessage = (error as? APIError)?.errorDescription ?? error.localizedDescription
        }
    }
}
