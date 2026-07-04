import SwiftUI
import SwiftData

/// Individual scan history entry with thumbnail, date, and quality.
struct ScanHistoryRow: View {
    let scan: Scan
    let onTap: () -> Void
    
    private var qualityColor: Color {
        switch scan.captureQuality {
        case 0.8...: return VColor.success
        case 0.5...: return VColor.warning
        default: return VColor.danger
        }
    }
    
    private var qualityLabel: String {
        switch scan.captureQuality {
        case 0.8...: return "Excellent"
        case 0.5...: return "Good"
        default: return "Fair"
        }
    }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Thumbnail placeholder
                RoundedRectangle(cornerRadius: 8)
                    .fill(VColor.bgElevated)
                    .frame(width: 60, height: 60)
                    .overlay(
                        Image(systemName: "photo.fill")
                            .font(.body.weight(.semibold))
                            .foregroundStyle(VColor.textTertiary)
                    )
                
                // Scan info
                VStack(alignment: .leading, spacing: 6) {
                    Text(scan.date.formatted(date: .abbreviated, time: .short))
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(VColor.textPrimary)
                    
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundStyle(qualityColor)
                        
                        Text(qualityLabel)
                            .font(.caption.weight(.medium))
                            .foregroundStyle(VColor.textSecondary)
                    }
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(VColor.textTertiary)
            }
            .padding(12)
            .background(VColor.bgSurface)
            .cornerRadius(10)
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(VColor.strokeSubtle, lineWidth: 1))
        }
    }
}

#Preview {
    ScanHistoryRow(
        scan: Scan(
            date: Date().addingTimeInterval(-86400),
            captureQuality: 0.85,
            attributeScores: [:]
        ),
        onTap: {}
    )
    .padding(20)
    .background(VColor.bgBase)
}
