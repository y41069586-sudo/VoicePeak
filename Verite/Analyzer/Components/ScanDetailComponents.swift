import SwiftUI

// MARK: - Scan Metric Display

struct ScanMetric: View {
    let label: String
    let value: String
    let icon: String?
    
    var body: some View {
        HStack(spacing: 10) {
            if let icon {
                Image(systemName: icon)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(VColor.primary.opacity(0.6))
                    .frame(width: 24)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(VColor.textSecondary)
                
                Text(value)
                    .font(.callout.weight(.medium))
                    .foregroundStyle(VColor.textPrimary)
            }
            
            Spacer()
        }
        .frame(height: 44)
    }
}

// MARK: - Attribute Bar

struct AttributeBar: View {
    let label: String
    let value: Double
    let icon: String?
    
    private var color: Color {
        switch value {
        case 0.7...: return VColor.danger
        case 0.4...: return VColor.warning
        default: return VColor.success
        }
    }
    
    private var levelLabel: String {
        switch value {
        case 0.8...: return "High"
        case 0.5...: return "Moderate"
        case 0.2...: return "Mild"
        default: return "Low"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                if let icon {
                    Image(systemName: icon)
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(color)
                        .frame(width: 20)
                }
                
                Text(label)
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(VColor.textPrimary)
                
                Spacer()
                
                Text(levelLabel)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(color)
            }
            
            ProgressView(value: value)
                .tint(color)
                .frame(height: 6)
        }
        .padding(12)
        .background(VColor.bgSurface)
        .cornerRadius(8)
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(VColor.strokeSubtle, lineWidth: 1))
    }
}

// MARK: - Scan Stats Grid

struct ScanStatsGrid: View {
    let date: Date
    let quality: Double
    let isBaseline: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Scan Details")
                .font(.headline.weight(.semibold))
                .foregroundStyle(VColor.textPrimary)
            
            VStack(spacing: 8) {
                ScanMetric(
                    label: "Date",
                    value: date.formatted(date: .abbreviated, time: .short),
                    icon: "calendar"
                )
                
                ScanMetric(
                    label: "Quality",
                    value: "\(Int(quality * 100))%",
                    icon: "checkmark.circle"
                )
                
                ScanMetric(
                    label: "Type",
                    value: isBaseline ? "Baseline" : "Progress Check",
                    icon: "flag"
                )
            }
        }
        .padding(16)
        .background(VColor.bgSurface)
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(VColor.strokeSubtle, lineWidth: 1))
    }
}

#Preview {
    VStack(spacing: 16) {
        ScanMetric(label: "Date", value: "Jan 15, 2:30 PM", icon: "calendar")
        
        AttributeBar(label: "Redness", value: 0.35, icon: "circle.fill")
        
        ScanStatsGrid(date: Date(), quality: 0.85, isBaseline: true)
    }
    .padding(20)
    .background(VColor.bgBase)
}
