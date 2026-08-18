import SwiftUI
import AuthenticationServices
import GoogleSignIn

// ============================================================
// MARK: — Screen 9: The Curve (where do you land?)
// ============================================================

/// Social comparison without a single fabricated testimonial (App Review
/// 2.3.1-safe): a population curve that draws itself live, then lights up the
/// user's own predicted band — with a "?" that keeps drifting inside it and
/// never settles, because only a scan can place it. Haptic ticks ride the
/// draw; a milestone pulse lands with the band.
///
/// NOTE: deliberately NO review prompt here — Apple 5.6.3 forbids rating asks
/// during onboarding. The ask lives post-scan (results, 3rd+ completed scan).
struct RampCurveScreen: View {
    let answers: RampQuizAnswers
    let onAdvance: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var bandShown = false

    private var range: (low: Int, high: Int) { answers.predictedRange }

    // Returns Text (not String) so the name interpolation goes through the
    // string catalog — a computed String would render as raw English.
    private var headline: Text {
        if let name = answers.displayName { return Text("Where do you\nland, \(name)?") }
        return Text("Where do\nyou land?")
    }

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: VSpace.md) {
                headline
                    .font(RampStage.serif(26, weight: .semibold))
                    .foregroundStyle(RampStage.ink)
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
                Text("Every score forms a curve. Yours is the one point still missing.")
                    .font(VType.bodyLarge)
                    .foregroundStyle(RampStage.textSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, VSpace.xl)

            RampDistributionCurve(range: range, startDelay: Self.drawStartDelay)
                .padding(.horizontal, VSpace.lg)
                .padding(.top, VSpace.lg)

            // The estimate echoed under its own band — lands with the pulse.
            Text("Your estimated range: \(range.low) – \(range.high)")
                .font(VType.caption)
                .foregroundStyle(RampStage.accentDeep)
                .padding(.top, VSpace.sm)
                .opacity(bandShown ? 1 : 0)
                .offset(y: bandShown ? 0 : 6)

            HStack(spacing: VSpace.md) {
                RampMiniClaim(icon: "lock.fill", text: "Secure & private")
                RampMiniClaim(icon: "square.grid.3x3.fill", text: "7 metrics")
                RampMiniClaim(icon: "gauge.with.dots.needle.bottom.50percent", text: "Honest 0–100")
            }
            .padding(.horizontal, VSpace.lg)
            .padding(.top, VSpace.lg)

            Spacer()

            RampPrimaryButton(title: "Find my spot") { onAdvance() }
                .padding(.horizontal, VSpace.lg)
            Spacer().frame(height: VSpace.xxl)
        }
        .task { await choreograph() }
    }

    /// The draw waits for the screen's own entrance (spring + stagger) so the
    /// user actually sees the line grow instead of it finishing invisibly.
    static let drawStartDelay: Double = 0.65

    /// Haptic ticks riding the curve draw, then a milestone pulse as the
    /// user's band lights up (timed to RampDistributionCurve's constants).
    private func choreograph() async {
        if reduceMotion {
            bandShown = true
            return
        }
        try? await Task.sleep(for: .milliseconds(Int(Self.drawStartDelay * 1000)))
        guard !Task.isCancelled else { return }
        let drawMs = Int(RampDistributionCurve.drawDuration * 1000)
        for _ in 1...3 {
            try? await Task.sleep(for: .milliseconds(drawMs / 4))
            guard !Task.isCancelled else { return }
            Haptics.fire(.tick)
        }
        try? await Task.sleep(for: .milliseconds(
            drawMs / 4 + Int(RampDistributionCurve.bandDelay * 1000)))
        guard !Task.isCancelled else { return }
        Haptics.fire(.milestone)
        withAnimation(VMotion.gentle) { bandShown = true }
    }
}

private struct RampMiniClaim: View {
    let icon: String
    let text: String

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .regular))
                .foregroundStyle(RampStage.accentDeep)
            Text(LocalizedStringKey(text))
                .font(VType.micro)
                .foregroundStyle(RampStage.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, VSpace.sm)
        .background(RampStage.card, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .rampCardShadow()
    }
}

// ============================================================
// MARK: — Screen: The science (proven actives, tappable sources)
// ============================================================

/// Right after the plan preview: WHY this plan is trustworthy. Each row is a
/// real, peer-reviewed finding behind one of the plan's actives, with the
/// actual study tappable (opens in the browser). No vague "dermatologist
/// approved" fluff — named journals, real trials.
struct RampEvidenceScreen: View {
    let onAdvance: () -> Void

    private struct Evidence: Identifiable {
        let icon: String
        let active: String
        let claim: String
        let source: String
        let url: URL
        var id: String { active }
    }

    private let items: [Evidence] = [
        Evidence(icon: "sun.max.fill",
                 active: "Daily SPF",
                 claim: "Slowed visible skin aging in a randomized trial.",
                 source: "Annals of Internal Medicine",
                 url: URL(string: "https://pubmed.ncbi.nlm.nih.gov/23732711/")!),
        Evidence(icon: "moon.stars.fill",
                 active: "Retinal",
                 claim: "Reduced breakouts in an 8-week randomized trial.",
                 source: "Clinical & Experimental Dermatology",
                 url: URL(string: "https://academic.oup.com/ced/article-abstract/24/5/354/6627773")!),
        Evidence(icon: "drop.halffull",
                 active: "Azelaic acid",
                 claim: "51% improvement across 1,624 patients in a meta-analysis.",
                 source: "Systematic review · PubMed",
                 url: URL(string: "https://pubmed.ncbi.nlm.nih.gov/37550898/")!),
        Evidence(icon: "circle.lefthalf.filled",
                 active: "Tranexamic acid",
                 claim: "Faded dark spots in a systematic review, with fewer side effects.",
                 source: "Systematic review · PMC",
                 url: URL(string: "https://pmc.ncbi.nlm.nih.gov/articles/PMC9805721/")!),
    ]

    var body: some View {
        VStack(spacing: 0) {
            Spacer().frame(height: VSpace.xxl + VSpace.md)

            VStack(spacing: VSpace.sm) {
                Text("BACKED BY SCIENCE")
                    .font(VType.micro)
                    .tracking(3)
                    .foregroundStyle(RampStage.accentDeep)
                Text("Real actives,\nreal research.")
                    .font(RampStage.serif(26, weight: .semibold))
                    .foregroundStyle(RampStage.ink)
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
                Text("Every active in your plan comes from published, peer-reviewed research.")
                    .font(VType.caption)
                    .foregroundStyle(RampStage.textSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, VSpace.xl)
            }

            Spacer().frame(height: VSpace.lg)

            // Four cards + footnote exceed an SE-class screen in German —
            // scrolls only when it must.
            ScrollView {
                VStack(spacing: 10) {
                    ForEach(items) { item in
                        evidenceCard(item)
                    }
                    Text("Studies open in your browser.")
                        .font(VType.micro)
                        .foregroundStyle(RampStage.textTertiary)
                        .padding(.top, VSpace.sm)
                }
                .padding(.horizontal, VSpace.lg)
            }
            .scrollBounceBehavior(.basedOnSize)
            .scrollIndicators(.hidden)

            Spacer().frame(height: VSpace.md)

            RampPrimaryButton(title: "Good to know") { onAdvance() }
                .padding(.horizontal, VSpace.lg)
            Spacer().frame(height: VSpace.xxl)
        }
    }

    private func evidenceCard(_ item: Evidence) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 10) {
                Image(systemName: item.icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(RampStage.accentDeep)
                    .frame(width: 30, height: 30)
                    .background(RampStage.accentSoft, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                Text(LocalizedStringKey(item.active))
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(RampStage.ink)
                Spacer(minLength: 0)
            }
            Text(LocalizedStringKey(item.claim))
                .font(VType.caption)
                .foregroundStyle(RampStage.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            // The actual study — tappable, clearly marked as external.
            Link(destination: item.url) {
                HStack(spacing: 5) {
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.system(size: 10, weight: .semibold))
                    Text(LocalizedStringKey(item.source))
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .lineLimit(1)
                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 9, weight: .bold))
                }
                .foregroundStyle(RampStage.accentDeep)
                .padding(.horizontal, 9).padding(.vertical, 5)
                .background(RampStage.accentSoft.opacity(0.7), in: Capsule())
            }
        }
        .padding(13)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RampStage.card, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .rampCardShadow()
    }
}

// ============================================================
// MARK: — Screen 10: Daily ritual (notifications, reframed)
// ============================================================

/// Custom screen BEFORE the system dialog — a denied system prompt is
/// unrecoverable, so the real request only fires from the primary button.
/// The user picks a concrete time FIRST (implementation intention: a chosen
/// "when" measurably outperforms a generic "daily"), then grants permission.
struct RampDailyReportScreen: View {
    let onAdvance: () -> Void

    private enum RitualTime: String, CaseIterable {
        case morning, evening
        var label: String { self == .morning ? "Morning" : "Evening" }
        var sub: String { self == .morning ? "With your routine, 8:00" : "Wind-down check, 21:00" }
        var icon: String { self == .morning ? "sun.min" : "moon" }
        /// PM-reminder time handed to the scheduler (the AM nudge is fixed at
        /// 8:00) — earlier for morning people, later for evening people.
        var pmHour: (hour: Int, minute: Int) { self == .morning ? (19, 0) : (21, 0) }
    }

    @State private var time: RitualTime = .evening
    @State private var requesting = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: VSpace.md) {
                Text("A gentle note,\nonce a day.")
                    .font(RampStage.serif(26, weight: .semibold))
                    .foregroundStyle(RampStage.ink)
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
                Text("A plan only works on the days you do it. When should yours check in?")
                    .font(VType.bodyLarge)
                    .foregroundStyle(RampStage.textSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, VSpace.xl)

            Spacer().frame(height: VSpace.xl)

            HStack(spacing: VSpace.sm) {
                ForEach(RitualTime.allCases, id: \.self) { option in
                    timeTile(option)
                }
            }
            .padding(.horizontal, VSpace.lg)

            // What you'll actually receive — an honest preview of the nudge,
            // rendered as a system-style banner. Updates with the choice.
            notificationPreview
                .padding(.horizontal, VSpace.lg)
                .padding(.top, VSpace.md)

            Spacer()

            VStack(spacing: VSpace.sm) {
                RampPrimaryButton(title: "Enable reminders", isEnabled: !requesting) {
                    guard !requesting else { return }
                    requesting = true
                    let chosen = time
                    Task {
                        let granted = await NotificationManager.requestAuthorization()
                        // Remember the wish + chosen time, but DON'T arm the
                        // reminders yet — there's no plan until the first scan,
                        // and a locked (non-Pro) plan must never get pinged.
                        // syncReminders arms the right one once state is known.
                        let pm = chosen.pmHour
                        NotificationManager.setRoutinePreference(enabled: granted,
                                                                 pmHour: pm.hour,
                                                                 pmMinute: pm.minute)
                        RampAnalytics.track("onboarding_notifications",
                                            ["choice": "enable",
                                             "time": chosen.rawValue,
                                             "granted": String(granted)])
                        onAdvance()
                    }
                }
                RampGhostButton(title: "Not now") {
                    RampAnalytics.track("onboarding_notifications", ["choice": "not_now"])
                    onAdvance()
                }
            }
            .padding(.horizontal, VSpace.lg)
            Spacer().frame(height: VSpace.xxl)
        }
    }

    /// A faux notification banner — exactly what the chosen reminder will say.
    private var notificationPreview: some View {
        HStack(spacing: 10) {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(RampStage.accent)
                .frame(width: 34, height: 34)
                .overlay(
                    Text(verbatim: "G")
                        .font(.system(size: 17, weight: .heavy, design: .serif))
                        // Ink: white on the beige app tile is 1.7:1.
                        .foregroundStyle(RampStage.ink)
                )
            VStack(alignment: .leading, spacing: 1) {
                HStack {
                    Text(verbatim: "SkinFix")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(RampStage.ink)
                    Spacer()
                    Text(verbatim: time == .morning ? "8:00" : "21:00")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(RampStage.textTertiary)
                }
                (time == .morning
                 ? Text("Morning ritual — 3 steps, 4 minutes.")
                 : Text("Evening ritual — 3 steps before bed."))
                    .font(.system(size: 12.5, weight: .medium, design: .rounded))
                    .foregroundStyle(RampStage.textSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(RampStage.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .rampCardShadow()
        .animation(VMotion.gentle, value: time)
        .accessibilityLabel("Preview of your daily reminder")
    }

    private func timeTile(_ option: RitualTime) -> some View {
        let selected = time == option
        return Button {
            Haptics.fire(.selection)
            time = option
        } label: {
            VStack(spacing: 6) {
                Image(systemName: option.icon)
                    .font(.system(size: 18, weight: .regular))
                    .foregroundStyle(selected ? RampStage.accentDeep : RampStage.textTertiary)
                Text(LocalizedStringKey(option.label))
                    .font(VType.bodyMedium)
                    .foregroundStyle(selected ? RampStage.accentDeep : RampStage.ink)
                Text(LocalizedStringKey(option.sub))
                    .font(VType.micro)
                    .foregroundStyle(RampStage.textTertiary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, VSpace.md)
            .background(selected ? RampStage.accentSoft : RampStage.card,
                        in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(selected ? RampStage.accentEdge : RampStage.hair,
                                  lineWidth: selected ? 2 : 1)
            )
        }
        .buttonStyle(PressableStyle())
        .animation(VMotion.gentle, value: time)
    }
}

// ============================================================
// MARK: — Screen: Your first plan (preview)
// ============================================================

/// Shows the shape of the deliverable BEFORE the commitment screens: a Day-1
/// preview of the 14-day plan. Illustrative, clearly labeled — the real one
/// is built from the scan. The user's own quiz answers surface INSIDE the
/// card (their acne-type answer names the evening active; SPF answer shapes
/// the AM line) so the preview reads as "already mine", not a template.
struct RampPlanPreviewScreen: View {
    let answers: RampQuizAnswers
    let onAdvance: () -> Void

    private struct Step { let title: String; let sub: String }

    private var morning: [Step] {
        [Step(title: "Gentle cleanser", sub: "Low-pH, non-stripping"),
         Step(title: "Hydrating serum", sub: "Hyaluronic acid + B5"),
         answers.spf == .daily
            ? Step(title: "Your SPF, kept", sub: "SPF 30+, every morning")
            : Step(title: "SPF 50", sub: "New — your biggest lever")]
    }

    private var evening: [Step] {
        [Step(title: "Cleanser", sub: "Lifts the day's residue"),
         concernActive,
         Step(title: "Moisturizer", sub: "Barrier repair, overnight")]
    }

    /// The middle evening step is built from their acne-type answer — the
    /// most specific signal onboarding collects, and the one `acneType`
    /// replaced the old broad "concern" question with. Priority follows
    /// severity: a user who picked more than one type gets the routine for
    /// the more serious one.
    private var concernActive: Step {
        let types = answers.acneTypes
        if types.contains("cysts") {
            return Step(title: "Deep-acne active", sub: "Adapalene 0.1%")
        } else if types.contains("papules") {
            return Step(title: "Blemish active", sub: "Benzoyl peroxide")
        } else if types.contains("blackheads") || types.contains("whiteheads") {
            return Step(title: "Pore-clearing active", sub: "Salicylic acid · BHA")
        } else if types.contains("scars") {
            return Step(title: "Scar-fading active", sub: "Vitamin C")
        } else {
            return Step(title: "Targeted active", sub: "Chosen from your scan")
        }
    }

    private var focusChip: String? { answers.acneTypeChip }

    var body: some View {
        VStack(spacing: 0) {
            // The whole reading area scrolls when the window is short, so the
            // two block cards never crush together — yet on a tall phone the
            // flexible spacers still expand and keep the content centered.
            GeometryReader { proxy in
                ScrollView {
                    VStack(spacing: 0) {
                        // Clear the status bar + progress line so the eyebrow never clips.
                        Spacer().frame(height: VSpace.xxl + VSpace.md)

                        VStack(spacing: VSpace.sm) {
                            Text("AFTER YOUR SCAN")
                                .font(VType.micro)
                                .tracking(3)
                                .foregroundStyle(RampStage.accentDeep)
                            Text("Your first plan,\nready in seconds.")
                                .font(RampStage.serif(26, weight: .semibold))
                                .foregroundStyle(RampStage.ink)
                                .multilineTextAlignment(.center)
                                .lineSpacing(2)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(.horizontal, VSpace.xl)

                        // Day-1 + focus chip row.
                        HStack(spacing: 8) {
                            Text("DAY 1")
                                .font(VType.micro).tracking(2)
                                .foregroundStyle(RampStage.textTertiary)
                            if let focusChip {
                                (Text("For:") + Text(verbatim: " ") + Text(LocalizedStringKey(focusChip)))
                                    .font(VType.micro).tracking(1.5)
                                    .textCase(.uppercase)
                                    .foregroundStyle(RampStage.accentDeep)
                                    .padding(.horizontal, 8).padding(.vertical, 3)
                                    .background(RampStage.accentSoft, in: Capsule())
                            }
                        }
                        .padding(.top, VSpace.md)

                        Spacer(minLength: VSpace.xl)

                        VStack(spacing: 14) {
                            blockCard(icon: "sun.max.fill", title: "Morning",
                                      subtitle: "After you wake up", steps: morning)
                            blockCard(icon: "moon.stars.fill", title: "Evening",
                                      subtitle: "Before bed", steps: evening)
                        }
                        .padding(.horizontal, VSpace.lg)

                        HStack(spacing: 6) {
                            Image(systemName: "checkmark.seal")
                                .font(.system(size: 11, weight: .semibold))
                            Text("Built from your scan — not a template.")
                                .font(VType.micro)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .foregroundStyle(RampStage.accentDeep)
                        .padding(.top, VSpace.md)

                        Spacer(minLength: VSpace.lg)
                    }
                    .frame(minHeight: proxy.size.height)
                }
                .scrollBounceBehavior(.basedOnSize)
            }

            RampPrimaryButton(title: "Sounds good") { onAdvance() }
                .padding(.horizontal, VSpace.lg)
                .padding(.top, VSpace.sm)
            Spacer().frame(height: VSpace.xxl)
        }
    }

    /// One AM/PM block, mirroring the real routine tab's card.
    private func blockCard(icon: String, title: LocalizedStringKey,
                           subtitle: LocalizedStringKey, steps: [Step]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(RampStage.accentDeep)
                    .frame(width: 32, height: 32)
                    .background(RampStage.accentSoft,
                                in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(RampStage.ink)
                    Text(subtitle)
                        .font(VType.micro)
                        .foregroundStyle(RampStage.textTertiary)
                }
                Spacer()
            }
            ForEach(steps.indices, id: \.self) { i in
                HStack(spacing: 11) {
                    Circle()
                        .strokeBorder(RampStage.hair, lineWidth: 1.5)
                        .frame(width: 20, height: 20)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(LocalizedStringKey(steps[i].title))
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .foregroundStyle(RampStage.ink)
                        Text(LocalizedStringKey(steps[i].sub))
                            .font(VType.micro)
                            .foregroundStyle(RampStage.textSecondary)
                    }
                    Spacer(minLength: 0)
                }
            }
        }
        .padding(VSpace.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: RampStage.ink.opacity(0.12), radius: 16, y: 8)
    }
}

// ============================================================
// MARK: — Screen: The commitment (sign your 14 days)
// ============================================================

/// The ONE deliberate exception to "every primary CTA is the skin→blemish
/// gradient." Every other screen in the flow uses `RampPrimaryButton` on
/// purpose — identical weight everywhere means the user never has to wonder
/// which tap matters more. But that sameness has a cost across 26 screens:
/// the single most invested moment in the whole flow (signing 14 days) reads
/// exactly like tapping "Sun protection?".
///
/// So this one goes the other way — no gradient, the palette's deepest
/// colour at full strength, taller, with a heavier shadow under it. It is
/// the most saturated shape anywhere in the flow, which is what makes the
/// signature moment read as the peak it actually is. Do not reuse this
/// elsewhere — a second "special" button anywhere else erases the point of
/// having one.
struct RampCommitButton: View {
    let title: String
    var isEnabled: Bool = true
    let action: () -> Void

    var body: some View {
        Button {
            Haptics.fire(.selection)
            action()
        } label: {
            Text(LocalizedStringKey(title))
                .font(.system(size: 18, weight: .heavy, design: .rounded))
                .foregroundStyle(Color.white)
                .frame(maxWidth: .infinity, minHeight: 64)
                .background(RampStage.accentDeep,
                            in: RoundedRectangle(cornerRadius: 30, style: .continuous))
                .shadow(color: RampStage.accentDeep.opacity(isEnabled ? 0.45 : 0), radius: 26, y: 12)
                .opacity(isEnabled ? 1 : 0.35)
        }
        .buttonStyle(PressableStyle())
        .disabled(!isEnabled)
    }
}

/// The strongest retention mechanic in consumer onboarding: a literal
/// signature. The user signs their 14 days with a finger — a contract with
/// themselves, not with us. Honesty guarantees: the drawing never leaves this
/// screen (only a signed yes/no goes to analytics), and the step is skippable.
struct RampCommitmentScreen: View {
    let name: String?
    let onAdvance: () -> Void

    @State private var strokes: [[CGPoint]] = []
    @State private var sealed = false

    private var signed: Bool {
        strokes.reduce(0) { $0 + $1.count } >= 12
    }

    // Text, not String — so the name interpolation localizes via the catalog.
    private var headline: Text {
        if let name { return Text("Make it official,\n\(name).") }
        return Text("Make it\nofficial.")
    }

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: VSpace.md) {
                Text("YOUR 14-DAY COMMITMENT")
                    .font(VType.micro)
                    .tracking(3)
                    .foregroundStyle(RampStage.accentDeep)
                headline
                    .font(RampStage.serif(26, weight: .semibold))
                    .foregroundStyle(RampStage.ink)
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
                Text("14 days, morning and evening.\nSign it — for yourself, not for us.")
                    .font(VType.bodyLarge)
                    .foregroundStyle(RampStage.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, VSpace.xl)

            Spacer().frame(height: VSpace.xl)

            signaturePad
                .padding(.horizontal, VSpace.lg)

            Text("Your signature stays on this screen — never stored, never uploaded.")
                .font(VType.micro)
                .foregroundStyle(RampStage.textTertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, VSpace.xl)
                .padding(.top, VSpace.sm)

            Spacer()

            VStack(spacing: VSpace.sm) {
                RampCommitButton(title: "I'm in for 14 days", isEnabled: signed && !sealed) {
                    guard !sealed else { return }
                    sealed = true
                    Haptics.fire(.verdictReveal)
                    RampAnalytics.track("onboarding_commitment", ["signed": "true"])
                    onAdvance()
                }
                RampGhostButton(title: "Not now") {
                    RampAnalytics.track("onboarding_commitment", ["signed": "false"])
                    onAdvance()
                }
            }
            .padding(.horizontal, VSpace.lg)
            Spacer().frame(height: VSpace.xxl)
        }
        .animation(VMotion.gentle, value: signed)
    }

    // MARK: The pad

    private var signaturePad: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color.white.opacity(0.8))
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(signed ? RampStage.accentEdge : RampStage.hairline,
                              lineWidth: signed ? 1.5 : 1)

            // Baseline + hint, fading once ink lands.
            VStack {
                Spacer()
                Rectangle()
                    .fill(RampStage.hair.opacity(0.8))
                    .frame(height: 1)
                    .padding(.horizontal, 28)
                (strokes.isEmpty ? Text("Sign with your finger") : Text(verbatim: " "))
                    .font(RampStage.serif(15))
                    .foregroundStyle(RampStage.textTertiary)
                    .padding(.top, 8)
                    .padding(.bottom, 18)
            }
            .opacity(strokes.isEmpty ? 1 : 0.4)

            SignatureCanvas(strokes: $strokes)

            // Clear, once there is something to clear.
            if !strokes.isEmpty {
                VStack {
                    HStack {
                        Spacer()
                        Button {
                            Haptics.fire(.selection)
                            strokes.removeAll()
                        } label: {
                            Image(systemName: "arrow.counterclockwise")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(RampStage.textSecondary)
                                .frame(width: 32, height: 32)
                                .background(RampStage.card, in: Circle())
                                .overlay(Circle().strokeBorder(RampStage.hairline, lineWidth: 1))
                        }
                        .accessibilityLabel("Clear signature")
                        .padding(10)
                    }
                    Spacer()
                }
                .transition(.opacity)
            }
        }
        .frame(height: 190)
        .shadow(color: RampStage.ink.opacity(signed ? 0.18 : 0.08), radius: 18, y: 8)
        .animation(VMotion.gentle, value: strokes.isEmpty)
    }
}

/// Finger-ink capture: strokes render live in a Canvas; nothing is persisted.
private struct SignatureCanvas: View {
    @Binding var strokes: [[CGPoint]]
    @State private var current: [CGPoint] = []

    var body: some View {
        Canvas { context, _ in
            for stroke in strokes + (current.isEmpty ? [] : [current]) {
                guard let first = stroke.first else { continue }
                var path = Path()
                path.move(to: first)
                for point in stroke.dropFirst() {
                    path.addLine(to: point)
                }
                context.stroke(path, with: .color(RampStage.ink),
                               style: StrokeStyle(lineWidth: 2.4, lineCap: .round, lineJoin: .round))
            }
        }
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    if current.isEmpty { Haptics.fire(.tick) }
                    current.append(value.location)
                }
                .onEnded { _ in
                    if !current.isEmpty {
                        strokes.append(current)
                        current = []
                    }
                }
        )
    }
}

// ============================================================
// MARK: — Screen: Register (before the first scan)
// ============================================================

/// A dedicated, unhurried registration screen right before the scan — its own
/// full canvas, only Apple + Google, plenty of breathing room. Apple keeps the
/// black wordmark button; Google carries its authentic multicolor "G".
///
/// Both buttons perform REAL authentication: Apple via the system
/// SignInWithAppleButton (identity token handed to Supabase), and Google via
/// the GoogleSignIn SDK — the Google button only appears when it's configured
/// (featureFlags.googleSignInEnabled), so no non-functional button ever ships.
/// Sign-in is optional: "Not now" skips it and the app is fully usable locally.
struct RampSignInScreen: View {
    /// Reports an optional given name (Sign in with Apple supplies one once,
    /// on first authorization).
    let onSignedIn: (String?) -> Void
    let onSkip: () -> Void

    @Environment(AppState.self) private var appState
    @Environment(PurchaseManager.self) private var purchases
    @Environment(\.modelContext) private var modelContext
    @State private var shown = false
    /// Raw nonce for the in-flight Apple request; its SHA-256 goes in the request.
    @State private var currentNonce: String?
    @State private var authError = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // Soft emblem — a blush disc with a single coral mark.
            ZStack {
                Circle()
                    .fill(RampStage.dawnPeach)
                    .frame(width: 108, height: 108)
                Circle()
                    .strokeBorder(RampStage.glow, lineWidth: 1)
                    .frame(width: 108, height: 108)
                Image(systemName: "lock.fill")
                    .font(.system(size: 38, weight: .regular))
                    .foregroundStyle(RampStage.accentDeep)
            }
            .opacity(shown ? 1 : 0)
            .scaleEffect(shown ? 1 : 0.9)

            Spacer().frame(height: VSpace.xl)

            VStack(spacing: VSpace.md) {
                Text("CREATE YOUR ACCOUNT")
                    .font(VType.micro)
                    .tracking(3)
                    .foregroundStyle(RampStage.accentDeep)
                Text("Register before\nyour first scan.")
                    .font(RampStage.serif(30))
                    .foregroundStyle(RampStage.ink)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                Text("So your readings and your 14-day plan\nare always yours — on any device.")
                    .font(VType.body)
                    .foregroundStyle(RampStage.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, VSpace.xl)
            .opacity(shown ? 1 : 0)
            .offset(y: shown ? 0 : 10)

            Spacer()

            VStack(spacing: VSpace.md) {
                // Apple — the real system button (correct request + credential
                // handling); we only supply the nonce and consume the result.
                SignInWithAppleButton(.continue) { request in
                    let nonce = AppleSignIn.randomNonce()
                    currentNonce = nonce
                    request.requestedScopes = [.fullName, .email]
                    request.nonce = AppleSignIn.sha256(nonce)
                } onCompletion: { result in
                    handleApple(result)
                }
                .signInWithAppleButtonStyle(.black)
                .frame(height: 58)
                .clipShape(Capsule())

                // Google — only when configured (GoogleSignIn SDK + client IDs).
                // Hidden otherwise, so no non-functional button ever ships.
                if appState.featureFlags.googleSignInEnabled {
                    Button {
                        handleGoogle()
                    } label: {
                        HStack(spacing: 10) {
                            GoogleGLogo()
                                .frame(width: 20, height: 20)
                            Text("Continue with Google")
                        }
                        .font(.system(size: 17, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color(red: 0.23, green: 0.23, blue: 0.24))
                        .frame(maxWidth: .infinity, minHeight: 58)
                        .background(Color.white, in: Capsule())
                        .overlay(Capsule().strokeBorder(RampStage.hairline, lineWidth: 1))
                    }
                    .buttonStyle(PressableStyle())
                }

                RampGhostButton(title: "Not now") {
                    RampAnalytics.track("onboarding_sign_in", ["provider": "none"])
                    onSkip()
                }
                .padding(.top, VSpace.xs)
            }
            .padding(.horizontal, VSpace.lg)
            .opacity(shown ? 1 : 0)

            Spacer().frame(height: VSpace.xxl)
        }
        .task {
            try? await Task.sleep(for: .milliseconds(150))
            withAnimation(.easeOut(duration: 0.7)) { shown = true }
        }
        .alert("Sign-in didn’t complete", isPresented: $authError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Please try again, or tap Not now to continue.")
        }
    }

    /// Real Sign in with Apple. The system button already performed the auth;
    /// we hand the identity token to Supabase (best effort — the app is fully
    /// usable locally, so a backend hiccup never blocks the user) and advance.
    private func handleApple(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .failure:
            return  // canceled or failed — user can retry or tap "Not now"
        case .success(let auth):
            guard let cred = auth.credential as? ASAuthorizationAppleIDCredential,
                  let tokenData = cred.identityToken,
                  let idToken = String(data: tokenData, encoding: .utf8),
                  let nonce = currentNonce else {
                authError = true
                return
            }
            let given = cred.fullName?.givenName
            RampAnalytics.track("onboarding_sign_in", ["provider": "apple"])
            Haptics.fire(.milestone)
            Task {
                let user = try? await appState.backend.signInWithApple(idToken: idToken, nonce: nonce)
                // Tie purchases to the account (cross-device entitlements).
                if let user { await purchases.logIn(appUserID: user.id) }
                await MainActor.run {
                    // Cross-device restore of the score history, then push the merge back up.
                    BackendSync.restoreThenUpload(backend: appState.backend, context: modelContext)
                    onSignedIn(given)
                }
            }
        }
    }

    /// Real Google sign-in via the GoogleSignIn SDK. GIDClientID +
    /// GIDServerClientID are read from Info.plist automatically, so we only
    /// present, read the ID token, and hand it to Supabase.
    private func handleGoogle() {
        guard let presenter = Self.topViewController() else { authError = true; return }
        RampAnalytics.track("onboarding_sign_in", ["provider": "google"])
        Task {
            do {
                let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: presenter)
                guard let idToken = result.user.idToken?.tokenString else {
                    await MainActor.run { authError = true }
                    return
                }
                let given = result.user.profile?.givenName
                let user = try? await appState.backend.signInWithGoogle(idToken: idToken)
                if let user { await purchases.logIn(appUserID: user.id) }
                await MainActor.run {
                    BackendSync.restoreThenUpload(backend: appState.backend, context: modelContext)
                    Haptics.fire(.milestone); onSignedIn(given)
                }
            } catch {
                // User canceled or the sheet failed — stay on the screen.
            }
        }
    }

    /// The top-most view controller, needed to present Google's consent sheet
    /// from SwiftUI.
    private static func topViewController() -> UIViewController? {
        let scene = UIApplication.shared.connectedScenes
            .first { $0.activationState == .foregroundActive } as? UIWindowScene
        var top = scene?.keyWindow?.rootViewController
        while let presented = top?.presentedViewController { top = presented }
        return top
    }
}

// ============================================================
// MARK: — Google "G" mark (authentic four colors)
// ============================================================

/// The recognizable Google "G" drawn as four arc segments in the brand palette
/// (blue #4285F4, green #34A853, yellow #FBBC05, red #EA4335) plus the blue
/// crossbar. This is a hand-built approximation for the mock button — if real
/// Google Sign-In is wired up, replace it with Google's official asset to stay
/// within their branding guidelines.
struct GoogleGLogo: View {
    private let blue   = Color(red: 0.259, green: 0.522, blue: 0.957) // #4285F4
    private let green  = Color(red: 0.204, green: 0.659, blue: 0.325) // #34A853
    private let yellow = Color(red: 0.984, green: 0.737, blue: 0.020) // #FBBC05
    private let red    = Color(red: 0.918, green: 0.263, blue: 0.208) // #EA4335

    var body: some View {
        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height)
            let lw = side * 0.22
            let center = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
            let radius = (side - lw) / 2

            ZStack {
                // Blue: right side, sweeping down into the crossbar area.
                arc(from: -20, to: 90, radius: radius, lineWidth: lw, center: center)
                    .foregroundStyle(blue)
                // Green: bottom-left.
                arc(from: 90, to: 160, radius: radius, lineWidth: lw, center: center)
                    .foregroundStyle(green)
                // Yellow: left.
                arc(from: 160, to: 230, radius: radius, lineWidth: lw, center: center)
                    .foregroundStyle(yellow)
                // Red: top.
                arc(from: 230, to: 340, radius: radius, lineWidth: lw, center: center)
                    .foregroundStyle(red)
                // The crossbar: blue bar from the center out to the right edge.
                Rectangle()
                    .fill(blue)
                    .frame(width: radius + lw / 2, height: lw)
                    .position(x: center.x + (radius + lw / 2) / 2, y: center.y)
            }
        }
    }

    private func arc(from start: Double, to end: Double, radius: CGFloat,
                     lineWidth: CGFloat, center: CGPoint) -> some View {
        Path { path in
            path.addArc(center: center, radius: radius,
                        startAngle: .degrees(start), endAngle: .degrees(end),
                        clockwise: false)
        }
        .stroke(style: StrokeStyle(lineWidth: lineWidth, lineCap: .butt))
    }
}

// ============================================================
// MARK: — Screen 12: Handoff (the real you)
// ============================================================

/// The resolution: the estimate is done, now the real reading. Camera
/// permission is requested HERE, on tap, at peak motivation — an open door,
/// not a gate.
struct RampHandoffScreen: View {
    let onComplete: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shown = false
    @State private var starting = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: VSpace.md) {
                Text("READY WHEN YOU ARE")
                    .font(VType.micro)
                    .tracking(3)
                    .foregroundStyle(RampStage.accentDeep)
                Text("Now, the\nreal you.")
                    .font(RampStage.serif(32))
                    .foregroundStyle(RampStage.ink)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                Text("Good light, no filter. One photo, and the estimate becomes your number.")
                    .font(VType.body)
                    .foregroundStyle(RampStage.textSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, VSpace.xl)
            .opacity(shown ? 1 : 0)
            .offset(y: shown ? 0 : 12)

            Spacer()

            VStack(spacing: VSpace.sm) {
                RampPrimaryButton(title: "Scan my skin", systemImage: "camera.fill") {
                    guard !starting else { return }
                    starting = true
                    Task {
                        let granted = await CameraPermission.request()
                        RampAnalytics.track("onboarding_camera_permission",
                                            ["granted": String(granted)])
                        onComplete()
                    }
                }
                Text("Your reading card and 14-day plan are built from this first scan.")
                    .font(VType.micro)
                    .foregroundStyle(RampStage.textTertiary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, VSpace.lg)

            Spacer().frame(height: VSpace.xxl)
        }
        .task {
            try? await Task.sleep(for: .milliseconds(reduceMotion ? 100 : 500))
            withAnimation(.easeOut(duration: 1.0)) { shown = true }
        }
    }
}
