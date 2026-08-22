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
    static let background      = Color.white
    static let surface         = Color(hex: "FFFFFF")
    static let surfaceElevated = Color(hex: "F8F2EC")
    /// COLOUR 1 · skin — the pale bandage peach. Chips, soft fills,
    /// segmented backgrounds.
    static let accent          = Color(hex: "FBE0CB")
    /// THE brand orange. Selection rings, progress fills, bar fills:
    /// anywhere the pale peach would vanish on white. Kept identical to
    /// `RampStage.accentEdge` — the app and its onboarding are one product,
    /// and the user meets this colour on a button 26 times before they ever
    /// reach the app proper.
    static let accentEdge      = Color(hex: "F5883F")
    /// The same orange taken dark enough to clear AA as TEXT on white.
    /// Accent text and small icons on light surfaces — never a fill behind
    /// white text.
    static let accentBright    = Color(hex: "B45718")
    /// Soft accent tint for icon chips, segmented backgrounds, soft fills.
    static let accentSoft      = Color(hex: "FDF1E8")
    /// Not black — the palette's own hue at its darkest. Text and icons only.
    static let textPrimary     = Color(hex: "1E1610")
    static let textSecondary   = Color(hex: "6D5F52")
    static let deltaUp         = Color(hex: "1F9D6B")
    static let deltaDown       = Color(hex: "DE5B4E")

    /// The brand sweep — the primary CTA fill, the scan line, and anywhere
    /// the brand needs to be a surface rather than a detail. Horizontal, not
    /// diagonal: on a wide pill a diagonal puts the darkest point in one
    /// corner, so the top edge and the bottom edge are different colours and
    /// the shape stops reading as flat.
    static let accentGradient = LinearGradient(
        colors: [Color(hex: "EE7B32"), Color(hex: "F9A55C")],
        startPoint: .leading, endPoint: .trailing
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

/// Primary CTA: a full-width pill, bold white label, on the brand's orange
/// sweep. Kept in lockstep with `RampPrimaryButton` — shape, height, shadow
/// and disabled treatment — so the button that carried the user through
/// onboarding is the same object once they are inside the app. See the notes
/// there on the disabled colour and on the contrast trade-off.
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
            .foregroundStyle(isEnabled ? Color.white : DQColor.textSecondary.opacity(0.55))
            .frame(maxWidth: .infinity, minHeight: 58)
            .background {
                Capsule().fill(isEnabled ? AnyShapeStyle(DQColor.accentGradient)
                                         : AnyShapeStyle(DQColor.accentSoft))
            }
            // Matches RampPrimaryButton — see the note there on why the
            // coloured shadow is this restrained.
            .shadow(color: DQColor.accentEdge.opacity(isEnabled ? 0.34 : 0), radius: 16, y: 8)
        }
        .buttonStyle(PressableStyle(brightenOnPress: true))
        .disabled(!isEnabled)
        .animation(VMotion.gentle, value: isEnabled)
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
