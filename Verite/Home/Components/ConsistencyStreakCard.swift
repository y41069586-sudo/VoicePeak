import SwiftUI
import SwiftData

/// Displays consistency streak for motivation and habit reinforcement.
/// Shows current streak, best streak, and encouragement.
struct ConsistencyStreakCard: View {
    let streak: Streak?
    
    private var currentStreak: Int {
        streak?.current ?? 0
    }
    
    private var bestStreak: Int {
        streak?.best ?? 0
    }
    
    private var streakStatus: String {
        switch currentStreak {
        case 0: return "Start a streak"
        case 1...3: return "Getting started"
        case 4...6: return "Building momentum"
        case 7...13: return "Solid routine"
        case 14...29: return "Committed"
        default: return "Expert"
        }
    }

    var body: some View {
        VStack(spacing: 16) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Consistency Streak")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(VColor.textSecondary)
                    
                    HStack(spacing: 4) {
                        Image(systemName: "flame.fill")
                            .font(.headline)
                            .foregroundStyle(VColor.warning)
                        
                        Text("\(currentStreak) days")
                            .font(.title2.weight(.bold))
                            .foregroundStyle(VColor.textPrimary)
                    }
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Best")
                        .font(.caption)
                        .foregroundStyle(VColor.textTertiary)
                    
                    Text("\(bestStreak) days")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(VColor.primary)
                }
            }
            
            Divider()
                .background(VColor.strokeSubtle)
            
            Text(streakStatus)
                .font(.caption.weight(.medium))
                .foregroundStyle(VColor.textSecondary)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, 4)
                .background(VColor.bgElevated)
                .cornerRadius(6)
        }
        .padding(16)
        .background(VColor.bgSurface)
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(VColor.strokeSubtle, lineWidth: 1))
    }
}

#Preview {
    VStack(spacing: 16) {
        ConsistencyStreakCard(streak: nil)
        
        ConsistencyStreakCard(streak: Streak(current: 7, best: 14))
        
        ConsistencyStreakCard(streak: Streak(current: 28, best: 45))
    }
    .padding(20)
    .background(VColor.bgBase)
}
