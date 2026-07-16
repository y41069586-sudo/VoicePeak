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
}

private final class TaskHolder: @unchecked Sendable {
    var task: Task<Void, Never>?
    deinit { task?.cancel() }
}
