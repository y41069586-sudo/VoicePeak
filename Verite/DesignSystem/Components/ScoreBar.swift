import SwiftUI

/// Horizontal fill bar for per-attribute readouts. The fill animates from 0 to
/// `value` on appear (precomputed target — no per-frame work) and honors Reduce
/// Motion by snapping to the final value.
struct ScoreBar: View {
    let labelKey: LocalizedStringKey
    /// Normalized 0...1.
    let value: Double
    var tone: PillTag.Tone = .info

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var animatedValue: Double = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(labelKey)
                    .font(.subheadline)
                    .foregroundStyle(Theme.textSecondary)
                Spacer()
                Text(percentString)
                    .font(Typography.number(15))
                    .foregroundStyle(Theme.textPrimary)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Theme.strokeSubtle.opacity(0.6))
                    Capsule()
                        .fill(fillColor)
                        .frame(width: geo.size.width * animatedValue.clamped01)
                }
            }
            .frame(height: 8)
        }
        .onAppear {
            if reduceMotion {
                animatedValue = value
            } else {
                withAnimation(Motion.springSoft) { animatedValue = value }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityValue(percentString)
    }

    private var percentString: String {
        value.formatted(.percent.precision(.fractionLength(0)))
    }

    private var fillColor: Color {
        switch tone {
        case .neutral: return Theme.textSecondary
        case .info:    return Theme.accent
        case .success: return Theme.success
        case .warning: return Theme.warning
        case .danger:  return Theme.danger
        }
    }
}

extension Double {
    /// Clamp to the unit interval — used everywhere a normalized score is drawn.
    var clamped01: Double { Swift.min(1, Swift.max(0, self)) }
}
