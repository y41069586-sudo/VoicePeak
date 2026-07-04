import SwiftUI

/// Educational section showing how the scanner works in 4 steps.
struct ScannerInsightsSection: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("How Scanning Works")
                .font(.headline.weight(.semibold))
                .foregroundStyle(VColor.textPrimary)
                .padding(.horizontal, 20)
            
            VStack(spacing: 12) {
                InsightStep(
                    number: 1,
                    title: "Position Your Face",
                    description: "Follow the AR guide to center your face in the circle.",
                    icon: "face.smiling"
                )
                
                InsightStep(
                    number: 2,
                    title: "Check Lighting",
                    description: "We'll guide you to optimal lighting conditions.",
                    icon: "sun.max"
                )
                
                InsightStep(
                    number: 3,
                    title: "Instant Analysis",
                    description: "AI analyzes redness, acne, hydration, and more.",
                    icon: "sparkles"
                )
                
                InsightStep(
                    number: 4,
                    title: "View Results",
                    description: "See detailed heatmaps and compare to your baseline.",
                    icon: "chart.bar"
                )
            }
            .padding(.horizontal, 20)
        }
    }
}

private struct InsightStep: View {
    let number: Int
    let title: String
    let description: String
    let icon: String
    
    var body: some View {
        HStack(spacing: 12) {
            // Step number badge
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                VColor.primary.opacity(0.15),
                                VColor.accent.opacity(0.1)
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                
                VStack(spacing: 1) {
                    Text("\(number)")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(VColor.primary)
                }
            }
            .frame(width: 44, height: 44)
            
            // Content
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(VColor.textPrimary)
                
                Text(description)
                    .font(.caption)
                    .foregroundStyle(VColor.textSecondary)
                    .lineLimit(2)
            }
            
            Spacer()
            
            Image(systemName: icon)
                .font(.body.weight(.semibold))
                .foregroundStyle(VColor.primary.opacity(0.5))
        }
        .padding(12)
        .background(VColor.bgSurface)
        .cornerRadius(10)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(VColor.strokeSubtle, lineWidth: 1))
    }
}

#Preview {
    ScannerInsightsSection()
        .padding(.vertical, 20)
        .background(VColor.bgBase)
}
