import StoreKit
import SwiftUI

/// StoreKit 2 wrapper: loads products, purchases, restores, and tracks the Pro
/// entitlement. Always present in the environment; only *used* when
/// `FeatureFlags.purchasesEnabled` is on. No external purchase links (guideline 3.1.1).
@Observable
@MainActor
final class PurchaseManager {
    private(set) var products: [StoreKit.Product] = []
    private(set) var isPro = false
    private(set) var isPurchasing = false

    // Held in a separate class so its deinit can safely cancel the task
    // without violating Swift 6 actor isolation rules.
    @ObservationIgnored
    private let taskHolder = TaskHolder()

    init() {
        taskHolder.task = listenForTransactions()
    }

    /// Load products + current entitlement. Call once when purchases are enabled.
    func load() async {
        products = (try? await StoreKit.Product.products(for: VeriteProducts.allIDs))?
            .sorted { $0.price < $1.price } ?? []
        await refreshEntitlements()
    }

    /// Buy a consumable (the €1.99 extra scan). Finishes the transaction and
    /// returns whether the purchase actually went through — never touches the
    /// Pro entitlement (a consumable doesn't grant Pro).
    func purchaseConsumable(_ product: StoreKit.Product) async -> Bool {
        isPurchasing = true
        defer { isPurchasing = false }
        guard let result = try? await product.purchase() else { return false }
        if case .success(let verification) = result,
           case .verified(let transaction) = verification {
            await transaction.finish()
            return true
        }
        return false
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

private final class TaskHolder: @unchecked Sendable {
    var task: Task<Void, Never>?
    deinit { task?.cancel() }
}
