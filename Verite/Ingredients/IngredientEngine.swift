import Foundation

/// Turns a product's raw INCI list into a classified `ProductProfile` using the
/// bundled knowledge base. Pure + synchronous — cheap enough to compute on demand,
/// so we never persist a stale profile.
enum IngredientEngine {

    static func profile(for product: Product) -> ProductProfile {
        classify(inci: product.inci)
    }

    static func classify(inci: [String]) -> ProductProfile {
        ProductProfile(ingredients: inci.map(classifyOne))
    }

    private static func classifyOne(_ name: String) -> ClassifiedIngredient {
        if let entry = IngredientKnowledgeBase.lookup(name) {
            return ClassifiedIngredient(
                name: name,
                classes: entry.classes,
                noteKey: entry.noteKey,
                comedogenic: entry.comedogenic,
                isKnown: true
            )
        }
        // Unknown → shown honestly as "not in our knowledge base yet", not guessed.
        return ClassifiedIngredient(name: name, classes: [.other], noteKey: nil, comedogenic: nil, isKnown: false)
    }
}
