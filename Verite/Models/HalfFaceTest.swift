import Foundation
import SwiftData

/// A controlled half-face test: the product on one side, the other side is the
/// control. **Validity rule:** each side is compared against its *own* Day-0
/// baseline, never left-vs-right absolute (faces are asymmetric). A verdict is
/// only surfaced past a data + significance threshold — see the scoring logic in
/// Milestone 6.
@Model
final class HalfFaceTest {
    @Attribute(.unique) var id: UUID
    var productID: UUID
    var testSide: FaceSide      // side the product is applied to
    var controlSide: FaceSide   // untreated control
    var startDate: Date
    var cadenceDays: Int
    /// IDs of the `Scan`s captured for this test.
    var scanIDs: [UUID]
    var status: TestStatus
    /// Change vs each side's own baseline, keyed "<side>.<attribute>".
    var perSideDeltas: [String: Double]
    /// 0...1 confidence derived from capture quality + number of scans.
    var confidence: Double
    var createdAt: Date

    init(
        id: UUID = UUID(),
        productID: UUID,
        testSide: FaceSide = .left,
        controlSide: FaceSide = .right,
        startDate: Date = .now,
        cadenceDays: Int = 3,
        scanIDs: [UUID] = [],
        status: TestStatus = .running,
        perSideDeltas: [String: Double] = [:],
        confidence: Double = 0,
        createdAt: Date = .now
    ) {
        self.id = id
        self.productID = productID
        self.testSide = testSide
        self.controlSide = controlSide
        self.startDate = startDate
        self.cadenceDays = cadenceDays
        self.scanIDs = scanIDs
        self.status = status
        self.perSideDeltas = perSideDeltas
        self.confidence = confidence
        self.createdAt = createdAt
    }

    func deltaKey(_ side: FaceSide, _ attribute: SkinAttribute) -> String {
        "\(side.rawValue).\(attribute.rawValue)"
    }
}
