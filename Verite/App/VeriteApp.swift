import SwiftUI
import SwiftData
import UserNotifications

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

    init() {
        // Apply the in-app language picker through `AppleLanguages`, the one
        // lever Foundation AND SwiftUI both read. Must happen here, before any
        // UI exists — the value is consumed as the process starts.
        AppLanguage.apply()
        // Notifications show in the foreground and their taps deep-link.
        UNUserNotificationCenter.current().delegate = DQNotificationDelegate.shared
    }

    var body: some Scene {
        WindowGroup {
            // Color scheme lives in RootView: dark for the cinematic onboarding
            // stage, then the committed light-first white-and-blue look.
            RootView()
                .environment(appState)
                .environment(purchases)
                .task {
                    if appState.featureFlags.purchasesEnabled { await purchases.load() }
                }
        }
        .modelContainer(modelContainer)
    }
}

// No `.environment(\.locale, …)` override here on purpose. It switches only
// `Text(…)`, leaving every `String(localized:)` on the device language — the
// half-translated-screen bug. `AppLanguage.apply()` in `init()` covers both.
