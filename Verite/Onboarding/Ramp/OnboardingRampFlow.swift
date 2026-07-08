import SwiftUI
import SwiftData

/// Vérité ramp onboarding — spectacle first, identity investment in the
/// middle, the scan as climax. Hands off to Guided Capture (the Scan tab).
///
/// The SceneKit head lives *behind* every screen for the whole flow; steps
/// only re-stage it (never recreate it), which is what makes the object feel
/// continuous. Every advance is a single CTA or a tap-selection — never both.
struct OnboardingRampFlow: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AppState.self) private var appState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Query private var profiles: [UserProfile]

    @State private var step: RampStep = .coldOpen
    @State private var answers = RampQuizAnswers()
    @State private var controller = ScanHeadController()

    var body: some View {
        ZStack {
            RampBackdrop()

            // The persistent 3D head — never torn down between screens.
            ScanHeadSceneView(controller: controller)
                .ignoresSafeArea()
                .allowsHitTesting(false)

            currentScreen
                .id(step)
                .transition(pageTransition)

            VStack {
                if step != .coldOpen {
                    RampProgressBar(screenIndex: step.screenIndex)
                        .padding(.horizontal, VSpace.lg)
                        .padding(.top, VSpace.sm)
                        .transition(.opacity)
                }
                Spacer()
            }
        }
        .animation(
            reduceMotion ? VMotion.crossfade : .spring(response: 0.42, dampingFraction: 0.88),
            value: step
        )
        .onAppear {
            controller.apply(step.headStage, reduceMotion: reduceMotion)
            RampAnalytics.screen(step)
        }
        .onChange(of: step) { _, newStep in
            controller.apply(newStep.headStage, reduceMotion: reduceMotion)
            Haptics.fire(.transition)
            RampAnalytics.screen(newStep)
        }
    }

    private var pageTransition: AnyTransition {
        guard !reduceMotion else { return .opacity }
        return .asymmetric(
            insertion: .move(edge: .trailing).combined(with: .opacity),
            removal: .move(edge: .leading).combined(with: .opacity)
        )
    }

    // MARK: Screen routing

    @ViewBuilder
    private var currentScreen: some View {
        switch step {
        case .coldOpen:
            RampColdOpenScreen(controller: controller) { advance() }
        case .claim:
            RampClaimScreen { advance() }
        case .proof:
            RampProofScreen { advance() }
        case .howItWorks:
            RampHowItWorksScreen(controller: controller) { advance() }
        case .quizSelfRating:
            RampQuizScreen(
                question: "How would you rate your skin right now?",
                options: RampQuizAnswers.SelfRating.allCases.map {
                    RampQuizOption(id: $0.rawValue, label: $0.label)
                },
                selectedID: answers.selfRating?.rawValue
            ) { id in
                answers.selfRating = RampQuizAnswers.SelfRating(rawValue: id)
                recordAnswer(question: "self_rating", answer: id)
            }
        case .quizConcern:
            RampQuizScreen(
                question: "What bothers you most in the mirror?",
                options: RampQuizAnswers.MirrorConcern.allCases.map {
                    RampQuizOption(id: $0.rawValue, label: $0.label, icon: $0.icon)
                },
                columns: 2,
                selectedID: answers.concern?.rawValue
            ) { id in
                answers.concern = RampQuizAnswers.MirrorConcern(rawValue: id)
                recordAnswer(question: "mirror_concern", answer: id)
            }
        case .quizRoutine:
            RampQuizScreen(
                question: "Your current routine?",
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
                question: "Sleep on an average night?",
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
        case .calibrating:
            RampCalibratingScreen(controller: controller, answers: answers) { advance() }
        case .socialProof:
            RampSocialProofScreen { advance() }
        case .notifications:
            RampNotificationScreen { advance() }
        case .scanRamp:
            RampScanRampScreen(controller: controller) { complete() }
        }
    }

    // MARK: Navigation

    /// Quiz mechanic: card fills, rigid haptic, auto-advance after 400ms.
    private func recordAnswer(question: String, answer: String) {
        Haptics.fire(.capture) // .rigid impact
        RampAnalytics.quizAnswer(question: question, answer: answer)
        let current = step
        Task {
            try? await Task.sleep(for: .milliseconds(400))
            // A second tap inside the window must not double-advance.
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

        // Hand off straight into the scan flow (master prompt Screen 2,
        // Guided Capture) — the moment of maximum motivation.
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
