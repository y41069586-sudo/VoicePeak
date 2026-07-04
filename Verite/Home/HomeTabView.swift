import SwiftUI
import SwiftData

/// Home tab: calm intelligent dashboard showing skin overview, today's insight,
/// active concerns, and recommended actions. Emotionally safe and visually clear.
struct HomeTabView: View {
    @Environment(AppState.self) private var appState
    @Query private var scans: [Scan]
    @Query private var tests: [HalfFaceTest]
    @Query private var streaks: [Streak]

    @State private var showSettings = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Skin health overview
                    SkinHealthCard(scans: scans)
                        .transition(.opacity.combined(with: .scale(scale: 0.95)))

                    // Active concerns
                    if !scans.isEmpty {
                        ActiveConcernsCard(scans: scans)
                            .transition(.opacity)
                    }

                    // Today's insight
                    TodaysInsightCard(scans: scans)
                        .transition(.opacity)

                    // Scan shortcut (primary action)
                    ScanActionCard {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            appState.selectedTab = .analyzer
                        }
                    }
                    .transition(.opacity)

                    // Hydration trend
                    HydrationTrendCard(scans: scans)
                        .transition(.opacity)

                    // Consistency badge
                    ConsistencyStreakCard(streak: streaks.first)
                        .transition(.opacity)

                    Spacer(minLength: 20)
                }
                .padding(20)
            }
            .scrollIndicators(.hidden)
            .background(VColor.bgBase.ignoresSafeArea())
            .navigationTitle("Home")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: { showSettings = true }) {
                        Image(systemName: "gearshape.fill")
                            .font(.headline)
                            .foregroundStyle(VColor.primary)
                    }
                }
            }
            .sheet(isPresented: $showSettings) {
                SettingsView(isPresented: $showSettings)
            }
        }
    }
}


#Preview {
    HomeTabView()
        .modelContainer(Persistence.previewContainer)
        .environment(AppState())
        .preferredColorScheme(.light)
}
