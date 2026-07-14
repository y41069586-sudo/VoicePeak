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
        // Referral links (verite://invite?…) credit bonus scans; Skin Duel
        // links (verite://duel?d=…) land in the inbox for the Duel tab.
        .onOpenURL { url in
            if ReferralStore.shared.handle(url) { return }
            DuelInbox.shared.handle(url)
        }
    }
}

#Preview {
    RootView()
        .modelContainer(Persistence.previewContainer)
        .environment(AppState())
        .environment(PurchaseManager())
        .preferredColorScheme(.light)
}
