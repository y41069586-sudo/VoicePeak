import Foundation
import SwiftUI

/// Detects common actives clashes between a candidate product and the user's
/// existing routine (retinol + acid, etc.). Heuristic and conservative — it warns,
/// it doesn't diagnose.
enum IngredientConflicts {

    struct Signals {
        var hasRetinol = false
        var hasAcid = false
        var hasVitaminC = false
        var hasBenzoylPeroxide = false
    }

    static func signals(for profile: ProductProfile) -> Signals {
        var s = Signals()
        for ingredient in profile.ingredients {
            let key = IngredientKnowledgeBase.normalizeKey(ingredient.name)
            if key.contains("retinol") || key.contains("retinal") { s.hasRetinol = true }
            if key == "glycolic acid" || key == "salicylic acid" || key == "lactic acid"
                || key == "mandelic acid" || key.contains("aha") || key.contains("bha") { s.hasAcid = true }
            if key == "ascorbic acid" { s.hasVitaminC = true }
            if key.contains("benzoyl peroxide") { s.hasBenzoylPeroxide = true }
        }
        return s
    }

    /// Signals derived from the user's routine: linked products' ingredients plus
    /// free-text current products from onboarding.
    static func routineSignals(routineProfiles: [ProductProfile], currentProducts: [String]) -> Signals {
        var s = Signals()
        for profile in routineProfiles {
            let p = signals(for: profile)
            s.hasRetinol = s.hasRetinol || p.hasRetinol
            s.hasAcid = s.hasAcid || p.hasAcid
            s.hasVitaminC = s.hasVitaminC || p.hasVitaminC
            s.hasBenzoylPeroxide = s.hasBenzoylPeroxide || p.hasBenzoylPeroxide
        }
        for raw in currentProducts {
            let t = raw.lowercased()
            if t.contains("retinol") || t.contains("retinal") || t.contains("retinoid") { s.hasRetinol = true }
            if t.contains("acid") || t.contains("aha") || t.contains("bha") || t.contains("peel") || t.contains("exfoliant") { s.hasAcid = true }
            if t.contains("vitamin c") || t.contains("ascorbic") { s.hasVitaminC = true }
            if t.contains("benzoyl") { s.hasBenzoylPeroxide = true }
        }
        return s
    }

    static func check(product: ProductProfile, routine: Signals) -> [ConflictWarning] {
        let new = signals(for: product)
        var warnings: [ConflictWarning] = []

        if (new.hasRetinol && routine.hasAcid) || (new.hasAcid && routine.hasRetinol) {
            warnings.append(ConflictWarning(titleKey: "match.conflict.retinolAcid"))
        }
        if (new.hasRetinol && routine.hasVitaminC) || (new.hasVitaminC && routine.hasRetinol) {
            warnings.append(ConflictWarning(titleKey: "match.conflict.vitCRetinol"))
        }
        if new.hasAcid && routine.hasAcid {
            warnings.append(ConflictWarning(titleKey: "match.conflict.overExfoliation"))
        }
        if (new.hasBenzoylPeroxide && routine.hasRetinol) || (new.hasRetinol && routine.hasBenzoylPeroxide) {
            warnings.append(ConflictWarning(titleKey: "match.conflict.bpoRetinol"))
        }
        return warnings
    }
}
