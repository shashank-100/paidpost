//
//  ContractView.swift
//  Methods
//
//  Read + e-sign a campaign contract. Mirrors the reference contract screen:
//  POST applications/{id}/contract/sign { signerName }.
//

import SwiftUI

struct ContractView: View {
    @Environment(\.dismiss) private var dismiss
    let applicationId: String
    let brand: String
    /// Called after a successful signature so the parent can refresh.
    var onSigned: () -> Void = {}

    @State private var signerName = ""
    @State private var agreed = false
    @State private var signing = false
    @State private var errorMessage: String?
    @State private var done = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if done {
                        signedConfirmation
                    } else {
                        contractBody
                    }
                }
                .padding(20)
            }
            .scrollIndicators(.hidden)
            .background(Theme.background)
            .navigationTitle("Creator Agreement")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(done ? "Done" : "Cancel") { dismiss() }
                        .foregroundStyle(Theme.textSecondary)
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private var contractBody: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Agreement with \(brand)")
                .font(.system(size: 22, weight: .heavy, design: .rounded))
                .foregroundStyle(Theme.textPrimary)

            Text(Self.terms)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Theme.textSecondary)
                .lineSpacing(4)

            Toggle(isOn: $agreed) {
                Text("I have read and agree to the terms above.")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.textPrimary)
            }
            .tint(Theme.accent)

            VStack(alignment: .leading, spacing: 8) {
                Text("Full legal name (signature)")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Theme.textSecondary)
                TextField("Your full name", text: $signerName)
                    .textContentType(.name)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(Theme.textPrimary)
                    .padding(14)
                    .background(Theme.surface)
                    .clipShape(.rect(cornerRadius: 14))
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.stroke, lineWidth: 1))
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.coral)
            }

            Button {
                Task { await sign() }
            } label: {
                Group {
                    if signing {
                        ProgressView().tint(Theme.background)
                    } else {
                        Text("Sign & accept")
                            .font(.system(size: 17, weight: .bold))
                    }
                }
                .foregroundStyle(Theme.background)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(canSign ? AnyShapeStyle(Theme.accent) : AnyShapeStyle(Theme.surfaceElevated))
                .clipShape(.rect(cornerRadius: 16))
            }
            .buttonStyle(.plain)
            .disabled(!canSign || signing)
        }
    }

    private var signedConfirmation: some View {
        VStack(spacing: 18) {
            Spacer().frame(height: 40)
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 64))
                .foregroundStyle(Theme.accent)
                .shadow(color: Theme.accentGlow, radius: 20)
            Text("Contract signed")
                .font(.system(size: 24, weight: .heavy, design: .rounded))
                .foregroundStyle(Theme.textPrimary)
            Text("Signed as \(signerName). You're all set to start creating for \(brand).")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }

    private var canSign: Bool {
        agreed && signerName.trimmingCharacters(in: .whitespaces).count >= 2
    }

    private func sign() async {
        signing = true
        errorMessage = nil
        defer { signing = false }
        do {
            try await WorkspaceAPI.signContract(
                applicationId: applicationId,
                signerName: signerName.trimmingCharacters(in: .whitespaces)
            )
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            onSigned()
            withAnimation { done = true }
        } catch {
            errorMessage = (error as? APIError)?.errorDescription ?? error.localizedDescription
        }
    }

    private static let terms = """
    This Creator Services Agreement is entered into between you ("Creator") and \
    the brand for the selected campaign. By signing, you agree to:

    • Produce original content meeting the campaign brief and platform guidelines.
    • Post the agreed content from the account(s) you connect, keeping it live for \
    the campaign period.
    • Disclose paid partnerships as required by applicable advertising rules.
    • Receive the agreed compensation through the platform's payout system once \
    deliverables are verified.

    Either party may end the engagement for material breach. Your data is handled \
    per the privacy policy. This summary supplements, and does not replace, the \
    full terms provided by the brand.
    """
}

#Preview {
    ContractView(applicationId: "demo", brand: "Nova AI")
        .preferredColorScheme(.dark)
}
