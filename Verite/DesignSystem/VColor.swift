import SwiftUI

/// Canonical color system (DESIGN_SPEC §2), carried in the committed **white-blue
/// (light)** palette. Elevation runs light-up (base is a soft blue-white; surfaces
/// step toward white). Semantic colors are tuned for contrast on white and appear
/// ONLY on honest risk flags — never decoratively.
enum VColor {
    // Backgrounds — light elevation ladder
    static let bgBase        = Color(hex: "F5F0FB") // app background, always
    static let bgSurface     = Color(hex: "FFFFFF") // first elevation (cards on base)
    static let bgElevated    = Color(hex: "F6F1FC") // second elevation (cards on cards)
    static let bgElevated2   = Color(hex: "EFE7F8") // stacked/nested cards
    static let strokeSubtle  = Color(hex: "E6DCF2") // hairline on every card
    static let strokeBright  = Color(hex: "C9B6E4") // focused/active borders

    // Brand
    static let primary       = Color(hex: "9B6BD3")
    static let primaryBright = Color(hex: "B48FDF")
    /// Legible cyan on white (spec's dark-theme value is #5AD1FF).
    static let accent        = Color(hex: "B57BD8")

    // Semantic (honest flags only)
    static let success       = Color(hex: "10A87E")
    static let warning       = Color(hex: "D9820A")
    static let danger        = Color(hex: "E24857")

    // Text
    static let textPrimary   = Color(hex: "1A1225")
    static let textSecondary = Color(hex: "6B5F7A")
    static let textTertiary  = Color(hex: "9C93AC") // captions, metadata, timestamps

    /// The signature gradient — reserved for the primary action, scan ring,
    /// score-reveal fills, and the logo mark. Never decorative.
    static let heroGradient = LinearGradient(
        colors: [primary, accent],
        startPoint: .topLeading, endPoint: .bottomTrailing
    )
}

extension Color {
    /// Create a `Color` from an "RRGGBB" (or "#RRGGBB") hex string.
    init(hex string: String) {
        var hex = string.trimmingCharacters(in: .whitespacesAndNewlines)
        if hex.hasPrefix("#") { hex.removeFirst() }
        var value: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&value)
        let r = Double((value >> 16) & 0xFF) / 255.0
        let g = Double((value >> 8) & 0xFF) / 255.0
        let b = Double(value & 0xFF) / 255.0
        self.init(.sRGB, red: r, green: g, blue: b, opacity: 1)
    }
}
