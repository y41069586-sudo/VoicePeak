import SwiftUI

/// One classified ingredient: its display name, the classes it falls into, an
/// optional specific plain-language note, and a comedogenic rating when known.
struct ClassifiedIngredient: Identifiable {
    let name: String
    let classes: [IngredientClass]
    let noteKey: LocalizedStringKey?
    let comedogenic: Int?      // 0...5 when known
    let isKnown: Bool

    var id: String { name.lowercased() }

    /// Risk-flag classes only (fragrance, alcohol, irritant, comedogenic).
    var riskClasses: [IngredientClass] { classes.filter { $0.isRiskFlag } }

    /// The explanation to show: a specific note if we have one, else the primary
    /// class description.
    var explanationKey: LocalizedStringKey {
        noteKey ?? (classes.first?.descriptionKey ?? IngredientClass.other.descriptionKey)
    }
}

/// A product's structured ingredient profile, built by `IngredientEngine`.
/// Surfaces risk **first** — that's the whole brand.
struct ProductProfile {
    let ingredients: [ClassifiedIngredient]

    var isEmpty: Bool { ingredients.isEmpty }
    var knownCount: Int { ingredients.filter { $0.isKnown }.count }
    var hasUnknowns: Bool { ingredients.contains { !$0.isKnown } }

    var actives: [ClassifiedIngredient] { ingredients.filter { $0.classes.contains(.active) } }

    /// INCI is ordered by descending concentration. Ingredients present at ≤1%
    /// typically begin around the first of these markers (preservatives, pH
    /// adjusters, chelators, thickeners, fragrance). Lets us tell a prominent
    /// active from a trace one ("fairy dusting").
    private static let onePercentMarkers: Set<String> = [
        "phenoxyethanol", "parfum", "sodium hydroxide", "citric acid",
        "disodium edta", "tetrasodium edta", "ethylhexylglycerin", "sodium benzoate",
        "potassium sorbate", "chlorphenesin", "carbomer", "xanthan gum", "tocopherol",
        "sodium chloride", "triethanolamine", "caprylyl glycol", "sodium citrate",
    ]

    /// Estimated index of the 1% line: the first recognised marker, or a sensible
    /// default when none is present. Never below 1 (position 0 is always prominent).
    var onePercentLineIndex: Int {
        for (i, ing) in ingredients.enumerated() {
            if Self.onePercentMarkers.contains(IngredientKnowledgeBase.normalizeKey(ing.name)) {
                return Swift.max(i, 1)
            }
        }
        return Swift.min(ingredients.count, 8)
    }

    /// Actives listed before the estimated 1% line — i.e. present at a
    /// concentration meaningful enough to credit as a real benefit.
    var prominentActives: [ClassifiedIngredient] {
        let line = onePercentLineIndex
        return ingredients.enumerated()
            .filter { $0.offset < line && $0.element.classes.contains(.active) }
            .map { $0.element }
    }

    /// Has actives, but all appear below the 1% line — likely too low to matter.
    var hasOnlyTraceActives: Bool { !actives.isEmpty && prominentActives.isEmpty }

    var hasFragrance: Bool { ingredients.contains { $0.classes.contains(.fragrance) } }
    var hasAlcohol: Bool { ingredients.contains { $0.classes.contains(.alcohol) } }
    var hasIrritant: Bool { ingredients.contains { $0.classes.contains(.irritant) } }
    var comedogenicMax: Int { ingredients.compactMap { $0.comedogenic }.max() ?? 0 }

    /// The honest "heads-up" flags, most relevant first.
    var riskFlags: [IngredientClass] {
        var flags: [IngredientClass] = []
        if hasIrritant { flags.append(.irritant) }
        if hasFragrance { flags.append(.fragrance) }
        if hasAlcohol { flags.append(.alcohol) }
        if comedogenicMax >= 3 { flags.append(.comedogenic) }
        return flags
    }
}
