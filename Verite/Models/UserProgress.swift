import Foundation
import SwiftData

/// Tracks user gamification progress: the scan consistency streak and total flames (points).
@Model
final class UserProgress {
    @Attribute(.unique) var id: UUID
    var currentStreak: Int
    var longestStreak: Int
    var lastScanDate: Date?
    var totalFlames: Int
    
    /// IDs of tasks completed today
    var completedDailyTaskIDs: [String]

    init(id: UUID = UUID(), currentStreak: Int = 0, longestStreak: Int = 0, lastScanDate: Date? = nil, totalFlames: Int = 0, completedDailyTaskIDs: [String] = []) {
        self.id = id
        self.currentStreak = currentStreak
        self.longestStreak = longestStreak
        self.lastScanDate = lastScanDate
        self.totalFlames = totalFlames
        self.completedDailyTaskIDs = completedDailyTaskIDs
    }
}
