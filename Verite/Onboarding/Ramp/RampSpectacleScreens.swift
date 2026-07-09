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

            VStack(spacing: VSpace.sm) {
                RampPrimaryButton(title: "Begin") { onAdvance() }
                Text("About a minute. No account needed.")
                    .font(VType.micro)
                    .foregroundStyle(RampStage.textTertiary)
            }
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
// MARK: — Screen 1: A Reading (the outcome, shown first)
// ============================================================

/// The genre's strongest opener: show the artifact the user will own BEFORE
/// asking for anything. An illustrative reading card — clearly labeled, no
/// invented people, no faces — cycles through a few example scores.
struct RampSampleReadingScreen: View {
    let onAdvance: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var index = 0

    private let samples = RampSampleReading.samples

    var body: some View {
        VStack(spacing: 0) {
            Spacer().frame(height: VSpace.xxl * 1.6)

            Text("Your skin, as a\nsingle honest page.")
                .font(RampStage.serif(27, italic: true))
                .foregroundStyle(RampStage.ink)
                .multilineTextAlignment(.center)
                .lineSpacing(2)

            Spacer()

            RampSampleReadingCard(sample: samples[index])
                .id(index)
                .transition(.opacity)

            // Cycle dots
            HStack(spacing: 6) {
                ForEach(samples.indices, id: \.self) { i in
                    Capsule()
                        .fill(i == index ? RampStage.accent : RampStage.hair)
                        .frame(width: i == index ? 18 : 6, height: 4)
                }
            }
            .padding(.top, VSpace.md)

            Text("Illustrative reading. Yours is built from your scan.")
                .font(VType.micro)
                .foregroundStyle(RampStage.textTertiary)
                .padding(.top, VSpace.xs)

            Spacer()

            RampPrimaryButton(title: "I want mine") { onAdvance() }
                .padding(.horizontal, VSpace.lg)
            Spacer().frame(height: VSpace.xxl)
        }
        .task {
            guard !reduceMotion else { return }
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(2600))
                guard !Task.isCancelled else { return }
                withAnimation(.easeInOut(duration: 0.5)) {
                    index = (index + 1) % samples.count
                }
            }
        }
    }
}

/// One illustrative reading: an overall score + per-metric levels.
struct RampSampleReading {
    let overall: Int
    let metrics: [(String, Double)] // label, 0…1

    static let samples: [RampSampleReading] = [
        RampSampleReading(overall: 74, metrics: [
            ("Texture", 0.71), ("Redness", 0.66), ("Pores", 0.78),
            ("Evenness", 0.73), ("Glow", 0.81), ("Hydration", 0.69), ("Blemishes", 0.84),
        ]),
        RampSampleReading(overall: 62, metrics: [
            ("Texture", 0.55), ("Redness", 0.48), ("Pores", 0.66),
            ("Evenness", 0.61), ("Glow", 0.58), ("Hydration", 0.72), ("Blemishes", 0.70),
        ]),
        RampSampleReading(overall: 86, metrics: [
            ("Texture", 0.84), ("Redness", 0.88), ("Pores", 0.82),
            ("Evenness", 0.87), ("Glow", 0.90), ("Hydration", 0.83), ("Blemishes", 0.89),
        ]),
    ]
}

/// The card itself — white paper on the porcelain stage, serif score,
/// seven quiet metric rows. This exact layout returns as the user's own
/// shareable Reading Card after the first scan.
struct RampSampleReadingCard: View {
    let sample: RampSampleReading

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(verbatim: "VÉRITÉ")
                    .font(VType.micro).tracking(4)
                    .foregroundStyle(RampStage.accentDeep)
                Spacer()
                Text(verbatim: "READING")
                    .font(VType.micro).tracking(4)
                    .foregroundStyle(RampStage.textTertiary)
            }

            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(verbatim: "\(sample.overall)")
                    .font(RampStage.serif(56))
                    .foregroundStyle(RampStage.ink)
                    .contentTransition(.numericText())
                Text(verbatim: "/ 100")
                    .font(VType.caption)
                    .foregroundStyle(RampStage.textTertiary)
            }
            .padding(.vertical, VSpace.sm)

            VStack(spacing: 9) {
                ForEach(sample.metrics, id: \.0) { metric in
                    HStack(spacing: 10) {
                        Text(metric.0)
                            .font(VType.caption)
                            .foregroundStyle(RampStage.textSecondary)
                            .frame(width: 74, alignment: .leading)
                        GeometryReader { proxy in
                            ZStack(alignment: .leading) {
                                Capsule().fill(RampStage.hair.opacity(0.55))
                                Capsule()
                                    .fill(RampStage.accent)
                                    .frame(width: proxy.size.width * metric.1)
                            }
                        }
                        .frame(height: 4)
                        Text(verbatim: "\(Int(metric.1 * 100))")
                            .font(VType.captionBold)
                            .foregroundStyle(RampStage.accentDeep)
                            .monospacedDigit()
                            .frame(width: 24, alignment: .trailing)
                    }
                }
            }
        }
        .padding(VSpace.lg)
        .frame(width: 290)
        .background(Color.white.opacity(0.72), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(RampStage.hairline, lineWidth: 1)
        )
        .shadow(color: RampStage.accent.opacity(0.18), radius: 26, y: 14)
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
                RampCalmFigure()
                    .vStaggeredAppear(index: 0)
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

/// A serif figure that never settles — it drifts through plausible scores
/// every couple of seconds, ending nowhere. Calm cousin of the slot-machine:
/// the number exists, it just isn't yours yet. Reduce Motion pins "· · ·".
private struct RampCalmFigure: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Group {
            if reduceMotion {
                figure("· · ·")
            } else {
                TimelineView(.periodic(from: .now, by: 1.6)) { timeline in
                    let tick = Int(timeline.date.timeIntervalSinceReferenceDate / 1.6)
                    figure(String(44 + Int(Self.hash(tick) * 51)))
                        .contentTransition(.numericText())
                        .animation(.easeInOut(duration: 0.7), value: tick)
                }
            }
        }
        .accessibilityHidden(true)
    }

    private func figure(_ text: String) -> some View {
        Text(verbatim: text)
            .font(RampStage.serif(58))
            .foregroundStyle(RampStage.ink.opacity(0.85))
            .monospacedDigit()
            .frame(minWidth: 92)
    }

    private static func hash(_ i: Int) -> Double {
        let v = sin(Double(i) * 127.1) * 43758.5453
        return v - floor(v)
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
