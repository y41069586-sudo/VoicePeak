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
                Text(LocalizedStringKey(chapter))
                    .font(VType.micro)
                    .tracking(3)
                    .foregroundStyle(RampStage.accentDeep)
                    .padding(.horizontal, VSpace.lg)
                    .padding(.bottom, VSpace.sm)
            }

            Text(LocalizedStringKey(question))
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

            Text("Stays private, like everything else.")
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
                .frame(width: 228, height: 304) // 3:4, no crop
                .opacity(shown ? 1 : 0)
                .scaleEffect(shown ? 1 : 0.97)

            Spacer()

            VStack(spacing: VSpace.md) {
                Text(LocalizedStringKey(eyebrow))
                    .font(VType.micro)
                    .tracking(3)
                    .foregroundStyle(RampStage.accentDeep)

                Text(LocalizedStringKey(insight))
                    .font(RampStage.serif(21, weight: .semibold))
                    .foregroundStyle(RampStage.ink)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
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

/// The reward for answering — a real, structured screen instead of bare
/// checkmarks floating in space: eyebrow + headline up top, then one card
/// where the estimate visibly assembles (your answers as chips, a filling
/// progress line, the work steps ticking in) and the personalized score
/// *range* lands inside that same card. A single number would answer the
/// question; a range is a quiet open question only the scan can close.
struct RampRevealScreen: View {
    let answers: RampQuizAnswers
    let onAdvance: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false
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

    /// The answers shaping the estimate, as scannable chips.
    private var answerChips: [String] {
        Array([answers.selfRating?.label, answers.concern?.label,
               answers.age?.label, answers.routine?.label]
            .compactMap { $0 }
            .prefix(4))
    }

    private var eyebrow: String {
        if !showRange { return "READING YOUR ANSWERS" }
        if let name = answers.displayName { return "\(name.uppercased())'S RANGE" }
        return "YOUR RANGE"
    }

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 24)

            // ---- Heading ----
            VStack(spacing: VSpace.sm) {
                Text(verbatim: eyebrow)
                    .font(VType.micro)
                    .tracking(3)
                    .foregroundStyle(RampStage.accentDeep)
                    .contentTransition(.opacity)
                Text(showRange ? "Your first estimate\nis ready." : "Building your\nfirst estimate")
                    .font(RampStage.serif(29))
                    .foregroundStyle(RampStage.ink)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                    .contentTransition(.opacity)
            }
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 12)

            Spacer(minLength: 24)

            // ---- The work card ----
            VStack(alignment: .leading, spacing: 16) {
                if !answerChips.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("FROM YOUR ANSWERS")
                            .font(VType.micro)
                            .tracking(2)
                            .foregroundStyle(RampStage.textTertiary)
                        ScrollView(.horizontal) {
                            HStack(spacing: 8) {
                                ForEach(answerChips, id: \.self) { chip in
                                    Text(chip)
                                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                                        .foregroundStyle(RampStage.accentDeep)
                                        .lineLimit(1)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 6)
                                        .background(RampStage.accentSoft, in: Capsule())
                                }
                            }
                        }
                        .scrollIndicators(.hidden)
                    }

                    Divider().overlay(RampStage.hairline)
                }

                if showRange {
                    // The payoff lands inside the same card the work ran in.
                    VStack(spacing: VSpace.sm) {
                        Text(verbatim: "\(range.low) – \(range.high)")
                            .font(RampStage.serif(54))
                            .foregroundStyle(RampStage.ink)
                        Text("Built from your \(answers.answeredCount) answers.\nOnly a scan narrows it to your real number.")
                            .font(VType.caption)
                            .foregroundStyle(RampStage.textSecondary)
                            .multilineTextAlignment(.center)
                            .lineSpacing(2)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                    .transition(.opacity.combined(with: .scale(scale: 0.96)))
                } else {
                    // Visible work: a filling hairline + steps ticking in.
                    VStack(alignment: .leading, spacing: 12) {
                        GeometryReader { proxy in
                            ZStack(alignment: .leading) {
                                Capsule().fill(RampStage.hair.opacity(0.6))
                                Capsule()
                                    .fill(RampStage.accent)
                                    .frame(width: proxy.size.width
                                           * CGFloat(stepCount) / CGFloat(max(steps.count, 1)))
                            }
                        }
                        .frame(height: 5)
                        .animation(VMotion.gentle, value: stepCount)

                        ForEach(0..<steps.count, id: \.self) { index in
                            let done = index < stepCount
                            HStack(spacing: 10) {
                                Image(systemName: done ? "checkmark.circle.fill" : "circle")
                                    .font(.system(size: 15, weight: .medium))
                                    .foregroundStyle(done ? RampStage.accent : RampStage.hair)
                                Text(steps[index])
                                    .font(VType.caption)
                                    .foregroundStyle(done ? RampStage.ink : RampStage.textTertiary)
                                Spacer(minLength: 0)
                            }
                            .opacity(done || index == stepCount ? 1 : 0.45)
                        }
                    }
                    .animation(VMotion.gentle, value: stepCount)
                    .transition(.opacity)
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RampStage.card, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .strokeBorder(RampStage.hairline, lineWidth: 1)
            )
            .shadow(color: RampStage.accent.opacity(0.10), radius: 22, y: 10)
            .padding(.horizontal, VSpace.lg)
            .opacity(appeared ? 1 : 0)
            .scaleEffect(appeared ? 1 : 0.96)
            .offset(y: appeared ? 0 : 18)
            .animation(VMotion.gentle, value: showRange)

            Spacer(minLength: 24)

            RampPrimaryButton(title: "See where I land") { onAdvance() }
                .padding(.horizontal, VSpace.lg)
                .opacity(showRange ? 1 : 0)
                .animation(VMotion.gentle, value: showRange)
            Spacer().frame(height: VSpace.xxl)
        }
        .task { await run() }
    }

    private func run() async {
        if reduceMotion {
            appeared = true
            stepCount = steps.count
            try? await Task.sleep(for: .milliseconds(400))
            showRange = true
            return
        }
        withAnimation(VMotion.gentle) { appeared = true }
        try? await Task.sleep(for: .milliseconds(500))
        for index in steps.indices {
            guard !Task.isCancelled else { return }
            withAnimation(VMotion.gentle) { stepCount = index + 1 }
            Haptics.fire(.tick)
            try? await Task.sleep(for: .milliseconds(640))
        }
        try? await Task.sleep(for: .milliseconds(300))
        guard !Task.isCancelled else { return }
        withAnimation(VMotion.gentle) { showRange = true }
        Haptics.fire(.verdictReveal)
    }
}
