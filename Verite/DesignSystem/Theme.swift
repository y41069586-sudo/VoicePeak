import SwiftUI

/// App-facing alias of the `VColor` system (DESIGN_SPEC §2). Existing feature code
/// references `Theme.*`; both names resolve to the same committed white-blue tokens,
/// so there is a single source of truth for color.
enum Theme {
    static let bgBase       = VColor.bgBase
    static let bgSurface    = VColor.bgSurface
    static let bgElevated   = VColor.bgElevated
    static let bgElevated2  = VColor.bgElevated2
    static let strokeSubtle = VColor.strokeSubtle
    static let strokeBright = VColor.strokeBright

    static let primary       = VColor.primary
    static let primaryBright = VColor.primaryBright
    static let accent        = VColor.accent

    static let success = VColor.success
    static let warning = VColor.warning
    static let danger  = VColor.danger

    static let textPrimary   = VColor.textPrimary
    static let textSecondary = VColor.textSecondary
    static let textTertiary  = VColor.textTertiary

    /// Signature gradient (= `VColor.heroGradient`). Reserved for the primary
    /// action, scan ring, score-reveal fills, and the logo mark.
    static let signature = VColor.heroGradient
    static let signatureSoft = LinearGradient(
        colors: [VColor.primary.opacity(0.85), VColor.accent.opacity(0.85)],
        startPoint: .leading, endPoint: .trailing
    )
}

// MARK: - Hex convenience (UInt32 literal form, kept for existing call sites)

extension Color {
    init(hex: UInt32, opacity: Double = 1.0) {
        let r = Double((hex >> 16) & 0xFF) / 255.0
        let g = Double((hex >> 8) & 0xFF) / 255.0
        let b = Double(hex & 0xFF) / 255.0
        self.init(.sRGB, red: r, green: g, blue: b, opacity: opacity)
    }
}

// MARK: - Reusable glow (forwards to the VShadow glow language)

extension View {
    /// Soft blue bloom on key elements (scan ring, hero, primary CTA).
    func blueGlow(_ color: Color = VColor.accent, radius: CGFloat = 20, opacity: Double = 0.35) -> some View {
        shadow(color: color.opacity(opacity), radius: radius)
    }
}
