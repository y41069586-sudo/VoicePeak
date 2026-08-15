import SwiftUI

// ============================================================
// MARK: — SkinFix v2 design system (MASTER PROMPT §6)
// ============================================================
//
// Warm linen ground (cream) with white surfaces, warm-black ink, and a modern
// coral accent. This file remains the ONLY place the v2 tokens are defined.
// (The v1 white-blue `VColor` system remains for legacy screens only.)
//
// Why warm neutral ground: the screen is mostly photographs of skin. Lavender
// tints skin, blue makes it sallow, grey drains it — a warm neutral is the
// one ground every skin tone sits correctly on. It also drops the "beauty
// product" read that lavender carries, which fought the product's own name.
//
// The accent is modern coral (hue 14°, saturation 72%, lightness 61%) —
// saturated enough to read as primary and contemporary, not desaturated like
// older skincare apps. CTAs use this accent as a gradient (135°) with white
// text for maximum legibility and a forward-looking aesthetic.
//
// The color palette balances warmth (skin tones in the ground and accent) with
// modern saturation (the coral has energy that feels current, not vintage).
// Contrast comes from saturation and the white text on the CTA, not just value.
//
// Haptics are part of the design system:
//   .rigid  → captures / commits        (Haptics.fire(.capture))
//   .soft   → stage/screen transitions  (Haptics.fire(.transition))
//   .light  → count-up ticks            (Haptics.fire(.tick))

enum DQColor {
    static let background      = Color(hex: "FBF7F2")
    static let surface         = Color(hex: "FFFFFF")
    static let surfaceElevated = Color(hex: "F5EFE8")
    /// Warm coral accent — CTAs, the portal ring, the scan line. Saturated
    /// enough to read as primary and modern, not the desaturated beige of v1.
    /// Carries white text on CTAs for maximum readability and contemporary feel.
    static let accent          = Color(hex: "E0785A")
    /// Hairline on accent surfaces and deeper form elements.
    static let accentEdge      = Color(hex: "C85E3F")
    /// The "bright" accent role for text-only elements on the ground.
    static let accentBright    = Color(hex: "B04A2C")
    /// Soft accent tint for icon chips, segmented backgrounds, soft fills.
    static let accentSoft      = Color(hex: "FBEBE3")
    static let textPrimary     = Color(hex: "1A1613")
    static let textSecondary   = Color(hex: "6E625A")
    static let deltaUp         = Color(hex: "1F9D6B")
    static let deltaDown       = Color(hex: "DE5B4E")

    /// Portal ring, scan line — a subtle same-hue sweep with the coral palette.
    static let accentGradient = LinearGradient(
        colors: [
            Color(hex: "E8886A"),
            Color(hex: "D2694A")
        ],
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

/// Primary CTA: full-width bold label on a coral gradient with white text.
/// The gradient (135°) adds depth and the white text ensures legibility.
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
            .frame(maxWidth: .infinity, minHeight: 60)
            .background(
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color(hex: "E8886A"),
                        Color(hex: "D2694A")
                    ]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                in: RoundedRectangle(cornerRadius: 26, style: .continuous)
            )
            .shadow(color: Color(hex: "C85E3F").opacity(isEnabled ? 0.32 : 0), radius: 22, y: 10)
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
