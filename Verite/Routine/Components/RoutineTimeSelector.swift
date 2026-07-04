import SwiftUI

/// Toggle between morning and evening routines with animated switching.
struct RoutineTimeSelector: View {
    @Binding var selected: TimeOfDay

    var body: some View {
        HStack(spacing: 12) {
            ForEach(TimeOfDay.allCases, id: \.self) { time in
                Button(action: { 
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { 
                        selected = time 
                    } 
                }) {
                    VStack(spacing: 6) {
                        Image(systemName: time == .am ? "sunrise.fill" : "moon.stars.fill")
                            .font(.headline.weight(.semibold))
                        
                        Text(time == .am ? "Morning" : "Evening")
                            .font(.subheadline.weight(.semibold))
                    }
                    .frame(maxWidth: .infinity)
                    .foregroundStyle(selected == time ? .white : VColor.textPrimary)
                    .padding(.vertical, 14)
                    .background(
                        selected == time
                            ? LinearGradient(
                                gradient: Gradient(colors: [VColor.primary, VColor.accent]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                            : LinearGradient(
                                gradient: Gradient(colors: [VColor.bgSurface, VColor.bgSurface]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                    )
                    .cornerRadius(10)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(
                                selected == time ? Color.clear : VColor.strokeSubtle,
                                lineWidth: 1
                            )
                    )
                }
            }
        }
    }
}

#Preview {
    @State var selected: TimeOfDay = .am
    
    return RoutineTimeSelector(selected: $selected)
        .padding(20)
        .background(VColor.bgBase)
}
