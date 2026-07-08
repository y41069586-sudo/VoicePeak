import SwiftUI

// ============================================================
// MARK: — Vérité v2 design system (MASTER PROMPT §6)
// ============================================================
//
// Dark, clinical-premium. This file is the ONLY place the v2 tokens are
// defined. (The v1 white-blue `VColor` system remains in the module for the
// legacy screens but is not part of the v2 experience.)
//
// Haptics are part of the design system:
//   .rigid  → captures / commits        (Haptics.fire(.capture))
//   .soft   → stage/screen transitions  (Haptics.fire(.transition))
//   .light  → count-up ticks            (Haptics.fire(.tick))

enum DQColor {
    static let background      = Color(hex: "0A0C10")
    static let surface         = Color(hex: "12151C")
    static let surfaceElevated = Color(hex: "1A1E28")
    static let accent          = Color(hex: "4D7CFF")
    static let accentBright    = Color(hex: "7B9EFF")
    static let textPrimary     = Color(hex: "F4F6FA")
    static let textSecondary   = Color(hex: "8A93A6")
    static let deltaUp         = Color(hex: "3DDC97")
    static let deltaDown       = Color(hex: "FF6B6B")

    /// Portal ring, scan line, primary CTAs.
    static let accentGradient = LinearGradient(
        colors: [accent, accentBright],
        startPoint: .topLeading, endPoint: .bottomTrailing
    )

    /// Hairline stroke on cards (derived, not a new hue).
    static let stroke = Color(hex: "8A93A6").opacity(0.16)
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

/// Primary CTA: accent-gradient pill, 54pt, monochrome light label.
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
                Text(title)
            }
            .font(Font.system(size: 17, weight: .semibold))
            .foregroundStyle(DQColor.textPrimary)
            .frame(maxWidth: .infinity, minHeight: 54)
            .background(DQColor.accentGradient, in: Capsule())
            .shadow(color: DQColor.accent.opacity(isEnabled ? 0.35 : 0), radius: 20)
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
