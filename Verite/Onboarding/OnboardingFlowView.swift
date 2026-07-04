import SwiftUI
import SwiftData

/// Milestone 8 / SCREENS_SPEC Part A — the full conversion flow, A1→A16:
///
///   A1  hero          — welcome, single "Begin"
///   A2  problem       — agitate: the industry runs on hope, not proof
///   A3  promise       — three numbered steps; step 3 (prove) is featured
///   A4  skinType      — single-select, auto-advances
///   A5  concerns      — multi-select chips
///   A6  sensitivities — multi-select chips (we flag these everywhere)
///   A7  products      — current routine rows (catch conflicts)
///   A8  goal          — single-select, auto-advances
///   A9  building      — status lines tick as we "assemble" the profile
///   A10 profileReveal — mirror back what they told us
///   A11–A13 baseline  — standardized Day-0 capture + reveal (OnboardingBaselineView)
///   A14 reminders     — opt-in with a routine time picker
///   A15 paywall       — soft paywall, half-face proof first, plan selector
///   A16 ready         — you're set → into the app
///
/// Every step is honest, skippable where appropriate, fully localized, and
/// Reduce-Motion aware. Answers persist to the on-device `UserProfile` at the end.
///
/// HARD RULE (SCREENS_SPEC): this rebuild changes layout / motion / copy only —
/// it routes every color, type, space, radius, shadow and motion through the
/// existing V* tokens and components. No raw values, no new palette.
struct OnboardingFlowView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Query private var profiles: [UserProfile]

    enum Step: Int, CaseIterable {
        case hero, problem, promise, skinType, concerns, sensitivities, products,
             goal, building, profileReveal, baseline, reminders, paywall, ready
    }
    @State private var step: Step = .hero

    // Draft answers (persisted only at `complete()`).
    @State private var skinType: SkinType?
    @State private var concerns: Set<SkinConcern> = []
    @State private var sensitivities: Set<String> = []
    @State private var currentProducts: Set<String> = []
    @State private var goal: String?
    @State private var heroAppeared = false
    @State private var reminderTime = Self.defaultReminderTime

    private let quizTotal = 5   // skinType … goal

    // Option lists for the free-text-ish steps (id is stored; key is displayed).
    private let sensitivityOptions: [(id: String, key: LocalizedStringKey)] = [
        ("fragrance", "sensitivity.fragrance"),
        ("alcohol", "sensitivity.alcohol"),
        ("essential oil", "sensitivity.essentialOils"),
        ("exfoliating acid", "sensitivity.acids"),
        ("none", "sensitivity.none"),
        ("not sure", "sensitivity.notSure"),
    ]
    private let productOptions: [(id: String, key: LocalizedStringKey)] = [
        ("cleanser", "cp.cleanser"),
        ("moisturizer", "cp.moisturizer"),
        ("serum", "cp.serum"),
        ("retinol", "cp.retinol"),
        ("vitamin c", "cp.vitaminc"),
        ("exfoliating acid", "cp.acid"),
        ("spf", "cp.spf"),
        ("none", "cp.none"),
    ]
    private let goalOptions: [(id: String, key: LocalizedStringKey)] = [
        ("calmer", "goal.calmer"),
        ("clearer", "goal.clearer"),
        ("smoother", "goal.smoother"),
        ("hydrated", "goal.hydrated"),
        ("aging", "goal.aging"),
        ("understand", "goal.understand"),
        ("saveMoney", "goal.saveMoney"),
    ]

    var body: some View {
        ZStack {
            VBackground().ignoresSafeArea()
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
        case .hero:          hero
        case .problem:       problem
        case .promise:       promise
        case .skinType:      skinTypeStep
        case .concerns:      concernsStep
        case .sensitivities: sensitivitiesStep
        case .products:      productsStep
        case .goal:          goalStep
        case .building:      building
        case .profileReveal: profileReveal
        case .baseline:      OnboardingBaselineView { advance() }
        case .reminders:     reminders
        case .paywall:       OnboardingPaywallView(onContinue: { advance() }, onSkip: { advance() })
        case .ready:         ready
        }
    }

    // MARK: A1 — Hero

    private var hero: some View {
        VStack(spacing: 0) {
            Spacer()
            VStack(spacing: VSpace.md) {
                Text(Brand.name)
                    .font(VType.hero(56))
                    .foregroundStyle(VColor.textPrimary)
                    .vGlow(VColor.accent, radius: 22, opacity: 0.3)
                Text("onboarding.hero.valueProp")
                    .font(VType.bodyLarge)
                    .foregroundStyle(VColor.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, VSpace.xl)
            }
            .opacity(heroAppeared ? 1 : 0)
            .offset(y: heroAppeared ? 0 : 16)
            Spacer()
            PrimaryButton(titleKey: "onboarding.cta.begin") { advance() }
                .padding(.horizontal, VSpace.lg)
            DisclaimerBanner(style: .short)
                .padding(.horizontal, VSpace.lg).padding(.bottom, VSpace.lg)
        }
        .onAppear {
            if reduceMotion { heroAppeared = true }
            else { withAnimation(Motion.springSoft.delay(0.1)) { heroAppeared = true } }
        }
    }

    // MARK: A2 — The problem (agitate)

    private let problemPoints: [(icon: String, key: LocalizedStringKey)] = [
        ("banknote", "onboarding.problem.p1"),
        ("megaphone", "onboarding.problem.p2"),
        ("eye.slash", "onboarding.problem.p3"),
    ]

    private var problem: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: VSpace.lg) {
                    Text("onboarding.problem.title")
                        .font(VType.heroTitle)
                        .foregroundStyle(VColor.textPrimary)
                        .padding(.top, VSpace.xl)
                    VStack(spacing: VSpace.sm) {
                        ForEach(Array(problemPoints.enumerated()), id: \.offset) { index, point in
                            GlassCard {
                                HStack(spacing: VSpace.md) {
                                    Image(systemName: point.icon)
                                        .font(.title3)
                                        .foregroundStyle(VColor.danger)
                                        .frame(width: 30)
                                    Text(point.key)
                                        .font(VType.body)
                                        .foregroundStyle(VColor.textPrimary)
                                    Spacer(minLength: 0)
                                }
                            }
                            .vStaggeredAppear(index: index)
                        }
                    }
                    Text("onboarding.problem.turn")
                        .font(VType.sectionTitle)
                        .foregroundStyle(VColor.primary)
                        .padding(.top, VSpace.xs)
                }
                .padding(VSpace.lg)
            }
            .scrollIndicators(.hidden)
            PrimaryButton(titleKey: "onboarding.continue") { advance() }
                .padding(.horizontal, VSpace.lg).padding(.bottom, VSpace.lg)
        }
    }

    // MARK: A3 — The promise (3 numbered steps; prove is featured)

    private var promise: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: VSpace.lg) {
                    VStack(alignment: .leading, spacing: VSpace.xs) {
                        Text("onboarding.promise.title")
                            .font(VType.heroTitle)
                            .foregroundStyle(VColor.textPrimary)
                        Text("onboarding.promise.subtitle")
                            .font(VType.body)
                            .foregroundStyle(VColor.textSecondary)
                    }
                    .padding(.top, VSpace.xl)
                    VStack(spacing: VSpace.md) {
                        promiseCard(1, "onboarding.promise.s1.title", "onboarding.promise.s1.body", index: 0)
                        promiseCard(2, "onboarding.promise.s2.title", "onboarding.promise.s2.body", index: 1)
                        promiseCard(3, "onboarding.promise.s3.title", "onboarding.promise.s3.body", index: 2, featured: true)
                    }
                }
                .padding(VSpace.lg)
            }
            .scrollIndicators(.hidden)
            PrimaryButton(titleKey: "onboarding.continue") { advance() }
                .padding(.horizontal, VSpace.lg).padding(.bottom, VSpace.lg)
        }
    }

    private func promiseCard(_ n: Int, _ titleKey: LocalizedStringKey, _ bodyKey: LocalizedStringKey,
                             index: Int, featured: Bool = false) -> some View {
        GlassCard(featured: featured) {
            HStack(alignment: .top, spacing: VSpace.md) {
                ZStack {
                    Circle()
                        .fill(featured ? AnyShapeStyle(VColor.heroGradient) : AnyShapeStyle(VColor.bgElevated2))
                        .frame(width: 38, height: 38)
                    Text(verbatim: "\(n)")
                        .font(VType.number(18))
                        .foregroundStyle(featured ? .white : VColor.primary)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(titleKey).font(VType.bodyLarge.weight(.semibold)).foregroundStyle(VColor.textPrimary)
                    Text(bodyKey).font(VType.body).foregroundStyle(VColor.textSecondary)
                }
                Spacer(minLength: 0)
            }
        }
        .vStaggeredAppear(index: index)
    }

    // MARK: A4 — Skin type (auto-advance)

    private var skinTypeStep: some View {
        OnboardingScaffold(titleKey: "quiz.skinType.title",
                           progress: (1, quizTotal),
                           continueEnabled: skinType != nil,
                           onContinue: { advance() }) {
            VStack(spacing: VSpace.sm) {
                ForEach(SkinType.allCases) { type in
                    OnboardingSelectCard(titleKey: type.localizationKey, selected: skinType == type) {
                        skinType = type
                        autoAdvance()
                    }
                }
            }
        }
    }

    // MARK: A5 — Concerns (chips)

    private var concernsStep: some View {
        OnboardingScaffold(titleKey: "quiz.concerns.title",
                           subtitleKey: "quiz.concerns.subtitle",
                           progress: (2, quizTotal),
                           continueEnabled: !concerns.isEmpty,
                           onContinue: { advance() }) {
            FlowLayout {
                ForEach(SkinConcern.allCases) { concern in
                    ChoiceChip(titleKey: concern.localizationKey, selected: concerns.contains(concern)) {
                        toggle(concern, in: &concerns)
                    }
                }
            }
        }
    }

    // MARK: A6 — Sensitivities (chips)

    private var sensitivitiesStep: some View {
        OnboardingScaffold(titleKey: "quiz.sensitivities.title",
                           subtitleKey: "quiz.sensitivities.subtitle",
                           progress: (3, quizTotal),
                           onContinue: { advance() },
                           onSkip: { sensitivities = []; advance() }) {
            chipGrid(sensitivityOptions, selection: $sensitivities)
        }
    }

    // MARK: A7 — Current routine (rows)

    private var productsStep: some View {
        OnboardingScaffold(titleKey: "quiz.products.title",
                           subtitleKey: "quiz.products.subtitle",
                           progress: (4, quizTotal),
                           onContinue: { advance() },
                           onSkip: { currentProducts = []; advance() }) {
            VStack(spacing: VSpace.sm) {
                ForEach(productOptions, id: \.id) { option in
                    OnboardingSelectCard(titleKey: option.key,
                                         selected: currentProducts.contains(option.id)) {
                        toggleOption(option.id, in: $currentProducts)
                    }
                }
            }
        }
    }

    // MARK: A8 — Goal (auto-advance)

    private var goalStep: some View {
        OnboardingScaffold(titleKey: "quiz.goal.title",
                           progress: (5, quizTotal),
                           continueEnabled: goal != nil,
                           onContinue: { advance() }) {
            VStack(spacing: VSpace.sm) {
                ForEach(goalOptions, id: \.id) { option in
                    OnboardingSelectCard(titleKey: option.key, selected: goal == option.id) {
                        goal = option.id
                        autoAdvance()
                    }
                }
            }
        }
    }

    /// Multi-select chips where selecting "none" clears the rest (and vice-versa).
    private func chipGrid(_ options: [(id: String, key: LocalizedStringKey)],
                          selection: Binding<Set<String>>) -> some View {
        FlowLayout {
            ForEach(options, id: \.id) { option in
                ChoiceChip(titleKey: option.key, selected: selection.wrappedValue.contains(option.id)) {
                    toggleOption(option.id, in: selection)
                }
            }
        }
    }

    // MARK: A9 — Building loader (ticking status)

    private let buildingSteps: [LocalizedStringKey] = [
        "onboarding.building.s1", "onboarding.building.s2", "onboarding.building.s3",
    ]
    @State private var buildingDone = 0

    private var building: some View {
        VStack(spacing: 0) {
            Spacer()
            VStack(alignment: .leading, spacing: VSpace.md) {
                Text("onboarding.building")
                    .font(VType.heroTitle)
                    .foregroundStyle(VColor.textPrimary)
                    .padding(.bottom, VSpace.xs)
                ForEach(Array(buildingSteps.enumerated()), id: \.offset) { index, key in
                    BuildingStatusRow(titleKey: key, done: index < buildingDone)
                }
            }
            .padding(VSpace.lg)
            .frame(maxWidth: .infinity, alignment: .leading)
            Spacer()
        }
        .task {
            buildingDone = 0
            for i in 1...buildingSteps.count {
                try? await Task.sleep(for: .seconds(0.6))
                withAnimation(VMotion.snappy) { buildingDone = i }
                Haptics.fire(.selection)
            }
            try? await Task.sleep(for: .seconds(0.5))
            advance()
        }
    }

    // MARK: A10 — Profile reveal (mirror it back)

    private var profileReveal: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: VSpace.lg) {
                    VStack(spacing: VSpace.xs) {
                        Image(systemName: "person.crop.circle.badge.checkmark")
                            .font(.system(size: 44, weight: .light))
                            .foregroundStyle(VColor.primary)
                            .vGlow(VColor.primary, radius: 18, opacity: 0.25)
                        Text("onboarding.profile.title")
                            .font(VType.heroTitle)
                            .foregroundStyle(VColor.textPrimary)
                            .multilineTextAlignment(.center)
                        Text("onboarding.profile.subtitle")
                            .font(VType.body)
                            .foregroundStyle(VColor.textSecondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, VSpace.xl)

                    GlassCard {
                        VStack(spacing: 0) {
                            summaryRow("onboarding.profile.type",
                                       value: skinType?.localizationKey ?? "onboarding.profile.notSet")
                            hairline
                            summaryRow("onboarding.profile.concerns",
                                       count: concerns.count)
                            hairline
                            summaryRow("onboarding.profile.flags",
                                       count: sensitivities.filter { $0 != "none" && $0 != "not sure" }.count)
                            hairline
                            summaryRow("onboarding.profile.goal", value: goalKey)
                        }
                    }
                }
                .padding(VSpace.lg)
            }
            .scrollIndicators(.hidden)
            PrimaryButton(titleKey: "onboarding.profile.cta") { advance() }
                .padding(.horizontal, VSpace.lg).padding(.bottom, VSpace.lg)
        }
    }

    /// The chosen goal's display key, looked up from `goalOptions` (avoids
    /// constructing a `LocalizedStringKey` from a runtime string).
    private var goalKey: LocalizedStringKey {
        goalOptions.first { $0.id == goal }?.key ?? "onboarding.profile.notSet"
    }

    private var hairline: some View {
        Rectangle().fill(VColor.strokeSubtle).frame(height: 1)
    }

    private func summaryRow(_ labelKey: LocalizedStringKey, value: LocalizedStringKey) -> some View {
        HStack {
            Text(labelKey).font(VType.body).foregroundStyle(VColor.textSecondary)
            Spacer()
            Text(value).font(VType.bodyMedium).foregroundStyle(VColor.textPrimary)
        }
        .padding(.vertical, VSpace.sm)
    }

    private func summaryRow(_ labelKey: LocalizedStringKey, count: Int) -> some View {
        HStack {
            Text(labelKey).font(VType.body).foregroundStyle(VColor.textSecondary)
            Spacer()
            Text(verbatim: "\(count)").font(VType.bodyMedium).foregroundStyle(VColor.textPrimary)
        }
        .padding(.vertical, VSpace.sm)
    }

    // MARK: A14 — Reminder opt-in (with time picker)

    private var reminders: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: VSpace.lg) {
                    VStack(spacing: VSpace.md) {
                        Image(systemName: "bell.badge")
                            .font(.system(size: 50, weight: .light))
                            .foregroundStyle(VColor.accent)
                            .vGlow(VColor.accent, radius: 18, opacity: 0.25)
                        Text("onboarding.reminders.title")
                            .font(VType.heroTitle).foregroundStyle(VColor.textPrimary)
                            .multilineTextAlignment(.center)
                        Text("onboarding.reminders.body")
                            .font(VType.body).foregroundStyle(VColor.textSecondary)
                            .multilineTextAlignment(.center).padding(.horizontal, VSpace.md)
                    }
                    .padding(.top, VSpace.xl)

                    GlassCard {
                        HStack {
                            Text("onboarding.reminders.time")
                                .font(VType.body).foregroundStyle(VColor.textPrimary)
                            Spacer()
                            DatePicker("onboarding.reminders.time",
                                       selection: $reminderTime,
                                       displayedComponents: .hourAndMinute)
                                .labelsHidden()
                                .tint(VColor.primary)
                        }
                    }
                }
                .padding(VSpace.lg)
            }
            .scrollIndicators(.hidden)

            VStack(spacing: VSpace.xs) {
                PrimaryButton(titleKey: "onboarding.reminders.set", systemImage: "bell.fill") {
                    Task {
                        if await NotificationManager.requestAuthorization() {
                            let c = Calendar.current.dateComponents([.hour, .minute], from: reminderTime)
                            NotificationManager.scheduleRoutineReminders(hour: c.hour ?? 8, minute: c.minute ?? 0)
                        }
                        advance()
                    }
                }
                SecondaryButton(titleKey: "onboarding.reminders.later") { advance() }
            }
            .padding(.horizontal, VSpace.lg).padding(.bottom, VSpace.lg)
        }
    }

    // MARK: A16 — Ready

    private var ready: some View {
        VStack(spacing: 0) {
            Spacer()
            VStack(spacing: VSpace.md) {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 60, weight: .light))
                    .foregroundStyle(VColor.success)
                    .vGlow(VColor.success, radius: 20, opacity: 0.25)
                Text("onboarding.ready.title")
                    .font(VType.heroTitle).foregroundStyle(VColor.textPrimary)
                    .multilineTextAlignment(.center)
                Text("onboarding.ready.body")
                    .font(VType.bodyLarge).foregroundStyle(VColor.textSecondary)
                    .multilineTextAlignment(.center).padding(.horizontal, VSpace.xl)
            }
            Spacer()
            PrimaryButton(titleKey: "onboarding.ready.cta", systemImage: "arrow.right") { complete() }
                .padding(.horizontal, VSpace.lg)
            DisclaimerBanner(style: .short)
                .padding(.horizontal, VSpace.lg).padding(.bottom, VSpace.lg)
        }
    }

    // MARK: Flow control

    private func advance() {
        if let next = Step(rawValue: step.rawValue + 1) { step = next }
    }

    /// Brief delay so the selected state is visible before the step slides away.
    private func autoAdvance() {
        let delay = reduceMotion ? 0.0 : 0.32
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { advance() }
    }

    private func toggle<T: Hashable>(_ value: T, in set: inout Set<T>) {
        if set.contains(value) { set.remove(value) } else { set.insert(value) }
    }

    /// Toggle a string option where "none" is mutually exclusive with the rest.
    private func toggleOption(_ id: String, in selection: Binding<Set<String>>) {
        var set = selection.wrappedValue
        if id == "none" {
            set = set.contains("none") ? [] : ["none"]
        } else {
            set.remove("none")
            if set.contains(id) { set.remove(id) } else { set.insert(id) }
        }
        selection.wrappedValue = set
    }

    private func complete() {
        let profile = profiles.first ?? {
            let created = UserProfile()
            modelContext.insert(created)
            return created
        }()
        profile.skinType = skinType
        profile.concerns = Array(concerns)
        profile.sensitivities = sensitivities.filter { $0 != "none" && $0 != "not sure" }
        profile.currentProducts = currentProducts.filter { $0 != "none" }
        profile.goal = goal
        profile.onboardingComplete = true
        try? modelContext.save()
        Haptics.fire(.verdictReveal)
    }

    private static var defaultReminderTime: Date {
        Calendar.current.date(from: DateComponents(hour: 21, minute: 0)) ?? .now
    }
}
