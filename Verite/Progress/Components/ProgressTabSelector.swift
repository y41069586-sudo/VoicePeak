import SwiftUI

enum ProgressViewTab: String, CaseIterable {
    case timeline, comparison, analytics, streak
    
    var label: String {
        switch self {
        case .timeline: return "Timeline"
        case .comparison: return "Compare"
        case .analytics: return "Stats"
        case .streak: return "Streak"
        }
    }
    
    var icon: String {
        switch self {
        case .timeline: return "chart.line.uptrend.xyaxis"
        case .comparison: return "rectangle.2.swap"
        case .analytics: return "sum"
        case .streak: return "flame.fill"
        }
    }
}

/// Tabbed navigation for Progress view: Timeline, Compare, Stats, Streak.
struct ProgressTabSelector: View {
    @Binding var selected: ProgressViewTab
    
    var body: some View {
        HStack(spacing: 8) {
            ForEach(ProgressViewTab.allCases, id: \.self) { tab in
                Button(action: { 
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { 
                        selected = tab 
                    } 
                }) {
                    VStack(spacing: 5) {
                        Image(systemName: tab.icon)
                            .font(.system(size: 14, weight: .semibold))
                        Text(tab.label)
                            .font(.caption2.weight(.semibold))
                    }
                    .frame(maxWidth: .infinity)
                    .foregroundStyle(selected == tab ? .white : VColor.textSecondary)
                    .padding(.vertical, 10)
                    .background(
                        selected == tab
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
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(
                                selected == tab ? Color.clear : VColor.strokeSubtle,
                                lineWidth: 1
                            )
                    )
                }
            }
        }
    }
}

#Preview {
    @State var selected: ProgressViewTab = .timeline
    
    return ProgressTabSelector(selected: $selected)
        .padding(20)
        .background(VColor.bgBase)
}
