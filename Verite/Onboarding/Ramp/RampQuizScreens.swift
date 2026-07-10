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

/// Calm question layout: a chapter eyebrow, a serif question, and a stack of
/// airy answer tiles. Selection is the advance — a gentle settle, a soft
/// haptic, and the flow moves on. No "Next", no energy.
struct RampQuizScreen: View {
    /// Editorial chapter label, e.g. "YOUR SKIN · ONE OF THREE".
    var chapter: String? = nil
    let question: String
    let options: [RampQuizOption]
    let selectedID: String?
    let onSelect: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer().frame(height: VSpace.xxl * 2)

            if let chapter {
                Text(verbatim: chapter)
                    .font(VType.micro)
                    .tracking(3)
                    .foregroundStyle(RampStage.accentDeep)
                    .padding(.horizontal, VSpace.lg)
                    .padding(.bottom, VSpace.sm)
            }

            Text(question)
                .font(RampStage.serif(25))
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
// MARK: — The Name (optional, personalizes everything after)
// ============================================================

/// One optional text field. Cheapest proven personalization lever there is:
/// from here on the engine addresses the user by name — honestly, because
/// they gave it to us seconds ago.
struct RampNameScreen: View {
    @Binding var name: String
    let onAdvance: () -> Void

    @FocusState private var focused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer().frame(height: VSpace.xxl * 2)

            Text("What should\nwe call you?")
                .font(RampStage.serif(25))
                .foregroundStyle(RampStage.ink)
                .lineSpacing(2)
                .padding(.horizontal, VSpace.lg)

            Spacer().frame(height: VSpace.xl)

            TextField("Your first name", text: $name)
                .font(VType.bodyLarge)
                .foregroundStyle(RampStage.ink)
                .tint(RampStage.accentDeep)
                .textContentType(.givenName)
                .autocorrectionDisabled()
                .submitLabel(.continue)
                .focused($focused)
                .onSubmit { onAdvance() }
                .padding(.horizontal, 18)
                .frame(minHeight: 62)
                .background(RampStage.card, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .strokeBorder(focused ? RampStage.accent : RampStage.hairline, lineWidth: 1)
                )
                .padding(.horizontal, VSpace.lg)
                .animation(VMotion.gentle, value: focused)

            Text("Stays on your device, like everything else.")
                .font(VType.micro)
                .foregroundStyle(RampStage.textTertiary)
                .padding(.horizontal, VSpace.lg)
                .padding(.top, VSpace.sm)

            Spacer()

            VStack(spacing: VSpace.xs) {
                RampPrimaryButton(title: "Continue") { onAdvance() }
                RampGhostButton(title: "Skip") {
                    name = ""
                    onAdvance()
                }
            }
            .padding(.horizontal, VSpace.lg)
            Spacer().frame(height: VSpace.xxl)
        }
        .task {
            try? await Task.sleep(for: .milliseconds(450))
            focused = true
        }
    }
}

// ============================================================
// MARK: — Insight interstitial (the engine talks back)
// ============================================================

/// The mid-quiz payoff: a beautiful photo card + the engine reflecting the
/// user's own answers back in full sentences. Pure template logic over THEIR
/// answers — the strongest documented conversion mechanic in this genre,
/// with nothing fabricated. Photo assets: "GlowTexture" / "GlowRitual".
struct RampInsightScreen: View {
    let eyebrow: String
    let insight: String
    var photoName: String = "GlowTexture"
    let onAdvance: () -> Void

    @State private var shown = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer().frame(height: VSpace.xxl * 1.4)

            RampPhoto(name: photoName, cornerRadius: 24)
                .frame(maxWidth: .infinity)
                .frame(height: 240)
                .padding(.horizontal, VSpace.lg)
                .opacity(shown ? 1 : 0)
                .scaleEffect(shown ? 1 : 0.97)

            Spacer()

            VStack(spacing: VSpace.md) {
                Text(verbatim: eyebrow)
                    .font(VType.micro)
                    .tracking(3)
                    .foregroundStyle(RampStage.accentDeep)

                Text(insight)
                    .font(RampStage.serif(21, weight: .semibold))
                    .foregroundStyle(RampStage.ink)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }
            .padding(.horizontal, VSpace.xl)
            .opacity(shown ? 1 : 0)
            .offset(y: shown ? 0 : 10)

            Spacer()

            RampPrimaryButton(title: "Continue") { onAdvance() }
                .padding(.horizontal, VSpace.lg)
                .opacity(shown ? 1 : 0)
            Spacer().frame(height: VSpace.xxl)
        }
        .task {
            try? await Task.sleep(for: .milliseconds(200))
            withAnimation(.easeOut(duration: 0.8)) { shown = true }
            Haptics.fire(.selection)
        }
    }
}

// ============================================================
// MARK: — The Reading (calm payoff + prediction range)
// ============================================================

/// The reward for answering. The estimate is visibly EARNED: four processing
/// steps tick through one by one (each referencing what the user actually
/// gave us), and only then does the personalized score *range* appear. A
/// single number would answer the question; a range is a quiet open question
/// only the scan can close.
struct RampRevealScreen: View {
    let answers: RampQuizAnswers
    let onAdvance: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var stepCount = 0
    @State private var showRange = false

    private var range: (low: Int, high: Int) { answers.predictedRange }

    private var steps: [String] {
        [
            "Mapping your skin profile…",
            "Weighing sleep & sun exposure…",
            answers.age != nil ? "Comparing against your age group…"
                               : "Comparing against typical profiles…",
            "Setting your range…",
        ]
    }

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            Group {
                if showRange {
                    rangeReveal
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                } else {
                    processingList
                }
            }
            .frame(minHeight: 220)
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

    /// The visible work: steps appear one by one, each settling with a check.
    private var processingList: some View {
        VStack(alignment: .leading, spacing: VSpace.md) {
            ForEach(0..<stepCount, id: \.self) { index in
                HStack(spacing: 12) {
                    Image(systemName: index < stepCount - 1 || showRange
                          ? "checkmark.circle.fill" : "circle.dotted")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(index < stepCount - 1 || showRange
                                         ? RampStage.accent : RampStage.textTertiary)
                    Text(steps[index])
                        .font(VType.body)
                        .foregroundStyle(index == stepCount - 1
                                         ? RampStage.ink : RampStage.textSecondary)
                }
                .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .animation(VMotion.gentle, value: stepCount)
    }

    private var rangeReveal: some View {
        VStack(spacing: VSpace.md) {
            if let name = answers.displayName {
                Text(verbatim: "\(name.uppercased())'S RANGE")
                    .font(VType.micro)
                    .tracking(3)
                    .foregroundStyle(RampStage.accentDeep)
            } else {
                Text(verbatim: "YOUR RANGE")
                    .font(VType.micro)
                    .tracking(3)
                    .foregroundStyle(RampStage.accentDeep)
            }

            Text(verbatim: "\(range.low) – \(range.high)")
                .font(RampStage.serif(60))
                .foregroundStyle(RampStage.ink)

            Text("Built from your \(answers.answeredCount) answers.\nOnly a scan narrows it to your real number.")
                .font(VType.body)
                .foregroundStyle(RampStage.textSecondary)
                .multilineTextAlignment(.center)
                .lineSpacing(2)
        }
    }

    private func run() async {
        if reduceMotion {
            stepCount = steps.count
            try? await Task.sleep(for: .milliseconds(400))
            showRange = true
            return
        }
        try? await Task.sleep(for: .milliseconds(400))
        for index in steps.indices {
            guard !Task.isCancelled else { return }
            withAnimation(VMotion.gentle) { stepCount = index + 1 }
            Haptics.fire(.tick)
            try? await Task.sleep(for: .milliseconds(720))
        }
        guard !Task.isCancelled else { return }
        withAnimation(VMotion.gentle) { showRange = true }
        Haptics.fire(.verdictReveal)
    }
}
