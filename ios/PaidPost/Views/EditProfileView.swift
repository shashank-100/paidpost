//
//  EditProfileView.swift
//  Methods
//
//  Edit display name / bio / location and upload a profile photo.
//

import SwiftUI
import PhotosUI

struct EditProfileView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var displayName = ""
    @State private var bio = ""
    @State private var location = ""
    @State private var languages = ""
    @State private var photoItem: PhotosPickerItem?
    @State private var photoPreview: Image?
    @State private var photoData: Data?
    @State private var saving = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    photoPicker
                    field("Display name", text: $displayName, prompt: "Your public name")
                    field("Location", text: $location, prompt: "City, Country")
                    // The profile payload doesn't return current languages, so
                    // this field can't be prefilled — make clear it sets/updates
                    // rather than reflecting an (apparently empty) current value.
                    field("Add or update languages", text: $languages, prompt: "English, Spanish…")
                    bioField

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Theme.coral)
                            .multilineTextAlignment(.center)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
            }
            .scrollIndicators(.hidden)
            .background(Theme.background)
            .navigationTitle("Edit profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(Theme.textSecondary)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        Task { await save() }
                    } label: {
                        if saving {
                            ProgressView().tint(Theme.accent)
                        } else {
                            Text("Save").bold().foregroundStyle(Theme.accent)
                        }
                    }
                    .disabled(saving || displayName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            displayName = store.creatorName
            bio = store.bio
            location = store.location
        }
        .onChange(of: photoItem) {
            Task {
                guard let item = photoItem,
                      let data = try? await item.loadTransferable(type: Data.self),
                      let uiImage = UIImage(data: data) else { return }
                // Re-encode as JPEG (backend accepts jpeg/png/webp) and cap size.
                let resized = uiImage.resized(maxDimension: 1024)
                photoData = resized.jpegData(compressionQuality: 0.85)
                photoPreview = Image(uiImage: resized)
            }
        }
    }

    private var photoPicker: some View {
        PhotosPicker(selection: $photoItem, matching: .images) {
            ZStack(alignment: .bottomTrailing) {
                Group {
                    if let photoPreview {
                        photoPreview.resizable().scaledToFill()
                    } else if let urlString = store.profilePictureURL, let url = URL(string: urlString) {
                        AsyncImage(url: url) { image in
                            image.resizable().scaledToFill()
                        } placeholder: {
                            initialsCircle
                        }
                    } else {
                        initialsCircle
                    }
                }
                .frame(width: 96, height: 96)
                .clipShape(.circle)

                Image(systemName: "camera.fill")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Theme.background)
                    .padding(7)
                    .background(Theme.accent)
                    .clipShape(.circle)
            }
        }
    }

    private var initialsCircle: some View {
        ZStack {
            Circle().fill(
                LinearGradient(colors: [Theme.accent, Theme.accentDim],
                               startPoint: .topLeading, endPoint: .bottomTrailing)
            )
            Text(String(displayName.prefix(1)).uppercased())
                .font(.system(size: 34, weight: .heavy, design: .rounded))
                .foregroundStyle(Theme.background)
        }
    }

    private func field(_ label: String, text: Binding<String>, prompt: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(Theme.textSecondary)
            TextField(prompt, text: text)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(Theme.textPrimary)
                .padding(14)
                .background(Theme.surface)
                .clipShape(.rect(cornerRadius: 14))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.stroke, lineWidth: 1))
        }
    }

    private var bioField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Bio")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(Theme.textSecondary)
            TextField("Tell brands about your content…", text: $bio, axis: .vertical)
                .lineLimit(4...8)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(Theme.textPrimary)
                .padding(14)
                .background(Theme.surface)
                .clipShape(.rect(cornerRadius: 14))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.stroke, lineWidth: 1))
        }
    }

    private func save() async {
        saving = true
        errorMessage = nil
        defer { saving = false }
        do {
            try await CreatorAPI.updateProfile(
                displayName: displayName.trimmingCharacters(in: .whitespaces),
                bio: bio.isEmpty ? nil : bio,
                location: location.isEmpty ? nil : location
            )
            if let photoData {
                _ = try await CreatorAPI.uploadProfilePicture(jpegData: photoData)
            }
            // Languages are a separate endpoint; split the comma-list and save
            // when the creator entered any.
            let langs = languages
                .split(separator: ",")
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
            if !langs.isEmpty {
                try await CreatorAPI.updateLanguages(langs)
            }
            await store.loadProfile()
            dismiss()
        } catch {
            errorMessage = (error as? APIError)?.errorDescription ?? error.localizedDescription
        }
    }
}

private extension UIImage {
    func resized(maxDimension: CGFloat) -> UIImage {
        let largest = max(size.width, size.height)
        guard largest > maxDimension else { return self }
        let scale = maxDimension / largest
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
        return UIGraphicsImageRenderer(size: newSize).image { _ in
            draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
}

#Preview {
    EditProfileView()
        .environment(AppStore())
        .preferredColorScheme(.dark)
}
