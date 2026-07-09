import SwiftUI

// ============================================================
// MARK: — Screen 0: Opening
// ============================================================

/// A quiet cold open. The orb glows into place (staged by the container), the
/// wordmark and a serif promise fade up, and a single calm CTA waits. No
/// terminal, no sweep — stillness is the first impression.
struct RampBootScreen: View {
    let onAdvance: () -> Void

    @State private var shown = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer().frame(height: VSpace.xxl)
            Text(verbatim: "VÉRITÉ")
                .font(VType.micro)
                .tracking(6)
                .foregroundStyle(RampStage.accentDeep)
                .opacity(shown ? 1 : 0)

            Spacer() // orb occupies the upper-middle (staged by the container)

            VStack(spacing: VSpace.md) {
                Text("Your skin,\ntold honestly.")
                    .font(RampStage.serif(34, italic: true))
                    .foregroundStyle(RampStage.ink)
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
                Text("A quiet, on-device reading of your complexion.")
                    .font(VType.body)
                    .foregroundStyle(RampStage.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, VSpace.xl)
            .opacity(shown ? 1 : 0)
            .offset(y: shown ? 0 : 12)

            Spacer()

            RampPrimaryButton(title: "Begin") { onAdvance() }
                .padding(.horizontal, VSpace.lg)
                .opacity(shown ? 1 : 0)
            Spacer().frame(height: VSpace.xxl)
        }
        .task {
            try? await Task.sleep(for: .milliseconds(200))
            withAnimation(.easeOut(duration: 1.1)) { shown = true }
        }
    }
}

// ============================================================
// MARK: — Screen 1: The Number (curiosity, calmly)
// ============================================================

struct RampNumberScreen: View {
    let onAdvance: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            Spacer()

            VStack(spacing: VSpace.md) {
                Text("Every complexion\nhas a number.")
                    .font(RampStage.serif(32, italic: true))
                    .foregroundStyle(RampStage.ink)
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
                    .vStaggeredAppear(index: 0)
                Text("Most people never learn theirs. Let's find yours — honestly, and only for you.")
                    .font(VType.bodyLarge)
                    .foregroundStyle(RampStage.textSecondary)
                    .multilineTextAlignment(.center)
                    .vStaggeredAppear(index: 1)
            }
            .padding(.horizontal, VSpace.xl)

            Spacer()

            RampPrimaryButton(title: "Continue") { onAdvance() }
                .padding(.horizontal, VSpace.lg)
            Spacer().frame(height: VSpace.xxl)
        }
    }
}

// ============================================================
// MARK: — Screen 2: The Split (what 14 days moves)
// ============================================================

/// Proof you make with your own thumb — but calm. Dragging the slider climbs
/// the metric bars from "day 1" to "day 14"; the orb glows a touch brighter as
/// you go. Interactive, quiet, no morphing wireframe.
struct RampSplitScreen: View {
    let onAdvance: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var t: Double = 0

    var body: some View {
        VStack(spacing: 0) {
            Spacer().frame(height: VSpace.xxl * 1.2)

            Text("What fourteen\ndays can move.")
                .font(RampStage.serif(28, italic: true))
                .foregroundStyle(RampStage.ink)
                .multilineTextAlignment(.center)
                .lineSpacing(2)

            Spacer() // orb glows here (staged by the container)

            VStack(spacing: VSpace.md) {
                ForEach(RampSplitMetric.samples.indices, id: \.self) { i in
                    let metric = RampSplitMetric.samples[i]
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(metric.label)
                                .font(VType.caption)
                                .foregroundStyle(RampStage.textSecondary)
                            Spacer()
                            Text(verbatim: "\(Int(metric.value(at: t) * 100))")
                                .font(VType.captionBold)
                                .foregroundStyle(RampStage.accentDeep)
                                .monospacedDigit()
                        }
                        GeometryReader { proxy in
                            ZStack(alignment: .leading) {
                                Capsule().fill(RampStage.hair.opacity(0.6))
                                Capsule()
                                    .fill(RampStage.accent)
                                    .frame(width: proxy.size.width * metric.value(at: t))
                            }
                        }
                        .frame(height: 6)
                    }
                }
            }
            .padding(.horizontal, VSpace.xl)

            RampMorphSlider(value: $t)
                .padding(.horizontal, VSpace.xl)
                .padding(.top, VSpace.lg)

            HStack {
                Text(verbatim: "DAY 1")
                    .foregroundStyle(t < 0.5 ? RampStage.accentDeep : RampStage.textTertiary)
                Spacer()
                Text(verbatim: "DAY 14")
                    .foregroundStyle(t >= 0.5 ? RampStage.accentDeep : RampStage.textTertiary)
            }
            .font(VType.micro)
            .tracking(1.5)
            .padding(.horizontal, VSpace.xl)
            .padding(.top, VSpace.sm)

            Spacer()

            RampPrimaryButton(title: "Read mine") { onAdvance() }
                .padding(.horizontal, VSpace.lg)
            Spacer().frame(height: VSpace.xxl)
        }
        .onAppear {
            guard !reduceMotion else { t = 0.6; return }
            Task {
                try? await Task.sleep(for: .milliseconds(700))
                withAnimation(.easeInOut(duration: 1.2)) { t = 0.72 }
                try? await Task.sleep(for: .milliseconds(1400))
                withAnimation(.easeInOut(duration: 0.9)) { t = 0.2 }
            }
        }
    }
}

/// One metric bar on the Split screen — interpolates before→after by `t`.
private struct RampSplitMetric {
    let label: String
    let before: Double
    let after: Double

    func value(at t: Double) -> CGFloat {
        CGFloat(before + (after - before) * max(0, min(1, t)))
    }

    static let samples: [RampSplitMetric] = [
        RampSplitMetric(label: "Texture",  before: 0.42, after: 0.83),
        RampSplitMetric(label: "Redness",  before: 0.50, after: 0.79),
        RampSplitMetric(label: "Evenness", before: 0.46, after: 0.81),
        RampSplitMetric(label: "Glow",     before: 0.38, after: 0.87),
    ]
}

/// Custom track slider with a soft knob — the one interaction on the Split
/// screen. Warm, quiet, no glow burst.
struct RampMorphSlider: View {
    @Binding var value: Double

    private let knob: CGFloat = 26

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let usable = max(width - knob, 1)
            let x = CGFloat(max(0, min(1, value))) * usable

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(RampStage.hair.opacity(0.6))
                    .frame(height: 5)
                Capsule()
                    .fill(RampStage.accent)
                    .frame(width: x + knob / 2, height: 5)
                Circle()
                    .fill(Color.white)
                    .frame(width: knob, height: knob)
                    .overlay(Circle().strokeBorder(RampStage.accent, lineWidth: 2))
                    .shadow(color: RampStage.accent.opacity(0.35), radius: 8, y: 3)
                    .offset(x: x)
            }
            .frame(maxHeight: .infinity, alignment: .center)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { g in
                        let newValue = Double(max(0, min(usable, g.location.x - knob / 2)) / usable)
                        if abs(newValue - value) > 0.02 { Haptics.fire(.tick) }
                        value = newValue
                    }
            )
        }
        .frame(height: knob)
        .accessibilityElement()
        .accessibilityLabel("onboarding.split")
        .accessibilityValue(Text(verbatim: "\(Int(value * 100))%"))
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: value = min(1, value + 0.1)
            case .decrement: value = max(0, value - 0.1)
            default: break
            }
        }
    }
}
