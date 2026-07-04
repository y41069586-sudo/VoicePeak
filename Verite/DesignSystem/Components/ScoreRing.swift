import SwiftUI

/// Score Ring (DESIGN_SPEC §6.4): gradient trim over a subtle track, big Playfair
/// numeral in the center. Reveals by trimming 0→value over 1.2s with a haptic at
/// completion; idle (unrevealed) state pulses the track.
struct ScoreRing: View {
    enum Size {
        case small, medium, large

        var diameter: CGFloat {
            switch self {
            case .small: return 64
            case .medium: return 100
            case .large: return 160
            }
        }

        var lineWidth: CGFloat {
            switch self {
            case .small: return 5
            case .medium: return 7
            case .large: return 10
            }
        }
    }

    /// Normalized 0...1.
    let value: Double
    let label: Int?
    var labelKey: LocalizedStringKey? = nil
    var size: Size = .large
    var revealed: Bool = true

    private var diameter: CGFloat { size.diameter }
    private var lineWidth: CGFloat { size.lineWidth }

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var animatedValue: Double = 0
    @State private var pulse = false

    var body: some View {
        ZStack {
            Circle()
                .stroke(VColor.strokeSubtle, lineWidth: lineWidth)
                .opacity(revealed ? 1 : (pulse ? 0.5 : 0.3))

            if revealed {
                Circle()
                    .trim(from: 0, to: animatedValue.clamped01)
                    .stroke(VColor.heroGradient, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .vGlow(VColor.primary, radius: 16, opacity: 0.25)

                VStack(spacing: 2) {
                    if let label {
                        Text("\(label)%")
                            .font(.system(size: diameter * 0.25, weight: .bold, design: .default))
                            .foregroundStyle(VColor.textPrimary)
                            .monospacedDigit()
                    } else {
                        Text(percentString)
                            .font(.system(size: diameter * 0.25, weight: .bold, design: .default))
                            .foregroundStyle(VColor.textPrimary)
                            .monospacedDigit()
                    }
                    if let labelKey {
                        Text(labelKey).font(.caption2).foregroundStyle(VColor.textSecondary)
                    }
                }
            }
        }
        .frame(width: diameter, height: diameter)
        .onAppear { start() }
        .onChange(of: revealed) { _, _ in start() }
        .onChange(of: value) { _, _ in start() }
    }

    private var percentString: String {
        value.formatted(.percent.precision(.fractionLength(0)))
    }

    private func start() {
        guard revealed else {
            if !reduceMotion {
                withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) { pulse = true }
            }
            return
        }
        if reduceMotion {
            animatedValue = value
            return
        }
        withAnimation(.easeOut(duration: 1.2)) { animatedValue = value }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { Haptics.fire(.verdictReveal) }
    }
}
