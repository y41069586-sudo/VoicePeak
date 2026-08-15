import SwiftUI

// ============================================================
// MARK: — SkinFix v2 design system (MASTER PROMPT §6)
// ============================================================
//
// A neutral, near-white ground with white surfaces, near-black ink, and one
// sand accent used sparingly. This file remains the ONLY place the v2
// tokens are defined. (The v1 white-blue `VColor` system remains for legacy
// screens only.)
//
// This replaced an all-over warm-beige/gold wash. The reason: no matter how
// modern the components get — borderless cards, bold type, real shadows —
// a screen where the ENTIRE canvas sits in one warm gold/cream hue reads as
// a sepia photograph before the eye even parses the layout. Warmth is real
// and belongs in the brand, but it has to live in a small set of deliberate
// places (a selection ring, a progress fill, a chip) and in the skin
// photography itself — never in the background, the card fills, or the CTA.
//
// The accent stays sand/gold in hue so the brand still reads warm at a
// glance, but it now only ever appears in small doses. CTAs are solid near-
// black with white text — contrast, not colour, is what says "primary
// action" now, which is also what keeps the accent legible as a SIGNAL
// (this is selected / this is progress) rather than as decoration repeated
// on every surface.
//
// Headings stay on SF Rounded — that choice was never the problem; the wash
// was.
//
// Haptics are part of the design system:
//   .rigid  → captures / commits        (Haptics.fire(.capture))
//   .soft   → stage/screen transitions  (Haptics.fire(.transition))
//   .light  → count-up ticks            (Haptics.fire(.tick))

enum DQColor {
    static let background      = Color(hex: "FBFAF8")
    static let surface         = Color(hex: "FFFFFF")
    static let surfaceElevated = Color(hex: "F2F0EC")
    /// Sand accent — selection rings, progress fill, chip backgrounds. Used
    /// in small doses only; never a background or CTA fill.
    static let accent          = Color(hex: "E9DEC7")
    /// One step deeper than `accent` — selection rings/borders need this to
    /// read against a white card.
    static let accentEdge      = Color(hex: "C9B387")
    /// Accent TEXT / icons on light surfaces — dark enough to clear AA.
    static let accentBright    = Color(hex: "8B764A")
    /// Soft accent tint for icon chips, segmented backgrounds, soft fills.
    static let accentSoft      = Color(hex: "E9DEC7")
    static let textPrimary     = Color(hex: "15130F")
    static let textSecondary   = Color(hex: "6E6A63")
    static let deltaUp         = Color(hex: "1F9D6B")
    static let deltaDown       = Color(hex: "DE5B4E")

    /// Kept for call sites that still reference a gradient (e.g. a scan
    /// line); a restrained same-hue sweep rather than a bright CTA gradient.
    static let accentGradient = LinearGradient(
        colors: [accent, accentEdge],
        startPoint: .topLeading, endPoint: .bottomTrailing
    )

    /// Hairline stroke — now reserved for the rare case a border is still
    /// wanted (e.g. a text field); ordinary cards use `DQCard`'s shadow
    /// instead, not this.
    static let stroke = Color(hex: "15130F").opacity(0.08)
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

/// Primary CTA: full-width bold white label on a solid near-black fill.
/// Contrast (dark on light), not the accent colour, is what reads as
/// "primary action" — this is what keeps the sand accent rare enough to
/// still mean something everywhere else it appears.
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
            .background(DQColor.textPrimary,
                        in: RoundedRectangle(cornerRadius: 26, style: .continuous))
            .shadow(color: DQColor.textPrimary.opacity(isEnabled ? 0.24 : 0), radius: 20, y: 10)
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
