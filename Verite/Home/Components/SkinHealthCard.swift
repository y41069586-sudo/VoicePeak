import SwiftUI
import SwiftData

/// Dashboard card showing overall skin health status and baseline establishment.
/// If no baseline scan exists, shows guidance. Otherwise, displays health score and status.
struct SkinHealthCard: View {
    let scans: [Scan]
    
    private var hasBaseline: Bool {
        scans.contains(where: { $0.isBaseline })
    }
    
    private var latestScore: Double {
        scans.sorted { $0.date > $1.date }
            .first?
            .attributeScores
            .values
            .average ?? 0
    }

    var body: some View {
        if !hasBaseline {
            baselinePrompt
        } else {
            healthStatus
        }
    }
    
    private var baselinePrompt: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "target")
                    .font(.headline)
                    .foregroundStyle(VColor.primary)
                
                Text("Establish Your Baseline")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(VColor.textPrimary)
            }
            
            Text("Your first scan creates a baseline. We'll track improvements relative to this starting point—not impossible standards.")
                .font(.callout)
                .foregroundStyle(VColor.textSecondary)
                .lineLimit(3)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(VColor.bgSurface)
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(VColor.strokeSubtle, lineWidth: 1))
    }
    
    private var healthStatus: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "heart.fill")
                    .font(.headline)
                    .foregroundStyle(VColor.success)
                
                Text("Skin Health")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(VColor.textSecondary)
            }
            
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(statusLabel(for: latestScore))
                        .font(.title2.weight(.bold))
                        .foregroundStyle(VColor.textPrimary)

                    Text("Overall score")
                        .font(.caption)
                        .foregroundStyle(VColor.textTertiary)
                }

                Spacer()

                ScoreRing(value: latestScore, label: Int(latestScore * 100), size: .medium, revealed: true)
            }
            
            ProgressView(value: latestScore)
                .tint(colorForScore(latestScore))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(VColor.bgSurface)
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(VColor.strokeSubtle, lineWidth: 1))
    }
    
    private func statusLabel(for score: Double) -> String {
        switch score {
        case 0.75...: return "Excellent"
        case 0.5...: return "Good"
        case 0.25...: return "Fair"
        default: return "Developing"
        }
    }
    
    private func colorForScore(_ score: Double) -> Color {
        switch score {
        case 0.75...: return VColor.success
        case 0.5...: return VColor.primary
        case 0.25...: return VColor.warning
        default: return VColor.danger
        }
    }
}

#Preview {
    VStack(spacing: 16) {
        SkinHealthCard(scans: [])
        
        SkinHealthCard(scans: [
            Scan(
                isBaseline: true,
                attributeScores: ["redness": 0.35, "acne": 0.15, "hydration": 0.72]
            )
        ])
    }
    .padding(20)
    .background(VColor.bgBase)
}
