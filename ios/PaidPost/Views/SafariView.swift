//
//  SafariView.swift
//  Methods
//
//  In-app Safari sheet for external flows (Stripe Connect onboarding).
//

import SwiftUI
import SafariServices

struct SafariView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> SFSafariViewController {
        SFSafariViewController(url: url)
    }

    func updateUIViewController(_ controller: SFSafariViewController, context: Context) {}
}

/// Wraps a `URL` so it can drive a `.sheet(item:)` without a retroactive
/// `Identifiable` conformance on the stdlib type (which is fragile and
/// version-sensitive).
struct IdentifiableURL: Identifiable {
    let url: URL
    var id: String { url.absoluteString }
}
