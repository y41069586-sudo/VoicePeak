import SwiftUI
import SwiftData

/// Vérité onboarding — "Lumière". A soft, editorial ritual: warm porcelain and
/// dawn light, a luminous complexion-orb that lives behind every screen, serif
/// questions and quiet answer tiles. Same honest mechanic (score, range,
/// 14-day plan) in a calm, beautiful shell. Hands off to Guided Capture.
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

            // The luminous orb — staged behind every screen, never recreated.
            GeometryReader { geo in
                TeintOrb(haloed: step.orbStage.haloed)
                    .scaleEffect(step.orbStage.scale)
                    .opacity(step.orbStage.opacity)
                    .offset(y: step.orbStage.yFraction * geo.size.height)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .allowsHitTesting(false)
            .ignoresSafeArea()
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.9), value: step)

            currentScreen
                .id(step)
                .transition(.opacity)

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
        .animation(reduceMotion ? VMotion.crossfade : .easeInOut(duration: 0.55), value: step)
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
        case .theNumber:
            RampNumberScreen { advance() }
        case .theSplit:
            RampSplitScreen { advance() }
        case .quizSelfRating:
            RampQuizScreen(
                question: "How does your skin feel lately?",
                options: RampQuizAnswers.SelfRating.allCases.map {
                    RampQuizOption(id: $0.rawValue, label: $0.label, sub: selfRatingSub($0))
                },
                selectedID: answers.selfRating?.rawValue
            ) { id in
                answers.selfRating = RampQuizAnswers.SelfRating(rawValue: id)
                recordAnswer(question: "self_rating", answer: id)
            }
        case .quizConcern:
            RampQuizScreen(
                question: "What draws your eye in the mirror?",
                options: RampQuizAnswers.MirrorConcern.allCases.map {
                    RampQuizOption(id: $0.rawValue, label: $0.label, icon: $0.icon)
                },
                selectedID: answers.concern?.rawValue
            ) { id in
                answers.concern = RampQuizAnswers.MirrorConcern(rawValue: id)
                recordAnswer(question: "mirror_concern", answer: id)
            }
        case .quizRoutine:
            RampQuizScreen(
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
                question: "Sun protection?",
                options: RampQuizAnswers.SunProtection.allCases.map {
                    RampQuizOption(id: $0.rawValue, label: $0.label)
                },
                selectedID: answers.spf?.rawValue
            ) { id in
                answers.spf = RampQuizAnswers.SunProtection(rawValue: id)
                recordAnswer(question: "sun_protection", answer: id)
            }
        case .twinComplete:
            RampRevealScreen(answers: answers) { advance() }
        case .theCurve:
            RampCurveScreen { advance() }
        case .dailyReport:
            RampDailyReportScreen { advance() }
        case .handoff:
            RampHandoffScreen { complete() }
        }
    }

    private func selfRatingSub(_ rating: RampQuizAnswers.SelfRating) -> String {
        switch rating {
        case .rough:        return "Tight, uneven, needs care"
        case .average:      return "Some good days, some off"
        case .decent:       return "Mostly calm and clear"
        case .honestlyGood: return "Honestly glowing"
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
