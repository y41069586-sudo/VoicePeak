import SwiftUI
import SwiftData

/// Vérité onboarding v3 — "The Twin". The engine builds your digital twin from
/// a scatter of points; every answer materializes it further; the final scan
/// replaces the twin with the real you. Hands off to Guided Capture.
///
/// The SceneKit head lives *behind* every screen for the whole flow; steps
/// only re-stage it (never recreate it), which is what makes the object feel
/// continuous. Twin integrity (top HUD) rises with each answer and drives the
/// head's densification — the visual spine of the whole story.
struct OnboardingRampFlow: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AppState.self) private var appState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Query private var profiles: [UserProfile]

    @State private var step: RampStep = .boot
    @State private var answers = RampQuizAnswers()
    @State private var controller = ScanHeadController()
    @State private var dragActive = false
    @State private var hasDraggedHead = false
    /// Mirrors the twin's materialization for the HUD (0…1).
    @State private var integrity: Double = 0

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

            // "You can grab this" — shown once, on the first question.
            if step == .quizSelfRating && !hasDraggedHead {
                VStack {
                    HStack {
                        Spacer()
                        RampDragHint().padding(.trailing, VSpace.xl)
                    }
                    .padding(.top, 120)
                    Spacer()
                }
                .allowsHitTesting(false)
                .transition(.opacity)
            }

            // The twin-integrity HUD replaces the old segmented progress bar.
            // Hidden on boot (pure spectacle) and on the Split screen (a full-
            // render demo, not the user's own twin — a 14% readout would lie).
            VStack {
                if step != .boot && step != .theSplit {
                    RampIntegrityHUD(integrity: integrity, verified: false)
                        .padding(.horizontal, VSpace.lg)
                        .padding(.top, VSpace.sm)
                        .transition(.opacity)
                }
                Spacer()
            }
        }
        // The head is grabbable: a horizontal drag anywhere spins it, with
        // fling inertia on release. Simultaneous, so buttons still tap fine.
        .simultaneousGesture(headDragGesture)
        .animation(
            reduceMotion ? VMotion.crossfade : .spring(response: 0.42, dampingFraction: 0.88),
            value: step
        )
        .animation(VMotion.gentle, value: hasDraggedHead)
        .onAppear {
            controller.apply(step.headStage, reduceMotion: reduceMotion)
            refreshTwin(animated: false)
            RampAnalytics.screen(step)
        }
        .onChange(of: step) { _, newStep in
            controller.apply(newStep.headStage, reduceMotion: reduceMotion)
            refreshTwin(animated: true)
            Haptics.fire(.transition)
            RampAnalytics.screen(newStep)
        }
    }

    /// Recompute twin integrity from the current step + answered count, push it
    /// to the HUD and the head. The Split screen owns the head directly, so we
    /// skip it there (it restores integrity on the way out via this same call).
    private func refreshTwin(animated: Bool) {
        let target = step.twinIntegrity(answeredCount: answers.answeredCount)
        integrity = target
        guard step != .theSplit else { return }
        controller.setTwinIntegrity(target, animated: animated)
    }

    // MARK: Head drag (interactive spin)

    private var headDragGesture: some Gesture {
        DragGesture(minimumDistance: 16)
            .onChanged { value in
                guard step.allowsHeadDrag, !reduceMotion else { return }
                if !dragActive {
                    dragActive = true
                    hasDraggedHead = true
                    controller.beginDrag()
                    Haptics.fire(.selection)
                }
                controller.dragBy(radians: Float(value.translation.width / 190))
            }
            .onEnded { value in
                guard dragActive else { return }
                dragActive = false
                let remainder = value.predictedEndTranslation.width - value.translation.width
                controller.endDrag(velocity: Float(remainder / 190) * 2.4)
            }
    }

    private var pageTransition: AnyTransition {
        guard !reduceMotion else { return .opacity }
        let depth = AnyTransition.modifier(
            active: RampPageEffect(active: true),
            identity: RampPageEffect(active: false)
        )
        return .asymmetric(
            insertion: .move(edge: .trailing).combined(with: .opacity).combined(with: depth),
            removal: .move(edge: .leading).combined(with: .opacity).combined(with: depth)
        )
    }

    // MARK: Screen routing

    @ViewBuilder
    private var currentScreen: some View {
        switch step {
        case .boot:
            RampBootScreen(controller: controller) { advance() }
        case .theNumber:
            RampNumberScreen { advance() }
        case .theSplit:
            RampSplitScreen(controller: controller) { advance() }
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
        case .twinComplete:
            RampTwinCompleteScreen(controller: controller, answers: answers) { advance() }
        case .theCurve:
            RampCurveScreen { advance() }
        case .dailyReport:
            RampDailyReportScreen(controller: controller) { advance() }
        case .handoff:
            RampHandoffScreen(controller: controller) { complete() }
        }
    }

    // MARK: Navigation

    /// Quiz mechanic: card fills, rigid haptic, the head leans in and absorbs
    /// the answer (cluster flash), twin integrity jumps, auto-advance after
    /// 400ms. `answers` is already updated by the caller, so `answeredCount`
    /// reflects this tap.
    private func recordAnswer(question: String, answer: String) {
        Haptics.fire(.capture) // .rigid impact
        controller.flash(ScanHeadController.Cluster.allCases.randomElement() ?? .forehead)
        controller.nudge(dx: 0.22)
        // Immediate densification feedback — the twin gains integrity on tap.
        let target = step.twinIntegrity(answeredCount: answers.answeredCount)
        integrity = target
        controller.setTwinIntegrity(target, animated: true, duration: 0.5)
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

/// Depth cue on page changes: incoming/outgoing screens blur and sink
/// slightly, so steps feel like planes moving in z — not flat slides.
private struct RampPageEffect: ViewModifier {
    let active: Bool

    func body(content: Content) -> some View {
        content
            .blur(radius: active ? 8 : 0)
            .scaleEffect(active ? 0.96 : 1)
    }
}

#Preview {
    OnboardingRampFlow()
        .modelContainer(Persistence.previewContainer)
        .environment(AppState())
}
