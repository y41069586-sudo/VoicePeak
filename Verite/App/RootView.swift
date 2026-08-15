import SwiftUI
import SwiftData
import GoogleSignIn

/// Top-level router: shows onboarding until a profile marks it complete, then the
/// main tab experience. The animated gradient mesh sits behind everything.
struct RootView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.modelContext) private var modelContext
    @Query private var profiles: [UserProfile]

    /// Up until the splash has finished leaving. Not persisted on purpose —
    /// it belongs to this launch, and a cold start is exactly when it should
    /// play.
    @State private var showSplash = true

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

            // Above everything, and owning its own exit — `SplashScreen`
            // animates itself out and then calls back, so there is no second
            // transition fighting the one inside it. It is built while the
            // app underneath is already laid out, which is what lets it
            // dissolve straight onto a finished screen.
            if showSplash {
                SplashScreen { showSplash = false }
                    .transition(.identity)
                    .zIndex(1)
            }
        }
        .veriteAnimation(value: onboardingComplete)
        .tint(DQColor.accentBright)
        .preferredColorScheme(.light) // warm GlamUp light, app-wide
        // Referral links (verite://invite?…) credit bonus scans; compare
        // links (verite://compare?d=…) open the friend face-off sheet.
        .onOpenURL { url in
            // Google Sign-In's OAuth callback must be handed to the SDK first.
            if GIDSignIn.sharedInstance.handle(url) { return }
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
