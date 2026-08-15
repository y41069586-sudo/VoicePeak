import SwiftUI

// ============================================================
// MARK: — SkinFix v2 design system (MASTER PROMPT §6)
// ============================================================
//
// ONE palette, pulled from the app icon, used app-wide. This file is the
// ONLY place the v2 tokens are defined, and `RampStage` (onboarding) mirrors
// the same values — so onboarding and the app proper are the same product to
// the eye. (The v1 white-blue `VColor` system remains for legacy screens.)
//
// TWO COLOURS, and everything else is a tone of them:
//
//   1. SKIN — the icon's peach, from the pale bandage (`accent`) down
//      through the skin tone (`accentEdge`). Grounds, chips, fills, rings.
//   2. BLEMISH — the icon's coral (`accentBright`). Primary actions,
//      emphasis text, anything that has to be looked at first.
//
// The ink is NOT black. It is the same peach hue driven almost to black
// (`textPrimary`), so text sits inside the family instead of next to it.
// Pure black + a warm accent is exactly the mix this palette exists to
// remove: two unrelated temperatures on one screen, neither committed to.
//
// The only colours outside the two are `deltaUp` / `deltaDown`, and they are
// not decoration — they are the one semantic pair that has to survive being
// the same hue as everything else ("this improved" / "this got worse").
// Nothing else may introduce a hue.
//
// Headings stay on SF Rounded.
//
// Haptics are part of the design system:
//   .rigid  → captures / commits        (Haptics.fire(.capture))
//   .soft   → stage/screen transitions  (Haptics.fire(.transition))
//   .light  → count-up ticks            (Haptics.fire(.tick))

enum DQColor {
    /// Peach-white — the ground everywhere. Warm enough to belong to the
    /// icon, pale enough that white cards still lift off it.
    static let background      = Color(hex: "FBF7F3")
    static let surface         = Color(hex: "FFFFFF")
    static let surfaceElevated = Color(hex: "F3E9DE")
    /// COLOUR 1 · skin — the icon's pale bandage peach. Chips, soft fills,
    /// segmented backgrounds.
    static let accent          = Color(hex: "F5DCC0")
    /// COLOUR 1, deeper — the icon's skin tone. Selection rings, progress
    /// fills, bar fills: anywhere the pale peach would vanish on white.
    static let accentEdge      = Color(hex: "E0995F")
    /// COLOUR 2 · blemish — the icon's coral. Accent TEXT and icons on light
    /// surfaces (clears AA), and the primary CTA fill.
    static let accentBright    = Color(hex: "C15A3E")
    /// Soft accent tint for icon chips, segmented backgrounds, soft fills.
    static let accentSoft      = Color(hex: "F5DCC0")
    /// Not black — the palette's own hue at its darkest. Text and icons only.
    static let textPrimary     = Color(hex: "1E1610")
    static let textSecondary   = Color(hex: "6D5F52")
    static let deltaUp         = Color(hex: "1F9D6B")
    static let deltaDown       = Color(hex: "DE5B4E")

    /// Skin → blemish. The primary CTA fill, the scan line, and anywhere the
    /// brand needs to be a surface rather than a detail.
    static let accentGradient = LinearGradient(
        colors: [accentEdge, accentBright],
        startPoint: .topLeading, endPoint: .bottomTrailing
    )

    /// Hairline stroke — now reserved for the rare case a border is still
    /// wanted (e.g. a text field); ordinary cards use `DQCard`'s shadow
    /// instead, not this.
    static let stroke = Color(hex: "1E1610").opacity(0.08)
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

    /// Headings: SF Pro Rounded rather than the standard grotesque — the same
    /// friendlier voice the score numerals already use, now carried through
    /// titles and section heads instead of stopping at the digits.
    static let title     = Font.system(size: 24, weight: .bold, design: .rounded)
    static let headline  = Font.system(size: 17, weight: .semibold, design: .rounded)
    // Body stays SF Pro Text — rounded reads soft in short bursts, not in
    // paragraphs, and body copy is the one place the app is actually read.
    static let body      = Font.system(size: 15, weight: .regular)
    static let caption   = Font.system(size: 13, weight: .regular)
    static let micro     = Font.system(size: 11, weight: .medium)
}

enum DQRadius {
    static let card: CGFloat = 22
    static let sheet: CGFloat = 28
}

// ============================================================
// MARK: — Core reusable pieces
// ============================================================

/// Primary CTA: full-width bold white label on the brand's own skin→blemish
/// gradient. This replaced a solid near-black fill. Black won on contrast
/// and lost on everything else: the biggest shape on almost every screen was
/// the one element that belonged to no palette, so the app read as "warm
/// accent applied to a black-and-white app" rather than as one warm thing.
/// The gradient is dark enough at its coral end to carry white text, so the
/// contrast argument survives the swap.
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
            .font(Font.system(size: 17, weight: .bold, design: .rounded))
            .foregroundStyle(Color.white)
            .frame(maxWidth: .infinity, minHeight: 58)
            .background(DQColor.accentGradient,
                        in: RoundedRectangle(cornerRadius: 26, style: .continuous))
            .shadow(color: DQColor.accentBright.opacity(isEnabled ? 0.34 : 0), radius: 20, y: 10)
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

/// Standard v2 card container. White, no border — separated from the ground
/// by a soft neutral shadow only, so nothing on screen reads as a bordered
/// form field.
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
            .shadow(color: DQColor.textPrimary.opacity(0.03), radius: 2, y: 1)
            .shadow(color: DQColor.textPrimary.opacity(0.05), radius: 16, y: 8)
    }
}
