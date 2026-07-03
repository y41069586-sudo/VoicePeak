import SwiftUI

/// "Aesthetic Blue" — the single source of truth for Vérité's color language.
/// Tokens mirror docs/DESIGN_SPEC.md. Light-first white-and-blue: these are the
/// committed light values (`.preferredColorScheme(.light)`).
enum Theme {

    // MARK: Backgrounds (white-blue)
    static let bgBase      = Color(hex: 0xEEF3FD) // soft blue-white app background
    static let bgSurface   = Color(hex: 0xFFFFFF) // cards
    static let bgElevated  = Color(hex: 0xF6F9FF)
    static let strokeSubtle = Color(hex: 0xD7E1F3)

    // MARK: Brand
    static let primary       = Color(hex: 0x3E6BFF) // vivid blue
    static let primaryBright = Color(hex: 0x6E9BFF)
    static let accent        = Color(hex: 0x1CA3E6) // cyan-blue (legible on white)

    // MARK: Semantic (honest flags — tuned for contrast on white)
    static let success = Color(hex: 0x10A87E)
    static let warning = Color(hex: 0xD9820A)
    static let danger  = Color(hex: 0xE24857) // "this may irritate you"

    // MARK: Text
    static let textPrimary   = Color(hex: 0x0E1B34) // deep navy
    static let textSecondary = Color(hex: 0x5D6E90) // muted blue-grey

    // MARK: Signature gradient (used sparingly on hero elements + CTAs)
    static let signature = LinearGradient(
        colors: [primary, accent],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    /// Softer variant for large fills where full saturation would overpower.
    static let signatureSoft = LinearGradient(
        colors: [primary.opacity(0.85), accent.opacity(0.85)],
        startPoint: .leading,
        endPoint: .trailing
    )
}

// MARK: - Hex convenience

extension Color {
    /// Create a `Color` from a 24-bit RGB hex literal, e.g. `Color(hex: 0x3E6BFF)`.
    init(hex: UInt32, opacity: Double = 1.0) {
        let r = Double((hex >> 16) & 0xFF) / 255.0
        let g = Double((hex >> 8) & 0xFF) / 255.0
        let b = Double(hex & 0xFF) / 255.0
        self.init(.sRGB, red: r, green: g, blue: b, opacity: opacity)
    }
}

// MARK: - Reusable glow

extension View {
    /// Soft blue bloom used on key elements (scan ring, hero, primary CTA).
    func blueGlow(_ color: Color = Theme.accent, radius: CGFloat = 18, opacity: Double = 0.5) -> some View {
        shadow(color: color.opacity(opacity), radius: radius)
    }
}
