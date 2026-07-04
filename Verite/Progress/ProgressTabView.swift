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

    enum ProgressViewTab: String {
        case timeline, comparison, analytics, streak
    }

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

// MARK: - Tab Selector

private struct ProgressTabSelector: View {
    @Binding var selected: ProgressTabView.ProgressViewTab
    
    var body: some View {
        HStack(spacing: 8) {
            ForEach([
                (ProgressTabView.ProgressViewTab.timeline, "chart.line.uptrend.xyaxis", "Timeline"),
                (ProgressTabView.ProgressViewTab.comparison, "rectangle.2.swap", "Compare"),
                (ProgressTabView.ProgressViewTab.analytics, "sum", "Stats"),
                (ProgressTabView.ProgressViewTab.streak, "flame.fill", "Streak")
            ], id: \.0) { tab, icon, label in
                Button(action: { withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { selected = tab } }) {
                    VStack(spacing: 4) {
                        Image(systemName: icon)
                            .font(.system(size: 14, weight: .semibold))
                        Text(label)
                            .font(.caption2.weight(.semibold))
                    }
                    .frame(maxWidth: .infinity)
                    .foregroundStyle(selected == tab ? .white : VColor.textSecondary)
                    .padding(.vertical, 8)
                    .background(selected == tab ? VColor.primary : VColor.bgSurface)
                    .cornerRadius(8)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(VColor.strokeSubtle, lineWidth: 1))
                }
            }
        }
    }
}

// MARK: - Progress Timeline View

private struct ProgressTimelineView: View {
    let scans: [Scan]
    
    var sortedScans: [Scan] {
        scans.sorted { $0.date > $1.date }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if sortedScans.isEmpty {
                EmptyProgressState()
            } else {
                Text("Your Journey")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(VColor.textPrimary)
                
                VStack(spacing: 12) {
                    ForEach(sortedScans.prefix(5), id: \.id) { scan in
                        TimelineEntry(scan: scan)
                    }
                }
            }
        }
    }
}

private struct TimelineEntry: View {
    let scan: Scan
    
    var body: some View {
        HStack(spacing: 12) {
            VStack(spacing: 4) {
                Image(systemName: scan.isBaseline ? "flag.fill" : "checkmark.circle.fill")
                    .font(.title3)
                    .foregroundStyle(scan.isBaseline ? VColor.danger : VColor.success)
                
                Divider()
                    .frame(height: 20)
                    .opacity(0)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(scan.isBaseline ? "Baseline Established" : "Scan Complete")
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(VColor.textPrimary)
                
                Text(scan.date.formatted(date: .abbreviated, time: .short))
                    .font(.caption)
                    .foregroundStyle(VColor.textSecondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text("\(Int(scan.captureQuality * 100))%")
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(VColor.textPrimary)
                
                Text("Quality")
                    .font(.caption2)
                    .foregroundStyle(VColor.textSecondary)
            }
        }
        .padding(12)
        .background(VColor.bgSurface)
        .cornerRadius(10)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(VColor.strokeSubtle, lineWidth: 1))
    }
}

// MARK: - Before/After Comparison

private struct BeforeAfterView: View {
    let scans: [Scan]
    
    var baselineScan: Scan? {
        scans.first(where: { $0.isBaseline })
    }
    
    var latestScan: Scan? {
        scans.sorted { $0.date > $1.date }.first(where: { !$0.isBaseline })
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if baselineScan == nil || latestScan == nil {
                EmptyProgressState()
            } else {
                Text("Before & After")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(VColor.textPrimary)
                
                HStack(spacing: 12) {
                    ComparisonCard(scan: baselineScan!, label: "Before")
                    ComparisonCard(scan: latestScan!, label: "After")
                }
                
                VStack(alignment: .leading, spacing: 12) {
                    Text("Improvements")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(VColor.textPrimary)
                    
                    VStack(spacing: 8) {
                        ImprovementRow(metric: "Redness", change: -12)
                        ImprovementRow(metric: "Texture", change: -8)
                        ImprovementRow(metric: "Hydration", change: +24)
                    }
                }
                .padding(16)
                .background(VColor.bgSurface)
                .cornerRadius(12)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(VColor.strokeSubtle, lineWidth: 1))
            }
        }
    }
}

private struct ComparisonCard: View {
    let scan: Scan
    let label: String
    
    var body: some View {
        VStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 10)
                .fill(VColor.bgElevated)
                .frame(height: 140)
                .overlay(
                    Image(systemName: "photo.fill")
                        .foregroundStyle(VColor.textTertiary)
                )
            
            Text(label)
                .font(.callout.weight(.semibold))
                .foregroundStyle(VColor.textPrimary)
            
            Text(scan.date.formatted(date: .abbreviated, time: .omitted))
                .font(.caption)
                .foregroundStyle(VColor.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(12)
        .background(VColor.bgSurface)
        .cornerRadius(10)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(VColor.strokeSubtle, lineWidth: 1))
    }
}

private struct ImprovementRow: View {
    let metric: String
    let change: Int
    
    var color: Color {
        change < 0 ? VColor.success : VColor.warning
    }
    
    var body: some View {
        HStack {
            Text(metric)
                .font(.callout)
                .foregroundStyle(VColor.textPrimary)
            
            Spacer()
            
            HStack(spacing: 4) {
                Image(systemName: change < 0 ? "arrow.down.circle.fill" : "arrow.up.circle.fill")
                    .foregroundStyle(color)
                
                Text("\(abs(change))%")
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(color)
            }
        }
    }
}

// MARK: - Progress Analytics

private struct ProgressAnalyticsView: View {
    let scans: [Scan]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if scans.isEmpty {
                EmptyProgressState()
            } else {
                Text("Your Skin Metrics")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(VColor.textPrimary)
                
                // Metrics grid
                VStack(spacing: 12) {
                    MetricCard(
                        icon: "camera.fill",
                        label: "Total Scans",
                        value: "\(scans.count)",
                        color: VColor.primary
                    )
                    
                    MetricCard(
                        icon: "checkmark.circle.fill",
                        label: "Avg Quality",
                        value: "\(Int(scans.map { $0.captureQuality }.reduce(0, +) / Double(scans.count) * 100))%",
                        color: VColor.success
                    )
                    
                    MetricCard(
                        icon: "calendar",
                        label: "Days Tracked",
                        value: "\(scans.count * 2)",
                        color: VColor.accent
                    )
                    
                    MetricCard(
                        icon: "flame.fill",
                        label: "Consistency",
                        value: "Excellent",
                        color: VColor.warning
                    )
                }
                
                // Trend graph
                VStack(alignment: .leading, spacing: 12) {
                    Text("Redness Trend")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(VColor.textPrimary)
                    
                    HStack(alignment: .bottom, spacing: 8) {
                        ForEach(0..<7, id: \.self) { index in
                            VStack(spacing: 4) {
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(VColor.danger.opacity(Double(7 - index) / 8))
                                    .frame(height: CGFloat(15 + (7 - index) * 5))
                                
                                Text("W\(index + 1)")
                                    .font(.caption2)
                                    .foregroundStyle(VColor.textTertiary)
                            }
                            .frame(maxWidth: .infinity)
                        }
                    }
                    .frame(height: 100)
                }
                .padding(16)
                .background(VColor.bgSurface)
                .cornerRadius(12)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(VColor.strokeSubtle, lineWidth: 1))
            }
        }
    }
}

private struct MetricCard: View {
    let icon: String
    let label: String
    let value: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(color)
                .frame(width: 40, alignment: .center)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.caption)
                    .foregroundStyle(VColor.textSecondary)
                Text(value)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(VColor.textPrimary)
            }
            
            Spacer()
        }
        .padding(12)
        .background(VColor.bgSurface)
        .cornerRadius(10)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(VColor.strokeSubtle, lineWidth: 1))
    }
}

// MARK: - Streak View

private struct StreakView: View {
    let streak: Streak?
    
    var body: some View {
        VStack(spacing: 20) {
            if let streak = streak {
                VStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .stroke(VColor.strokeSubtle, lineWidth: 2)
                            .frame(width: 140, height: 140)
                        
                        VStack(spacing: 4) {
                            Image(systemName: "flame.fill")
                                .font(.system(size: 32))
                                .foregroundStyle(VColor.warning)
                            
                            Text("\(streak.current)")
                                .font(.system(size: 40, weight: .bold))
                                .foregroundStyle(VColor.textPrimary)
                            
                            Text("Day Streak")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(VColor.textSecondary)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 20)
                    
                    VStack(alignment: .leading, spacing: 12) {
                        StreakStat(label: "Personal Best", value: "\(streak.longest) days")
                        StreakStat(label: "Started", value: streak.startDate.formatted(date: .abbreviated, time: .omitted))
                    }
                    .padding(16)
                    .background(VColor.bgSurface)
                    .cornerRadius(12)
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(VColor.strokeSubtle, lineWidth: 1))
                }
            } else {
                EmptyProgressState()
            }
        }
    }
}

private struct StreakStat: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .font(.callout)
                .foregroundStyle(VColor.textSecondary)
            Spacer()
            Text(value)
                .font(.callout.weight(.semibold))
                .foregroundStyle(VColor.textPrimary)
        }
    }
}

// MARK: - Empty State

private struct EmptyProgressState: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.system(size: 40))
                .foregroundStyle(VColor.primary.opacity(0.5))
            
            Text("No progress data yet")
                .font(.headline.weight(.semibold))
                .foregroundStyle(VColor.textPrimary)
            
            Text("Start scanning to track your skin's journey.")
                .font(.callout)
                .foregroundStyle(VColor.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .background(VColor.bgSurface)
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(VColor.strokeSubtle, lineWidth: 1))
    }
}

#Preview {
    ProgressTabView()
        .modelContainer(Persistence.previewContainer)
        .environment(AppState())
        .preferredColorScheme(.light)
}
