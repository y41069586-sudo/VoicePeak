import Foundation

/// Finds alternatives that share this product's core actives *and* also fit the
/// user's skin — the anti-marketing "you don't need the expensive one" feature.
enum DupeFinder {

    static func find(for product: Product,
                     in catalog: [Product],
                     context: SkinContext,
                     limit: Int = 3) -> [Dupe] {
        let target = activeKeys(for: product)
        guard !target.isEmpty else { return [] }

        var dupes: [Dupe] = []
        for candidate in catalog {
            guard candidate.id != product.id else { continue }
            // Skip same brand — a "dupe" from the same line isn't the point.
            if !candidate.brand.isEmpty && candidate.brand.caseInsensitiveCompare(product.brand) == .orderedSame { continue }

            let candidateProfile = IngredientEngine.profile(for: candidate)
            let candidateKeys = activeKeys(profile: candidateProfile)
            let shared = target.intersection(candidateKeys)
            guard !shared.isEmpty else { continue }

            // Only suggest it if it also fits this user (never an "avoid").
            let match = MatchEngine.evaluate(profile: candidateProfile, context: context)
            guard match.verdict != .avoid else { continue }

            dupes.append(Dupe(product: candidate, sharedActives: Array(shared).sorted()))
        }

        return dupes
            .sorted { $0.sharedActives.count > $1.sharedActives.count }
            .prefix(limit)
            .map { $0 }
    }

    private static func activeKeys(for product: Product) -> Set<String> {
        activeKeys(profile: IngredientEngine.profile(for: product))
    }

    private static func activeKeys(profile: ProductProfile) -> Set<String> {
        Set(profile.actives.map { IngredientKnowledgeBase.normalizeKey($0.name) })
    }
}
