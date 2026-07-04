import SwiftUI
import SwiftData

/// Shows hydration trend over the last 7 days with mini bar chart.
/// Gives visual proof of skin improvements.
struct HydrationTrendCard: View {
    let scans: [Scan]
    
    private var hydrationTrend: [Double] {
        let sortedScans = scans.sorted { $0.date > $1.date }.prefix(7)
        return Array(sortedScans)
            .reversed()
            .map { scan in
                scan.attributeScores["hydration"] ?? 0.5
            }
    }
    
    private var maxValue: Double {
        max(hydrationTrend.max() ?? 0.6, 0.6)
    }
    
    private var trend: String {
        guard hydrationTrend.count > 1 else { return "→" }
        let first = hydrationTrend.first ?? 0.5
        let last = hydrationTrend.last ?? 0.5
        if last > first { return "↗" }
        else if last < first { return "↘" }
        else { return "→" }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "drop.fill")
                    .font(.headline)
                    .foregroundStyle(VColor.accent)
                
                Text("Hydration Trend")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(VColor.textSecondary)
                
                Spacer()
                
                HStack(spacing: 2) {
                    Image(systemName: "arrow.\(trend == "↗" ? "up" : trend == "↘" ? "down" : "right")")
                        .font(.caption.weight(.semibold))
                    Text(trend)
                        .font(.caption.weight(.bold))
                }
                .foregroundStyle(trendColor)
            }
            
            if hydrationTrend.isEmpty {
                VStack(spacing: 8) {
                    Text("No data yet")
                        .font(.callout)
                        .foregroundStyle(VColor.textSecondary)
                    Text("Start scanning to build your hydration history.")
                        .font(.caption)
                        .foregroundStyle(VColor.textTertiary)
                }
                .frame(height: 80)
            } else {
                HStack(alignment: .bottom, spacing: 8) {
                    ForEach(Array(hydrationTrend.enumerated()), id: \.offset) { index, value in
                        VStack(spacing: 4) {
                            RoundedRectangle(cornerRadius: 3)
                                .fill(
                                    LinearGradient(
                                        gradient: Gradient(colors: [
                                            VColor.accent.opacity(0.8),
                                            VColor.primary.opacity(0.6)
                                        ]),
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                                .frame(height: CGFloat(value / maxValue * 60))
                            
                            Text("D\(index + 1)")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(VColor.textTertiary)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                .frame(height: 90)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(VColor.bgSurface)
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(VColor.strokeSubtle, lineWidth: 1))
    }
    
    private var trendColor: Color {
        switch trend {
        case "↗": return VColor.success
        case "↘": return VColor.warning
        default: return VColor.textSecondary
        }
    }
}

#Preview {
    VStack(spacing: 16) {
        HydrationTrendCard(scans: [])
        
        HydrationTrendCard(scans: [
            Scan(attributeScores: ["hydration": 0.4], date: Date().addingTimeInterval(-6 * 86400)),
            Scan(attributeScores: ["hydration": 0.5], date: Date().addingTimeInterval(-5 * 86400)),
            Scan(attributeScores: ["hydration": 0.55], date: Date().addingTimeInterval(-4 * 86400)),
            Scan(attributeScores: ["hydration": 0.6], date: Date().addingTimeInterval(-3 * 86400)),
            Scan(attributeScores: ["hydration": 0.65], date: Date().addingTimeInterval(-2 * 86400)),
            Scan(attributeScores: ["hydration": 0.72], date: Date().addingTimeInterval(-1 * 86400)),
            Scan(attributeScores: ["hydration": 0.75], date: Date()),
        ])
    }
    .padding(20)
    .background(VColor.bgBase)
}
