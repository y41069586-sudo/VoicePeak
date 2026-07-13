import Foundation
import SwiftData

/// Scan-consistency streak. Consistency (not beauty) is what SKINMAXX rewards.
@Model
final class Streak {
    @Attribute(.unique) var id: UUID
    var current: Int
    var longest: Int
    var lastScanDate: Date?

    init(id: UUID = UUID(), current: Int = 0, longest: Int = 0, lastScanDate: Date? = nil) {
        self.id = id
        self.current = current
        self.longest = longest
        self.lastScanDate = lastScanDate
    }
}
