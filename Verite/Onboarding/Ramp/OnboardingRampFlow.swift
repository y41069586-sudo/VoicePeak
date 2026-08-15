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

    var body: some View {
        ZStack {
            RampBackdrop()

            // A single horizontal push, like a pager: the old screen glides out
            // to the left while the new one glides in from the right — one
            // spring, one direction, nothing pops or re-animates on top.
            currentScreen
                .id(step)
                .transition(
                    reduceMotion
                        ? AnyTransition.opacity
                        : AnyTransition.asymmetric(
                            insertion: .move(edge: .trailing).combined(with: .opacity),
                            removal: .move(edge: .leading).combined(with: .opacity)
                        )
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
        // One smooth spring for every step change. Damping ~1 → no overshoot,
        // so the push reads as a glide, never a bounce.
        .animation(reduceMotion ? VMotion.crossfade : .spring(response: 0.48, dampingFraction: 0.98),
                   value: step)
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
                    RampQuizOption(id: $0.rawValue, label: $0.label, icon: $0.icon)
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
                    RampQuizOption(id: $0.rawValue, label: $0.label,
                                    icon: selfRatingIcon($0), sub: selfRatingSub($0))
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
                    RampQuizOption(id: $0.rawValue, label: $0.label, icon: ageIcon($0))
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
                    RampQuizOption(id: $0.rawValue, label: $0.label, icon: routineIcon($0))
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
                    RampQuizOption(id: $0.rawValue, label: $0.label, icon: sleepIcon($0))
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
                    RampQuizOption(id: $0.rawValue, label: $0.label, icon: spfIcon($0))
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
                    RampQuizOption(id: $0.rawValue, label: $0.label, icon: $0.icon)
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
                    RampQuizOption(id: $0.rawValue, label: $0.label, icon: $0.icon)
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

    private func selfRatingSub(_ rating: RampQuizAnswers.SelfRating) -> String {
        switch rating {
        case .rough:        return "Tight, uneven, needs care"
        case .average:      return "Some good days, some off"
        case .decent:       return "Mostly calm and clear"
        case .honestlyGood: return "Honestly glowing"
        }
    }

    // MARK: Swipe-card icons + descriptors

    private func selfRatingIcon(_ r: RampQuizAnswers.SelfRating) -> String {
        switch r {
        case .rough:        return "cloud.rain"
        case .average:      return "cloud.sun"
        case .decent:       return "sun.min"
        case .honestlyGood: return "sun.max.fill"
        }
    }

    private func ageIcon(_ a: RampQuizAnswers.AgeBand) -> String {
        switch a {
        case .under25:    return "1.circle.fill"
        case .from25to34: return "2.circle.fill"
        case .from35to44: return "3.circle.fill"
        case .over45:     return "4.circle.fill"
        }
    }

    private func routineIcon(_ r: RampQuizAnswers.RoutineLevel) -> String {
        switch r {
        case .nothing:      return "xmark.circle"
        case .cleanserOnly: return "drop"
        case .threePlus:    return "square.stack"
        case .fullStack:    return "square.stack.3d.up.fill"
        }
    }

    private func sleepIcon(_ s: RampQuizAnswers.SleepBucket) -> String {
        switch s {
        case .under6:       return "moon"
        case .sixToSeven:   return "moon.stars"
        case .sevenToEight: return "bed.double"
        case .eightPlus:    return "bed.double.fill"
        }
    }

    private func spfIcon(_ s: RampQuizAnswers.SunProtection) -> String {
        switch s {
        case .daily:     return "sun.max.fill"
        case .sometimes: return "sun.min"
        case .whatsSPF:  return "questionmark.circle"
        }
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
        if let next = step.next { step = next } else { complete() }
    }

    /// Step back one screen (chevron top-left). Never leaves onboarding — the
    /// opening `.boot` screen has no back, so the earliest reachable step is
    /// `acneType`.
    private func back() {
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
