import SwiftUI

// ============================================================
// MARK: — Screen 0: Cold Open (non-interactive)
// ============================================================

/// Black screen → head fades in half-lit, one sweep, wordmark types on.
/// Pure spectacle; auto-advances. The head itself is staged by the container.
struct RampColdOpenScreen: View {
    let controller: ScanHeadController
    let onAdvance: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var showTagline = false

    var body: some View {
        VStack {
            Spacer()
            Spacer()
            VStack(spacing: VSpace.md) {
                TypewriterText(
                    text: "VÉRITÉ",
                    perCharacter: .milliseconds(80),
                    startDelay: .milliseconds(900),
                    font: .system(size: 32, weight: .semibold, design: .monospaced),
                    tracking: 8
                )
                Text("The honest skin rating.")
                    .font(VType.body)
                    .foregroundStyle(RampStage.textSecondary)
                    .opacity(showTagline ? 1 : 0)
            }
            .padding(.bottom, VSpace.xxl * 2)
        }
        .frame(maxWidth: .infinity)
        .task {
            if !reduceMotion {
                controller.sweep(duration: 1.4, delay: 0.6)
            }
            try? await Task.sleep(for: .milliseconds(1700))
            withAnimation(VMotion.gentle) { showTagline = true }
            try? await Task.sleep(for: .milliseconds(1400))
            guard !Task.isCancelled else { return }
            onAdvance()
        }
    }
}

// ============================================================
// MARK: — Screen 1: The Claim
// ============================================================

struct RampClaimScreen: View {
    let onAdvance: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Spacer() // head rotates in the upper third (staged by the container)
            Spacer()
            VStack(spacing: VSpace.md) {
                Text("Your skin has a score.\nMost people never learn it.")
                    .font(VType.hero(32))
                    .foregroundStyle(RampStage.textPrimary)
                    .multilineTextAlignment(.center)
                Text("Vérité measures it — and shows you your ceiling.")
                    .font(VType.bodyLarge)
                    .foregroundStyle(RampStage.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, VSpace.xl)
            .vStaggeredAppear(index: 0)
            Spacer()
            DQPrimaryButton(title: "Find out mine") { onAdvance() }
                .padding(.horizontal, VSpace.lg)
            Spacer().frame(height: VSpace.xxl)
        }
    }
}

// ============================================================
// MARK: — Screen 2: The Proof (before/after theater)
// ============================================================

struct RampProofScreen: View {
    let onAdvance: () -> Void

    @State private var index = 0
    private let cases = RampProofCase.samples

    var body: some View {
        VStack(spacing: 0) {
            Spacer().frame(height: VSpace.xxl)
            Text("Real users. Real numbers.")
                .font(VType.hero(28))
                .foregroundStyle(RampStage.textPrimary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, VSpace.xl)

            Spacer()

            RampBeforeAfterCard(proofCase: cases[index])
                .id(index)
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .move(edge: .leading).combined(with: .opacity)
                ))

            // Cycle dots
            HStack(spacing: 6) {
                ForEach(cases.indices, id: \.self) { i in
                    Capsule()
                        .fill(i == index ? RampStage.accent : Color.white.opacity(0.15))
                        .frame(width: i == index ? 20 : 7, height: 5)
                }
            }
            .padding(.top, VSpace.md)

            Text("Results from Vérité users. Individual results vary.")
                .font(VType.micro)
                .foregroundStyle(RampStage.textTertiary)
                .padding(.top, VSpace.sm)

            Spacer()

            DQPrimaryButton(title: "How it works") { onAdvance() }
                .padding(.horizontal, VSpace.lg)
            Spacer().frame(height: VSpace.xxl)
        }
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(2500))
                guard !Task.isCancelled else { return }
                withAnimation(VMotion.standard) { index = (index + 1) % cases.count }
            }
        }
    }
}

/// One before/after example: score morph + duration label.
struct RampProofCase {
    let scoreFrom: Int
    let scoreTo: Int
    let days: Int
    let skinTone: Color
    let seed: UInt64

    static let samples: [RampProofCase] = [
        RampProofCase(scoreFrom: 61, scoreTo: 84, days: 14, skinTone: Color(hex: "E8B893"), seed: 7),
        RampProofCase(scoreFrom: 55, scoreTo: 79, days: 14, skinTone: Color(hex: "8D5A3B"), seed: 21),
        RampProofCase(scoreFrom: 68, scoreTo: 88, days: 21, skinTone: Color(hex: "F1CBA9"), seed: 42),
    ]
}

/// Before/after pair with an animated vertical wipe divider and a counting
/// score badge.
private struct RampBeforeAfterCard: View {
    let proofCase: RampProofCase

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var wipe: CGFloat = 0
    @State private var score: Int

    init(proofCase: RampProofCase) {
        self.proofCase = proofCase
        _score = State(initialValue: proofCase.scoreFrom)
    }

    private let portraitSize = CGSize(width: 250, height: 300)

    var body: some View {
        VStack(spacing: VSpace.md) {
            ZStack {
                // "Before" underneath; "after" wipes over it left → right.
                RampSamplePortrait(clear: false, tone: proofCase.skinTone, seed: proofCase.seed)
                RampSamplePortrait(clear: true, tone: proofCase.skinTone, seed: proofCase.seed)
                    .mask(alignment: .leading) {
                        Rectangle().frame(width: portraitSize.width * wipe)
                    }
                // The divider light
                Rectangle()
                    .fill(RampStage.accent)
                    .frame(width: 2)
                    .blur(radius: 0.5)
                    .vGlow(RampStage.accent, radius: 10, opacity: 0.9)
                    .offset(x: portraitSize.width * (wipe - 0.5))
                    .opacity(wipe > 0.01 && wipe < 0.99 ? 1 : 0)
            }
            .frame(width: portraitSize.width, height: portraitSize.height)
            .clipShape(RoundedRectangle(cornerRadius: VRadius.lg, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: VRadius.lg, style: .continuous)
                    .strokeBorder(RampStage.hairline, lineWidth: 1)
            )

            HStack(spacing: VSpace.sm) {
                Text(verbatim: "\(proofCase.scoreFrom)")
                    .font(VType.number(24))
                    .foregroundStyle(RampStage.textSecondary)
                Image(systemName: "arrow.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(RampStage.textTertiary)
                Text(verbatim: "\(score)")
                    .font(VType.number(24))
                    .foregroundStyle(RampStage.accent)
                    .contentTransition(.numericText(value: Double(score)))
                Text(verbatim: "· \(proofCase.days) days")
                    .font(VType.caption)
                    .foregroundStyle(RampStage.textTertiary)
            }
            .padding(.horizontal, VSpace.md)
            .padding(.vertical, VSpace.sm)
            .background(RampStage.card, in: Capsule())
            .overlay(Capsule().strokeBorder(RampStage.hairline, lineWidth: 1))
        }
        .task {
            if reduceMotion {
                wipe = 1
                score = proofCase.scoreTo
                return
            }
            try? await Task.sleep(for: .milliseconds(350))
            withAnimation(.easeInOut(duration: 1.1)) { wipe = 1 }
            // Count the score up in step with the wipe.
            let steps = proofCase.scoreTo - proofCase.scoreFrom
            for value in stride(from: proofCase.scoreFrom, through: proofCase.scoreTo, by: 1) {
                guard !Task.isCancelled else { return }
                withAnimation(.linear(duration: 0.05)) { score = value }
                try? await Task.sleep(for: .milliseconds(1100 / UInt64(max(steps, 1))))
            }
        }
    }
}

/// Stylized sample portrait, drawn in code.
///
/// PRODUCTION ASSETS: replace this placeholder with real, licensed
/// before/after photography bundled in Assets.xcassets (`proof.1.before`,
/// `proof.1.after`, …) and swap this view for `Image(...)`. The wipe/score
/// choreography above stays unchanged.
private struct RampSamplePortrait: View {
    let clear: Bool
    let tone: Color
    let seed: UInt64

    var body: some View {
        ZStack {
            LinearGradient(colors: [RampStage.backdropGlow.opacity(0.9), Color.black],
                           startPoint: .top, endPoint: .bottom)
            // Face
            Ellipse()
                .fill(
                    LinearGradient(
                        colors: [tone.opacity(clear ? 1.0 : 0.88), tone.opacity(clear ? 0.85 : 0.62)],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    )
                )
                .frame(width: 150, height: 200)
                .offset(y: 10)
            // Blemish speckles on the "before" side only.
            if !clear {
                Canvas { context, size in
                    var rng = RampSeededGenerator(seed: seed)
                    for _ in 0..<26 {
                        let x = 50 + CGFloat.random(in: 0...150, using: &rng)
                        let y = 60 + CGFloat.random(in: 0...180, using: &rng)
                        let r = CGFloat.random(in: 1.5...4, using: &rng)
                        let redness = Double.random(in: 0.18...0.4, using: &rng)
                        context.fill(
                            Path(ellipseIn: CGRect(x: x, y: y, width: r, height: r)),
                            with: .color(DQColor.deltaDown.opacity(redness))
                        )
                        _ = size
                    }
                }
            } else {
                // Soft highlight sheen on the "after" side.
                Ellipse()
                    .fill(Color.white.opacity(0.14))
                    .frame(width: 60, height: 100)
                    .blur(radius: 18)
                    .offset(x: -30, y: -20)
            }
        }
    }
}

/// Deterministic RNG so the sample "before" speckles are stable per case.
private struct RampSeededGenerator: RandomNumberGenerator {
    private var state: UInt64
    init(seed: UInt64) { state = seed &+ 0x9E3779B97F4A7C15 }
    mutating func next() -> UInt64 {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return state
    }
}

// ============================================================
// MARK: — Screen 3: How It Works (3 beats, one screen)
// ============================================================

struct RampHowItWorksScreen: View {
    let controller: ScanHeadController
    let onAdvance: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var beat = -1
    @State private var showCTA = false

    private struct Beat {
        let title: String
        let subtitle: String
    }

    private let beats: [Beat] = [
        Beat(title: "Scan", subtitle: "7 skin metrics, one photo"),
        Beat(title: "Score", subtitle: "Honest, 0–100. No sugarcoating."),
        Beat(title: "Ceiling", subtitle: "See your face at its 10/10"),
    ]

    var body: some View {
        VStack(spacing: 0) {
            Spacer() // head center stage
            Spacer()

            // Beat label
            VStack(spacing: VSpace.xs) {
                if beat >= 0 && beat < beats.count {
                    Text(beats[beat].title)
                        .font(VType.hero(26))
                        .foregroundStyle(RampStage.textPrimary)
                    Text(beats[beat].subtitle)
                        .font(VType.body)
                        .foregroundStyle(RampStage.textSecondary)
                }
            }
            .id(beat)
            .transition(.opacity.combined(with: .move(edge: .bottom)))
            .frame(height: 70)

            // Beat progress dots
            HStack(spacing: 8) {
                ForEach(beats.indices, id: \.self) { i in
                    Circle()
                        .fill(i <= beat ? RampStage.accent : Color.white.opacity(0.15))
                        .frame(width: 6, height: 6)
                }
            }
            .padding(.top, VSpace.md)

            Spacer()

            DQPrimaryButton(title: "Let's build my profile") { onAdvance() }
                .padding(.horizontal, VSpace.lg)
                .opacity(showCTA ? 1 : 0)
                .disabled(!showCTA)
                .animation(VMotion.gentle, value: showCTA)
            Spacer().frame(height: VSpace.xxl)
        }
        .animation(VMotion.standard, value: beat)
        .task { await runBeats() }
        .onDisappear { controller.setCeilingMode(false) }
    }

    private func runBeats() async {
        try? await Task.sleep(for: .milliseconds(400))
        guard !Task.isCancelled else { return }

        // Beat 1 — the scan-line sweeps the head.
        beat = 0
        if !reduceMotion { controller.sweep(duration: 1.6, delay: 0.2) }
        try? await Task.sleep(for: .milliseconds(2100))
        guard !Task.isCancelled else { return }

        // Beat 2 — vertex clusters flash (cheeks, forehead, chin).
        beat = 1
        for cluster in ScanHeadController.Cluster.allCases {
            controller.flash(cluster)
            try? await Task.sleep(for: .milliseconds(320))
            guard !Task.isCancelled else { return }
        }
        try? await Task.sleep(for: .milliseconds(900))
        guard !Task.isCancelled else { return }

        // Beat 3 — the surface smooths: crossfade to the denser, calmer mesh.
        beat = 2
        controller.setCeilingMode(true)
        try? await Task.sleep(for: .milliseconds(1800))
        guard !Task.isCancelled else { return }

        showCTA = true
    }
}
