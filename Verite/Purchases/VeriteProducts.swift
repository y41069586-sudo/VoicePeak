import Foundation

/// StoreKit product identifiers. Configure the matching products in App Store
/// Connect (and in `Resources/Verite.storekit` for local testing).
enum VeriteProducts {
    static let proYearly = "com.verite.app.pro.yearly"
    static let proMonthly = "com.verite.app.pro.monthly"

    /// All subscription product IDs that grant Pro.
    static let proIDs: Set<String> = [proYearly, proMonthly]
}
