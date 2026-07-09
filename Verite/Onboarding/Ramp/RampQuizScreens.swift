import SwiftUI

// ============================================================
// MARK: — Quiz screen (one question, editorial tiles)
// ============================================================

struct RampQuizOption: Identifiable {
    let id: String
    let label: String
    var sub: String? = nil
    var icon: String? = nil
}

/// Calm question layout: a small step label, a serif question, and a stack of
/// airy answer tiles. Selection is the advance — a gentle settle, a soft
/// haptic, and the flow moves on. No "Next", no energy.
struct RampQuizScreen: View {
    let question: String
    let options: [RampQuizOption]
    let selectedID: String?
    let onSelect: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer().frame(height: VSpace.xxl * 2)

            Text(question)
                .font(RampStage.serif(27, italic: true))
                .foregroundStyle(RampStage.ink)
                .lineSpacing(2)
                .padding(.horizontal, VSpace.lg)

            Spacer().frame(height: VSpace.xl)

            VStack(spacing: VSpace.sm) {
                ForEach(Array(options.enumerated()), id: \.element.id) { index, option in
                    RampOptionCard(
                        label: option.label,
                        sub: option.sub,
                        icon: option.icon,
                        selected: selectedID == option.id
                    ) {
                        onSelect(option.id)
                    }
                    .vStaggeredAppear(index: index)
                }
            }
            .padding(.horizontal, VSpace.lg)

            Spacer()
        }
    }
}

// ============================================================
// MARK: — The Reading (calm payoff + prediction range)
// ============================================================

/// The reward for answering — but hushed. The answers settle into a soft line,
/// the orb warms (staged by the container), and the engine reveals a
/// personalized score *range*. A single number would answer the question; a
/// range is a quiet open question only the scan can close.
struct RampRevealScreen: View {
    let answers: RampQuizAnswers
    let onAdvance: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var showChips = false
    @State private var showRange = false

    private var range: (low: Int, high: Int) { answers.predictedRange }

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            Text(verbatim: "YOUR READING, SO FAR")
                .font(VType.micro)
                .tracking(3)
                .foregroundStyle(RampStage.accentDeep)
                .opacity(showChips ? 1 : 0)

            Text(answers.chipLabels.joined(separator: "  ·  "))
                .font(VType.caption)
                .foregroundStyle(RampStage.textSecondary)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .padding(.horizontal, VSpace.xl)
                .padding(.top, VSpace.sm)
                .opacity(showChips ? 1 : 0)

            Spacer() // orb warms here (staged by the container)

            Group {
                if showRange {
                    rangeReveal
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                } else {
                    Text("Reading your answers…")
                        .font(VType.body)
                        .foregroundStyle(RampStage.textSecondary)
                }
            }
            .frame(minHeight: 150)
            .padding(.horizontal, VSpace.xl)
            .animation(VMotion.gentle, value: showRange)

            Spacer()

            if showRange {
                RampPrimaryButton(title: "See where I land") { onAdvance() }
                    .padding(.horizontal, VSpace.lg)
                    .transition(.opacity)
            }
            Spacer().frame(height: VSpace.xxl)
        }
        .animation(VMotion.gentle, value: showRange)
        .task { await run() }
    }

    private var rangeReveal: some View {
        VStack(spacing: VSpace.md) {
            Text(verbatim: "\(range.low) – \(range.high)")
                .font(RampStage.serif(60))
                .foregroundStyle(RampStage.ink)

            Text("The engine already has an estimate.\nOnly a scan narrows it to your real number.")
                .font(VType.body)
                .foregroundStyle(RampStage.textSecondary)
                .multilineTextAlignment(.center)
                .lineSpacing(2)
        }
    }

    private func run() async {
        try? await Task.sleep(for: .milliseconds(reduceMotion ? 100 : 500))
        withAnimation(.easeOut(duration: 0.9)) { showChips = true }
        Haptics.fire(.selection)

        try? await Task.sleep(for: .milliseconds(reduceMotion ? 200 : 1400))
        guard !Task.isCancelled else { return }
        withAnimation(VMotion.gentle) { showRange = true }
        Haptics.fire(.verdictReveal)
    }
}
