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

    /// Language override chosen in Settings; empty string = follow system locale.
    @AppStorage("languageOverride") private var languageOverride: String = ""

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(appState)
                .preferredColorScheme(.dark) // dark-mode-first, committed look
                .applyLanguageOverride(languageOverride)
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
