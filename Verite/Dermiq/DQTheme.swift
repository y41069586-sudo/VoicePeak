import SwiftUI

// ============================================================
// MARK: — SkinFix v2 design system (MASTER PROMPT §6)
// ============================================================
//
// Warm light-linen world — a pale, warm neutral ground with white surfaces,
// warm-black ink, and ONE cool accent set against the warm ground. This file
// remains the ONLY place the v2 tokens are defined.
// (The v1 white-blue `VColor` system remains for legacy screens only.)
//
// Why warm neutral rather than the old lavender: the screen is mostly
// photographs of skin. Lavender tints skin, blue makes it sallow, grey drains
// it — a warm neutral is the one ground every skin tone sits correctly on. It
// also drops the "beauty product" read that lavender carries, which fought the
// product's own name.
//
// Why the accent is COOL on a warm ground: warm-on-warm (the cream/terracotta
// pairing) is the default everyone lands on, and it reads as decoration. The
// temperature contrast is what makes the palette look decided. It also keeps
// the accent from ever competing with skin tones in the photo.
//
// Haptics are part of the design system:
//   .rigid  → captures / commits        (Haptics.fire(.capture))
//   .soft   → stage/screen transitions  (Haptics.fire(.transition))
//   .light  → count-up ticks            (Haptics.fire(.tick))

enum DQColor {
    static let background      = Color(hex: "FAF7F1")
    static let surface         = Color(hex: "FFFFFF")
    static let surfaceElevated = Color(hex: "F3EFE6")
    static let accent          = Color(hex: "12655D")
    /// On the light ground the "bright" accent role needs the DEEPER shade for
    /// contrast — it is used for accent text and small indicators.
    static let accentBright    = Color(hex: "0C4A44")
    /// Soft accent tint for icon chips, segmented backgrounds, soft fills.
    static let accentSoft      = Color(hex: "E4EDEA")
    static let textPrimary     = Color(hex: "1C1A17")
    static let textSecondary   = Color(hex: "6E6862")
    static let deltaUp         = Color(hex: "1F9D6B")
    static let deltaDown       = Color(hex: "DE5B4E")

    /// Portal ring, scan line — a subtle same-hue sweep (CTAs are flat now).
    static let accentGradient = LinearGradient(
        colors: [accent, accentBright],
        startPoint: .topLeading, endPoint: .bottomTrailing
    )

    /// Hairline stroke on cards (derived, not a new hue).
    static let stroke = Color(hex: "1C1A17").opacity(0.10)
}

enum DQFont {
    /// Score numerals: SF Pro Rounded, heavy, monospaced digits — no layout
    /// jitter during count-ups.
    static func score(_ size: CGFloat) -> Font {
        Font.system(size: size, weight: .heavy, design: .rounded).monospacedDigit()
    }

    /// Status/technical: SF Mono (analysis labels, sub-score values).
    static func mono(_ size: CGFloat, weight: Font.Weight = .medium) -> Font {
        Font.system(size: size, weight: weight, design: .monospaced)
    }

    // Body: SF Pro Text.
    static let title     = Font.system(size: 24, weight: .bold)
    static let headline  = Font.system(size: 17, weight: .semibold)
    static let body      = Font.system(size: 15, weight: .regular)
    static let caption   = Font.system(size: 13, weight: .regular)
    static let micro     = Font.system(size: 11, weight: .medium)
}

enum DQRadius {
    static let card: CGFloat = 20
    static let sheet: CGFloat = 28
}

// ============================================================
// MARK: — Core reusable pieces
// ============================================================

/// Primary CTA: modern UMax-style button — full-width, bold white label on a
/// flat solid blue 20pt rounded rectangle with one tight shadow. No gradient,
/// no wide glow.
struct DQPrimaryButton: View {
    let title: String
    var systemImage: String? = nil
    var isEnabled: Bool = true
    let action: () -> Void

    var body: some View {
        Button {
            Haptics.fire(.selection)
            action()
        } label: {
            HStack(spacing: 8) {
                if let systemImage { Image(systemName: systemImage) }
                Text(LocalizedStringKey(title))
            }
            .font(Font.system(size: 17, weight: .bold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, minHeight: 58)
            .background(DQColor.accent,
                        in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .shadow(color: DQColor.accent.opacity(isEnabled ? 0.30 : 0), radius: 12, y: 6)
            .opacity(isEnabled ? 1 : 0.35)
        }
        .buttonStyle(PressableStyle(brightenOnPress: true))
        .disabled(!isEnabled)
    }
}

/// Diagonal light sweep for "rendering…" placeholders.
struct DQShimmer: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var phase: CGFloat = -1

    func body(content: Content) -> some View {
        content.overlay {
            if !reduceMotion {
                GeometryReader { proxy in
                    LinearGradient(
                        colors: [.clear, DQColor.accentBright.opacity(0.14), .clear],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    )
                    .frame(width: proxy.size.width * 0.7)
                    .offset(x: proxy.size.width * phase)
                    .onAppear {
                        withAnimation(.linear(duration: 1.6).repeatForever(autoreverses: false)) {
                            phase = 1.4
                        }
                    }
                }
                .allowsHitTesting(false)
            }
        }
        .clipped()
    }
}

extension View {
    func dqShimmer() -> some View { modifier(DQShimmer()) }
}

/// Standard v2 card container.
struct DQCard<Content: View>: View {
    var elevated = false
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                elevated ? DQColor.surfaceElevated : DQColor.surface,
                in: RoundedRectangle(cornerRadius: DQRadius.card, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: DQRadius.card, style: .continuous)
                    .strokeBorder(DQColor.stroke, lineWidth: 1)
            )
    }
}
