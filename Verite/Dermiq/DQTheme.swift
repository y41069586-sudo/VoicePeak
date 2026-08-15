import SwiftUI

// ============================================================
// MARK: — SkinFix v2 design system (MASTER PROMPT §6)
// ============================================================
//
// Warm linen ground (cream) with white surfaces, warm-black ink, and a bright
// honey-gold accent. This file remains the ONLY place the v2 tokens are
// defined. (The v1 white-blue `VColor` system remains for legacy screens
// only.)
//
// Why warm neutral ground: the screen is mostly photographs of skin. Lavender
// tints skin, blue makes it sallow, grey drains it — a warm neutral is the
// one ground every skin tone sits correctly on. It also drops the "beauty
// product" read that lavender carries, which fought the product's own name.
//
// The accent stays in the beige/gold family the brand asked for, but pushed
// to real saturation and lightness rather than the sepia-grey the earlier
// pass landed on: hue 38, saturation 68%, lightness 62% reads as honey or
// marigold — warm and cheerful — where the old E6D4B4 (hue 38, sat 50%,
// light 80%) was pale enough to disappear into the ground and read as
// disabled. CTAs use a two-stop gradient of this hue with warm near-black
// text: gold under white text fails contrast, gold under dark text reads
// clean at 8:1+.
//
// Typography leans into the same "cheerful" brief: headings use the rounded
// SF design (already used for the score numerals) rather than the standard
// grotesque, which softens the whole app's voice without touching layout.
//
// Haptics are part of the design system:
//   .rigid  → captures / commits        (Haptics.fire(.capture))
//   .soft   → stage/screen transitions  (Haptics.fire(.transition))
//   .light  → count-up ticks            (Haptics.fire(.tick))

enum DQColor {
    static let background      = Color(hex: "FFFBF3")
    static let surface         = Color(hex: "FFFFFF")
    static let surfaceElevated = Color(hex: "FBF2DE")
    /// Honey-gold accent — CTAs, the portal ring, the scan line. Bright and
    /// saturated so it reads as primary and cheerful, not the sepia-pale
    /// beige of v1 that read as disabled.
    static let accent          = Color(hex: "E3A855")
    /// Hairline on every filled accent surface — one step darker than the
    /// fill so a control still reads as bounded on a light gold field.
    static let accentEdge      = Color(hex: "C48A3A")
    /// Accent TEXT on the pale ground — deliberately far darker than
    /// `accent` so it clears AA at roughly 6.5:1, where the fill itself
    /// would be close to invisible as text.
    static let accentBright    = Color(hex: "8A5A1D")
    /// Soft accent tint for icon chips, segmented backgrounds, soft fills.
    static let accentSoft      = Color(hex: "FBEDD4")
    static let textPrimary     = Color(hex: "211A12")
    static let textSecondary   = Color(hex: "6E6053")
    static let deltaUp         = Color(hex: "1F9D6B")
    static let deltaDown       = Color(hex: "DE5B4E")

    /// Portal ring, scan line — a same-hue sweep across the honey gradient.
    static let accentGradient = LinearGradient(
        colors: [
            Color(hex: "F0C170"),
            Color(hex: "DCA047")
        ],
        startPoint: .topLeading, endPoint: .bottomTrailing
    )

    /// Hairline stroke on cards (derived, not a new hue).
    static let stroke = Color(hex: "211A12").opacity(0.09)
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
    /// 22 rather than 20 — a touch softer, matched to the friendlier type.
    static let card: CGFloat = 22
    static let sheet: CGFloat = 28
}

// ============================================================
// MARK: — Core reusable pieces
// ============================================================

/// Primary CTA: full-width bold label on a honey-gold gradient with warm
/// near-black text. The gradient (135°) adds depth; dark text (not white)
/// is what keeps a gold fill legible.
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
            .foregroundStyle(DQColor.textPrimary)
            .frame(maxWidth: .infinity, minHeight: 60)
            .background(
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color(hex: "F0C170"),
                        Color(hex: "DCA047")
                    ]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                in: RoundedRectangle(cornerRadius: 26, style: .continuous)
            )
            .shadow(color: Color(hex: "C48A3A").opacity(isEnabled ? 0.34 : 0), radius: 22, y: 10)
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

/// Standard v2 card container. A soft warm-tinted shadow replaces a flat
/// stroke-only card — it is what makes cards read as "lifted" rather than
/// just outlined, which is part of the same cheerful, less flat brief.
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
            .shadow(color: Color(hex: "211A12").opacity(0.05), radius: 14, y: 6)
    }
}
