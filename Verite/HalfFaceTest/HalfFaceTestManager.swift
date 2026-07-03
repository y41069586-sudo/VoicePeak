import SwiftData
import Foundation

/// Lifecycle + queue management for half-face tests. Enforces one active test at
/// a time; promotes the next queued test when one finishes. On pass → the product
/// is promoted into the proven routine; on fail → the money-saved counter ticks up.
@MainActor
enum HalfFaceTestManager {

    static func activeTest(in tests: [HalfFaceTest]) -> HalfFaceTest? {
        tests.first { $0.status == .running || $0.status == .verdictReady }
    }

    /// Create a test. Queued if another is already active.
    @discardableResult
    static func start(product: Product,
                      testSide: FaceSide,
                      cadenceDays: Int,
                      price: Double?,
                      existingTests: [HalfFaceTest],
                      in context: ModelContext) -> HalfFaceTest {
        let hasActive = existingTests.contains { $0.status == .running || $0.status == .verdictReady }
        let test = HalfFaceTest(
            productID: product.id,
            testSide: testSide,
            controlSide: testSide.opposite,
            cadenceDays: cadenceDays,
            status: hasActive ? .queued : .running,
            price: price
        )
        context.insert(test)
        try? context.save()
        return test
    }

    /// Store one scan round: a per-side `Scan` for the treated and control sides.
    static func recordRound(test: HalfFaceTest,
                            sideAnalysis: SideAnalysis,
                            quality: Double,
                            thumbnailFilename: String?,
                            in context: ModelContext) {
        for side in [test.testSide, test.controlSide] {
            let scan = Scan(
                captureQuality: quality,
                attributeScores: sideAnalysis.scores(for: side),
                isBaseline: false,
                side: side,
                thumbnailFilename: thumbnailFilename,
                testID: test.id
            )
            context.insert(scan)
            test.scanIDs.append(scan.id)
        }
        try? context.save()
    }

    /// Finalize a test: promote to routine (pass) or bank the savings (fail), then
    /// start the next queued test.
    static func finalize(test: HalfFaceTest,
                         passed: Bool,
                         confidence: Double,
                         allTests: [HalfFaceTest],
                         routineItems: [RoutineItem],
                         ledgers: [SavingsLedger],
                         in context: ModelContext) {
        test.status = passed ? .passed : .failed
        test.confidence = confidence

        if passed {
            if !routineItems.contains(where: { $0.productID == test.productID }) {
                let item = RoutineItem(productID: test.productID, timeOfDay: .pm, order: routineItems.count, proven: true)
                context.insert(item)
            }
        } else {
            let ledger = ledgers.first ?? {
                let created = SavingsLedger(currencyCode: test.currencyCode)
                context.insert(created)
                return created
            }()
            ledger.recordSaved(test.price ?? 0)
        }

        // Promote the oldest queued test.
        if let next = allTests.filter({ $0.status == .queued }).sorted(by: { $0.createdAt < $1.createdAt }).first {
            next.status = .running
        }

        try? context.save()
    }

    /// When the next scan is due, from the last round + cadence.
    static func nextScanDate(test: HalfFaceTest, scans: [Scan]) -> Date? {
        let testScans = HalfFaceTestScoring.testScans(test, in: scans)
        guard let last = testScans.map(\.date).max() else { return nil }
        return Calendar.current.date(byAdding: .day, value: test.cadenceDays, to: last)
    }
}
