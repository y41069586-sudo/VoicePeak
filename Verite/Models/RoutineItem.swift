import Foundation
import SwiftData

/// A step in the user's routine. `proven` is only ever true for products that
/// passed their half-face test — "a routine you can prove."
@Model
final class RoutineItem {
    @Attribute(.unique) var id: UUID
    var productID: UUID
    var timeOfDay: TimeOfDay
    var order: Int
    var proven: Bool
    /// Optional wait (seconds) before the next step, e.g. after a retinol — used
    /// by the routine timer in Milestone 7.
    var waitSeconds: Int
    var createdAt: Date

    init(
        id: UUID = UUID(),
        productID: UUID,
        timeOfDay: TimeOfDay = .am,
        order: Int = 0,
        proven: Bool = false,
        waitSeconds: Int = 0,
        createdAt: Date = .now
    ) {
        self.id = id
        self.productID = productID
        self.timeOfDay = timeOfDay
        self.order = order
        self.proven = proven
        self.waitSeconds = waitSeconds
        self.createdAt = createdAt
    }
}
