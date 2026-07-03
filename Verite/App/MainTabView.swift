import SwiftUI

/// The six-tab shell. Individual tabs are filled in across later milestones;
/// for now Today + Settings are real and the rest are honest "coming soon" states.
struct MainTabView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        @Bindable var appState = appState

        TabView(selection: $appState.selectedTab) {
            DashboardView()
                .tabItem { Label(AppTab.today.titleKey, systemImage: AppTab.today.systemImage) }
                .tag(AppTab.today)

            ScanView()
                .tabItem { Label(AppTab.scan.titleKey, systemImage: AppTab.scan.systemImage) }
                .tag(AppTab.scan)

            CatalogView()
                .tabItem { Label(AppTab.catalog.titleKey, systemImage: AppTab.catalog.systemImage) }
                .tag(AppTab.catalog)

            RoutineView()
                .tabItem { Label(AppTab.routine.titleKey, systemImage: AppTab.routine.systemImage) }
                .tag(AppTab.routine)

            ProgressDashboardView()
                .tabItem { Label(AppTab.progress.titleKey, systemImage: AppTab.progress.systemImage) }
                .tag(AppTab.progress)

            SettingsView()
                .tabItem { Label(AppTab.settings.titleKey, systemImage: AppTab.settings.systemImage) }
                .tag(AppTab.settings)
        }
    }
}

#Preview {
    MainTabView()
        .modelContainer(Persistence.previewContainer)
        .environment(AppState())
        .preferredColorScheme(.dark)
}
