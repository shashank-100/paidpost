//
//  Theme.swift
//  Methods
//

import SwiftUI

/// Central design tokens for the Methods app.
enum Theme {
    // Backgrounds
    static let background = Color(hex: 0x0A0B0D)
    static let surface = Color(hex: 0x16181D)
    static let surfaceElevated = Color(hex: 0x1E2127)
    static let stroke = Color.white.opacity(0.08)

    // Accent — vibrant lime "money" green
    static let accent = Color(hex: 0xC6FF3D)
    static let accentDim = Color(hex: 0x9BD418)
    static let accentGlow = Color(hex: 0xC6FF3D).opacity(0.35)

    // Secondary accents
    static let electric = Color(hex: 0x5B8CFF)
    static let coral = Color(hex: 0xFF6B5B)
    static let gold = Color(hex: 0xFFD23D)

    // Text
    static let textPrimary = Color.white
    static let textSecondary = Color.white.opacity(0.6)
    static let textTertiary = Color.white.opacity(0.38)

    static let cardCorner: CGFloat = 22
}

extension Color {
    init(hex: UInt, alpha: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: alpha
        )
    }
}

extension View {
    /// Standard elevated card styling used across the app.
    func methodCard(padding: CGFloat = 18) -> some View {
        self
            .padding(padding)
            .background(Theme.surface)
            .clipShape(.rect(cornerRadius: Theme.cardCorner))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.cardCorner)
                    .stroke(Theme.stroke, lineWidth: 1)
            )
    }
}
