import SwiftUI
import SwiftData

/// Top-level router: shows onboarding until a profile marks it complete, then the
/// main tab experience. The animated gradient mesh sits behind everything.
struct RootView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.modelContext) private var modelContext
    @Query private var profiles: [UserProfile]

    /// ANY completed profile counts — `.first` on an unsorted query is
    /// nondeterministic, and a stray second profile row must never bounce a
    /// finished user back into onboarding (e.g. on a widget cold launch).
    private var onboardingComplete: Bool {
        profiles.contains { $0.onboardingComplete }
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
        // Referral links (verite://invite?…) credit bonus scans; compare
        // links (verite://compare?d=…) open the friend face-off sheet.
        .onOpenURL { url in
            if ReferralStore.shared.handle(url) { return }
            _ = CompareInbox.shared.handle(url)
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
