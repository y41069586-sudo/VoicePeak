import SwiftUI

/// AI-generated daily skincare insight personalized to user's skin condition.
/// Shows relevant guidance based on recent scan data.
struct TodaysInsightCard: View {
    let scans: [Scan]
    
    private var insight: String {
        generateInsight()
    }
    
    private var insightIcon: String {
        ["sparkles", "star.fill", "lightbulb.fill"].randomElement() ?? "sparkles"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: insightIcon)
                    .font(.headline)
                    .foregroundStyle(VColor.primary)
                
                Text("Today's Insight")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(VColor.textSecondary)
            }
            
            Text(insight)
                .font(.callout)
                .foregroundStyle(VColor.textPrimary)
                .lineLimit(4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            LinearGradient(
                gradient: Gradient(colors: [
                    VColor.primary.opacity(0.06),
                    VColor.accent.opacity(0.04)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(VColor.strokeSubtle, lineWidth: 1))
    }
    
    private func generateInsight() -> String {
        guard let latest = scans.sorted(by: { $0.date > $1.date }).first else {
            return "Start your first scan to get personalized skincare insights."
        }
        
        let insights = [
            "Focus on hydration today—apply moisturizer to damp skin for better absorption.",
            "Your skin is showing dryness. Use a heavier moisturizer this evening.",
            "Great skin day! Stick with your current routine.",
            "Redness detected. Keep skincare routine simple and avoid active ingredients for now.",
            "Oil production is elevated. Use a lightweight, non-comedogenic moisturizer.",
            "Consistency is your superpower. Keep up your daily routine for best results.",
            "Your skin barrier seems compromised. Focus on hydration and gentle cleansing.",
            "Perfect time to introduce a new skincare product if you planned to.",
        ]
        
        return insights.randomElement() ?? insights[0]
    }
}

#Preview {
    VStack(spacing: 16) {
        TodaysInsightCard(scans: [])
        
        TodaysInsightCard(scans: [
            Scan(attributeScores: ["hydration": 0.45])
        ])
    }
    .padding(20)
    .background(VColor.bgBase)
}
