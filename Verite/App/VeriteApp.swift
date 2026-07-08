import SwiftUI
import SwiftData

/// Application entry point. Sets up the SwiftData container, injects global state,
/// commits to the dark "Aesthetic Blue" look, and applies any language override.
@main
struct VeriteApp: App {
    /// The shared on-disk store.
    let modelContainer = Persistence.makeContainer()

    /// Global observable state (holds the feature flags — all OFF by default).
    @State private var appState = AppState()

    /// StoreKit manager — always in the environment, only *used* when purchases
    /// are enabled.
    @State private var purchases = PurchaseManager()

    /// Language override chosen in Settings; empty string = follow system locale.
    @AppStorage("languageOverride") private var languageOverride: String = ""

    var body: some Scene {
        WindowGroup {
            // Color scheme lives in RootView: dark for the cinematic onboarding
            // stage, then the committed light-first white-and-blue look.
            RootView()
                .environment(appState)
                .environment(purchases)
                .applyLanguageOverride(languageOverride)
                .task {
                    if appState.featureFlags.purchasesEnabled { await purchases.load() }
                }
        }
        .modelContainer(modelContainer)
    }
}

private extension View {
    /// Force a specific UI language when the user overrides it in Settings.
    /// An empty override falls back to the system locale.
    @ViewBuilder
    func applyLanguageOverride(_ code: String) -> some View {
        if code.isEmpty {
            self
        } else {
            self.environment(\.locale, Locale(identifier: code))
        }
    }
}
