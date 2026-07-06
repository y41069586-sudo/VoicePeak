import SwiftUI

/// A bundled, offline knowledge base classifying common INCI ingredients. This is
/// intentionally curated (not exhaustive) — enough to give honest, useful signal
/// on most products without a network call. Extended over time.
enum IngredientKnowledgeBase {

    struct Entry: @unchecked Sendable {
        let classes: [IngredientClass]
        let noteKey: LocalizedStringKey?
        let comedogenic: Int?
        init(_ classes: [IngredientClass], note: LocalizedStringKey? = nil, comedogenic: Int? = nil) {
            self.classes = classes
            self.noteKey = note
            self.comedogenic = comedogenic
        }
    }

    /// Normalized key for lookup (lowercase, no periods, common alias folding).
    static func normalizeKey(_ name: String) -> String {
        var key = INCIParser.normalize(name)
        for (alias, canonical) in aliases where key == alias { key = canonical }
        return key
    }

    static func lookup(_ name: String) -> Entry? {
        let key = normalizeKey(name)
        if let exact = entries[key] { return exact }
        // Pattern fallbacks for families we don't enumerate exhaustively.
        for (needle, entry) in patterns where key.contains(needle) { return entry }
        return nil
    }

    // MARK: Alias folding (INCI ⇄ common name)

    private static let aliases: [String: String] = [
        "water": "aqua",
        "hyaluronic acid": "sodium hyaluronate",
        "vitamin c": "ascorbic acid",
        "l-ascorbic acid": "ascorbic acid",
        "vitamin e": "tocopherol",
        "parfum/fragrance": "parfum",
        "fragrance": "parfum",
        "alcohol denat": "alcohol denat.",
        "denatured alcohol": "alcohol denat.",
        "cocos nucifera oil": "coconut oil",
        "butyrospermum parkii butter": "shea butter",
        "centella asiatica extract": "centella asiatica",
    ]

    // MARK: Exact entries

    private static let entries: [String: Entry] = [
        // Bases / preservatives
        "aqua": Entry([.other], note: "ingredient.note.water"),
        "glycerin": Entry([.humectant], note: "ingredient.note.glycerin", comedogenic: 0),
        "phenoxyethanol": Entry([.other]),
        "propylene glycol": Entry([.humectant], comedogenic: 0),
        "pentylene glycol": Entry([.humectant], comedogenic: 0),
        "sodium pca": Entry([.humectant], comedogenic: 0),
        "urea": Entry([.humectant]),

        // Actives
        "niacinamide": Entry([.active], note: "ingredient.note.niacinamide", comedogenic: 0),
        "retinol": Entry([.active, .irritant], note: "ingredient.note.retinol", comedogenic: 0),
        "ascorbic acid": Entry([.active], note: "ingredient.note.vitaminC", comedogenic: 0),
        "sodium hyaluronate": Entry([.humectant, .active], note: "ingredient.note.hyaluronic", comedogenic: 0),
        "salicylic acid": Entry([.active, .irritant], note: "ingredient.note.salicylic", comedogenic: 0),
        "glycolic acid": Entry([.active, .irritant], note: "ingredient.note.glycolic", comedogenic: 0),
        "lactic acid": Entry([.active, .humectant], comedogenic: 0),
        "azelaic acid": Entry([.active], comedogenic: 0),
        "benzoyl peroxide": Entry([.active, .irritant]),
        "centella asiatica": Entry([.active], note: "ingredient.note.cica"),
        "panthenol": Entry([.humectant], comedogenic: 0),
        "allantoin": Entry([.other], comedogenic: 0),
        "tocopherol": Entry([.emollient, .active], comedogenic: 2),
        "zinc pca": Entry([.other], comedogenic: 0),

        // Emollients / occlusives
        "dimethicone": Entry([.emollient], comedogenic: 1),
        "squalane": Entry([.emollient], comedogenic: 0),
        "cetyl alcohol": Entry([.emollient], comedogenic: 2),
        "cetearyl alcohol": Entry([.emollient], comedogenic: 2),
        "stearyl alcohol": Entry([.emollient], comedogenic: 2),
        "shea butter": Entry([.emollient], comedogenic: 1),
        "coconut oil": Entry([.emollient, .comedogenic], comedogenic: 4),
        "isopropyl myristate": Entry([.emollient, .comedogenic], comedogenic: 5),

        // Alcohols (drying) — distinct from fatty alcohols above
        "alcohol denat.": Entry([.alcohol], note: "ingredient.note.alcoholDenat"),
        "ethanol": Entry([.alcohol]),

        // Fragrance / allergens
        "parfum": Entry([.fragrance], note: "ingredient.note.fragrance"),
        "limonene": Entry([.fragrance, .irritant]),
        "linalool": Entry([.fragrance, .irritant]),
        "citronellol": Entry([.fragrance, .irritant]),
        "geraniol": Entry([.fragrance, .irritant]),
        "citral": Entry([.fragrance, .irritant]),
        "menthol": Entry([.irritant, .fragrance]),
        "citrus limon peel oil": Entry([.fragrance, .irritant]),
    ]

    // MARK: Pattern fallbacks (checked only on exact miss)

    private static let patterns: [(String, Entry)] = [
        ("parfum", Entry([.fragrance], note: "ingredient.note.fragrance")),
        ("fragrance", Entry([.fragrance], note: "ingredient.note.fragrance")),
        ("alcohol denat", Entry([.alcohol], note: "ingredient.note.alcoholDenat")),
        ("essential oil", Entry([.fragrance, .irritant])),
        ("peg-", Entry([.other])),
        ("glycol", Entry([.humectant])),
    ]
}
