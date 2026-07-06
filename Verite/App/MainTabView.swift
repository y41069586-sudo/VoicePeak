import SwiftUI

/// The six-tab shell. Individual tabs are filled in across later milestones;
/// for now Today + Settings are real and the rest are honest "coming soon" states.
struct MainTabView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        @Bindable var appState = appState

        ZStack(alignment: .bottom) {
            Group {
                switch appState.selectedTab {
                case .home:
                    DashboardView()
                case .analyze:
                    ScanView()
                case .routine:
                    RoutineView()
                case .progress:
                    ProgressDashboardView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            
            // Custom premium glassmorphic tab bar
            customTabBar
        }
        .ignoresSafeArea(.keyboard, edges: .bottom)
    }

    private var customTabBar: some View {
        HStack {
            tabButton(for: .home)
            Spacer()
            tabButton(for: .analyze)
            Spacer()
            tabButton(for: .routine)
            Spacer()
            tabButton(for: .progress)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(
            .ultraThinMaterial,
            in: RoundedRectangle(cornerRadius: 22, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(VColor.strokeSubtle, lineWidth: 1)
        )
        .padding(.horizontal, 20)
        .padding(.bottom, 12)
        .shadow(color: VColor.primary.opacity(0.06), radius: 10, x: 0, y: 5)
    }

    private func tabButton(for tab: AppTab) -> some View {
        Button {
            Haptics.fire(.selection)
            withAnimation(VMotion.snappy) {
                appState.selectedTab = tab
            }
        } label: {
            VStack(spacing: 3) {
                Image(systemName: tab.systemImage)
                    .font(.system(size: 20, weight: tab == appState.selectedTab ? .semibold : .regular))
                    .foregroundStyle(tab == appState.selectedTab ? VColor.primary : VColor.textSecondary)
                    .scaleEffect(tab == appState.selectedTab ? 1.12 : 1.0)
                Text(tab.titleKey)
                    .font(VType.micro)
                    .foregroundStyle(tab == appState.selectedTab ? VColor.textPrimary : VColor.textSecondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    MainTabView()
        .modelContainer(Persistence.previewContainer)
        .environment(AppState())
        .environment(PurchaseManager())
        .preferredColorScheme(.light)
}
