import SwiftUI
import SwiftData

/// Top-level router: shows onboarding until a profile marks it complete, then the
/// main tab experience. The animated gradient mesh sits behind everything.
struct RootView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.modelContext) private var modelContext
    @Query private var profiles: [UserProfile]

    private var onboardingComplete: Bool {
        profiles.first?.onboardingComplete ?? false
    }

    var body: some View {
        ZStack {
            GradientMeshBackground()

            if onboardingComplete {
                MainTabView()
                    .transition(.opacity)
            } else {
                OnboardingRampFlow()
                    .transition(.opacity)
            }
        }
        .veriteAnimation(value: onboardingComplete)
        .tint(Theme.primary)
        // Dark system chrome over the cinematic onboarding stage; the committed
        // light-first white-and-blue look everywhere else.
        .preferredColorScheme(onboardingComplete ? .light : .dark)
        .task { SeedData.seedCatalogIfNeeded(modelContext) }
    }
}

#Preview {
    RootView()
        .modelContainer(Persistence.previewContainer)
        .environment(AppState())
        .environment(PurchaseManager())
        .preferredColorScheme(.light)
}
