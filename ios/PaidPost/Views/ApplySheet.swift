//
//  ApplySheet.swift
//  Methods
//

import SwiftUI

/// Confirmation sheet shown when applying to a Method.
struct ApplySheet: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let method: Method

    @State private var submitted = false
    @State private var submitting = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 0) {
            if submitted {
                successView
            } else {
                formView
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 20)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.background)
    }

    private var formView: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Ready to earn?")
                .font(.system(size: 24, weight: .heavy, design: .rounded))
                .foregroundStyle(Theme.textPrimary)

            VStack(alignment: .leading, spacing: 14) {
                step(number: 1, text: "Record a \(method.lengthLabel) video for \(method.brand)")
                step(number: 2, text: "Post it to your socials with the hook")
                step(number: 3, text: "Get $\(Int(method.payPerPost)) paid out instantly")
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.coral)
            }

            Spacer()

            Button {
                Task { await submit() }
            } label: {
                Group {
                    if submitting {
                        ProgressView().tint(Theme.background)
                    } else {
                        Text("Submit application").font(.system(size: 17, weight: .bold))
                    }
                }
                .foregroundStyle(Theme.background)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 17)
                .background(Theme.accent)
                .clipShape(.rect(cornerRadius: 18))
            }
            .buttonStyle(.plain)
            .disabled(submitting)
            .padding(.bottom, 12)
        }
    }

    /// Persists the application and only shows the success screen once the
    /// backend confirms — a failure surfaces an error instead of a fake "You're in!".
    private func submit() async {
        submitting = true
        errorMessage = nil
        defer { submitting = false }
        let ok = await store.apply(to: method)
        guard ok else {
            errorMessage = store.authError ?? "Couldn't submit your application. Try again."
            return
        }
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
            submitted = true
        }
    }

    private func step(number: Int, text: String) -> some View {
        HStack(spacing: 12) {
            Text("\(number)")
                .font(.system(size: 15, weight: .heavy, design: .rounded))
                .foregroundStyle(Theme.accent)
                .frame(width: 30, height: 30)
                .background(Theme.accent.opacity(0.15))
                .clipShape(.circle)
            Text(text)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(Theme.textPrimary)
            Spacer()
        }
    }

    private var successView: some View {
        VStack(spacing: 18) {
            Spacer()
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(Theme.accent)
                .shadow(color: Theme.accentGlow, radius: 20)
            Text("You're in!")
                .font(.system(size: 26, weight: .heavy, design: .rounded))
                .foregroundStyle(Theme.textPrimary)
            Text("We'll review your application and notify you when you're approved to post.")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)
            Spacer()
            Button {
                dismiss()
            } label: {
                Text("Done")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(Theme.background)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 17)
                    .background(Theme.accent)
                    .clipShape(.rect(cornerRadius: 18))
            }
            .buttonStyle(.plain)
            .padding(.bottom, 12)
        }
    }
}

#Preview {
    ApplySheet(method: SampleData.methods[0])
        .environment(AppStore())
        .preferredColorScheme(.dark)
}
