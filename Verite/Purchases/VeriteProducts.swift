import Foundation

/// StoreKit product identifiers. Configure the matching products in App Store
/// Connect (and in `Resources/Verite.storekit` for local testing).
enum VeriteProducts {
    static let proYearly = "com.verite.app.pro.yearly"
    static let proMonthly = "com.verite.app.pro.monthly"
    /// v2 paywall: weekly + annual (annual pre-selected).
    static let proWeekly = "com.verite.app.pro.weekly"

    /// Consumable: one extra scan once a Pro user hits the weekly cap
    /// (€1.99). Not a subscription — never grants Pro, just one more scan.
    static let extraScan = "com.verite.app.scan.extra"

    /// All subscription product IDs that grant Pro.
    static let proIDs: Set<String> = [proYearly, proMonthly, proWeekly]

    /// Everything to load from StoreKit (subs + the extra-scan consumable).
    static let allIDs: Set<String> = proIDs.union([extraScan])
}
