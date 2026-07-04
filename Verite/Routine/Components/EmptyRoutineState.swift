import SwiftUI

/// Guidance card shown when routine is empty for a time of day.
struct EmptyRoutineState: View {
    let timeOfDay: TimeOfDay
    let action: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            VStack(spacing: 10) {
                Image(systemName: timeOfDay == .am ? "sunrise.fill" : "moon.stars.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(VColor.primary.opacity(0.6))
                
                VStack(spacing: 4) {
                    Text("No products yet")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(VColor.textPrimary)
                    
                    Text("Build your \(timeOfDay == .am ? "morning" : "evening") routine")
                        .font(.callout)
                        .foregroundStyle(VColor.textSecondary)
                }
            }
            .frame(maxWidth: .infinity)
            
            Button(action: action) {
                HStack(spacing: 6) {
                    Image(systemName: "plus.circle.fill")
                    Text("Add First Product")
                        .font(.headline.weight(.semibold))
                }
                .frame(maxWidth: .infinity)
                .foregroundStyle(.white)
                .padding(.vertical, 12)
                .background(
                    LinearGradient(
                        gradient: Gradient(colors: [VColor.primary, VColor.accent]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .cornerRadius(8)
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
        EmptyRoutineState(timeOfDay: .am) { }
        EmptyRoutineState(timeOfDay: .pm) { }
    }
    .padding(20)
    .background(VColor.bgBase)
}
