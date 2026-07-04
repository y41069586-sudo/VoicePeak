import SwiftUI

/// Elevation via tinted shadows (DESIGN_SPEC §4). Dual shadow — a soft blue
/// ambient lift + a soft contact shadow — is what makes cards feel lifted rather
/// than pasted on. Contact shadow uses navy (not black) so it stays gentle on the
/// white-blue ground.
enum VShadow {
    static func card(_ view: some View) -> some View {
        view.modifier(VCardShadow())
    }
    static func glow(_ view: some View, color: Color = VColor.accent) -> some View {
        view.shadow(color: color.opacity(0.30), radius: 24, x: 0, y: 0)
    }
}

struct VCardShadow: ViewModifier {
    func body(content: Content) -> some View {
        content
            .shadow(color: VColor.primary.opacity(0.10), radius: 20, x: 0, y: 8) // ambient blue lift
            .shadow(color: VColor.textPrimary.opacity(0.08), radius: 6, x: 0, y: 2) // soft contact
    }
}

extension View {
    /// Standard card elevation (every card gets this).
    func vCardShadow() -> some View { modifier(VCardShadow()) }

    /// Additive glow for active/verified/on-target elements only.
    func vGlow(_ color: Color = VColor.accent, radius: CGFloat = 24, opacity: Double = 0.30) -> some View {
        shadow(color: color.opacity(opacity), radius: radius, x: 0, y: 0)
    }
}
