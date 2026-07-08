import SwiftUI

// ============================================================
// MARK: — Quiz screen (screens 4–5, one question per step)
// ============================================================

struct RampQuizOption: Identifiable {
    let id: String
    let label: String
    var icon: String? = nil
}

/// Shared quiz layout: question on top, large option cards, the head reduced
/// to a corner watermark (staged by the container — it "listens").
/// Selection IS the advance: card fills with accent, rigid haptic, and the
/// container moves on after 400ms. No "Next" button — the pace is the point.
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
                .padding(.trailing, VSpace.xxl) // clear of the corner watermark

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
// MARK: — Screen 6: Calibrating (mid-flow payoff)
// ============================================================

/// The reward for investing: quiz answers fly into the fast-spinning head as
/// chips, each absorption flashes a vertex cluster, then the status lines
/// tick in. Auto-advances — this screen converts form answers into perceived
/// machine intelligence.
struct RampCalibratingScreen: View {
    let controller: ScanHeadController
    let answers: RampQuizAnswers
    let onAdvance: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var absorbedCount = 0
    @State private var statusCount = 0

    private let statusLines = ["Profile built", "Metrics weighted", "Engine ready"]
    private let clusters: [ScanHeadController.Cluster] = [
        .forehead, .leftCheek, .rightCheek, .chin, .forehead,
    ]

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // Chips orbit the head and get absorbed one by one.
            ZStack {
                let chips = answers.chipLabels
                ForEach(Array(chips.enumerated()), id: \.offset) { index, label in
                    RampAnswerChip(
                        label: label,
                        angle: .degrees(Double(index) / Double(max(chips.count, 1)) * 360 - 90),
                        absorbed: index < absorbedCount
                    )
                }
            }
            .frame(height: 320)

            Spacer()

            VStack(spacing: VSpace.sm) {
                Text("Calibrating your baseline…")
                    .font(VType.body)
                    .foregroundStyle(RampStage.textSecondary)

                HStack(spacing: VSpace.sm) {
                    ForEach(0..<statusCount, id: \.self) { index in
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark")
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(DQColor.deltaUp)
                            Text(statusLines[index])
                                .font(VType.captionBold)
                                .foregroundStyle(RampStage.textPrimary)
                        }
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                    }
                }
                .animation(VMotion.snappy, value: statusCount)
                .frame(height: 24)
            }
            Spacer().frame(height: VSpace.xxl * 1.5)
        }
        .task { await run() }
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
            Haptics.fire(.selection) // light tick per absorption
            try? await Task.sleep(for: .milliseconds(reduceMotion ? 120 : 380))
        }

        try? await Task.sleep(for: .milliseconds(300))
        for index in statusLines.indices {
            guard !Task.isCancelled else { return }
            statusCount = index + 1
            Haptics.fire(.selection)
            try? await Task.sleep(for: .milliseconds(reduceMotion ? 150 : 450))
        }

        try? await Task.sleep(for: .milliseconds(700))
        guard !Task.isCancelled else { return }
        onAdvance()
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
