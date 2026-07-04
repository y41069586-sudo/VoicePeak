import SwiftUI
import SwiftData

/// Displays current active skin concerns detected in recent scans.
/// Shows main concerns with icons and status indicators.
struct ActiveConcernsCard: View {
    let scans: [Scan]
    
    private var activeConcerns: [(concern: String, icon: String, severity: Double)] {
        guard let latest = scans.sorted(by: { $0.date > $1.date }).first else {
            return []
        }
        
        var concerns: [(String, String, Double)] = []
        
        // Extract attribute concerns from latest scan
        if let redness = latest.attributeScores["redness"], redness > 0.3 {
            concerns.append(("Redness detected", "circle.fill", redness))
        }
        if let dryness = latest.attributeScores["hydration"], dryness < 0.4 {
            concerns.append(("Dryness", "water.circle", 1 - dryness))
        }
        if let acne = latest.attributeScores["acne"], acne > 0.2 {
            concerns.append(("Acne activity", "exclamationmark.circle", acne))
        }
        if let oiliness = latest.attributeScores["oiliness"], oiliness > 0.6 {
            concerns.append(("Excess oiliness", "drop.circle.fill", oiliness))
        }
        
        return concerns.isEmpty
            ? [("Skin looking clear", "checkmark.circle.fill", 0)]
            : Array(concerns.prefix(3))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "list.bullet.circle")
                    .font(.headline)
                    .foregroundStyle(VColor.primary)
                
                Text("Active Concerns")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(VColor.textSecondary)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                ForEach(activeConcerns, id: \.0) { concern, icon, severity in
                    ConcernRow(concern: concern, icon: icon, severity: severity)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(VColor.bgSurface)
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(VColor.strokeSubtle, lineWidth: 1))
    }
}

private struct ConcernRow: View {
    let concern: String
    let icon: String
    let severity: Double
    
    var severityColor: Color {
        switch severity {
        case 0.7...: return VColor.danger
        case 0.4...: return VColor.warning
        default: return VColor.success
        }
    }
    
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.body.weight(.semibold))
                .foregroundStyle(severityColor)
                .frame(width: 24)
            
            Text(concern)
                .font(.callout.weight(.medium))
                .foregroundStyle(VColor.textPrimary)
            
            Spacer()
            
            if severity > 0 {
                Gauge(value: severity)
                    .gaugeStyle(.accessoryCircular)
                    .frame(width: 32)
                    .tint(severityColor)
            }
        }
        .frame(height: 32)
    }
}

#Preview {
    VStack(spacing: 16) {
        ActiveConcernsCard(scans: [])
        
        ActiveConcernsCard(scans: [
            Scan(
                attributeScores: [
                    "redness": 0.45,
                    "hydration": 0.35,
                    "acne": 0.25
                ]
            )
        ])
    }
    .padding(20)
    .background(VColor.bgBase)
}
