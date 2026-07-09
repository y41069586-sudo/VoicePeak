import SwiftUI

// ============================================================
// MARK: — Quiz screen (the interrogation, one question per step)
// ============================================================

struct RampQuizOption: Identifiable {
    let id: String
    let label: String
    var icon: String? = nil
}

/// Shared quiz layout: question on top, large option cards, the head reduced
/// to a top-corner presence that visibly densifies as answers come in.
/// Selection IS the advance: card fills with accent, energy discharges, the
/// head absorbs the answer, and the container moves on after 400ms. No "Next"
/// button — the pace is the point.
struct RampQuizScreen: View {
    let question: String
    let options: [RampQuizOption]
    var columns: Int = 1
    let selectedID: String?
    let onSelect: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer().frame(height: VSpace.xxl * 1.6)

            Text(question)
                .font(VType.hero(28))
                .foregroundStyle(RampStage.textPrimary)
                .padding(.horizontal, VSpace.lg)
                .padding(.trailing, VSpace.xxl) // clear of the corner head

            Spacer().frame(height: VSpace.xl)

            optionGrid
                .padding(.horizontal, VSpace.lg)

            Spacer()
        }
    }

    @ViewBuilder
    private var optionGrid: some View {
        if columns <= 1 {
            VStack(spacing: VSpace.sm) {
                ForEach(Array(options.enumerated()), id: \.element.id) { index, option in
                    card(option).vStaggeredAppear(index: index)
                }
            }
        } else {
            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: VSpace.sm), count: columns),
                spacing: VSpace.sm
            ) {
                ForEach(Array(options.enumerated()), id: \.element.id) { index, option in
                    card(option).vStaggeredAppear(index: index)
                }
            }
        }
    }

    private func card(_ option: RampQuizOption) -> some View {
        RampOptionCard(
            label: option.label,
            icon: option.icon,
            selected: selectedID == option.id
        ) {
            onSelect(option.id)
        }
    }
}

// ============================================================
// MARK: — Twin Complete (payoff + personalized prediction range)
// ============================================================

/// The reward for investing: the answer chips orbit the fast-spinning head on
/// visible guide rings and get pulled in one by one, integrity locks to 100%,
/// an energy burst fires — then the engine reveals a *personalized score
/// range*. A single number would answer the question; a range is an open
/// wound only the scan can close. This is the strongest conversion beat.
struct RampTwinCompleteScreen: View {
    let controller: ScanHeadController
    let answers: RampQuizAnswers
    let onAdvance: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var absorbedCount = 0
    @State private var burst = false
    @State private var showRange = false

    private let clusters: [ScanHeadController.Cluster] = [
        .forehead, .leftCheek, .rightCheek, .chin, .forehead,
    ]

    private var range: (low: Int, high: Int) { answers.predictedRange }

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            ZStack {
                Ellipse()
                    .strokeBorder(Color.white.opacity(0.07), lineWidth: 1)
                    .frame(width: 306, height: 348)
                Ellipse()
                    .strokeBorder(Color.white.opacity(0.045), lineWidth: 1)
                    .frame(width: 244, height: 282)

                let chips = answers.chipLabels
                if reduceMotion {
                    orbitingChips(chips: chips, time: 0)
                } else {
                    TimelineView(.animation(minimumInterval: 1.0 / 40)) { timeline in
                        orbitingChips(
                            chips: chips,
                            time: timeline.date.timeIntervalSinceReferenceDate
                        )
                    }
                }

                if burst {
                    RampShockwave(maxScale: 2.8, lineWidth: 1.5, duration: 0.9)
                        .frame(width: 190, height: 190)
                    RampShockwave(maxScale: 2.1, lineWidth: 2.5, duration: 0.7)
                        .frame(width: 130, height: 130)
                }
            }
            .frame(height: 340)

            Spacer()

            Group {
                if showRange {
                    rangeReveal
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                } else {
                    Text("Assembling your twin…")
                        .font(VType.body)
                        .foregroundStyle(RampStage.textSecondary)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(minHeight: 170)
            .padding(.horizontal, VSpace.xl)
            .animation(VMotion.gentle, value: showRange)

            Spacer()

            if showRange {
                DQPrimaryButton(title: "See where I land") { onAdvance() }
                    .padding(.horizontal, VSpace.lg)
                    .transition(.opacity)
            }
            Spacer().frame(height: VSpace.xxl)
        }
        .animation(VMotion.standard, value: showRange)
        .task { await run() }
    }

    private var rangeReveal: some View {
        VStack(spacing: VSpace.md) {
            Text("ESTIMATED RANGE")
                .font(DQFont.mono(11, weight: .semibold))
                .tracking(3)
                .foregroundStyle(RampStage.textTertiary)

            HStack(alignment: .firstTextBaseline, spacing: VSpace.sm) {
                Text(verbatim: "\(range.low)")
                    .font(DQFont.score(56))
                    .foregroundStyle(RampStage.textPrimary)
                Text(verbatim: "–")
                    .font(DQFont.score(36))
                    .foregroundStyle(RampStage.textTertiary)
                Text(verbatim: "\(range.high)")
                    .font(DQFont.score(56))
                    .foregroundStyle(DQColor.accentGradient)
            }
            .vGlow(RampStage.accent, radius: 28, opacity: 0.4)

            Text("Our model already has an estimate.\nOnly a scan collapses it to your real number.")
                .font(VType.body)
                .foregroundStyle(RampStage.textSecondary)
                .multilineTextAlignment(.center)
        }
    }

    /// The chip ring at a given wall-clock time — chips drift slowly around
    /// their orbit until absorbed, so the system feels alive, not posed.
    private func orbitingChips(chips: [String], time: TimeInterval) -> some View {
        ZStack {
            ForEach(Array(chips.enumerated()), id: \.offset) { index, label in
                RampAnswerChip(
                    label: label,
                    angle: .degrees(
                        Double(index) / Double(max(chips.count, 1)) * 360 - 90
                        + time.truncatingRemainder(dividingBy: 360) * 9
                    ),
                    absorbed: index < absorbedCount
                )
            }
        }
    }

    private func run() async {
        let chips = answers.chipLabels
        try? await Task.sleep(for: .milliseconds(reduceMotion ? 200 : 700))

        for index in chips.indices {
            guard !Task.isCancelled else { return }
            withAnimation(reduceMotion ? VMotion.crossfade : VMotion.standard) {
                absorbedCount = index + 1
            }
            controller.flash(clusters[index % clusters.count])
            Haptics.fire(.selection)
            try? await Task.sleep(for: .milliseconds(reduceMotion ? 120 : 380))
        }

        // The twin locks in — energy discharge + milestone haptic.
        try? await Task.sleep(for: .milliseconds(300))
        if !reduceMotion { burst = true }
        Haptics.fire(.milestone)

        try? await Task.sleep(for: .milliseconds(600))
        guard !Task.isCancelled else { return }
        withAnimation(VMotion.gentle) { showRange = true }
        Haptics.fire(.verdictReveal)
    }
}

/// One labeled answer chip that flies from its orbit position into the head.
private struct RampAnswerChip: View {
    let label: String
    let angle: Angle
    let absorbed: Bool

    private var orbitOffset: CGSize {
        CGSize(width: cos(angle.radians) * 130, height: sin(angle.radians) * 150)
    }

    var body: some View {
        Text(label)
            .font(VType.captionBold)
            .foregroundStyle(RampStage.textPrimary)
            .padding(.horizontal, VSpace.md)
            .padding(.vertical, 7)
            .background(RampStage.card, in: Capsule())
            .overlay(Capsule().strokeBorder(RampStage.accent.opacity(0.5), lineWidth: 1))
            .offset(absorbed ? .zero : orbitOffset)
            .scaleEffect(absorbed ? 0.05 : 1)
            .opacity(absorbed ? 0 : 1)
            .animation(.easeIn(duration: 0.4), value: absorbed)
    }
}
