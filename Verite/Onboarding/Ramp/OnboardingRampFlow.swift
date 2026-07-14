import SwiftUI
import SwiftData

/// SKINMAXX onboarding — "Lumière". A soft, editorial ritual: warm porcelain,
/// dawn light and film grain, restrained serif headlines, quiet answer tiles.
/// No mascot, no hero object — the content carries every screen. Same honest
/// mechanic (score, range, 14-day plan) in a calm shell. Hands off to Guided
/// Capture.
struct OnboardingRampFlow: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AppState.self) private var appState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Query private var profiles: [UserProfile]

    @State private var step: RampStep = .boot
    @State private var answers = RampQuizAnswers()

    var body: some View {
        ZStack {
            RampBackdrop()

            currentScreen
                .id(step)
                .transition(
                    reduceMotion
                        ? AnyTransition.opacity
                        : AnyTransition.asymmetric(
                            insertion: .opacity.combined(with: .offset(y: 14)),
                            removal: .opacity
                        )
                )

            // One thin filling hairline — the whole progress language.
            VStack {
                if step != .boot {
                    RampProgressLine(fraction: progressFraction)
                        .padding(.horizontal, VSpace.lg)
                        .padding(.top, VSpace.sm)
                        .transition(.opacity)
                }
                Spacer()
            }
        }
        // One smooth spring for every step change — the new screen rises in
        // while the old one dissolves, no hard easing.
        .animation(reduceMotion ? VMotion.crossfade : .spring(response: 0.55, dampingFraction: 0.9),
                   value: step)
        .onAppear { RampAnalytics.screen(step) }
        .onChange(of: step) { _, newStep in
            Haptics.fire(.transition)
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
            RampBootScreen { advance() }
        case .sampleReading:
            RampSampleReadingScreen { advance() }
        case .theSplit:
            RampSplitScreen { advance() }
        case .name:
            RampNameScreen(name: nameBinding) { advance() }
        case .quizSelfRating:
            RampSwipeQuizScreen(
                chapter: "YOUR SKIN · ONE OF THREE",
                question: personalized("How does your skin feel lately?",
                                       named: "%@, how does your skin feel lately?"),
                options: RampQuizAnswers.SelfRating.allCases.map {
                    RampSwipeOption(id: $0.rawValue, label: $0.label,
                                    icon: selfRatingIcon($0), sub: selfRatingSub($0))
                }
            ) { id in
                answers.selfRating = RampQuizAnswers.SelfRating(rawValue: id)
                recordAnswer(question: "self_rating", answer: id)
            }
        case .quizConcern:
            RampSwipeQuizScreen(
                chapter: "YOUR SKIN · TWO OF THREE",
                question: "What draws your eye in the mirror?",
                options: RampQuizAnswers.MirrorConcern.allCases.map {
                    RampSwipeOption(id: $0.rawValue, label: $0.label,
                                    icon: $0.icon, sub: concernSub($0))
                }
            ) { id in
                answers.concern = RampQuizAnswers.MirrorConcern(rawValue: id)
                recordAnswer(question: "mirror_concern", answer: id)
            }
        case .quizAge:
            RampSwipeQuizScreen(
                chapter: "YOUR SKIN · THREE OF THREE",
                question: "Your age group?",
                options: RampQuizAnswers.AgeBand.allCases.map {
                    RampSwipeOption(id: $0.rawValue, label: $0.label, icon: ageIcon($0))
                }
            ) { id in
                answers.age = RampQuizAnswers.AgeBand(rawValue: id)
                recordAnswer(question: "age_band", answer: id)
            }
        case .insightSkin:
            RampInsightScreen(
                eyebrow: "WHAT WE HEAR SO FAR",
                insight: answers.skinInsight,
                photoName: "GlowTexture",
                chips: [answers.selfRating?.chip, answers.concern.flatMap { $0.chip }, answers.age?.chip]
                    .compactMap { $0 }
            ) { advance() }
        case .quizRoutine:
            RampSwipeQuizScreen(
                chapter: "YOUR LIFE · ONE OF THREE",
                question: "Your routine, honestly?",
                options: RampQuizAnswers.RoutineLevel.allCases.map {
                    RampSwipeOption(id: $0.rawValue, label: $0.label, icon: routineIcon($0))
                }
            ) { id in
                answers.routine = RampQuizAnswers.RoutineLevel(rawValue: id)
                recordAnswer(question: "routine_level", answer: id)
            }
        case .quizSleep:
            RampSwipeQuizScreen(
                chapter: "YOUR LIFE · TWO OF THREE",
                question: "Sleep, on an average night?",
                options: RampQuizAnswers.SleepBucket.allCases.map {
                    RampSwipeOption(id: $0.rawValue, label: $0.label, icon: sleepIcon($0))
                }
            ) { id in
                answers.sleep = RampQuizAnswers.SleepBucket(rawValue: id)
                recordAnswer(question: "sleep", answer: id)
            }
        case .quizSPF:
            RampSwipeQuizScreen(
                chapter: "YOUR LIFE · THREE OF THREE",
                question: "Sun protection?",
                options: RampQuizAnswers.SunProtection.allCases.map {
                    RampSwipeOption(id: $0.rawValue, label: $0.label, icon: spfIcon($0))
                }
            ) { id in
                answers.spf = RampQuizAnswers.SunProtection(rawValue: id)
                recordAnswer(question: "sun_protection", answer: id)
            }
        case .insightLife:
            RampInsightScreen(
                eyebrow: "THE LEVERS IN YOUR ANSWERS",
                insight: answers.lifeInsight,
                photoName: "GlowRitual",
                chips: [answers.routine?.label, answers.sleep?.label, answers.spf?.label]
                    .compactMap { $0 }
            ) { advance() }
        case .theReading:
            RampRevealScreen(answers: answers) { advance() }
        case .theCurve:
            RampCurveScreen(answers: answers) { advance() }
        case .planPreview:
            RampPlanPreviewScreen(answers: answers) { advance() }
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

    /// Swaps in the name-addressed variant once the user has given a name.
    private func personalized(_ plain: String, named template: String) -> String {
        guard let name = answers.displayName else { return plain }
        return String(format: template, name)
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

    private func concernSub(_ c: RampQuizAnswers.MirrorConcern) -> String {
        switch c {
        case .breakouts: return "Spots and congestion"
        case .redness:   return "Flushing and irritation"
        case .pores:     return "Visible pores and oil"
        case .texture:   return "Rough, uneven surface"
        case .dullness:  return "Tired, lacking glow"
        case .nothing:   return "Nothing jumps out"
        }
    }

    // MARK: Navigation

    /// Selection is the advance: a soft haptic, then a gentle auto-advance.
    private func recordAnswer(question: String, answer: String) {
        Haptics.fire(.selection)
        RampAnalytics.quizAnswer(question: question, answer: answer)
        let current = step
        Task {
            try? await Task.sleep(for: .milliseconds(420))
            guard step == current else { return }
            advance()
        }
    }

    private func advance() {
        if let next = step.next { step = next } else { complete() }
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

        appState.selectedTab = .analyze
        Haptics.fire(.verdictReveal)
        RampAnalytics.track("onboarding_complete")
    }
}

#Preview {
    OnboardingRampFlow()
        .modelContainer(Persistence.previewContainer)
        .environment(AppState())
}
