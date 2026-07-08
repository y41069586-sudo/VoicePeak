import SwiftUI

// ============================================================
// MARK: — The dark onboarding stage
// ============================================================
//
// The ramp onboarding is a cinematic *dark* sequence (cold open on black,
// glowing wireframe head) while the app proper is white-blue. Nothing here
// redefines a design token — this enum only *maps* the committed VColor
// tokens onto the dark stage (deep-navy glow = `textPrimary`, accent glow =
// `primaryBright`) so there stays a single source of truth for color.

enum RampStage {
    /// Deep-navy bloom behind the head — the token, used as a surface.
    static let backdropGlow = VColor.textPrimary
    /// Accent used for glows, progress fill and selected states on dark.
    static let accent = VColor.primaryBright

    // Text ladder on the dark stage.
    static let textPrimary   = Color.white
    static let textSecondary = Color.white.opacity(0.64)
    static let textTertiary  = Color.white.opacity(0.42)

    // Surfaces on the dark stage.
    static let card     = Color.white.opacity(0.06)
    static let hairline = Color.white.opacity(0.14)

    /// Total number of conceptual screens (0–9) for the progress bar.
    static let screenCount = 10
}

/// Full-bleed backdrop: black with a deep-navy radial bloom behind the head.
struct RampBackdrop: View {
    var body: some View {
        ZStack {
            Color.black
            RadialGradient(
                colors: [RampStage.backdropGlow.opacity(0.85), .clear],
                center: UnitPoint(x: 0.5, y: 0.34),
                startRadius: 10,
                endRadius: 480
            )
        }
        .ignoresSafeArea()
    }
}

// ============================================================
// MARK: — Progress bar (thin, segmented, accent fill)
// ============================================================

struct RampProgressBar: View {
    /// Index of the current conceptual screen (0-based).
    let screenIndex: Int

    var body: some View {
        HStack(spacing: VSpace.xs) {
            ForEach(0..<RampStage.screenCount, id: \.self) { index in
                Capsule()
                    .fill(index <= screenIndex
                          ? AnyShapeStyle(RampStage.accent)
                          : AnyShapeStyle(Color.white.opacity(0.12)))
                    .frame(height: 3)
            }
        }
        .animation(VMotion.standard, value: screenIndex)
        .accessibilityElement()
        .accessibilityLabel("onboarding.progress")
        .accessibilityValue(Text(verbatim: "\(screenIndex + 1)/\(RampStage.screenCount)"))
    }
}

// ============================================================
// MARK: — Typewriter text (cold-open wordmark)
// ============================================================

struct TypewriterText: View {
    let text: String
    var perCharacter: Duration = .milliseconds(80)
    var startDelay: Duration = .zero
    let font: Font
    var color: Color = RampStage.textPrimary
    var tracking: CGFloat = 0

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var visibleCount = 0

    var body: some View {
        // Full string reserves layout; visible prefix types over it.
        Text(text)
            .font(font)
            .tracking(tracking)
            .opacity(0)
            .overlay(alignment: .leading) {
                Text(String(text.prefix(visibleCount)))
                    .font(font)
                    .tracking(tracking)
                    .foregroundStyle(color)
                    .lineLimit(1)
                    .fixedSize()
            }
            .accessibilityLabel(Text(verbatim: text))
            .task {
                if reduceMotion {
                    visibleCount = text.count
                    return
                }
                try? await Task.sleep(for: startDelay)
                for index in 1...max(text.count, 1) {
                    try? await Task.sleep(for: perCharacter)
                    guard !Task.isCancelled else { return }
                    visibleCount = index
                }
            }
    }
}

// ============================================================
// MARK: — Buttons & option cards on the dark stage
// ============================================================

/// Small text-only secondary action ("Not now").
struct RampGhostButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(VType.body)
                .foregroundStyle(RampStage.textSecondary)
                .padding(.vertical, VSpace.sm)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(PressableStyle())
    }
}

/// Large tappable quiz option card. Fills with accent when selected —
/// selection *is* the advance, so there is no checkmark bookkeeping.
struct RampOptionCard: View {
    let label: String
    var icon: String? = nil
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: VSpace.md) {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 17, weight: .medium))
                        .foregroundStyle(selected ? Color.white : RampStage.accent)
                        .frame(width: 26)
                }
                Text(label)
                    .font(VType.bodyLarge.weight(.medium))
                    .foregroundStyle(selected ? Color.white : RampStage.textPrimary)
                    .multilineTextAlignment(.leading)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, VSpace.md)
            .frame(maxWidth: .infinity, minHeight: 58, alignment: .leading)
            .background(
                selected ? AnyShapeStyle(VColor.heroGradient) : AnyShapeStyle(RampStage.card),
                in: RoundedRectangle(cornerRadius: VRadius.md, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: VRadius.md, style: .continuous)
                    .strokeBorder(selected ? RampStage.accent.opacity(0.9) : RampStage.hairline,
                                  lineWidth: 1)
            )
            .vGlow(VColor.primary, radius: 18, opacity: selected ? 0.35 : 0)
        }
        .buttonStyle(PressableStyle())
        .animation(VMotion.snappy, value: selected)
    }
}
