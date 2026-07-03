import Foundation
import SwiftData

/// Running tally of money saved by *not* buying products that failed their test.
/// The anti-marketing counter — every failed test that spares a purchase adds up.
@Model
final class SavingsLedger {
    @Attribute(.unique) var id: UUID
    var totalSaved: Double
    /// ISO 4217 currency code (e.g. "EUR", "USD"), formatted per locale in the UI.
    var currencyCode: String
    var failedTestsCount: Int

    init(
        id: UUID = UUID(),
        totalSaved: Double = 0,
        currencyCode: String = Locale.current.currency?.identifier ?? "EUR",
        failedTestsCount: Int = 0
    ) {
        self.id = id
        self.totalSaved = totalSaved
        self.currencyCode = currencyCode
        self.failedTestsCount = failedTestsCount
    }

    func recordSaved(_ amount: Double) {
        totalSaved += max(0, amount)
        failedTestsCount += 1
    }
}
