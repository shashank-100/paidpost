//
//  ProfileSetupView.swift
//  PaidPost
//
//  First-run guided profile setup shown after sign-in when the creator has no
//  display name yet. Steps: name → date of birth (18+) → location → photo.
//  Mirrors the reference profile_setup flow; writes via PATCH creator/profile.
//

import SwiftUI
import PhotosUI

struct ProfileSetupView: View {
    @Environment(AppStore.self) private var store

    private enum Step: Int, CaseIterable { case name, dob, location, photo }
    @State private var step: Step = .name

    @State private var firstName = ""
    @State private var lastName = ""
    @State private var dob = Calendar.current.date(byAdding: .year, value: -20, to: Date()) ?? Date()
    @State private var dobConfirmed = false
    @State private var location = ""
    @State private var photoItem: PhotosPickerItem?
    @State private var photoPreview: Image?
    @State private var photoData: Data?

    @State private var saving = false
    @State private var errorMessage: String?

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            VStack(spacing: 28) {
                progressBar
                Spacer()
                stepContent
                if let errorMessage {
                    Text(errorMessage)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Theme.coral)
                        .multilineTextAlignment(.center)
                }
                Spacer()
                primaryButton
            }
            .padding(.horizontal, 28)
            .padding(.vertical, 40)
        }
        .onChange(of: photoItem) {
            Task {
                guard let item = photoItem,
                      let data = try? await item.loadTransferable(type: Data.self),
                      let img = UIImage(data: data) else { return }
                let resized = img.setupResized(max: 1024)
                photoData = resized.jpegData(compressionQuality: 0.85)
                photoPreview = Image(uiImage: resized)
            }
        }
    }

    private var progressBar: some View {
        HStack(spacing: 8) {
            ForEach(Step.allCases, id: \.rawValue) { s in
                Capsule()
                    .fill(s.rawValue <= step.rawValue ? Theme.accent : Theme.surfaceElevated)
                    .frame(height: 5)
            }
        }
    }

    @ViewBuilder
    private var stepContent: some View {
        switch step {
        case .name:
            stepHeader("What's your name?", "This is how brands will see you.")
            VStack(spacing: 12) {
                setupField("First name", text: $firstName)
                setupField("Last name", text: $lastName)
            }
        case .dob:
            stepHeader("Your date of birth", "You must be 18 or older to earn on PaidPost.")
            DatePicker("", selection: $dob, in: ...Date(), displayedComponents: .date)
                .datePickerStyle(.wheel)
                .labelsHidden()
                .colorScheme(.dark)
                .onChange(of: dob) { dobConfirmed = true }
        case .location:
            stepHeader("Where are you based?", "We use this to show relevant campaigns.")
            setupField("City, Country", text: $location)
        case .photo:
            stepHeader("Add a profile photo", "Optional, but it helps you get picked.")
            PhotosPicker(selection: $photoItem, matching: .images) {
                ZStack {
                    if let photoPreview {
                        photoPreview.resizable().scaledToFill()
                    } else {
                        Circle().fill(Theme.surface)
                        Image(systemName: "camera.fill")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundStyle(Theme.textTertiary)
                    }
                }
                .frame(width: 120, height: 120)
                .clipShape(.circle)
                .overlay(Circle().stroke(Theme.stroke, lineWidth: 1))
            }
        }
    }

    private func stepHeader(_ title: String, _ subtitle: String) -> some View {
        VStack(spacing: 8) {
            Text(title)
                .font(.system(size: 26, weight: .heavy, design: .rounded))
                .foregroundStyle(Theme.textPrimary)
                .multilineTextAlignment(.center)
            Text(subtitle)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)
        }
    }

    private func setupField(_ prompt: String, text: Binding<String>) -> some View {
        TextField(prompt, text: text)
            .font(.system(size: 17, weight: .medium))
            .foregroundStyle(Theme.textPrimary)
            .multilineTextAlignment(.center)
            .padding(16)
            .background(Theme.surface)
            .clipShape(.rect(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.stroke, lineWidth: 1))
    }

    private var primaryButton: some View {
        Button {
            advance()
        } label: {
            Group {
                if saving { ProgressView().tint(Theme.background) }
                else { Text(step == .photo ? "Finish" : "Continue").font(.system(size: 17, weight: .bold)) }
            }
            .foregroundStyle(Theme.background)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 17)
            .background(canAdvance ? AnyShapeStyle(Theme.accent) : AnyShapeStyle(Theme.surfaceElevated))
            .clipShape(.rect(cornerRadius: 18))
        }
        .buttonStyle(.plain)
        .disabled(!canAdvance || saving)
    }

    private var canAdvance: Bool {
        switch step {
        case .name: return !firstName.trimmingCharacters(in: .whitespaces).isEmpty
        // Require the user to actively set their DOB (not just accept the
        // 20-years-ago default) AND be 18+, so the age gate is real.
        case .dob: return dobConfirmed && isAdult
        case .location: return !location.trimmingCharacters(in: .whitespaces).isEmpty
        case .photo: return true   // photo is optional
        }
    }

    private var isAdult: Bool {
        let years = Calendar.current.dateComponents([.year], from: dob, to: Date()).year ?? 0
        return years >= 18
    }

    private func advance() {
        errorMessage = nil
        guard step == .photo else {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                step = Step(rawValue: step.rawValue + 1) ?? .photo
            }
            return
        }
        Task { await finish() }
    }

    private func finish() async {
        saving = true
        errorMessage = nil
        defer { saving = false }
        let iso = DateFormatter.dobFormatter.string(from: dob)
        do {
            try await store.completeProfileSetup(
                firstName: firstName.trimmingCharacters(in: .whitespaces),
                lastName: lastName.trimmingCharacters(in: .whitespaces),
                location: location.trimmingCharacters(in: .whitespaces),
                dateOfBirth: iso,
                photoData: photoData
            )
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        } catch {
            errorMessage = (error as? APIError)?.errorDescription ?? error.localizedDescription
        }
    }
}

private extension DateFormatter {
    static let dobFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()
}

private extension UIImage {
    func setupResized(max dimension: CGFloat) -> UIImage {
        let largest = Swift.max(size.width, size.height)
        guard largest > dimension else { return self }
        let scale = dimension / largest
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
        return UIGraphicsImageRenderer(size: newSize).image { _ in
            draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
}

#Preview {
    ProfileSetupView()
        .environment(AppStore())
        .preferredColorScheme(.dark)
}
