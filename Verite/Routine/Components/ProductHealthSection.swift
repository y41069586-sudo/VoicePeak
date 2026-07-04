import SwiftUI
import SwiftData

/// Shows product health stats: proven, testing, and irritating products.
struct ProductHealthSection: View {
    let items: [RoutineItem]
    
    private var provenCount: Int {
        items.filter { $0.status == "proven" }.count
    }
    
    private var testingCount: Int {
        items.filter { $0.status == "testing" }.count
    }
    
    private var irritatingCount: Int {
        items.filter { $0.status == "irritating" }.count
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Product Health")
                .font(.headline.weight(.semibold))
                .foregroundStyle(VColor.textPrimary)
            
            HStack(spacing: 12) {
                ProductStatusCard(
                    icon: "checkmark.circle.fill",
                    count: provenCount,
                    label: "Proven",
                    color: VColor.success
                )
                
                ProductStatusCard(
                    icon: "clock.fill",
                    count: testingCount,
                    label: "Testing",
                    color: VColor.warning
                )
                
                ProductStatusCard(
                    icon: "exclamationmark.circle.fill",
                    count: irritatingCount,
                    label: "Stop",
                    color: VColor.danger
                )
            }
        }
        .padding(16)
        .background(VColor.bgSurface)
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(VColor.strokeSubtle, lineWidth: 1))
    }
}

private struct ProductStatusCard: View {
    let icon: String
    let count: Int
    let label: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.headline.weight(.semibold))
                .foregroundStyle(color)
            
            Text("\(count)")
                .font(.headline.weight(.bold))
                .foregroundStyle(VColor.textPrimary)
            
            Text(label)
                .font(.caption.weight(.medium))
                .foregroundStyle(VColor.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(12)
        .background(color.opacity(0.08))
        .cornerRadius(8)
    }
}

#Preview {
    ProductHealthSection(items: [
        RoutineItem(status: "proven"),
        RoutineItem(status: "proven"),
        RoutineItem(status: "testing"),
    ])
    .padding(20)
    .background(VColor.bgBase)
}
