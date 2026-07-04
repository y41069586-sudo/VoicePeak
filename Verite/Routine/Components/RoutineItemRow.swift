import SwiftUI
import SwiftData

/// Individual routine product row with checkbox, product name, and status badge.
struct RoutineItemRow: View {
    let item: RoutineItem
    let product: Product
    
    @Environment(\.modelContext) private var modelContext
    @State private var isCompleted = false
    
    private var statusColor: Color {
        switch item.status {
        case "proven": return VColor.success
        case "testing": return VColor.warning
        case "irritating": return VColor.danger
        default: return VColor.textSecondary
        }
    }
    
    private var statusLabel: String {
        switch item.status {
        case "proven": return "Proven"
        case "testing": return "Testing"
        case "irritating": return "Stop"
        default: return "New"
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            // Checkbox
            Button(action: { 
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    isCompleted.toggle()
                }
            }) {
                Image(systemName: isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(isCompleted ? VColor.success : VColor.textTertiary)
                    .frame(width: 32, height: 32)
            }
            
            // Product info
            VStack(alignment: .leading, spacing: 4) {
                Text(product.name)
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(VColor.textPrimary)
                    .strikethrough(isCompleted)
                
                if let brand = product.brand, !brand.isEmpty {
                    Text(brand)
                        .font(.caption)
                        .foregroundStyle(VColor.textTertiary)
                        .strikethrough(isCompleted)
                }
            }
            
            Spacer()
            
            // Status badge
            VStack(spacing: 2) {
                Text(statusLabel)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(statusColor)
                    .padding(.vertical, 4)
                    .padding(.horizontal, 8)
                    .background(statusColor.opacity(0.1))
                    .cornerRadius(4)
            }
        }
        .padding(12)
        .background(VColor.bgSurface)
        .cornerRadius(10)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(VColor.strokeSubtle, lineWidth: 1))
    }
}

#Preview {
    let product = Product(name: "Moisturizer", brand: "Cetaphil")
    let item = RoutineItem(productID: product.id, timeOfDay: .am, status: "proven")
    
    return RoutineItemRow(item: item, product: product)
        .padding(20)
        .background(VColor.bgBase)
        .modelContainer(for: Product.self, inMemory: true)
}
