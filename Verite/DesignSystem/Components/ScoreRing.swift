import SwiftUI

/// Score Ring (DESIGN_SPEC §6.4): gradient trim over a subtle track, big Playfair
/// numeral in the center. Reveals by trimming 0→value over 1.2s with a haptic at
/// completion; idle (unrevealed) state pulses the track.
struct ScoreRing: View {
    /// Normalized 0...1.
    let value: Double
    var labelKey: LocalizedStringKey? = nil
    var diameter: CGFloat = 160
    var lineWidth: CGFloat = 10
    var revealed: Bool = true

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

                VStack(spacing: VSpace.xs) {
                    Text(percentString)
                        .font(VType.number(diameter * 0.32))
                        .foregroundStyle(VColor.textPrimary)
                        .monospacedDigit()
                    if let labelKey {
                        Text(labelKey).font(VType.caption).foregroundStyle(VColor.textSecondary)
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
