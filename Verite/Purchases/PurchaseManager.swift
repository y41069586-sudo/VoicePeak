import RevenueCat
import SwiftUI

/// Subscription + entitlement via RevenueCat (which sits on top of StoreKit 2).
/// RevenueCat validates receipts and is the single source of truth for the
/// `pro` entitlement; its dashboard receives all purchase analytics
/// automatically. Always present in the environment; only *used* when
/// `FeatureFlags.purchasesEnabled` is on. No external purchase links (3.1.1).
@Observable
@MainActor
final class PurchaseManager {
    private(set) var isPro = false
    private(set) var isPurchasing = false

    /// productID → RevenueCat StoreProduct (for price display + purchase).
    @ObservationIgnored
    private var storeProducts: [String: StoreProduct] = [:]

    @ObservationIgnored
    private let taskHolder = TaskHolder()

    /// RevenueCat PUBLIC SDK key. Public by design (ships in every app binary),
    /// so it is safe to embed — it is not a secret.
    private static let apiKey = "appl_CmCKmzohxbRBKwNpIibNvHuLRSW"

    init() {
        if !Purchases.isConfigured {
            Purchases.logLevel = .warn
            Purchases.configure(withAPIKey: Self.apiKey)
        }
        // Keep `isPro` live as subscriptions renew, expire or are refunded.
        taskHolder.task = Task { [weak self] in
            for await info in Purchases.shared.customerInfoStream {
                await MainActor.run { self?.apply(info) }
            }
        }
    }

    private func apply(_ info: CustomerInfo) {
        isPro = info.entitlements["pro"]?.isActive == true
    }

    /// Load products + current entitlement. Call once when purchases are enabled.
    func load() async {
        let products = await Purchases.shared.products(Array(VeriteProducts.allIDs))
        storeProducts = Dictionary(products.map { ($0.productIdentifier, $0) },
                                   uniquingKeysWith: { first, _ in first })
        if let info = try? await Purchases.shared.customerInfo() { apply(info) }
    }

    /// Localized price string for a product (e.g. "39,99 €"); nil if not loaded.
    func displayPrice(for productID: String) -> String? {
        storeProducts[productID]?.localizedPriceString
    }

    /// The yearly price broken down per week, localized (e.g. "≈ 0,77 €").
    func weeklyEquivalent(forYearly productID: String) -> String? {
        guard let product = storeProducts[productID] else { return nil }
        let weekly = product.price / 52
        let formatter = product.priceFormatter ?? NumberFormatter()
        return formatter.string(from: weekly as NSDecimalNumber)
    }

    /// Whole-percent saved by the yearly plan vs paying the weekly plan for a
    /// full year (52×), computed from the LIVE StoreKit prices. nil until both
    /// load — never a hard-coded claim, so the badge is correct in every
    /// storefront/currency (regional price ladders aren't proportional).
    func annualVsWeeklySavingsPercent(yearly: String, weekly: String) -> Int? {
        guard let y = storeProducts[yearly]?.price,
              let w = storeProducts[weekly]?.price, w > 0 else { return nil }
        let weeklyYear = w * 52
        guard weeklyYear > 0 else { return nil }
        let ratio = (weeklyYear - y) / weeklyYear                     // Decimal
        let saved = NSDecimalNumber(decimal: ratio).doubleValue
        return max(0, Int((saved * 100).rounded()))
    }

    /// Whole-percent saved by a discounted product vs its regular counterpart
    /// (same billing cadence), from the live prices. nil until both load.
    func savingsPercent(offer: String, regular: String) -> Int? {
        guard let o = storeProducts[offer]?.price,
              let r = storeProducts[regular]?.price, r > 0 else { return nil }
        let ratio = (r - o) / r                                       // Decimal
        let saved = NSDecimalNumber(decimal: ratio).doubleValue
        return max(0, Int((saved * 100).rounded()))
    }

    /// Buy a subscription. Returns true once the `pro` entitlement is active.
    @discardableResult
    func purchase(productID: String) async -> Bool {
        guard let product = storeProducts[productID] else { return false }
        isPurchasing = true
        defer { isPurchasing = false }
        do {
            let result = try await Purchases.shared.purchase(product: product)
            apply(result.customerInfo)
            return !result.userCancelled && isPro
        } catch {
            return false
        }
    }

    /// Buy the consumable extra scan. No entitlement — true = it went through.
    func purchaseConsumable(productID: String) async -> Bool {
        guard let product = storeProducts[productID] else { return false }
        isPurchasing = true
        defer { isPurchasing = false }
        do {
            let result = try await Purchases.shared.purchase(product: product)
            return !result.userCancelled
        } catch {
            return false
        }
    }

    func restore() async {
        if let info = try? await Purchases.shared.restorePurchases() { apply(info) }
    }

    // MARK: Account linking

    /// Tie the RevenueCat customer to the signed-in account, so entitlements
    /// follow the user across devices and the dashboard shows real user IDs
    /// instead of anonymous ones. Aliases any purchases made while anonymous.
    func logIn(appUserID: String) async {
        guard !appUserID.isEmpty else { return }
        if let result = try? await Purchases.shared.logIn(appUserID) {
            apply(result.customerInfo)
        }
    }

    /// Back to an anonymous customer on sign-out / account deletion. Purchases
    /// stay restorable via the Apple ID (Restore button) — this only detaches
    /// the account link. Throws-away error: logging out an already-anonymous
    /// user is a no-op failure by design.
    func logOut() async {
        if let info = try? await Purchases.shared.logOut() {
            apply(info)
        }
    }
}

private final class TaskHolder: @unchecked Sendable {
    var task: Task<Void, Never>?
    deinit { task?.cancel() }
}
