import SwiftUI

// ============================================================
// MARK: — Quiz screen (one question, editorial tiles)
// ============================================================

struct RampQuizOption: Identifiable {
    let id: String
    let label: String
    var icon: String? = nil
}

/// Calm question layout: a chapter eyebrow, a serif question, and a stack of
/// airy answer tiles. Selection is the advance — a gentle settle, a soft
/// haptic, and the flow moves on. No "Next", no energy.
struct RampQuizScreen: View {
    /// Editorial chapter label, e.g. "YOUR SKIN · ONE OF THREE".
    var chapter: String? = nil
    let question: String
    /// One optional line under the question. Reserved for questions that
    /// need to say why they're being asked — the emotional ones, where the
    /// user is owed an explanation before they answer honestly.
    var subtitle: String? = nil
    let options: [RampQuizOption]
    let selectedID: String?
    let onSelect: (String) -> Void

    var body: some View {
        // Scroll-safe AND centered at any height: on a short canvas the column
        // scrolls instead of cramming the tiles; on a tall one (e.g. the iPad
        // compatibility window) the flexible spacers expand and keep the
        // question + tiles vertically centred. Floor on the top spacer keeps
        // the header clear of the back chevron + progress line.
        GeometryReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    Spacer(minLength: RampStage.headerClearance)

                    if let chapter {
                        Text(LocalizedStringKey(chapter))
                            .font(VType.micro)
                            .tracking(3)
                            .foregroundStyle(RampStage.accentDeep)
                            .padding(.horizontal, VSpace.lg)
                            .padding(.bottom, VSpace.sm)
                    }

                    Text(LocalizedStringKey(question))
                        .font(RampStage.serif(28))
                        .foregroundStyle(RampStage.ink)
                        .lineSpacing(2)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, VSpace.lg)

                    if let subtitle {
                        Text(LocalizedStringKey(subtitle))
                            .font(VType.body)
                            .foregroundStyle(RampStage.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.horizontal, VSpace.lg)
                            .padding(.top, VSpace.xs)
                    }

                    Spacer().frame(height: VSpace.xl)

                    // No per-tile stagger: the tiles ride in with the screen's
                    // own push. A second entrance animation on top of the
                    // transition is exactly what made the advance feel glitchy.
                    VStack(spacing: VSpace.sm) {
                        ForEach(options) { option in
                            RampOptionCard(
                                label: option.label,
                                icon: option.icon,
                                selected: selectedID == option.id
                            ) {
                                onSelect(option.id)
                            }
                        }
                    }
                    .padding(.horizontal, VSpace.lg)

                    Spacer(minLength: VSpace.xxl)
                }
                .frame(minHeight: proxy.size.height, alignment: .leading)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
    }
}

// ============================================================
// MARK: — Sensitivities (multi-select allergies → routine build)
// ============================================================

/// Multi-select: ingredients the user reacts to. Flagged actives get swapped
/// for gentle alternatives when the 14-day plan is built. "None" clears the
/// rest; picking any active clears "None". Always advanceable (Continue).
struct RampSensitivityScreen: View {
    @Binding var selected: Set<String>
    let onAdvance: () -> Void

    private let options = SkinSensitivity.allCases

    var body: some View {
        GeometryReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    Spacer(minLength: RampStage.headerClearance)

                    Text("YOUR LIFE · FOUR OF SIX")
                        .font(VType.micro).tracking(3)
                        .foregroundStyle(RampStage.accentDeep)
                        .padding(.horizontal, VSpace.lg)
                        .padding(.bottom, VSpace.sm)
                    Text("Anything your skin\nreacts to?")
                        .font(RampStage.serif(28))
                        .foregroundStyle(RampStage.ink)
                        .lineSpacing(2)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, VSpace.lg)
                    Text("We'll build your plan around it — no ingredient you flagged.")
                        .font(VType.body)
                        .foregroundStyle(RampStage.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, VSpace.lg)
                        .padding(.top, VSpace.xs)

                    Spacer().frame(height: VSpace.xl)

                    VStack(spacing: VSpace.sm) {
                        ForEach(options, id: \.rawValue) { option in
                            RampOptionCard(
                                label: option.label,
                                icon: option.icon,
                                selected: selected.contains(option.rawValue)
                            ) {
                                toggle(option.rawValue)
                            }
                        }
                        // "None" — clears every flag.
                        RampOptionCard(
                            label: "Nothing I know of",
                            icon: "checkmark.seal",
                            selected: selected.isEmpty
                        ) {
                            Haptics.fire(.selection)
                            selected.removeAll()
                        }
                    }
                    .padding(.horizontal, VSpace.lg)

                    Spacer(minLength: VSpace.xl)

                    RampPrimaryButton(title: "Continue") { onAdvance() }
                        .padding(.horizontal, VSpace.lg)
                    Spacer().frame(height: VSpace.xxl)
                }
                .frame(minHeight: proxy.size.height, alignment: .leading)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
    }

    private func toggle(_ raw: String) {
        Haptics.fire(.selection)
        if selected.contains(raw) { selected.remove(raw) } else { selected.insert(raw) }
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
            Spacer(minLength: RampStage.headerClearance)

            Text("What should\nwe call you?")
                .font(RampStage.serif(28))
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
                        .strokeBorder(focused ? RampStage.accentEdge : RampStage.hairline, lineWidth: 1)
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
            // After the 480ms push transition — a keyboard sliding up mid-push
            // visibly jolts the settling screen.
            try? await Task.sleep(for: .milliseconds(620))
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
    /// The user's own answers, echoed back as chips that pop in one by one.
    var chips: [String] = []
    let onAdvance: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var photoIn = false
    @State private var eyebrowIn = false
    @State private var chipsShown = 0
    @State private var textIn = false
    @State private var buttonIn = false

    var body: some View {
        // Scroll-safe + centered: floors on the spacers let the column scroll
        // when the canvas is short (no crush), while they still expand to keep
        // the photo/insight balanced on a tall one.
        GeometryReader { proxy in
            ScrollView {
                VStack(spacing: 0) {
                    Spacer(minLength: VSpace.xl)

                    RampPhoto(name: photoName, cornerRadius: 24)
                        .frame(width: 220, height: 293) // 3:4, no crop
                        .opacity(photoIn ? 1 : 0)
                        .scaleEffect(photoIn ? 1 : 0.94)
                        .blur(radius: photoIn ? 0 : 8)

                    Spacer(minLength: VSpace.lg)

                    VStack(spacing: VSpace.md) {
                        Text(LocalizedStringKey(eyebrow))
                            .font(VType.micro)
                            .tracking(3)
                            .foregroundStyle(RampStage.accentDeep)
                            .opacity(eyebrowIn ? 1 : 0)
                            .offset(y: eyebrowIn ? 0 : 6)

                        // The user's answers, echoed back — each pops in on its
                        // own. ViewThatFits keeps them centered when they fit on
                        // one line, falling back to a horizontal scroll only if
                        // they'd overflow.
                        if !chips.isEmpty {
                            let row = HStack(spacing: 7) {
                                ForEach(chips.indices, id: \.self) { i in
                                    Text(LocalizedStringKey(chips[i]))
                                        .font(.system(size: 12.5, weight: .semibold, design: .rounded))
                                        .foregroundStyle(RampStage.accentDeep)
                                        .lineLimit(1)
                                        .padding(.horizontal, 11).padding(.vertical, 6)
                                        .background(RampStage.accentSoft, in: Capsule())
                                        .opacity(i < chipsShown ? 1 : 0)
                                        .scaleEffect(i < chipsShown ? 1 : 0.6)
                                }
                            }
                            ViewThatFits(in: .horizontal) {
                                row
                                ScrollView(.horizontal) { row }
                                    .scrollIndicators(.hidden)
                            }
                        }

                        Text(LocalizedStringKey(insight))
                            .font(RampStage.serif(21, weight: .semibold))
                            .foregroundStyle(RampStage.ink)
                            .multilineTextAlignment(.center)
                            .lineSpacing(4)
                            .fixedSize(horizontal: false, vertical: true)
                            .opacity(textIn ? 1 : 0)
                            .offset(y: textIn ? 0 : 10)
                    }
                    .padding(.horizontal, VSpace.xl)

                    Spacer(minLength: VSpace.lg)

                    RampPrimaryButton(title: "Continue") { onAdvance() }
                        .padding(.horizontal, VSpace.lg)
                        .opacity(buttonIn ? 1 : 0)
                    Spacer(minLength: VSpace.xxl)
                }
                .frame(minHeight: proxy.size.height)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
        .task {
            if reduceMotion {
                photoIn = true; eyebrowIn = true
                chipsShown = chips.count; textIn = true; buttonIn = true
                return
            }
            withAnimation(.easeOut(duration: 0.7)) { photoIn = true }
            try? await Task.sleep(for: .milliseconds(450))
            withAnimation(.easeOut(duration: 0.4)) { eyebrowIn = true }
            Haptics.fire(.selection)
            try? await Task.sleep(for: .milliseconds(240))
            if chips.count > 0 {
                for i in 1...chips.count {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.62)) { chipsShown = i }
                    Haptics.fire(.tick)
                    try? await Task.sleep(for: .milliseconds(270))
                    if Task.isCancelled { return }
                }
            }
            withAnimation(.easeOut(duration: 0.6)) { textIn = true }
            try? await Task.sleep(for: .milliseconds(320))
            withAnimation(.easeOut(duration: 0.4)) { buttonIn = true }
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
        Array([answers.selfRating?.label, answers.acneTypeChip,
               answers.age?.label, answers.routine?.label]
            .compactMap { $0 }
            .prefix(4))
    }

    // Text, not String — Text(verbatim:) on a computed String never localizes.
    private var eyebrow: Text {
        if !showRange { return Text("READING YOUR ANSWERS") }
        if let name = answers.displayName { return Text("\(name.uppercased())'S RANGE") }
        return Text("YOUR RANGE")
    }

    var body: some View {
        // Scroll-safe + centered at any height (short canvas scrolls; tall one
        // keeps the card block centred). The inner GeometryReader further down
        // measures the progress-bar width — distinct from this outer one.
        GeometryReader { outer in
            ScrollView {
                VStack(spacing: 0) {
            Spacer(minLength: 24)

            // ---- Heading ----
            VStack(spacing: VSpace.sm) {
                eyebrow
                    .font(VType.micro)
                    .tracking(3)
                    .foregroundStyle(RampStage.accentDeep)
                    .contentTransition(.opacity)
                (showRange ? Text("Your first estimate\nis ready.") : Text("Building your\nfirst estimate"))
                    .font(RampStage.serif(29))
                    .foregroundStyle(RampStage.ink)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                    .contentTransition(.opacity)
            }
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 12)

            // Fixed gap (not flexible) so the heading and work card stay a
            // single centred block instead of drifting apart on tall canvases.
            Spacer().frame(height: 28)

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
                                    Text(LocalizedStringKey(chip))
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
                                    .overlay(Capsule().strokeBorder(RampStage.accentEdge, lineWidth: 1))
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
                                    .foregroundStyle(done ? RampStage.accentEdge : RampStage.hair)
                                Text(LocalizedStringKey(steps[index]))
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
            .shadow(color: RampStage.ink.opacity(0.10), radius: 22, y: 10)
            .padding(.horizontal, VSpace.lg)
            .opacity(appeared ? 1 : 0)
            .scaleEffect(appeared ? 1 : 0.96)
            .offset(y: appeared ? 0 : 18)
            .animation(VMotion.gentle, value: showRange)

            Spacer(minLength: 24)

            RampPrimaryButton(title: "See where I land") { onAdvance() }
                .padding(.horizontal, VSpace.lg)
                .opacity(showRange ? 1 : 0)
                // Not just invisible — non-tappable until revealed, so a tap in
                // the empty space can't advance the screen before the reading.
                .allowsHitTesting(showRange)
                .animation(VMotion.gentle, value: showRange)
            Spacer(minLength: VSpace.xxl)
                }
                .frame(minHeight: outer.size.height)
            }
            .scrollBounceBehavior(.basedOnSize)
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
