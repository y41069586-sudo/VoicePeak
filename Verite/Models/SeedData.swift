import Foundation
import SwiftData

/// Seed content so the app is functional offline on first launch, and so
/// previews have something to render. The real bundled starter catalog +
/// ingredient knowledge base arrive in Milestone 4; this is a minimal stub.
enum SeedData {

    /// Populate an (in-memory) preview context with a plausible profile + catalog.
    @MainActor
    static func populatePreview(_ context: ModelContext) {
        let profile = UserProfile(
            skinType: .combination,
            concerns: [.redness, .pores, .texture],
            sensitivities: ["fragrance"],
            goal: "calmer skin",
            onboardingComplete: true
        )
        context.insert(profile)

        for product in starterCatalog {
            context.insert(product)
        }

        context.insert(Streak(current: 4, longest: 9, lastScanDate: .now))
        context.insert(SavingsLedger(totalSaved: 92, currencyCode: "EUR", failedTestsCount: 2))
    }

    /// Seed the bundled starter catalog into the real store on first launch so the
    /// app is functional offline immediately (§14). No-op once any product exists.
    @MainActor
    static func seedCatalogIfNeeded(_ context: ModelContext) {
        let existing = (try? context.fetchCount(FetchDescriptor<Product>())) ?? 0
        guard existing == 0 else { return }
        for product in starterCatalog { context.insert(product) }
        try? context.save()
    }

    /// A tiny, source-attributed starter catalog (INCI only — imagery is added at
    /// runtime from legal/open sources, never bundled from brand assets).
    /// Computed so each call yields fresh, uninserted model instances.
    static var starterCatalog: [Product] {[
        Product(
            name: "Gentle Hydrating Cleanser",
            brand: "Seed Lab",
            inci: ["Aqua", "Glycerin", "Coco-Glucoside", "Panthenol", "Sodium PCA"],
            source: .seed
        ),
        Product(
            name: "Niacinamide 10% Serum",
            brand: "Seed Lab",
            inci: ["Aqua", "Niacinamide", "Zinc PCA", "Pentylene Glycol", "Glycerin"],
            source: .seed
        ),
        Product(
            name: "Fragranced Renewal Essence",
            brand: "Seed Lab",
            inci: ["Aqua", "Alcohol Denat.", "Parfum", "Citrus Limon Peel Oil", "Glycerin"],
            source: .seed
        ),
    ]}
}
