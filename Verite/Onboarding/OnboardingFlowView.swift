import SwiftUI
import SwiftData

/// Milestone 8 — the full conversion flow: hero → 3-promise → personalization
/// quiz (skin type, concerns, sensitivities, current products, goal) → building
/// loader → baseline scan → reminder opt-in → soft paywall → dashboard. Every
/// step is skippable where honest, fully localized, and animated (Reduce-Motion
/// aware). Answers persist to the on-device `UserProfile`.
struct OnboardingFlowView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Query private var profiles: [UserProfile]

    enum Step: Int, CaseIterable {
        case hero, promise, skinType, concerns, sensitivities, products, goal, building, baseline, reminders, paywall
    }
    @State private var step: Step = .hero

    // Draft answers
    @State private var skinType: SkinType?
    @State private var concerns: Set<SkinConcern> = []
    @State private var sensitivities: Set<String> = []
    @State private var currentProducts: Set<String> = []
    @State private var goal: String?
    @State private var heroAppeared = false

    private let quizTotal = 5

    // Option lists for the free-text-ish steps (id is stored; key is displayed).
    private let sensitivityOptions: [(id: String, key: LocalizedStringKey)] = [
        ("fragrance", "sensitivity.fragrance"),
        ("alcohol", "sensitivity.alcohol"),
        ("essential oil", "sensitivity.essentialOils"),
        ("none", "sensitivity.none"),
    ]
    private let productOptions: [(id: String, key: LocalizedStringKey)] = [
        ("retinol", "cp.retinol"),
        ("vitamin c", "cp.vitaminc"),
        ("exfoliating acid", "cp.acid"),
        ("benzoyl peroxide", "cp.bpo"),
        ("spf", "cp.spf"),
        ("none", "cp.none"),
    ]
    private let goalOptions: [(id: String, key: LocalizedStringKey)] = [
        ("calmer", "goal.calmer"),
        ("clearer", "goal.clearer"),
        ("smoother", "goal.smoother"),
        ("hydrated", "goal.hydrated"),
        ("aging", "goal.aging"),
    ]

    var body: some View {
        ZStack {
            GradientMeshBackground().ignoresSafeArea()
            currentStep
                .id(step)
                .transition(stepTransition)
        }
        .animation(Motion.animation(reduceMotion: reduceMotion), value: step)
    }

    private var stepTransition: AnyTransition {
        reduceMotion ? .opacity :
            .asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .move(edge: .leading).combined(with: .opacity))
    }

    @ViewBuilder
    private var currentStep: some View {
        switch step {
        case .hero: hero
        case .promise: promise
        case .skinType: skinTypeStep
        case .concerns: concernsStep
        case .sensitivities: sensitivitiesStep
        case .products: productsStep
        case .goal: goalStep
        case .building: building
        case .baseline: OnboardingBaselineView { advance() }
        case .reminders: reminders
        case .paywall: OnboardingPaywallView(onContinue: complete, onSkip: complete)
        }
    }

    // MARK: Hero + promise

    private var hero: some View {
        VStack(spacing: 0) {
            Spacer()
            VStack(spacing: 18) {
                Text(Brand.name)
                    .font(Typography.display(56))
                    .foregroundStyle(Theme.textPrimary)
                    .blueGlow(Theme.accent, radius: 22, opacity: 0.3)
                Text("onboarding.hero.valueProp")
                    .font(.title3)
                    .foregroundStyle(Theme.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
            .opacity(heroAppeared ? 1 : 0)
            .offset(y: heroAppeared ? 0 : 16)
            Spacer()
            PrimaryButton(titleKey: "onboarding.cta.start") { advance() }
                .padding(.horizontal, 24)
            DisclaimerBanner(style: .short)
                .padding(.horizontal, 24).padding(.bottom, 24)
        }
        .onAppear {
            if reduceMotion { heroAppeared = true }
            else { withAnimation(Motion.springSoft.delay(0.1)) { heroAppeared = true } }
        }
    }

    private var promise: some View {
        OnboardingScaffold(titleKey: "onboarding.promise.title",
                           subtitleKey: "onboarding.promise.subtitle",
                           onContinue: { advance() }) {
            VStack(spacing: 12) {
                promiseRow("camera.viewfinder", "onboarding.promise.scan")
                promiseRow("checkmark.seal", "onboarding.promise.match")
                promiseRow("flask", "onboarding.promise.prove")
            }
        }
    }

    private func promiseRow(_ icon: String, _ key: LocalizedStringKey) -> some View {
        GlassCard {
            HStack(spacing: 14) {
                Image(systemName: icon).font(.title3).foregroundStyle(Theme.accent).frame(width: 32)
                Text(key).font(.headline).foregroundStyle(Theme.textPrimary)
                Spacer()
            }
        }
    }

    // MARK: Quiz steps

    private var skinTypeStep: some View {
        OnboardingScaffold(titleKey: "quiz.skinType.title",
                           progress: (1, quizTotal),
                           continueEnabled: skinType != nil,
                           onContinue: { advance() }) {
            VStack(spacing: 10) {
                ForEach(SkinType.allCases) { type in
                    OnboardingSelectCard(titleKey: type.localizationKey, selected: skinType == type) {
                        skinType = type
                    }
                }
            }
        }
    }

    private var concernsStep: some View {
        OnboardingScaffold(titleKey: "quiz.concerns.title",
                           subtitleKey: "quiz.concerns.subtitle",
                           progress: (2, quizTotal),
                           continueEnabled: !concerns.isEmpty,
                           onContinue: { advance() }) {
            VStack(spacing: 10) {
                ForEach(SkinConcern.allCases) { concern in
                    OnboardingSelectCard(titleKey: concern.localizationKey, selected: concerns.contains(concern)) {
                        toggle(concern, in: &concerns)
                    }
                }
            }
        }
    }

    private var sensitivitiesStep: some View {
        OnboardingScaffold(titleKey: "quiz.sensitivities.title",
                           subtitleKey: "quiz.sensitivities.subtitle",
                           progress: (3, quizTotal),
                           onContinue: { advance() },
                           onSkip: { sensitivities = []; advance() }) {
            optionCards(sensitivityOptions, selection: $sensitivities)
        }
    }

    private var productsStep: some View {
        OnboardingScaffold(titleKey: "quiz.products.title",
                           subtitleKey: "quiz.products.subtitle",
                           progress: (4, quizTotal),
                           onContinue: { advance() },
                           onSkip: { currentProducts = []; advance() }) {
            optionCards(productOptions, selection: $currentProducts)
        }
    }

    private var goalStep: some View {
        OnboardingScaffold(titleKey: "quiz.goal.title",
                           progress: (5, quizTotal),
                           continueEnabled: goal != nil,
                           onContinue: { advance() }) {
            VStack(spacing: 10) {
                ForEach(goalOptions, id: \.id) { option in
                    OnboardingSelectCard(titleKey: option.key, selected: goal == option.id) {
                        goal = option.id
                    }
                }
            }
        }
    }

    /// Multi-select cards where selecting "none" clears the rest (and vice-versa).
    private func optionCards(_ options: [(id: String, key: LocalizedStringKey)],
                             selection: Binding<Set<String>>) -> some View {
        VStack(spacing: 10) {
            ForEach(options, id: \.id) { option in
                OnboardingSelectCard(titleKey: option.key, selected: selection.wrappedValue.contains(option.id)) {
                    var set = selection.wrappedValue
                    if option.id == "none" {
                        set = set.contains("none") ? [] : ["none"]
                    } else {
                        set.remove("none")
                        if set.contains(option.id) { set.remove(option.id) } else { set.insert(option.id) }
                    }
                    selection.wrappedValue = set
                }
            }
        }
    }

    // MARK: Building loader

    private var building: some View {
        VStack(spacing: 20) {
            Spacer()
            ProgressView()
                .controlSize(.large)
                .tint(Theme.primary)
            Text("onboarding.building")
                .font(Typography.display(24))
                .foregroundStyle(Theme.textPrimary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Spacer()
        }
        .task {
            try? await Task.sleep(for: .seconds(1.6))
            advance()
        }
    }

    // MARK: Reminders

    private var reminders: some View {
        VStack(spacing: 18) {
            Spacer()
            Image(systemName: "bell.badge")
                .font(.system(size: 50, weight: .light))
                .foregroundStyle(Theme.accent)
                .blueGlow()
            Text("onboarding.reminders.title")
                .font(Typography.display(26)).foregroundStyle(Theme.textPrimary)
                .multilineTextAlignment(.center)
            Text("onboarding.reminders.body")
                .font(.subheadline).foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center).padding(.horizontal, 32)
            Spacer()
            PrimaryButton(titleKey: "onboarding.reminders.enable", systemImage: "bell.fill") {
                Task {
                    if await NotificationManager.requestAuthorization() {
                        NotificationManager.scheduleRoutineReminders()
                    }
                    advance()
                }
            }
            .padding(.horizontal, 24)
            SecondaryButton(titleKey: "onboarding.skip") { advance() }
                .padding(.bottom, 20)
        }
    }

    // MARK: Flow control

    private func advance() {
        if let next = Step(rawValue: step.rawValue + 1) { step = next }
    }

    private func toggle<T: Hashable>(_ value: T, in set: inout Set<T>) {
        if set.contains(value) { set.remove(value) } else { set.insert(value) }
    }

    private func complete() {
        let profile = profiles.first ?? {
            let created = UserProfile()
            modelContext.insert(created)
            return created
        }()
        profile.skinType = skinType
        profile.concerns = Array(concerns)
        profile.sensitivities = sensitivities.filter { $0 != "none" }
        profile.currentProducts = currentProducts.filter { $0 != "none" }
        profile.goal = goal
        profile.onboardingComplete = true
        try? modelContext.save()
        Haptics.fire(.verdictReveal)
    }
}
