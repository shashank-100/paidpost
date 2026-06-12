//
//  SignInView.swift
//  Methods
//
//  Passwordless email OTP sign-in.
//

import SwiftUI

struct SignInView: View {
    @Environment(AppStore.self) private var store

    private enum Step { case email, code }
    @State private var step: Step = .email
    @State private var email = ""
    @State private var code = ""
    @FocusState private var focused: Bool

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            VStack(spacing: 28) {
                Spacer()

                VStack(spacing: 12) {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 44, weight: .bold))
                        .foregroundStyle(Theme.accent)
                        .shadow(color: Theme.accentGlow, radius: 20)
                    Text(step == .email ? "Sign in to PaidPost" : "Enter your code")
                        .font(.system(size: 26, weight: .heavy, design: .rounded))
                        .foregroundStyle(Theme.textPrimary)
                    Text(step == .email
                         ? "We'll email you a 6-digit code."
                         : "Sent to \(email)")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(Theme.textSecondary)
                        .multilineTextAlignment(.center)
                }

                if step == .email {
                    emailField
                } else {
                    codeField
                }

                if let err = store.authError {
                    Text(err)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Theme.coral)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }

                primaryButton

                if step == .code {
                    Button("Use a different email") {
                        step = .email; code = ""; store.authError = nil
                    }
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.textTertiary)
                }

                Spacer()
            }
            .padding(.horizontal, 28)
        }
        .onAppear { focused = true }
    }

    private var emailField: some View {
        TextField("you@email.com", text: $email)
            .keyboardType(.emailAddress)
            .textContentType(.emailAddress)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .focused($focused)
            .font(.system(size: 17, weight: .medium))
            .foregroundStyle(Theme.textPrimary)
            .padding(16)
            .background(Theme.surface)
            .clipShape(.rect(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.stroke, lineWidth: 1))
    }

    private var codeField: some View {
        TextField("123456", text: $code)
            .keyboardType(.numberPad)
            .textContentType(.oneTimeCode)
            .focused($focused)
            .font(.system(size: 24, weight: .bold, design: .rounded))
            .multilineTextAlignment(.center)
            .foregroundStyle(Theme.textPrimary)
            .padding(16)
            .background(Theme.surface)
            .clipShape(.rect(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.stroke, lineWidth: 1))
    }

    private var primaryButton: some View {
        Button {
            Task { await handlePrimary() }
        } label: {
            HStack(spacing: 8) {
                if store.authInProgress {
                    ProgressView().tint(Theme.background)
                } else {
                    Text(step == .email ? "Send code" : "Verify")
                        .font(.system(size: 17, weight: .bold))
                }
            }
            .foregroundStyle(Theme.background)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 17)
            .background(canSubmit ? AnyShapeStyle(Theme.accent) : AnyShapeStyle(Theme.surfaceElevated))
            .clipShape(.rect(cornerRadius: 16))
        }
        .buttonStyle(.plain)
        .disabled(!canSubmit || store.authInProgress)
    }

    private var canSubmit: Bool {
        step == .email ? email.contains("@") && email.contains(".") : code.count >= 6
    }

    private func handlePrimary() async {
        if step == .email {
            if await store.sendSignInCode(email: email.trimmingCharacters(in: .whitespaces)) {
                step = .code
                focused = true
            }
        } else {
            _ = await store.verifySignInCode(
                email: email.trimmingCharacters(in: .whitespaces),
                code: code.trimmingCharacters(in: .whitespaces)
            )
        }
    }
}

#Preview {
    SignInView()
        .environment(AppStore())
        .preferredColorScheme(.dark)
}
