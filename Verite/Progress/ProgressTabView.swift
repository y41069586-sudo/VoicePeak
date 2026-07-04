import SwiftUI
import SwiftData

/// Progress tab: proof and motivation. Timeline, before/after comparisons,
/// analytics, streak system, and visual progress. Users feel their improvement.
struct ProgressTabView: View {
    @Environment(AppState.self) private var appState
    @Query private var scans: [Scan]
    @Query private var tests: [HalfFaceTest]
    @Query private var streaks: [Streak]
    @State private var selectedTab: ProgressViewTab = .timeline

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Tab selector
                ProgressTabSelector(selected: $selectedTab)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                
                ScrollView {
                    VStack(spacing: 20) {
                        switch selectedTab {
                        case .timeline:
                            ProgressTimelineView(scans: scans)
                        case .comparison:
                            BeforeAfterView(scans: scans)
                        case .analytics:
                            ProgressAnalyticsView(scans: scans)
                        case .streak:
                            StreakView(streak: streaks.first)
                        }
                        
                        Spacer(minLength: 20)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                }
                .scrollIndicators(.hidden)
            }
            .background(VColor.bgBase.ignoresSafeArea())
            .navigationTitle("Progress")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

// MARK: - Progress Timeline View

private struct ProgressTimelineView: View {
    let scans: [Scan]
    
    private var sortedScans: [Scan] {
        scans.sorted { $0.date > $1.date }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if sortedScans.isEmpty {
                EmptyProgressState()
            } else {
                Text("Your Scan Journey")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(VColor.textPrimary)
                
                VStack(spacing: 12) {
                    ForEach(sortedScans.prefix(10), id: \.id) { scan in
                        TimelineEntry(scan: scan)
                    }
                }
            }
        }
    }
}

// MARK: - Before/After Comparison

private struct BeforeAfterView: View {
    let scans: [Scan]
    
    private var baseline: Scan? {
        scans.first(where: { $0.isBaseline })
    }
    
    private var latest: Scan? {
        scans.sorted(by: { $0.date > $1.date }).first(where: { !$0.isBaseline })
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let baseline, let latest {
                Text("Your Progress")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(VColor.textPrimary)
                
                HStack(spacing: 12) {
                    ComparisonCard(
                        label: "Baseline",
                        date: baseline.date,
                        quality: baseline.captureQuality
                    )
                    
                    ComparisonCard(
                        label: "Latest",
                        date: latest.date,
                        quality: latest.captureQuality
                    )
                }
                
                VStack(alignment: .leading, spacing: 12) {
                    Text("Improvements")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(VColor.textPrimary)
                    
                    VStack(spacing: 8) {
                        ImprovementRow(metric: "Hydration", change: 0.15)
                        ImprovementRow(metric: "Redness", change: -0.22)
                        ImprovementRow(metric: "Acne", change: -0.10)
                        ImprovementRow(metric: "Texture", change: 0.18)
                    }
                }
            } else {
                EmptyProgressState()
            }
        }
    }
}

// MARK: - Analytics View

private struct ProgressAnalyticsView: View {
    let scans: [Scan]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Progress Metrics")
                .font(.headline.weight(.semibold))
                .foregroundStyle(VColor.textPrimary)
            
            VStack(spacing: 8) {
                AnalyticsCard(
                    title: "Total Scans",
                    value: "\(scans.count)",
                    subtitle: "Since baseline",
                    icon: "camera.fill",
                    color: VColor.primary
                )
                
                AnalyticsCard(
                    title: "Avg Quality",
                    value: "\(Int(scans.map { $0.captureQuality }.average * 100))%",
                    subtitle: "Capture quality",
                    icon: "checkmark.circle.fill",
                    color: VColor.success
                )
                
                AnalyticsCard(
                    title: "Trend",
                    value: "Improving",
                    subtitle: "Overall trajectory",
                    icon: "arrow.up.right",
                    color: VColor.accent
                )
                
                AnalyticsCard(
                    title: "Consistency",
                    value: "Good",
                    subtitle: "Scanning regularly",
                    icon: "calendar",
                    color: VColor.warning
                )
            }
            
            // Trend graph placeholder
            VStack(alignment: .leading, spacing: 12) {
                Text("7-Day Trend")
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(VColor.textPrimary)
                
                HStack(alignment: .bottom, spacing: 8) {
                    ForEach(0..<7, id: \.self) { _ in
                        RoundedRectangle(cornerRadius: 3)
                            .fill(
                                LinearGradient(
                                    gradient: Gradient(colors: [
                                        VColor.primary.opacity(0.8),
                                        VColor.accent.opacity(0.6)
                                    ]),
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .frame(height: CGFloat.random(in: 20...80))
                    }
                }
                .frame(height: 100)
                .padding(12)
                .background(VColor.bgSurface)
                .cornerRadius(8)
            }
        }
    }
}

// MARK: - Streak View

private struct StreakView: View {
    let streak: Streak?
    
    private var current: Int {
        streak?.current ?? 0
    }
    
    private var best: Int {
        streak?.best ?? 0
    }

    var body: some View {
        VStack(alignment: .center, spacing: 16) {
            Text("Consistency Streak")
                .font(.headline.weight(.semibold))
                .foregroundStyle(VColor.textPrimary)
            
            StreakCounter(current: current, best: best)
            
            VStack(alignment: .leading, spacing: 12) {
                Text("Streak Tips")
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(VColor.textPrimary)
                
                VStack(alignment: .leading, spacing: 10) {
                    StreakTip(icon: "calendar", text: "Scan around the same time each day")
                    StreakTip(icon: "sun.max", text: "Consistent lighting conditions help")
                    StreakTip(icon: "target", text: "Follow the AR guide for best results")
                }
            }
        }
    }
}

private struct StreakTip: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.body.weight(.semibold))
                .foregroundStyle(VColor.primary)
                .frame(width: 24)
            
            Text(text)
                .font(.callout)
                .foregroundStyle(VColor.textSecondary)
            
            Spacer()
        }
    }
}

#Preview {
    ProgressTabView()
        .modelContainer(Persistence.previewContainer)
        .environment(AppState())
        .preferredColorScheme(.light)
}
