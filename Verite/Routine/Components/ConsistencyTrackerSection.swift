import SwiftUI

/// Shows weekly consistency tracking with day-by-day checkmarks.
struct ConsistencyTrackerSection: View {
    @State private var completionDays: [Bool] = Array(repeating: false, count: 7)
    
    private let dayLabels = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
    
    private var completionPercentage: Double {
        let completed = completionDays.filter { $0 }.count
        return Double(completed) / Double(completionDays.count)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("This Week's Consistency")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(VColor.textPrimary)
                    
                    Text("\(Int(completionPercentage * 100))% complete")
                        .font(.caption)
                        .foregroundStyle(VColor.textSecondary)
                }
                
                Spacer()
                
                VStack(spacing: 2) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.headline)
                        .foregroundStyle(VColor.success)
                    
                    Text("\(completionDays.filter { $0 }.count)/7")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(VColor.textPrimary)
                }
            }
            
            // Week grid
            VStack(spacing: 8) {
                HStack(spacing: 8) {
                    ForEach(Array(completionDays.enumerated()), id: \.offset) { index, completed in
                        VStack(spacing: 6) {
                            Button(action: { 
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    completionDays[index].toggle()
                                }
                            }) {
                                Circle()
                                    .fill(completed ? VColor.success : VColor.bgElevated)
                                    .frame(height: 36)
                                    .overlay(
                                        Image(systemName: completed ? "checkmark" : "")
                                            .font(.caption.weight(.bold))
                                            .foregroundStyle(.white)
                                    )
                            }
                            
                            Text(dayLabels[index])
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(VColor.textTertiary)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                
                ProgressView(value: completionPercentage)
                    .tint(VColor.success)
            }
        }
        .padding(16)
        .background(VColor.bgSurface)
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(VColor.strokeSubtle, lineWidth: 1))
    }
}

#Preview {
    ConsistencyTrackerSection()
        .padding(20)
        .background(VColor.bgBase)
}
