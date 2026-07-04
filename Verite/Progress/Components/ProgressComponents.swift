import SwiftUI
import SwiftData

// MARK: - Empty Progress State

struct EmptyProgressState: View {
    var body: some View {
        VStack(spacing: 16) {
            VStack(spacing: 12) {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.system(size: 48))
                    .foregroundStyle(VColor.primary.opacity(0.6))
                
                VStack(spacing: 4) {
                    Text("No scans yet")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(VColor.textPrimary)
                    
                    Text("Start scanning to track your progress")
                        .font(.callout)
                        .foregroundStyle(VColor.textSecondary)
                }
            }
            .frame(maxWidth: .infinity)
        }
        .padding(32)
        .background(VColor.bgSurface)
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(VColor.strokeSubtle, lineWidth: 1))
    }
}

// MARK: - Timeline Entry

struct TimelineEntry: View {
    let scan: Scan
    
    var body: some View {
        HStack(spacing: 12) {
            VStack(spacing: 0) {
                Image(systemName: scan.isBaseline ? "flag.fill" : "checkmark.circle.fill")
                    .font(.headline)
                    .foregroundStyle(scan.isBaseline ? VColor.danger : VColor.success)
                    .frame(height: 32)
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

// MARK: - Comparison Card

struct ComparisonCard: View {
    let label: String
    let date: Date
    let quality: Double
    
    var body: some View {
        VStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 10)
                .fill(VColor.bgElevated)
                .frame(height: 200)
                .overlay(
                    Image(systemName: "photo.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(VColor.textTertiary)
                )
            
            VStack(alignment: .leading, spacing: 4) {
                Text(label)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(VColor.textSecondary)
                
                Text(date.formatted(date: .abbreviated, time: .omitted))
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(VColor.textPrimary)
                
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(VColor.success)
                    Text("\(Int(quality * 100))% quality")
                        .font(.caption)
                        .foregroundStyle(VColor.textSecondary)
                }
            }
        }
        .padding(12)
        .background(VColor.bgSurface)
        .cornerRadius(10)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(VColor.strokeSubtle, lineWidth: 1))
    }
}

// MARK: - Improvement Row

struct ImprovementRow: View {
    let metric: String
    let change: Double
    
    private var changeLabel: String {
        let percent = Int(change * 100)
        return change > 0 ? "+\(percent)%" : "\(percent)%"
    }
    
    private var changeColor: Color {
        change > 0 ? VColor.success : (change < 0 ? VColor.danger : VColor.textSecondary)
    }
    
    var body: some View {
        HStack {
            Text(metric)
                .font(.callout)
                .foregroundStyle(VColor.textPrimary)
            
            Spacer()
            
            HStack(spacing: 6) {
                Image(systemName: change > 0 ? "arrow.up.right" : change < 0 ? "arrow.down.right" : "minus")
                    .font(.caption.weight(.semibold))
                
                Text(changeLabel)
                    .font(.callout.weight(.semibold))
                    .monospacedDigit()
            }
            .foregroundStyle(changeColor)
        }
        .padding(12)
        .background(VColor.bgSurface)
        .cornerRadius(8)
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(VColor.strokeSubtle, lineWidth: 1))
    }
}

// MARK: - Analytics Card

struct AnalyticsCard: View {
    let title: String
    let value: String
    let subtitle: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(color)
                
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(VColor.textSecondary)
            }
            
            Text(value)
                .font(.title2.weight(.bold))
                .foregroundStyle(VColor.textPrimary)
            
            Text(subtitle)
                .font(.caption)
                .foregroundStyle(VColor.textTertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(color.opacity(0.08))
        .cornerRadius(10)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(color.opacity(0.2), lineWidth: 1))
    }
}

// MARK: - Large Streak Display

struct StreakCounter: View {
    let current: Int
    let best: Int
    
    var body: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                VColor.primary.opacity(0.1),
                                VColor.accent.opacity(0.05)
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 180, height: 180)
                
                VStack(spacing: 8) {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 40))
                        .foregroundStyle(VColor.warning)
                    
                    Text("\(current)")
                        .font(.system(size: 56, weight: .bold, design: .default))
                        .foregroundStyle(VColor.textPrimary)
                    
                    Text("day streak")
                        .font(.callout.weight(.medium))
                        .foregroundStyle(VColor.textSecondary)
                }
            }
            
            HStack(spacing: 20) {
                VStack(spacing: 4) {
                    Text("Current")
                        .font(.caption)
                        .foregroundStyle(VColor.textSecondary)
                    Text("\(current)")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(VColor.textPrimary)
                }
                
                Divider()
                
                VStack(spacing: 4) {
                    Text("Personal Best")
                        .font(.caption)
                        .foregroundStyle(VColor.textSecondary)
                    Text("\(best)")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(VColor.primary)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(16)
            .background(VColor.bgSurface)
            .cornerRadius(10)
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(VColor.strokeSubtle, lineWidth: 1))
        }
    }
}

#Preview {
    VStack(spacing: 16) {
        EmptyProgressState()
        TimelineEntry(scan: Scan(isBaseline: true, captureQuality: 0.85))
        ComparisonCard(label: "Before", date: Date().addingTimeInterval(-86400), quality: 0.7)
        ImprovementRow(metric: "Hydration", change: 0.15)
        AnalyticsCard(title: "Scans", value: "7", subtitle: "This month", icon: "camera.fill", color: VColor.primary)
        StreakCounter(current: 7, best: 14)
    }
    .padding(20)
    .background(VColor.bgBase)
}
