import StoreKit
import SwiftUI

/// StoreKit 2 wrapper: loads products, purchases, restores, and tracks the Pro
/// entitlement. Always present in the environment; only *used* when
/// `FeatureFlags.purchasesEnabled` is on. No external purchase links (guideline 3.1.1).
@Observable
@MainActor
final class PurchaseManager {
    // Fully qualified: the app also declares a SwiftData `Product` model, which
    // would otherwise shadow StoreKit's `Product` within this module.
    private(set) var products: [StoreKit.Product] = []
    private(set) var isPro = false
    private(set) var isPurchasing = false

    // nonisolated: only ever written from `init` (MainActor) and read
    // from `deinit`, which runs nonisolated — cancelling a Task is thread-safe.
    @ObservationIgnored
    nonisolated private var updatesTask: Task<Void, Never>?

    init() {
        updatesTask = listenForTransactions()
    }

    deinit {
        updatesTask?.cancel()
    }

    /// Load products + current entitlement. Call once when purchases are enabled.
    func load() async {
        products = (try? await StoreKit.Product.products(for: VeriteProducts.proIDs))?
            .sorted { $0.price < $1.price } ?? []
        await refreshEntitlements()
    }

    @discardableResult
    func purchase(_ product: StoreKit.Product) async -> Bool {
        isPurchasing = true
        defer { isPurchasing = false }
        guard let result = try? await product.purchase() else { return false }
        switch result {
        case .success(let verification):
            if case .verified(let transaction) = verification {
                await transaction.finish()
                await refreshEntitlements()
                return isPro
            }
            return false
        case .userCancelled, .pending:
            return false
        @unknown default:
            return false
        }
    }

    func restore() async {
        try? await AppStore.sync()
        await refreshEntitlements()
    }

    func refreshEntitlements() async {
        var pro = false
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result,
               VeriteProducts.proIDs.contains(transaction.productID),
               transaction.revocationDate == nil {
                pro = true
            }
        }
        isPro = pro
    }

    private func listenForTransactions() -> Task<Void, Never> {
        Task { [weak self] in
            for await update in Transaction.updates {
                guard case .verified(let transaction) = update else { continue }
                await transaction.finish()
                await self?.refreshEntitlements()
            }
        }
    }
}
