import SwiftUI
import SwiftData

/// SkinFix onboarding — "Lumière". A soft, editorial ritual: warm porcelain,
/// dawn light and film grain, restrained serif headlines, quiet answer tiles.
/// No mascot, no hero object — the content carries every screen. Same honest
/// mechanic (score, range, 14-day plan) in a calm shell. Hands off to Guided
/// Capture.
struct OnboardingRampFlow: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Query private var profiles: [UserProfile]

    @State private var step: RampStep = .boot
    @State private var answers = RampQuizAnswers()

    /// Where the back chevron sends `.signIn`. `.signIn` is reachable two
    /// ways — the funnel's own order (from `.dailyRitual`) and the boot
    /// screen's "Already have an account?" shortcut, which jumps straight
    /// there from `.boot`, skipping everything between. `step.previous`
    /// alone can't tell those apart: it only knows the enum's fixed order,
    /// so a chevron tap after the shortcut landed on `.dailyRitual` — a
    /// screen near the END of a funnel the user never walked, which reads
    /// exactly like onboarding secretly happened. This tracks the real
    /// entry point instead. Defaults to the funnel's own order and is
    /// overridden only by the shortcut, so a normal run needs no upkeep.
    @State private var signInBackTarget: RampStep = .dailyRitual

    var body: some View {
        ZStack {
            RampBackdrop()

            // Each screen drifts across rather than getting shoved off — see
            // `RampLeafDrift` in RampStage.swift for why a spring was the
            // wrong tool for this and what replaced it.
            currentScreen
                .id(step)
                .transition(
                    reduceMotion
                        ? AnyTransition.opacity
                        : AnyTransition.asymmetric(insertion: .rampLeafIn, removal: .rampLeafOut)
                )

            // The thin filling progress hairline sits ABOVE the back chevron.
            VStack(spacing: VSpace.xs) {
                if step != .boot {
                    RampProgressLine(fraction: progressFraction)
                        .padding(.horizontal, VSpace.lg)
                    HStack {
                        Button {
                            Haptics.fire(.selection)
                            back()
                        } label: {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundStyle(RampStage.textSecondary)
                                .frame(width: 44, height: 44)
                                .contentShape(Rectangle())
                        }
                        .accessibilityLabel("Back")
                        Spacer()
                    }
                    .padding(.leading, VSpace.xs)
                    .transition(.opacity)
                }
                Spacer()
            }
            .padding(.top, VSpace.sm)
        }
        // `RampMotion.drift`, not a spring — see `RampLeafDrift` for why.
        .animation(reduceMotion ? VMotion.crossfade : RampMotion.drift, value: step)
        .onAppear { RampAnalytics.screen(step) }
        .onChange(of: step) { _, newStep in
            // No haptic here: the tapped button/tile already fired .selection —
            // a second buzz per advance felt like a double-tap.
            RampAnalytics.screen(newStep)
        }
    }

    private var progressFraction: Double {
        Double(step.screenIndex) / Double(max(RampStage.screenCount - 1, 1))
    }

    // MARK: Screen routing

    @ViewBuilder
    private var currentScreen: some View {
        switch step {
        case .boot:
            RampBootScreen(onAdvance: { advance() },
                           onSignIn: {
                               RampAnalytics.track("intro_sign_in_tapped")
                               signInBackTarget = .boot
                               step = .signIn
                           })
        case .sampleReading:
            RampSampleReadingScreen { advance() }
        case .theSplit:
            RampSplitScreen { advance() }
        case .attribution:
            RampQuizScreen(
                question: "Where did you find SkinFix?",
                options: RampQuizAnswers.AcquisitionSource.allCases.map {
                    RampQuizOption(id: $0.rawValue, label: $0.label)
                },
                selectedID: answers.acquisition?.rawValue
            ) { id in
                answers.acquisition = RampQuizAnswers.AcquisitionSource(rawValue: id)
                // Durable channel attribution — read this against creator
                // spend (UserDefaults so it survives sign-out/updates).
                UserDefaults.standard.set(id, forKey: "dq.attribution.source")
                recordAnswer(question: "acquisition_source", answer: id)
            }
        case .name:
            RampNameScreen(name: nameBinding) { advance() }
        case .quizSelfRating:
            RampQuizScreen(
                chapter: "YOUR SKIN · ONE OF TWO",
                question: personalized("How does your skin feel lately?",
                                       named: "%@, how does your skin feel lately?"),
                options: RampQuizAnswers.SelfRating.allCases.map {
                    RampQuizOption(id: $0.rawValue, label: $0.label)
                },
                selectedID: answers.selfRating?.rawValue
            ) { id in
                answers.selfRating = RampQuizAnswers.SelfRating(rawValue: id)
                recordAnswer(question: "self_rating", answer: id)
            }
        case .quizAge:
            RampQuizScreen(
                chapter: "YOUR SKIN · TWO OF TWO",
                question: "Your age group?",
                options: RampQuizAnswers.AgeBand.allCases.map {
                    RampQuizOption(id: $0.rawValue, label: $0.label)
                },
                selectedID: answers.age?.rawValue
            ) { id in
                answers.age = RampQuizAnswers.AgeBand(rawValue: id)
                recordAnswer(question: "age_band", answer: id)
            }
        case .insightSkin:
            RampInsightScreen(
                eyebrow: "WHAT WE HEAR SO FAR",
                insight: answers.skinInsight,
                photoName: "GlowTexture",
                chips: [answers.selfRating?.chip, answers.acneTypeChip, answers.age?.chip]
                    .compactMap { $0 }
            ) { advance() }
        case .quizRoutine:
            RampQuizScreen(
                chapter: "YOUR LIFE · ONE OF SIX",
                question: "Your routine, honestly?",
                options: RampQuizAnswers.RoutineLevel.allCases.map {
                    RampQuizOption(id: $0.rawValue, label: $0.label)
                },
                selectedID: answers.routine?.rawValue
            ) { id in
                answers.routine = RampQuizAnswers.RoutineLevel(rawValue: id)
                recordAnswer(question: "routine_level", answer: id)
            }
        case .quizSleep:
            RampQuizScreen(
                chapter: "YOUR LIFE · TWO OF SIX",
                question: "Sleep, on an average night?",
                options: RampQuizAnswers.SleepBucket.allCases.map {
                    RampQuizOption(id: $0.rawValue, label: $0.label)
                },
                selectedID: answers.sleep?.rawValue
            ) { id in
                answers.sleep = RampQuizAnswers.SleepBucket(rawValue: id)
                recordAnswer(question: "sleep", answer: id)
            }
        case .quizSPF:
            RampQuizScreen(
                chapter: "YOUR LIFE · THREE OF SIX",
                question: "Sun protection?",
                options: RampQuizAnswers.SunProtection.allCases.map {
                    RampQuizOption(id: $0.rawValue, label: $0.label)
                },
                selectedID: answers.spf?.rawValue
            ) { id in
                answers.spf = RampQuizAnswers.SunProtection(rawValue: id)
                recordAnswer(question: "sun_protection", answer: id)
            }
        case .insightLife:
            RampInsightScreen(
                eyebrow: "THE LEVERS IN YOUR ANSWERS",
                insight: answers.lifeInsight,
                photoName: "GlowHero",
                chips: [answers.routine?.label, answers.sleep?.label, answers.spf?.label]
                    .compactMap { $0 }
            ) { advance() }
        case .acneType:
            RampAcneTypeScreen(selected: acneTypesBinding) {
                let picked = answers.acneTypes.sorted()
                RampAnalytics.quizAnswer(question: "acne_types",
                                         answer: picked.joined(separator: ","))
                UserDefaults.standard.set(picked, forKey: "dq.acneTypes")
                // RampPrimaryButton already fires .selection on tap — no
                // second call here.
                advance()
            }
        case .acneDuration:
            RampQuizScreen(
                chapter: "YOUR ACNE · ONE OF THREE",
                question: "How long has your skin\nbeen like this?",
                options: RampQuizAnswers.AcneDuration.allCases.map {
                    RampQuizOption(id: $0.rawValue, label: $0.label)
                },
                selectedID: answers.acneDuration?.rawValue
            ) { id in
                answers.acneDuration = RampQuizAnswers.AcneDuration(rawValue: id)
                UserDefaults.standard.set(id, forKey: "dq.acneDuration")
                recordAnswer(question: "acne_duration", answer: id)
            }
        case .acneTried:
            RampAcneTriedScreen(selected: acneTriedBinding) {
                answers.sawAcneTried = true
                let picked = answers.acneTried.sorted()
                RampAnalytics.quizAnswer(question: "acne_tried",
                                         answer: picked.joined(separator: ","))
                UserDefaults.standard.set(picked, forKey: "dq.acneTried")
                advance()
            }
        case .acneImpact:
            RampQuizScreen(
                chapter: "YOUR ACNE · THREE OF THREE",
                question: personalized("Be honest — how much\ndoes it get to you?",
                                       named: "%@, how much does\nit get to you?"),
                subtitle: "This changes nothing about your plan. It changes how we talk to you.",
                options: RampQuizAnswers.AcneImpact.allCases.map {
                    RampQuizOption(id: $0.rawValue, label: $0.label)
                },
                selectedID: answers.acneImpact?.rawValue
            ) { id in
                answers.acneImpact = RampQuizAnswers.AcneImpact(rawValue: id)
                recordAnswer(question: "acne_impact", answer: id)
            }
        case .acneEmpathy:
            RampAcneEmpathyScreen(
                headline: answers.acneEmpathyHeadline,
                message: answers.acneEmpathyBody,
                chips: answers.acneChips
            ) { advance() }
        case .sensitivities:
            RampSensitivityScreen(selected: sensitivitiesBinding) {
                answers.sawSensitivities = true
                let picked = answers.sensitivities.sorted()
                RampAnalytics.quizAnswer(question: "sensitivities",
                                         answer: picked.joined(separator: ","))
                advance()
            }
        case .brands:
            RampBrandScreen(selected: brandsBinding,
                            onAdvance: {
                                let picked = answers.brands.sorted()
                                RampAnalytics.quizAnswer(question: "brands",
                                                         answer: picked.joined(separator: ","))
                                UserDefaults.standard.set(picked, forKey: "dq.brands")
                                advance()
                            })
        case .spend:
            RampSpendScreen(bucket: spendBinding) {
                RampAnalytics.quizAnswer(question: "monthly_spend_bucket",
                                         answer: "\(answers.spendBucket)")
                UserDefaults.standard.set(answers.spendBucket, forKey: "dq.spendBucket")
                advance()
            }
        case .theCycle:
            RampCycleScreen { advance() }
        case .goal:
            RampGoalScreen(selected: answers.goal) { goal in
                answers.goal = goal
                goal.store()
                recordAnswer(question: "goal", answer: goal.rawValue)
            }
        case .theReading:
            RampRevealScreen(answers: answers) { advance() }
        case .theCurve:
            RampCurveScreen(answers: answers) { advance() }
        case .planPreview:
            RampPlanPreviewScreen(answers: answers) { advance() }
        case .evidence:
            RampEvidenceScreen { advance() }
        case .commitment:
            RampCommitmentScreen(name: answers.displayName) { advance() }
        case .dailyRitual:
            RampDailyReportScreen { advance() }
        case .signIn:
            RampSignInScreen(
                onSignedIn: { givenName in
                    // Apple's name beats an empty field, never a typed one.
                    if answers.displayName == nil, let givenName, !givenName.isEmpty {
                        answers.name = givenName
                    }
                    advance()
                },
                onSkip: { advance() }
            )
        case .handoff:
            RampHandoffScreen { complete() }
        }
    }

    private var nameBinding: Binding<String> {
        Binding(get: { answers.name ?? "" }, set: { answers.name = $0 })
    }

    private var sensitivitiesBinding: Binding<Set<String>> {
        Binding(get: { answers.sensitivities }, set: { answers.sensitivities = $0 })
    }

    private var acneTypesBinding: Binding<Set<String>> {
        Binding(get: { answers.acneTypes }, set: { answers.acneTypes = $0 })
    }

    private var acneTriedBinding: Binding<Set<String>> {
        Binding(get: { answers.acneTried }, set: { answers.acneTried = $0 })
    }

    private var brandsBinding: Binding<Set<String>> {
        Binding(get: { answers.brands }, set: { answers.brands = $0 })
    }

    private var spendBinding: Binding<Int> {
        Binding(get: { answers.spendBucket }, set: { answers.spendBucket = $0 })
    }

    /// Swaps in the name-addressed variant once the user has given a name.
    private func personalized(_ plain: String, named template: String) -> String {
        guard let name = answers.displayName else { return plain }
        // Localize the template BEFORE substituting the name — the composed
        // result ("Anna, how does…") would never match a catalog key.
        return String(format: String(localized: String.LocalizationValue(template)), name)
    }


    // MARK: Navigation

    /// Selection is the advance — but never a jump: the tile gets a beat to
    /// settle (fill, dot, haptic) before the screen glides on. 280ms is the
    /// sweet spot: the fill spring is visibly underway when the push starts,
    /// so tap → fill → glide reads as ONE continuous motion. The original
    /// 700ms left ~400ms of dead stillness after the fill finished, which
    /// read as a hang followed by a jerk. Re-tapping a different answer
    /// within the beat re-arms cleanly via the step guard.
    private func recordAnswer(question: String, answer: String) {
        Haptics.fire(.selection)
        RampAnalytics.quizAnswer(question: question, answer: answer)
        let current = step
        Task {
            try? await Task.sleep(for: .milliseconds(280))
            guard step == current else { return }
            advance()
        }
    }

    private func advance() {
        guard let next = step.next else { complete(); return }
        // Reaching `.signIn` the normal way — re-arms the shortcut's
        // override in case this is a second pass through the funnel after
        // an earlier "Already have an account?" tap (see `signInBackTarget`).
        if next == .signIn { signInBackTarget = step }
        step = next
    }

    /// Step back one screen (chevron top-left). Never leaves onboarding — the
    /// opening `.boot` screen has no back, so the earliest reachable step is
    /// `acneType`. `.signIn` is the one step whose back target isn't just
    /// "the previous case" — see `signInBackTarget`.
    private func back() {
        if step == .signIn { step = signInBackTarget; return }
        if let prev = step.previous { step = prev }
    }

    private func complete() {
        let profile = profiles.first ?? {
            let created = UserProfile()
            modelContext.insert(created)
            return created
        }()
        answers.apply(to: profile)
        profile.onboardingComplete = true
        try? modelContext.save()

        Haptics.fire(.verdictReveal)
        RampAnalytics.track("onboarding_complete")
    }
}

#Preview {
    OnboardingRampFlow()
        .modelContainer(Persistence.previewContainer)
        .environment(AppState())
}
