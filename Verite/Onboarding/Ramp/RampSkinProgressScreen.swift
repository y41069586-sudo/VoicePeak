import SwiftUI

// ============================================================
// MARK: — The fourteen days, as a schedule rather than a claim
// ============================================================

/// What the next two weeks actually contain, staged day by day.
///
/// THREE THINGS THE FIRST DRAFT GOT WRONG, kept here because each one is easy
/// to reintroduce and expensive to ship.
///
///  1. IT INVENTED FOUR NUMBERS. Redness −40%, clarity +60%, texture +35%,
///     hydration +45%, laid out as four confident tiles. Nothing measured any
///     of them — the scan has not run yet; it runs three screens after this
///     one. Every other screen in this flow refuses to put a figure on an
///     outcome it has not observed (see `RampSawtoothScreen`'s note on why
///     the rising stroke there carries no endpoint label), and four fabricated
///     efficacy percentages in a skincare funnel are also the exact claim a
///     store review or an advertising regulator asks you to substantiate.
///     They are gone. What replaced them is the one thing we can honestly
///     describe: the ORDER events happen in.
///  2. IT ARGUED WITH ITSELF. The headline said fourteen days; the sentence
///     under the photographs said "improvement in 2–3 weeks" — up to twenty
///     one. The screen promised a fortnight and then quietly took it back,
///     inside the same card.
///  3. IT SAID NOTHING ABOUT THIS USER. At the time it sat at step 20, after
///     twenty screens of mirroring their own answers back — and then a page
///     identical for everybody. `headline` was rewritten to open on the
///     duration they gave us, because "years of this, now fourteen days" is
///     an argument and "14 days with SkinFix" is a banner.
///
///     That fix is currently dormant: the screen has since moved to step 1,
///     where nothing has been answered yet, so the headline always takes its
///     `nil` branch. See the note on `headline` — the branches are kept
///     because they cost nothing and come back the moment this screen sits
///     anywhere after `acneDuration` again.
///
/// WHY A SCHEDULE IS THE STRONGER SCREEN. A before and an after state two
/// things and skip the part the reader is actually anxious about: the middle,
/// where nothing appears to be working. Naming days 1–3 as the stretch where
/// nothing shows is worth more than any percentage — it is the week most
/// people quit in, and saying it out loud before they hit it is the single
/// most useful sentence on the page. The fortnight then ends on the app's own
/// mechanic rather than on a promise about their face: day fourteen is the
/// second scan, and the payoff is that they can finally compare.
struct RampSkinProgressScreen: View {
    let answers: RampQuizAnswers
    let onAdvance: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var cardIn = false
    @State private var stepsIn = 0

    var body: some View {
        GeometryReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    Spacer(minLength: RampStage.headerClearance)

                    Text(LocalizedStringKey(headline))
                        .font(RampStage.serif(26, weight: .semibold))
                        .foregroundStyle(RampStage.ink)
                        .lineSpacing(2)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, VSpace.lg)

                    Text("What actually happens, and when.")
                        .font(VType.body)
                        .foregroundStyle(RampStage.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, VSpace.lg)
                        .padding(.top, VSpace.xs)

                    transformationCard
                        .padding(.horizontal, VSpace.lg)
                        .padding(.top, VSpace.lg)
                        .opacity(cardIn ? 1 : 0)
                        .offset(y: cardIn ? 0 : 10)

                    timeline
                        .padding(.horizontal, VSpace.lg)
                        .padding(.top, VSpace.lg)

                    // The hedge sits here rather than inside the card, where an
                    // earlier draft put a two-line version that contradicted
                    // the headline. One line, last, in the smallest type on the
                    // screen: present, honest, not competing with the schedule.
                    Text("A typical fortnight. Yours depends on where you start.")
                        .font(VType.micro)
                        .foregroundStyle(RampStage.textTertiary)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, VSpace.lg)
                        .padding(.top, VSpace.md)

                    Spacer(minLength: VSpace.lg)
                    RampPrimaryButton(title: "Continue") { onAdvance() }
                        .padding(.horizontal, VSpace.lg)
                    Spacer().frame(height: VSpace.xxl)
                }
                .frame(minHeight: proxy.size.height, alignment: .leading)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
        .task { await choreograph() }
    }

    // MARK: The two states

    /// Photographs rather than icons: a sparkle beside a tick is a claim
    /// written in symbols, and on a screen about skin the only evidence that
    /// counts is skin. Circles, so the crop reads as a sample rather than as a
    /// before/after advert, and large enough that the texture survives — at
    /// 80pt the lesions blurred into a pink wash and the pair read as two
    /// colour swatches.
    private var transformationCard: some View {
        HStack(spacing: VSpace.md) {
            progressState(photo: "ProgressBefore", label: "Today", ringed: false)

            Image(systemName: "arrow.right")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(RampStage.accentEdge)
                // The captions hang below the circles, so centring the arrow
                // on the whole stack would drop it off their axis.
                .padding(.bottom, 22)

            progressState(photo: "ProgressAfter", label: "Day 14", ringed: true)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, VSpace.md)
        .padding(.horizontal, VSpace.sm)
        .background(RampStage.accentSoft)
        .cornerRadius(16)
        .accessibilityElement()
        .accessibilityLabel("Skin today, and after fourteen days.")
    }

    /// One circle and its caption. `ringed` marks the far end in accent — the
    /// only difference between the two, so the direction reads before the
    /// labels do.
    private func progressState(photo: String, label: String, ringed: Bool) -> some View {
        VStack(spacing: VSpace.sm) {
            skinCircle(photo)
                .frame(width: Self.circleSize, height: Self.circleSize)
                .clipShape(Circle())
                .overlay {
                    Circle()
                        .strokeBorder(ringed ? RampStage.accentEdge : Color.white.opacity(0.75),
                                      lineWidth: ringed ? 2.5 : 2)
                }
                .shadow(color: RampStage.ink.opacity(0.12), radius: 10, y: 4)

            Text(LocalizedStringKey(label))
                .font(VType.caption)
                .foregroundStyle(ringed ? RampStage.accentDeep : RampStage.textTertiary)
        }
    }

    /// The photo if it shipped, a quiet wash if it did not — a missing asset
    /// must never leave an empty ring on screen.
    @ViewBuilder
    private func skinCircle(_ name: String) -> some View {
        #if canImport(UIKit)
        if let image = RampPhoto.load(name) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
        } else {
            RampStage.accent
        }
        #else
        RampStage.accent
        #endif
    }

    private static let circleSize: CGFloat = 124

    // MARK: The schedule

    private struct Stage {
        let emoji: String
        let days: String
        let lede: String
        let rest: String
    }

    /// Four beats, and the first one is the reason the screen exists.
    ///
    /// Days 1–3 is the stretch where a routine looks like it is failing, and
    /// it is where people abandon one. Promising nothing there — saying, in
    /// advance, that nothing will show and that this is the routine working
    /// rather than not — is worth more than any figure we could print.
    ///
    /// The fortnight then lands on the second scan, not on a face. That is the
    /// one outcome we can actually guarantee: a measurement, next to today's.
    /// Pick emoji that carry a default EMOJI presentation. The first draft used
    /// 🌤 (U+1F324) for "redness settles", which defaults to TEXT presentation
    /// and needs a U+FE0F selector — without one it fell back to a hollow
    /// glyph box. Anything in this list must render in colour unaided, and
    /// must mean its row rather than merely decorate it.
    private static let stages: [Stage] = [
        Stage(emoji: "💧", days: "Days 1–3",
              lede: "Barrier first.",
              rest: "Nothing shows yet — that part is normal."),
        Stage(emoji: "📉", days: "Days 4–7",
              lede: "Fewer new ones.",
              rest: "Spots start arriving less often."),
        Stage(emoji: "🧊", days: "Days 8–11",
              lede: "Redness settles.",
              rest: "What's already there gets quieter."),
        Stage(emoji: "📸", days: "Day 14",
              lede: "Scan two.",
              rest: "Side by side with today — a number, not a feeling."),
    ]

    private var timeline: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(Self.stages.enumerated()), id: \.offset) { index, stage in
                stageRow(stage, isLast: index == Self.stages.count - 1)
                    .opacity(index < stepsIn ? 1 : 0)
                    .offset(x: index < stepsIn ? 0 : -8)
            }
        }
    }

    private func stageRow(_ stage: Stage, isLast: Bool) -> some View {
        HStack(alignment: .top, spacing: VSpace.md) {
            // Marker column. The rail is drawn per row rather than as one line
            // behind the stack, so it stretches with whatever the text beside
            // it wraps to and cannot fall out of step with it.
            VStack(spacing: 0) {
                Text(stage.emoji)
                    .font(.system(size: 15))
                    .frame(width: Self.markerSize, height: Self.markerSize)
                    .background(Circle().fill(RampStage.accentSoft))

                if !isLast {
                    Rectangle()
                        .fill(RampStage.hair)
                        .frame(width: 1.5)
                        .frame(maxHeight: .infinity)
                }
            }
            .fixedSize(horizontal: true, vertical: false)

            VStack(alignment: .leading, spacing: 2) {
                Text(LocalizedStringKey(stage.days))
                    .font(VType.micro)
                    .tracking(1.1)
                    .textCase(.uppercase)
                    .foregroundStyle(RampStage.accentDeep)

                // Lede in semibold, remainder regular, as one wrapping
                // paragraph — two `Text`s in a stack would break the line
                // where the layout wants rather than where the sentence does.
                (Text(LocalizedStringKey(stage.lede)).font(VType.bodyMedium.weight(.semibold))
                 + Text(" ")
                 + Text(LocalizedStringKey(stage.rest)).font(VType.body))
                    .foregroundStyle(RampStage.ink)
                    .fixedSize(horizontal: false, vertical: true)
                    .lineSpacing(1)
            }
            .padding(.bottom, isLast ? 0 : VSpace.md)
        }
        .accessibilityElement(children: .combine)
    }

    private static let markerSize: CGFloat = 30

    // MARK: Copy

    /// Opens on the duration they gave us. "Years of this" earns the fourteen
    /// days that follow it; a generic banner does not.
    ///
    /// AT THE MOMENT ONLY THE `nil` BRANCH EVER RUNS. This screen sits at step
    /// 1, ahead of `acneDuration`, so there is no duration to open on and the
    /// fallback is what everybody reads — write it as the primary headline,
    /// not as a stopgap. The four specific branches are deliberately kept: they
    /// cost nothing, and they light up again the moment this screen is placed
    /// anywhere after the acne chapter.
    private var headline: String {
        switch answers.acneDuration {
        case .months:            return "Months of this.\nNow fourteen days."
        case .aboutAYear:        return "A year of this.\nNow fourteen days."
        case .fewYears:          return "Years of this.\nNow fourteen days."
        case .asLongAsIRemember: return "All that time.\nNow fourteen days."
        case nil:                return "The next\nfourteen days."
        }
    }

    // MARK: Choreography

    /// The card lands, then the schedule writes itself downward, one beat per
    /// stage. Reading order and animation order are the same on purpose — the
    /// point of the screen is the sequence, so it arrives as a sequence.
    private func choreograph() async {
        if reduceMotion {
            cardIn = true
            stepsIn = Self.stages.count
            return
        }

        try? await Task.sleep(for: .milliseconds(180))
        guard !Task.isCancelled else { return }
        withAnimation(VMotion.gentle) { cardIn = true }

        try? await Task.sleep(for: .milliseconds(260))
        for _ in Self.stages.indices {
            guard !Task.isCancelled else { return }
            Haptics.fire(.tick)
            withAnimation(VMotion.snappy) { stepsIn += 1 }
            try? await Task.sleep(for: .milliseconds(190))
        }
    }
}
