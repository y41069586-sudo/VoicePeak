import SwiftUI
import SwiftData

struct TasksSheetView: View {
    @Query private var progresses: [UserProgress]
    @Environment(\.dismiss) private var dismiss
    
    private var progress: UserProgress? { progresses.first }
    private var totalFlames: Int { progress?.totalFlames ?? 0 }
    
    var body: some View {
        NavigationStack {
            ZStack {
                GradientMeshBackground().ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Header
                        VStack(spacing: 8) {
                            Image(systemName: "flame.fill")
                                .font(.system(size: 60))
                                .foregroundStyle(Theme.warning)
                                .shadow(color: Theme.warning.opacity(0.6), radius: 10, y: 5)
                            
                            Text("\(totalFlames)")
                                .font(VType.hero(50))
                                .foregroundStyle(VColor.textPrimary)
                            
                            Text("Total Flames")
                                .font(VType.captionBold)
                                .foregroundStyle(VColor.textSecondary)
                        }
                        .padding(.top, 24)
                        
                        // Tasks List
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Heutige Aufgaben")
                                .font(VType.sectionTitle)
                                .foregroundStyle(VColor.textPrimary)
                                .padding(.horizontal, 4)
                            
                            ForEach(FlameTask.allCases) { task in
                                taskRow(for: task)
                            }
                        }
                        .padding(.horizontal, 20)
                        
                        DisclaimerBanner(style: .short)
                            .padding(.top, 20)
                    }
                    .padding(.bottom, 40)
                }
            }
            .navigationTitle("Aufgaben")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(VColor.textTertiary)
                            .font(.title3)
                    }
                }
            }
        }
    }
    
    @ViewBuilder
    private func taskRow(for task: FlameTask) -> some View {
        let isCompleted = progress?.completedDailyTaskIDs.contains(task.id) ?? false
        
        GlassCard {
            HStack(spacing: 16) {
                // Icon
                ZStack {
                    Circle()
                        .fill(isCompleted ? Theme.success.opacity(0.2) : Theme.accent.opacity(0.1))
                        .frame(width: 44, height: 44)
                    Image(systemName: isCompleted ? "checkmark" : task.icon)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(isCompleted ? Theme.success : Theme.accent)
                }
                
                // Text
                VStack(alignment: .leading, spacing: 4) {
                    Text(task.defaultTitle)
                        .font(VType.bodyMedium)
                        .foregroundStyle(isCompleted ? VColor.textSecondary : VColor.textPrimary)
                        .strikethrough(isCompleted)
                    
                    if isCompleted {
                        Text("Abgeschlossen")
                            .font(VType.micro)
                            .foregroundStyle(Theme.success)
                    }
                }
                
                Spacer()
                
                // Reward
                HStack(spacing: 4) {
                    Text("+\(task.reward)")
                        .font(VType.captionBold)
                    Image(systemName: "flame.fill")
                        .font(.caption2)
                }
                .foregroundStyle(isCompleted ? VColor.textTertiary : Theme.warning)
            }
        }
        .opacity(isCompleted ? 0.6 : 1.0)
    }
}
