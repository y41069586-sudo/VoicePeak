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
// The accent is a DEEPER SHADE OF THE GROUND, not a second hue: the app is
// tonal beige throughout, and the only high-contrast element on screen is the
// warm near-black type. An earlier version used a teal accent for temperature
// contrast; on full-width CTAs that read as a green app sitting on beige,
// which is not what this is. Contrast now comes from value, not hue — so the
// one saturated thing on screen is the skin photograph itself.
//
// Tonal does NOT mean desaturated, and it does not mean dark. Two earlier
// passes got this wrong in opposite directions: one held the accent at 27%
// saturation, which on a full-width CTA reads as khaki, and the correction
// pushed saturation up while keeping the value mid-range, which reads as
// brown. The accent is now a genuinely LIGHT beige — 80% lightness at 50%
// saturation, hue 38°. The neutrals carry a little of that warmth too (13%
// saturation rather than 6%), because a truly neutral grey next to sand is
// what made the screen look grey.
//
// The cost of a pale fill is that it barely separates from the ground (1.4:1),
// so a fill alone no longer says "button". Every filled accent surface takes
// `accentEdge` as a hairline — that plus the drop shadow is what identifies
// the control; the fill is decoration.
//
// Consequence to keep in mind when adding UI: a beige CTA cannot carry white
// text. Labels on `accent` are `textPrimary`. Accent TEXT uses `accentBright`,
// which is deliberately far darker than `accent` for exactly this reason.
//
// Haptics are part of the design system:
//   .rigid  → captures / commits        (Haptics.fire(.capture))
//   .soft   → stage/screen transitions  (Haptics.fire(.transition))
//   .light  → count-up ticks            (Haptics.fire(.tick))

enum DQColor {
    static let background      = Color(hex: "FAF7F1")
    static let surface         = Color(hex: "FFFFFF")
    static let surfaceElevated = Color(hex: "F6F0E3")
    /// Light beige — CTAs, the portal ring, the scan line. Carries ink, not
    /// white: warm near-black reads at 11.9:1 here, white at 1.7:1.
    static let accent          = Color(hex: "E6D4B4")
    /// Hairline on every filled accent surface. The fill itself is only 1.4:1
    /// against the ground, which is not enough to bound a control on its own.
    static let accentEdge      = Color(hex: "BCA070")
    /// The "bright" accent role is accent TEXT on the pale ground, so it needs
    /// to be far DARKER than `accent` — this passes AA at 5.5:1, where
    /// `accent` itself would only reach 1.4:1 and be invisible.
    static let accentBright    = Color(hex: "7D5F33")
    /// Soft accent tint for icon chips, segmented backgrounds, soft fills.
    static let accentSoft      = Color(hex: "F5EBD8")
    static let textPrimary     = Color(hex: "1C1A17")
    static let textSecondary   = Color(hex: "6B6053")
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
            // Ink, not white — white on the beige CTA is 1.7:1 and unreadable.
            .foregroundStyle(DQColor.textPrimary)
            .frame(maxWidth: .infinity, minHeight: 58)
            .background(DQColor.accent,
                        in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            // The pale fill needs the edge to read as a control at all.
            .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(DQColor.accentEdge, lineWidth: 1.5))
            .shadow(color: Color(hex: "1C1A17").opacity(isEnabled ? 0.16 : 0), radius: 12, y: 6)
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
