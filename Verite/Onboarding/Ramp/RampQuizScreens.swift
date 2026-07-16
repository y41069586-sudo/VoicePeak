import SwiftUI

// ============================================================
// MARK: — Quiz screen (one question, editorial tiles)
// ============================================================

struct RampQuizOption: Identifiable {
    let id: String
    let label: String
    var icon: String? = nil
    var sub: String? = nil
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

            // No per-tile stagger: the tiles ride in with the screen's own
            // push. A second entrance animation on top of the transition is
            // exactly what made the advance feel glitchy.
            VStack(spacing: VSpace.sm) {
                ForEach(options) { option in
                    RampOptionCard(
                        label: option.label,
                        sub: option.sub,
                        icon: option.icon,
                        selected: selectedID == option.id
                    ) {
                        onSelect(option.id)
                    }
                }
            }
            .padding(.horizontal, VSpace.lg)

            Spacer()
        }
    }
}

// ============================================================
// MARK: — Swipe-stack quiz (tactile single-select)
// ============================================================

/// One card in the swipe deck.
struct RampSwipeOption: Identifiable {
    let id: String
    let label: String
    var icon: String = "circle.fill"
    var sub: String? = nil
}

/// Any single-select question as a swipeable card deck: swipe a card RIGHT to
/// pick it (that IS the answer + advance), LEFT to skip to the next. Far more
/// tactile than a list, and it makes the choice feel like a decision.
struct RampSwipeQuizScreen: View {
    var chapter: String? = nil
    let question: String
    let options: [RampSwipeOption]
    let onSelect: (String) -> Void

    @State private var index = 0
    @State private var drag: CGSize = .zero
    @State private var gone = false
    /// A one-time swipe tutorial — shown on the first swipe screen only.
    @State private var showCoach = !UserDefaults.standard.bool(forKey: "dq.swipeCoachSeen")

    var body: some View {
        VStack(spacing: 0) {
            Spacer().frame(height: VSpace.xxl * 1.3)

            if let chapter {
                Text(LocalizedStringKey(chapter))
                    .font(VType.micro).tracking(3)
                    .foregroundStyle(RampStage.accentDeep)
            }
            Text(LocalizedStringKey(question))
                .font(RampStage.serif(24))
                .foregroundStyle(RampStage.ink)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, VSpace.lg)
                .padding(.top, VSpace.sm)

            Spacer()

            ZStack {
                // The next card peeks behind.
                cardView(options[(index + 1) % options.count])
                    .scaleEffect(0.93)
                    .offset(y: 18)
                    .opacity(0.55)

                // The active card — draggable.
                cardView(options[index])
                    .offset(drag)
                    .rotationEffect(.degrees(Double(drag.width) / 18))
                    .overlay(alignment: .topLeading) {
                        badge("SKIP", color: RampStage.textTertiary,
                              show: drag.width < -30, rotate: -12).padding(20)
                    }
                    .overlay(alignment: .topTrailing) {
                        badge("PICK", color: RampStage.accent,
                              show: drag.width > 30, rotate: 12).padding(20)
                    }
                    .id(index)
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.92).combined(with: .opacity),
                        removal: .opacity))
                    .gesture(
                        DragGesture()
                            .onChanged { v in
                                if showCoach { dismissCoach() }
                                drag = v.translation
                            }
                            .onEnded { g in
                                if g.translation.width > 110 { pick(g.translation.height) }
                                else if g.translation.width < -110 { skip(g.translation.height) }
                                else { withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) { drag = .zero } }
                            }
                    )
            }
            .frame(height: 372)
            .blur(radius: showCoach ? 6 : 0)
            .overlay {
                if showCoach { RampSwipeCoach() }
            }
            .animation(.easeOut(duration: 0.3), value: showCoach)

            Spacer()

            HStack(spacing: 22) {
                Label("SKIP", systemImage: "arrow.left")
                    .foregroundStyle(RampStage.textTertiary)
                Text(verbatim: "\(index + 1) / \(options.count)")
                    .foregroundStyle(RampStage.textSecondary).monospacedDigit()
                Label("PICK", systemImage: "arrow.right")
                    .labelStyle(.trailingIcon)
                    .foregroundStyle(RampStage.accentDeep)
            }
            .font(VType.micro)
            .tracking(1)
            .padding(.bottom, VSpace.xl)
        }
        .task {
            guard showCoach else { return }
            try? await Task.sleep(for: .seconds(2.6))
            if showCoach { dismissCoach() }
        }
    }

    private func pick(_ dy: CGFloat) {
        guard !gone else { return }
        gone = true
        Haptics.fire(.selection)
        withAnimation(.easeIn(duration: 0.28)) { drag = CGSize(width: 720, height: dy) }
        onSelect(options[index].id)
    }

    private func skip(_ dy: CGFloat) {
        Haptics.fire(.tick)
        withAnimation(.easeIn(duration: 0.24)) {
            drag = CGSize(width: -720, height: dy)
        } completion: {
            withAnimation(.spring(response: 0.32, dampingFraction: 0.78)) {
                index = (index + 1) % options.count
                drag = .zero
            }
        }
    }

    private func dismissCoach() {
        UserDefaults.standard.set(true, forKey: "dq.swipeCoachSeen")
        withAnimation(.easeOut(duration: 0.25)) { showCoach = false }
    }

    private func cardView(_ option: RampSwipeOption) -> some View {
        VStack(spacing: 14) {
            Image(systemName: option.icon)
                .font(.system(size: 38, weight: .regular))
                .foregroundStyle(RampStage.accentDeep)
                .frame(width: 92, height: 92)
                .background(RampStage.accentSoft, in: Circle())
            Text(LocalizedStringKey(option.label))
                .font(RampStage.serif(23, weight: .semibold))
                .foregroundStyle(RampStage.ink)
                .multilineTextAlignment(.center)
            if let sub = option.sub {
                Text(LocalizedStringKey(sub))
                    .font(VType.body)
                    .foregroundStyle(RampStage.textSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(28)
        .frame(width: 282, height: 336)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 26, style: .continuous)
            .strokeBorder(RampStage.hairline, lineWidth: 1))
        .shadow(color: RampStage.accent.opacity(0.16), radius: 22, y: 12)
    }

    private func badge(_ text: String, color: Color, show: Bool, rotate: Double) -> some View {
        Text(LocalizedStringKey(text))
            .font(.system(size: 15, weight: .heavy, design: .rounded)).tracking(1)
            .foregroundStyle(color)
            .padding(.horizontal, 12).padding(.vertical, 6)
            .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(color, lineWidth: 2))
            .rotationEffect(.degrees(rotate))
            .opacity(show ? 1 : 0)
    }
}

/// First-run swipe hint. The card behind it is blurred; this just floats a
/// clean "swipe left or right" label with two nudging arrows. Non-interactive,
/// and it auto-dismisses after a couple of seconds (or on the first drag).
private struct RampSwipeCoach: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var spread = false

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 34) {
                Image(systemName: "arrow.left").offset(x: spread ? -6 : 2)
                Image(systemName: "arrow.right").offset(x: spread ? 6 : -2)
            }
            .font(.system(size: 26, weight: .bold))
            .foregroundStyle(RampStage.accentDeep)

            Text("Swipe left or right")
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(RampStage.ink)
        }
        .padding(.horizontal, 22).padding(.vertical, 16)
        .background(Color.white.opacity(0.85), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .shadow(color: RampStage.accent.opacity(0.2), radius: 14, y: 6)
        .allowsHitTesting(false)
        .transition(.opacity)
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) { spread = true }
        }
    }
}

/// A label with its icon on the trailing side (used by the swipe hints).
private struct TrailingIconLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 4) { configuration.title; configuration.icon }
    }
}
extension LabelStyle where Self == TrailingIconLabelStyle {
    static var trailingIcon: TrailingIconLabelStyle { TrailingIconLabelStyle() }
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
        VStack(spacing: 0) {
            Spacer().frame(height: VSpace.xxl * 1.3)

            RampPhoto(name: photoName, cornerRadius: 24)
                .frame(width: 220, height: 293) // 3:4, no crop
                .opacity(photoIn ? 1 : 0)
                .scaleEffect(photoIn ? 1 : 0.94)
                .blur(radius: photoIn ? 0 : 8)

            Spacer()

            VStack(spacing: VSpace.md) {
                Text(LocalizedStringKey(eyebrow))
                    .font(VType.micro)
                    .tracking(3)
                    .foregroundStyle(RampStage.accentDeep)
                    .opacity(eyebrowIn ? 1 : 0)
                    .offset(y: eyebrowIn ? 0 : 6)

                // The user's answers, echoed back — each pops in on its own.
                // ViewThatFits keeps them centered when they fit on one line,
                // and only falls back to a horizontal scroll if they'd overflow.
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

            Spacer()

            RampPrimaryButton(title: "Continue") { onAdvance() }
                .padding(.horizontal, VSpace.lg)
                .opacity(buttonIn ? 1 : 0)
            Spacer().frame(height: VSpace.xxl)
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
        Array([answers.selfRating?.label, answers.concern?.label,
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
