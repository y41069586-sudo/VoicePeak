import SwiftUI

/// The premium four-tab shell: Home, Analyzer (core), Routine, Progress.
/// Settings are moved to a dedicated settings modal, accessed via Home.
struct MainTabView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        @Bindable var appState = appState

        TabView(selection: $appState.selectedTab) {
            HomeTabView()
                .tabItem { Label(AppTab.home.titleKey, systemImage: AppTab.home.systemImage) }
                .tag(AppTab.home)

            AnalyzerTabView()
                .tabItem { Label(AppTab.analyzer.titleKey, systemImage: AppTab.analyzer.systemImage) }
                .tag(AppTab.analyzer)

            RoutineTabView()
                .tabItem { Label(AppTab.routine.titleKey, systemImage: AppTab.routine.systemImage) }
                .tag(AppTab.routine)

            ProgressTabView()
                .tabItem { Label(AppTab.progress.titleKey, systemImage: AppTab.progress.systemImage) }
                .tag(AppTab.progress)
        }
        .tint(VColor.primary)
    }
}

#Preview {
    MainTabView()
        .modelContainer(Persistence.previewContainer)
        .environment(AppState())
        .environment(PurchaseManager())
        .preferredColorScheme(.light)
}
