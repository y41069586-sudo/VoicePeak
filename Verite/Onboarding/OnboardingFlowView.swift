import SwiftUI
import SwiftData

// MARK: - Main Onboarding Flow

/// Premium 8-screen onboarding for SKINMAXX.
/// Emotionally-driven, conversion-optimised, Apple-quality UX.
/// All design tokens route through VColor / VType / VSpace / VMotion.
struct OnboardingFlowView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Query private var profiles: [UserProfile]

    enum Step: Int, CaseIterable {
        case emotionalHook     // Screen 1 — cinematic welcome
        case whatVeriteDoes    // Screen 2 — mock dashboard preview
        case mockScan          // Screen 3 — simulated face analysis
        case productMatching   // Screen 4 — ingredient intelligence
        case privacy           // Screen 5 — trust & data
        case goalSetup         // Screen 6 — personalisation
        case account           // Screen 7 — account creation
        case firstScanCTA      // Screen 8 — start analysis
    }

    @State private var step: Step = .emotionalHook

    // Profile data collected across screens
    @State private var skinType: SkinType?
    @State private var concerns: Set<SkinConcern> = []
    @State private var sensitivities: Set<String> = []
    @State private var currentProducts: Set<String> = []
    @State private var goal: String?

    // Per-screen animation state
    @State private var heroVisible = false

    var body: some View {
        ZStack {
            VBackground().ignoresSafeArea()
            currentScreen
                .id(step)
                .transition(pageTransition)
        }
        .animation(
            reduceMotion ? VMotion.crossfade : .spring(response: 0.42, dampingFraction: 0.88),
            value: step
        )
    }

    private var pageTransition: AnyTransition {
        guard !reduceMotion else { return .opacity }
        return .asymmetric(
            insertion: .move(edge: .trailing).combined(with: .opacity),
            removal:   .move(edge: .leading).combined(with: .opacity)
        )
    }

    @ViewBuilder
    private var currentScreen: some View {
        switch step {
        case .emotionalHook:   screen1
        case .whatVeriteDoes:  screen2
        case .mockScan:        screen3
        case .productMatching: screen4
        case .privacy:         screen5
        case .goalSetup:       screen6
        case .account:         screen7
        case .firstScanCTA:    screen8
        }
    }

    // MARK: Screen 1 — Emotional Hook

    private var screen1: some View {
        VStack(spacing: 0) {
            Spacer()
            VStack(spacing: VSpace.md) {
                // Wordmark
                Text("SKINMAXX")
                    .font(VType.hero(52))
                    .foregroundStyle(VColor.textPrimary)
                    .tracking(-0.5)
                    .vGlow(VColor.primary, radius: 28, opacity: 0.18)

                VStack(spacing: VSpace.sm) {
                    Text("Your skin changes every day.")
                        .font(VType.heroTitle)
                        .foregroundStyle(VColor.textPrimary)
                        .multilineTextAlignment(.center)
                    Text("Most skincare never notices.")
                        .font(VType.heroTitle)
                        .foregroundStyle(VColor.textSecondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, VSpace.xl)

                // Trust micro-copy
                Text("Science-backed · 100% on-device · Private")
                    .font(VType.micro)
                    .tracking(0.8)
                    .textCase(.uppercase)
                    .foregroundStyle(VColor.textTertiary)
                    .padding(.top, VSpace.xs)
            }
            .opacity(heroVisible ? 1 : 0)
            .offset(y: heroVisible ? 0 : 28)
            Spacer()
            PrimaryButton(titleKey: "Begin") { advance() }
                .padding(.horizontal, VSpace.lg)
            Spacer().frame(height: VSpace.xxl)
        }
        .onAppear {
            guard !heroVisible else { return }
            if reduceMotion {
                heroVisible = true
            } else {
                withAnimation(VMotion.gentle.delay(0.15)) { heroVisible = true }
            }
        }
    }

    // MARK: Screen 2 — What SKINMAXX Does

    private var screen2: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: VSpace.lg) {
                    screen2Header
                    MockDashboardCard().vStaggeredAppear(index: 0)
                    MockTrendCard().vStaggeredAppear(index: 1)
                    MockRoutineCard().vStaggeredAppear(index: 2)
                }
                .padding(.horizontal, VSpace.lg)
                .padding(.bottom, VSpace.lg)
            }
            .scrollIndicators(.hidden)
            PrimaryButton(titleKey: "See How It Works") { advance() }
                .padding(.horizontal, VSpace.lg)
            Spacer().frame(height: VSpace.xxl)
        }
    }

    private var screen2Header: some View {
        VStack(alignment: .leading, spacing: VSpace.sm) {
            Text("Advanced skin intelligence,")
                .font(VType.heroTitle)
                .foregroundStyle(VColor.textPrimary)
            Text("made personal.")
                .font(VType.heroTitle)
                .foregroundStyle(VColor.primary)
        }
        .padding(.top, VSpace.xl)
    }

    // MARK: Screen 3 — Interactive Mock Scan

    private var screen3: some View {
        VStack(spacing: 0) {
            VStack(spacing: VSpace.sm) {
                Text("Experience your first analysis.")
                    .font(VType.heroTitle)
                    .foregroundStyle(VColor.textPrimary)
                    .multilineTextAlignment(.center)
                Text("This is what SKINMAXX sees.")
                    .font(VType.body)
                    .foregroundStyle(VColor.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, VSpace.xxl)
            .padding(.horizontal, VSpace.lg)

            Spacer()

            MockFaceScanView(reduceMotion: reduceMotion)
                .padding(.horizontal, VSpace.lg)

            Spacer()

            PrimaryButton(titleKey: "This looks incredible. Continue.") { advance() }
                .padding(.horizontal, VSpace.lg)
            Spacer().frame(height: VSpace.xxl)
        }
    }

    // MARK: Screen 4 — Product Matching

    private var screen4: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: VSpace.lg) {
                    VStack(alignment: .leading, spacing: VSpace.sm) {
                        Text("Formulated around you.")
                            .font(VType.heroTitle)
                            .foregroundStyle(VColor.textPrimary)
                        Text("Every ingredient, understood.")
                            .font(VType.body)
                            .foregroundStyle(VColor.textSecondary)
                    }
                    .padding(.top, VSpace.xl)

                    IngredientMatchCard(
                        icon: "checkmark.circle.fill",
                        iconColor: VColor.success,
                        name: "Barrier Repair Serum",
                        brand: "La Roche-Posay",
                        insight: "Ceramide complex supports your skin's natural lipid barrier — ideal for your profile.",
                        badge: "Matches your barrier goal",
                        badgeColor: VColor.success
                    )
                    .vStaggeredAppear(index: 0)

                    IngredientMatchCard(
                        icon: "exclamationmark.triangle.fill",
                        iconColor: VColor.warning,
                        name: "Denatured Alcohol (SD-38)",
                        brand: "Ingredient alert detected",
                        insight: "May amplify sensitivity in your skin type. Look for alcohol-free alternatives.",
                        badge: "Flagged for your profile",
                        badgeColor: VColor.warning
                    )
                    .vStaggeredAppear(index: 1)

                    GlassCard {
                        HStack(spacing: VSpace.md) {
                            Image(systemName: "brain")
                                .font(.title2)
                                .foregroundStyle(VColor.primary)
                                .frame(width: 36)
                            VStack(alignment: .leading, spacing: 4) {
                                Text("SKINMAXX reads every ingredient label.")
                                    .font(VType.bodyMedium)
                                    .foregroundStyle(VColor.textPrimary)
                                Text("Open Beauty Facts database, cross-matched with your unique skin profile.")
                                    .font(VType.caption)
                                    .foregroundStyle(VColor.textSecondary)
                            }
                        }
                    }
                    .vStaggeredAppear(index: 2)
                }
                .padding(.horizontal, VSpace.lg)
                .padding(.bottom, VSpace.lg)
            }
            .scrollIndicators(.hidden)
            PrimaryButton(titleKey: "Continue") { advance() }
                .padding(.horizontal, VSpace.lg)
            Spacer().frame(height: VSpace.xxl)
        }
    }

    // MARK: Screen 5 — Privacy & Trust

    private var screen5: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: VSpace.xl) {
                    privacyHero
                    privacyPillars
                    privacyFootnote
                }
                .padding(.horizontal, VSpace.lg)
                .padding(.bottom, VSpace.lg)
            }
            .scrollIndicators(.hidden)
            PrimaryButton(titleKey: "I Trust This. Let's Continue.") { advance() }
                .padding(.horizontal, VSpace.lg)
            Spacer().frame(height: VSpace.xxl)
        }
    }

    private var privacyHero: some View {
        VStack(spacing: VSpace.md) {
            Image(systemName: "lock.shield.fill")
                .font(.system(size: 54, weight: .light))
                .foregroundStyle(VColor.primary)
                .vGlow(VColor.primary, radius: 20, opacity: 0.20)
                .padding(.top, VSpace.xl)
            Text("Your skin data\nstays with you.")
                .font(VType.heroTitle)
                .foregroundStyle(VColor.textPrimary)
                .multilineTextAlignment(.center)
            Text("SKINMAXX was designed from the ground up with your privacy as the foundation — not an afterthought.")
                .font(VType.body)
                .foregroundStyle(VColor.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, VSpace.sm)
        }
    }

    private var privacyPillars: some View {
        GlassCard {
            VStack(spacing: 0) {
                PrivacyPillarRow(icon: "iphone", text: "Scans processed entirely on-device", index: 0)
                Rectangle().fill(VColor.strokeSubtle).frame(height: 1)
                PrivacyPillarRow(icon: "xmark.icloud.fill", text: "No face images ever leave your phone", index: 1)
                Rectangle().fill(VColor.strokeSubtle).frame(height: 1)
                PrivacyPillarRow(icon: "hand.raised.slash.fill", text: "No biometric data shared or sold", index: 2)
                Rectangle().fill(VColor.strokeSubtle).frame(height: 1)
                PrivacyPillarRow(icon: "trash.fill", text: "Delete everything, any time", index: 3)
            }
        }
    }

    private var privacyFootnote: some View {
        Text("SKINMAXX uses Apple's Vision framework for on-device processing. No cloud AI. No third-party data sharing.")
            .font(VType.caption)
            .foregroundStyle(VColor.textTertiary)
            .multilineTextAlignment(.center)
    }

    // MARK: Screen 6 — Goal Setup

    private var screen6: some View {
        GoalSetupScreen(
            skinType: $skinType,
            concerns: $concerns,
            goal: $goal,
            reduceMotion: reduceMotion,
            onComplete: { advance() }
        )
    }

    // MARK: Screen 7 — Account Creation

    private var screen7: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: VSpace.xl) {
                    screen7Hero
                    screen7Benefits
                }
                .padding(.horizontal, VSpace.lg)
                .padding(.bottom, VSpace.lg)
            }
            .scrollIndicators(.hidden)
            screen7CTAs
        }
    }

    private var screen7Hero: some View {
        VStack(spacing: VSpace.md) {
            Image(systemName: "chart.line.uptrend.xyaxis.circle.fill")
                .font(.system(size: 58, weight: .light))
                .foregroundStyle(VColor.primary)
                .vGlow(VColor.primary, radius: 22, opacity: 0.20)
                .padding(.top, VSpace.xl)
            Text("Keep your progress.")
                .font(VType.heroTitle)
                .foregroundStyle(VColor.textPrimary)
                .multilineTextAlignment(.center)
            Text("Your scans, routines, and insights — persisted and always available.")
                .font(VType.body)
                .foregroundStyle(VColor.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, VSpace.md)
        }
    }

    private var screen7Benefits: some View {
        GlassCard {
            VStack(spacing: 0) {
                AccountBenefitRow(icon: "chart.xyaxis.line", text: "Scan history across all devices", index: 0)
                Rectangle().fill(VColor.strokeSubtle).frame(height: 1)
                AccountBenefitRow(icon: "arrow.triangle.2.circlepath", text: "Personalized routine sync", index: 1)
                Rectangle().fill(VColor.strokeSubtle).frame(height: 1)
                AccountBenefitRow(icon: "chart.bar.fill", text: "Long-term skin trend insights", index: 2)
                Rectangle().fill(VColor.strokeSubtle).frame(height: 1)
                AccountBenefitRow(icon: "bell.badge.fill", text: "Smart scan & routine reminders", index: 3)
            }
        }
    }

    private var screen7CTAs: some View {
        VStack(spacing: VSpace.sm) {
            AppleSignInPlaceholder { advance() }
            Button(action: { advance() }) {
                Text("Continue without account")
                    .font(VType.body)
                    .foregroundStyle(VColor.textSecondary)
                    .padding(.vertical, VSpace.sm)
            }
            Text("No password. No marketing emails.")
                .font(VType.caption)
                .foregroundStyle(VColor.textTertiary)
        }
        .padding(.horizontal, VSpace.lg)
        .padding(.bottom, VSpace.xxl)
    }

    // MARK: Screen 8 — First Scan CTA

    private var screen8: some View {
        VStack(spacing: 0) {
            Spacer()
            VStack(spacing: VSpace.lg) {
                PulsingScanOrb()
                VStack(spacing: VSpace.sm) {
                    Text("Let's see your skin.")
                        .font(VType.heroTitle)
                        .foregroundStyle(VColor.textPrimary)
                        .multilineTextAlignment(.center)
                    Text("Your first analysis takes about 60 seconds.")
                        .font(VType.body)
                        .foregroundStyle(VColor.textSecondary)
                        .multilineTextAlignment(.center)
                }
                screen8Hints
            }
            .padding(.horizontal, VSpace.lg)
            Spacer()
            screen8CTAs
        }
    }

    private var screen8Hints: some View {
        VStack(alignment: .leading, spacing: VSpace.sm) {
            ScanHintRow(icon: "sun.max", text: "Good lighting makes a difference")
            ScanHintRow(icon: "face.smiling", text: "No makeup needed")
            ScanHintRow(icon: "lock", text: "Completely private — processed on your iPhone")
        }
        .padding(.horizontal, VSpace.xl)
    }

    private var screen8CTAs: some View {
        VStack(spacing: VSpace.sm) {
            PrimaryButton(titleKey: "Start Your First Analysis", systemImage: "camera.fill") {
                complete()
            }
            Button(action: { complete() }) {
                Text("I'll do this later")
                    .font(VType.body)
                    .foregroundStyle(VColor.textSecondary)
                    .padding(.vertical, VSpace.sm)
            }
        }
        .padding(.horizontal, VSpace.lg)
        .padding(.bottom, VSpace.xxl)
    }

    // MARK: — Navigation

    private func advance() {
        if let next = Step(rawValue: step.rawValue + 1) { step = next }
        else { complete() }
    }

    private func complete() {
        let profile = profiles.first ?? {
            let p = UserProfile()
            modelContext.insert(p)
            return p
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
}

// MARK: - Goal Setup Screen

/// Extracted to its own struct to keep the main flow type-checker-friendly.
private struct GoalSetupScreen: View {
    @Binding var skinType: SkinType?
    @Binding var concerns: Set<SkinConcern>
    @Binding var goal: String?
    let reduceMotion: Bool
    let onComplete: () -> Void

    private enum SubStep { case skinType, goal, concerns }
    @State private var subStep: SubStep = .skinType

    private let skinTypeOptions: [(type: SkinType, icon: String, desc: String)] = [
        (.oily,        "drop.fill",               "Shine, enlarged pores"),
        (.combination, "circle.lefthalf.filled",  "T-zone oily, cheeks normal"),
        (.normal,      "checkmark.circle.fill",   "Balanced, minimal issues"),
        (.dry,         "leaf.fill",               "Tightness, flakiness"),
        (.sensitive,   "heart.fill",              "Reacts easily to products"),
    ]

    private let goalOptions: [(id: String, label: String, icon: String)] = [
        ("calmer",     "Calmer skin",         "leaf"),
        ("clearer",    "Clearer skin",         "sparkles"),
        ("hydrated",   "Better hydration",     "drop.fill"),
        ("redness",    "Reduce redness",       "heart.fill"),
        ("barrier",    "Barrier recovery",     "shield.fill"),
        ("understand", "Understand my skin",   "chart.bar.fill"),
    ]

    var body: some View {
        VStack(spacing: 0) {
            // Sub-step dots
            HStack(spacing: 6) {
                let steps: [SubStep] = [.skinType, .goal, .concerns]
                ForEach(steps.indices, id: \.self) { i in
                    let isCurrent = steps[i] == subStep
                    Capsule()
                        .fill(isCurrent ? VColor.primary : VColor.strokeSubtle)
                        .frame(width: isCurrent ? 22 : 8, height: 6)
                }
            }
            .animation(VMotion.snappy, value: subStep)
            .padding(.top, VSpace.md)

            switch subStep {
            case .skinType: skinTypeView
            case .goal:     goalView
            case .concerns: concernsView
            }
        }
        .animation(
            reduceMotion ? VMotion.crossfade : VMotion.standard,
            value: subStep
        )
    }

    // Sub-step A: Skin type
    private var skinTypeView: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: VSpace.md) {
                    VStack(alignment: .leading, spacing: VSpace.sm) {
                        Text("What's your skin type?")
                            .font(VType.heroTitle)
                            .foregroundStyle(VColor.textPrimary)
                        Text("We'll personalise everything around this.")
                            .font(VType.body)
                            .foregroundStyle(VColor.textSecondary)
                    }
                    .padding(.top, VSpace.lg)

                    VStack(spacing: VSpace.sm) {
                        ForEach(skinTypeOptions.indices, id: \.self) { i in
                            let option = skinTypeOptions[i]
                            GoalLargeCard(
                                icon: option.icon,
                                label: option.type.rawValue.capitalized,
                                subtitle: option.desc,
                                selected: skinType == option.type
                            ) {
                                Haptics.fire(.selection)
                                skinType = option.type
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.32) {
                                    withAnimation(VMotion.standard) { subStep = .goal }
                                }
                            }
                            .vStaggeredAppear(index: i)
                        }
                    }
                }
                .padding(.horizontal, VSpace.lg)
                .padding(.bottom, VSpace.lg)
            }
            .scrollIndicators(.hidden)
        }
    }

    // Sub-step B: Primary goal
    private var goalView: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: VSpace.md) {
                    VStack(alignment: .leading, spacing: VSpace.sm) {
                        Text("What matters most to you?")
                            .font(VType.heroTitle)
                            .foregroundStyle(VColor.textPrimary)
                        Text("Your primary goal shapes every recommendation.")
                            .font(VType.body)
                            .foregroundStyle(VColor.textSecondary)
                    }
                    .padding(.top, VSpace.lg)

                    VStack(spacing: VSpace.sm) {
                        ForEach(goalOptions.indices, id: \.self) { i in
                            let option = goalOptions[i]
                            GoalLargeCard(
                                icon: option.icon,
                                label: option.label,
                                subtitle: nil,
                                selected: goal == option.id
                            ) {
                                Haptics.fire(.selection)
                                goal = option.id
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.32) {
                                    withAnimation(VMotion.standard) { subStep = .concerns }
                                }
                            }
                            .vStaggeredAppear(index: i)
                        }
                    }
                }
                .padding(.horizontal, VSpace.lg)
                .padding(.bottom, VSpace.lg)
            }
            .scrollIndicators(.hidden)
        }
    }

    // Sub-step C: Concerns (optional)
    private var concernsView: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: VSpace.md) {
                    VStack(alignment: .leading, spacing: VSpace.sm) {
                        Text("Any specific concerns?")
                            .font(VType.heroTitle)
                            .foregroundStyle(VColor.textPrimary)
                        Text("Select all that apply. SKINMAXX flags these across every scan.")
                            .font(VType.body)
                            .foregroundStyle(VColor.textSecondary)
                    }
                    .padding(.top, VSpace.lg)

                    FlexWrap {
                        ForEach(SkinConcern.allCases) { concern in
                            ChoiceChip(
                                titleKey: concern.localizationKey,
                                selected: concerns.contains(concern)
                            ) {
                                Haptics.fire(.selection)
                                if concerns.contains(concern) {
                                    concerns.remove(concern)
                                } else {
                                    concerns.insert(concern)
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, VSpace.lg)
                .padding(.bottom, VSpace.lg)
            }
            .scrollIndicators(.hidden)

            VStack(spacing: VSpace.sm) {
                PrimaryButton(titleKey: "Continue") { onComplete() }
                SecondaryButton(titleKey: "Skip") { onComplete() }
            }
            .padding(.horizontal, VSpace.lg)
            .padding(.bottom, VSpace.xxl)
        }
    }
}
