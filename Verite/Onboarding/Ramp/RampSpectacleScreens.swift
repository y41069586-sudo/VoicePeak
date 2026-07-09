import SwiftUI

// ============================================================
// MARK: — Screen 0: Boot (terminal + point-cloud assembly)
// ============================================================

/// The trailer moment. Terminal lines flicker up in mono, the scattered point
/// cloud collapses into the head, a shockwave fires and the wordmark stamps in.
/// Pure spectacle — the first three seconds that decide the uninstall.
struct RampBootScreen: View {
    let controller: ScanHeadController
    let onAdvance: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var lineCount = 0
    @State private var showWordmark = false
    @State private var ping = false

    private let lines = [
        "VÉRITÉ ENGINE v3",
        "OPTICS CALIBRATED",
        "7 METRICS LOADED",
        "SUBJECT: UNKNOWN",
    ]

    var body: some View {
        ZStack {
            if ping {
                RampShockwave(maxScale: 2.6, lineWidth: 1.2, duration: 1.0)
                    .frame(width: 240, height: 240)
                    .offset(y: -30)
            }

            VStack(spacing: 0) {
                Spacer().frame(height: VSpace.xxl * 1.4)

                // Terminal boot log.
                VStack(alignment: .leading, spacing: 7) {
                    ForEach(0..<lineCount, id: \.self) { index in
                        HStack(spacing: 8) {
                            Text(verbatim: ">")
                                .foregroundStyle(RampStage.accent)
                            Text(verbatim: lines[index])
                                .foregroundStyle(index == lines.count - 1
                                                 ? RampStage.textPrimary
                                                 : RampStage.textSecondary)
                        }
                        .font(DQFont.mono(12, weight: .medium))
                        .transition(.opacity.combined(with: .move(edge: .leading)))
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .frame(height: 120, alignment: .top)
                .padding(.horizontal, VSpace.xl)

                Spacer()

                VStack(spacing: VSpace.md) {
                    if showWordmark {
                        TypewriterText(
                            text: "VÉRITÉ",
                            perCharacter: .milliseconds(70),
                            font: .system(size: 32, weight: .semibold, design: .monospaced),
                            tracking: 8
                        )
                        Text("The honest skin rating.")
                            .font(VType.body)
                            .foregroundStyle(RampStage.textSecondary)
                            .transition(.opacity)
                    }
                }
                .frame(height: 90)
                .padding(.bottom, VSpace.xxl * 1.6)
            }
        }
        .frame(maxWidth: .infinity)
        .task { await run() }
    }

    private func run() async {
        if reduceMotion {
            lineCount = lines.count
            controller.assembleFromCloud(duration: 0.01)
            showWordmark = true
            try? await Task.sleep(for: .milliseconds(1400))
            guard !Task.isCancelled else { return }
            onAdvance()
            return
        }

        // The scattered cloud swirls into the head as the boot log types.
        controller.assembleFromCloud(duration: 1.6)
        controller.sweep(duration: 1.4, delay: 0.5)

        for index in lines.indices {
            withAnimation(VMotion.snappy) { lineCount = index + 1 }
            Haptics.fire(.tick)
            try? await Task.sleep(for: .milliseconds(340))
            guard !Task.isCancelled else { return }
        }

        try? await Task.sleep(for: .milliseconds(320))
        guard !Task.isCancelled else { return }
        ping = true
        Haptics.fire(.capture)

        try? await Task.sleep(for: .milliseconds(220))
        withAnimation(VMotion.gentle) { showWordmark = true }

        try? await Task.sleep(for: .milliseconds(1600))
        guard !Task.isCancelled else { return }
        onAdvance()
    }
}

// ============================================================
// MARK: — Screen 1: The Number (curiosity trap + hold-to-begin)
// ============================================================

struct RampNumberScreen: View {
    let onAdvance: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            Spacer()

            VStack(spacing: VSpace.lg) {
                RampScrambleFigure()
                    .vStaggeredAppear(index: 0)

                VStack(spacing: VSpace.sm) {
                    Text("Everyone has a Skin Score.")
                        .font(VType.hero(30))
                        .foregroundStyle(RampStage.textPrimary)
                        .multilineTextAlignment(.center)
                    Text("You've just never seen yours.")
                        .font(VType.bodyLarge)
                        .foregroundStyle(RampStage.textSecondary)
                }
                .vStaggeredAppear(index: 1)

                RampForeignScoreTicker()
                    .padding(.top, VSpace.xs)
                    .vStaggeredAppear(index: 2)
            }
            .padding(.horizontal, VSpace.xl)

            Spacer()

            VStack(spacing: VSpace.sm) {
                RampHoldToBeginButton(title: "Hold to reveal mine") { onAdvance() }
                Text("Press and hold")
                    .font(VType.micro)
                    .foregroundStyle(RampStage.textTertiary)
            }
            .padding(.horizontal, VSpace.lg)

            Spacer().frame(height: VSpace.xxl)
        }
    }
}

// ============================================================
// MARK: — Screen 2: The Split (interactive day 1 ↔ day 14)
// ============================================================

/// Proof you make with your own thumb. Dragging the slider morphs the head
/// between a rough "day 1" wireframe and a dense, calm "day 14" mesh, while
/// the metric bars climb in lockstep. Interactive before/after beats autoplay.
struct RampSplitScreen: View {
    let controller: ScanHeadController
    let onAdvance: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var t: Double = 0

    var body: some View {
        VStack(spacing: 0) {
            Spacer().frame(height: VSpace.xxl * 1.4)

            Text("Drag to see what 14 days moves.")
                .font(VType.hero(26))
                .foregroundStyle(RampStage.textPrimary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, VSpace.xl)

            Spacer() // head morphs here (staged by the container)

            VStack(spacing: VSpace.md) {
                ForEach(RampSplitMetric.samples.indices, id: \.self) { i in
                    let metric = RampSplitMetric.samples[i]
                    VStack(alignment: .leading, spacing: 5) {
                        HStack {
                            Text(metric.label)
                                .font(VType.caption)
                                .foregroundStyle(RampStage.textSecondary)
                            Spacer()
                            Text(verbatim: "\(Int((metric.value(at: t)) * 100))")
                                .font(DQFont.mono(11, weight: .semibold))
                                .foregroundStyle(RampStage.accent)
                        }
                        GeometryReader { proxy in
                            ZStack(alignment: .leading) {
                                Capsule().fill(Color.white.opacity(0.08))
                                Capsule()
                                    .fill(DQColor.accentGradient)
                                    .frame(width: proxy.size.width * metric.value(at: t))
                            }
                        }
                        .frame(height: 7)
                    }
                }
            }
            .padding(.horizontal, VSpace.xl)

            RampMorphSlider(value: $t)
                .padding(.horizontal, VSpace.xl)
                .padding(.top, VSpace.lg)

            HStack {
                Text(verbatim: "DAY 1")
                    .foregroundStyle(t < 0.5 ? RampStage.accent : RampStage.textTertiary)
                Spacer()
                Text(verbatim: "DAY 14")
                    .foregroundStyle(t >= 0.5 ? RampStage.accent : RampStage.textTertiary)
            }
            .font(DQFont.mono(10, weight: .semibold))
            .tracking(1.5)
            .padding(.horizontal, VSpace.xl)
            .padding(.top, VSpace.sm)

            Spacer()

            DQPrimaryButton(title: "Now build mine") { onAdvance() }
                .padding(.horizontal, VSpace.lg)
            Spacer().frame(height: VSpace.xxl)
        }
        .onAppear {
            // Preview the head fully rendered so the two states read cleanly;
            // leaving this screen resets integrity so the user's own twin
            // starts sparse and builds from their answers.
            controller.setTwinIntegrity(1.0, animated: true, duration: 0.9)
            controller.setSplit(t)
            if !reduceMotion {
                // A gentle self-demo nudge so the payoff is obvious.
                Task {
                    try? await Task.sleep(for: .milliseconds(700))
                    withAnimation(.easeInOut(duration: 1.1)) { t = 0.7 }
                    try? await Task.sleep(for: .milliseconds(1300))
                    withAnimation(.easeInOut(duration: 0.9)) { t = 0.15 }
                }
            }
        }
        .onChange(of: t) { _, newValue in controller.setSplit(newValue) }
    }
}

/// One metric bar on the Split screen — interpolates before→after by the
/// slider position `t`.
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

/// Custom track slider with a glowing knob — the interaction the whole Split
/// screen is built around.
struct RampMorphSlider: View {
    @Binding var value: Double

    private let knob: CGFloat = 28

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let usable = max(width - knob, 1)
            let x = CGFloat(max(0, min(1, value))) * usable

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.white.opacity(0.10))
                    .frame(height: 6)
                Capsule()
                    .fill(DQColor.accentGradient)
                    .frame(width: x + knob / 2, height: 6)
                Circle()
                    .fill(Color.white)
                    .frame(width: knob, height: knob)
                    .overlay(Circle().strokeBorder(RampStage.accent, lineWidth: 2))
                    .vGlow(RampStage.accent, radius: 12, opacity: 0.6)
                    .offset(x: x)
            }
            .frame(maxHeight: .infinity, alignment: .center)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { g in
                        let newValue = Double(max(0, min(usable, g.location.x - knob / 2)) / usable)
                        if abs(newValue - value) > 0.001 { Haptics.fire(.tick) }
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
