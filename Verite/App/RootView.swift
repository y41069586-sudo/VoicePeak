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
            DQColor.background.ignoresSafeArea()

            if onboardingComplete {
                DermiqTabShell()
                    .transition(.opacity)
            } else {
                OnboardingRampFlow()
                    .transition(.opacity)
            }
        }
        .veriteAnimation(value: onboardingComplete)
        .tint(DQColor.accent)
        .preferredColorScheme(.light) // warm GlamUp light, app-wide
        .task { SeedData.seedCatalogIfNeeded(modelContext) }
        // Skin Duel invite/result links (verite://duel?d=…) land in the inbox;
        // the Duel tab picks them up and routes accordingly.
        .onOpenURL { url in DuelInbox.shared.handle(url) }
    }
}

#Preview {
    RootView()
        .modelContainer(Persistence.previewContainer)
        .environment(AppState())
        .environment(PurchaseManager())
        .preferredColorScheme(.light)
}
