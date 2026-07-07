import Foundation
import SwiftUI

// MARK: - Output types

/// Risk level expressed as a human-readable tier.
enum RiskLevel: String, Sendable {
    case low, medium, high

    var localizationKey: LocalizedStringKey { "compatibility.risk.\(rawValue)" }

    var color: Color {
        switch self {
        case .low: return Theme.success
        case .medium: return Theme.warning
        case .high: return Theme.danger
        }
    }

    var systemImage: String {
        switch self {
        case .low: return "checkmark.shield.fill"
        case .medium: return "exclamationmark.shield.fill"
        case .high: return "xmark.shield.fill"
        }
    }
}

/// A pair of ingredients that interact negatively when used together.
final class IngredientConflict: Identifiable, @unchecked Sendable {
    let id = UUID()
    let ingredientA: String
    let ingredientB: String
    let reasonKey: LocalizedStringKey

    init(ingredientA: String, ingredientB: String, reasonKey: LocalizedStringKey) {
        self.ingredientA = ingredientA
        self.ingredientB = ingredientB
        self.reasonKey = reasonKey
    }
}

/// Sendable & Hashable wrapper around LocalizedStringKey for use in UI collections and Swift 6 Sendable models.
final class LocalizedKeyWrapper: Hashable, @unchecked Sendable, Identifiable {
    let id = UUID()
    let key: LocalizedStringKey

    init(key: LocalizedStringKey) {
        self.key = key
    }

    // Manually conform to Hashable since LocalizedStringKey is not Hashable
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: LocalizedKeyWrapper, rhs: LocalizedKeyWrapper) -> Bool {
        lhs.id == rhs.id
    }
}

/// Full structured compatibility output for a product × skin profile pair.
/// Designed to be directly renderable by the UI without further transformation.
struct CompatibilityReport: @unchecked Sendable {
    /// 0 (worst) … 100 (best match).
    let compatibilityScore: Int
    let riskLevel: RiskLevel
    /// Short benefit strings, localisation-key ready.
    let benefits: [LocalizedKeyWrapper]
    /// Short concern strings, localisation-key ready.
    let concerns: [LocalizedKeyWrapper]
    /// Pairs of conflicting ingredients found in this product.
    let ingredientConflicts: [IngredientConflict]
    /// Which skin types this product is well-suited for, based on ingredients.
    let recommendedFor: [SkinType]
    /// The underlying MatchResult for access to detailed reason/zone data.
    let matchResult: MatchResult
}

// MARK: - Engine

/// Extends `MatchEngine` to produce a structured `CompatibilityReport` with a
/// 0–100 numeric score, risk level, ingredient conflict detection, and
/// skin-type compatibility recommendations.
///
/// All logic is documented rule-based inference — no ML, no network call.
enum CompatibilityEngine {

    // MARK: Known conflicting pairs (INCI-normalized keys)

    struct ConflictPair: @unchecked Sendable {
        let a: String
        let b: String
        let reasonKey: LocalizedStringKey
    }

    /// Pairs of ingredient keys that are known to be problematic when combined.
    private static let conflictPairs: [ConflictPair] = [
        ConflictPair(a: "retinol",       b: "glycolic acid",  reasonKey: "ingredient.conflict.retinolGlycolic"),
        ConflictPair(a: "retinol",       b: "lactic acid",    reasonKey: "ingredient.conflict.retinolAcid"),
        ConflictPair(a: "retinol",       b: "salicylic acid", reasonKey: "ingredient.conflict.retinolAcid"),
        ConflictPair(a: "benzoyl peroxide", b: "retinol",     reasonKey: "ingredient.conflict.benzRetinol"),
        ConflictPair(a: "ascorbic acid", b: "niacinamide",    reasonKey: "ingredient.conflict.vitCNiacinamide"),
        ConflictPair(a: "alcohol denat.", b: "retinol",       reasonKey: "ingredient.conflict.alcoholRetinol"),
    ]

    // MARK: Public API

    /// Generate a full compatibility report for one product against one skin context.
    static func report(product: Product, skinContext: SkinContext) -> CompatibilityReport {
        let profile = IngredientEngine.profile(for: product)
        let match = MatchEngine.evaluate(profile: profile, context: skinContext)

        let score = numericScore(match: match, profile: profile, context: skinContext)
        let risk = riskLevel(from: score)
        let benefits = buildBenefits(match: match, profile: profile, context: skinContext)
        let concerns = buildConcerns(match: match, profile: profile)
        let conflicts = detectConflicts(in: profile)
        let recommended = recommendedSkinTypes(profile: profile)

        return CompatibilityReport(
            compatibilityScore: score,
            riskLevel: risk,
            benefits: benefits,
            concerns: concerns,
            ingredientConflicts: conflicts,
            recommendedFor: recommended,
            matchResult: match
        )
    }

    // MARK: Score

    private static func numericScore(match: MatchResult,
                                     profile: ProductProfile,
                                     context: SkinContext) -> Int {
        // Start at 72 (a "neutral but safe" baseline for unknown skin).
        var score = 72.0

        // Verdict adjustment.
        switch match.verdict {
        case .avoid:     score -= 30
        case .caution:   score -= 15
        case .neutral:   score += 0
        case .favorable: score += 18
        }

        // Benefit reasons each add a bit.
        let benefitCount = Double(match.benefitReasons.count)
        score += min(12, benefitCount * 4)

        // Risk reasons each penalise.
        let riskCount = Double(match.riskReasons.count)
        score -= min(25, riskCount * 10)

        // Comedogenic max penalty.
        if profile.comedogenicMax >= 4 { score -= 10 }
        else if profile.comedogenicMax == 3 { score -= 5 }

        // Actives bonus — only actives at a meaningful concentration count.
        if !profile.prominentActives.isEmpty { score += 4 }
        else if profile.hasOnlyTraceActives { score -= 4 } // present but likely under-dosed

        // Conflict penalty.
        let conflicts = detectConflicts(in: profile)
        score -= Double(conflicts.count) * 6

        return Int(score.clamped(to: 0...100))
    }

    private static func riskLevel(from score: Int) -> RiskLevel {
        if score >= 68 { return .low }
        if score >= 45 { return .medium }
        return .high
    }

    // MARK: Benefits

    private static func buildBenefits(match: MatchResult,
                                      profile: ProductProfile,
                                      context: SkinContext) -> [LocalizedKeyWrapper] {
        var out: [LocalizedStringKey] = []

        // One line per benefit reason.
        for reason in match.benefitReasons {
            out.append(reason.titleKey)
        }

        // Active bonus lines — only when present at a meaningful concentration.
        if profile.prominentActives.contains(where: { IngredientKnowledgeBase.normalizeKey($0.name) == "niacinamide" }) {
            out.append("compatibility.benefit.niacinamide")
        }
        if profile.ingredients.contains(where: { $0.classes.contains(.humectant) }) {
            out.append("compatibility.benefit.hydrating")
        }
        if profile.prominentActives.contains(where: { IngredientKnowledgeBase.normalizeKey($0.name) == "centella asiatica" }) {
            out.append("compatibility.benefit.calming")
        }

        return Array(out.prefix(5)).map { LocalizedKeyWrapper(key: $0) }   // cap to avoid UI overflow
    }

    // MARK: Concerns

    private static func buildConcerns(match: MatchResult,
                                      profile: ProductProfile) -> [LocalizedKeyWrapper] {
        var out: [LocalizedStringKey] = []

        for reason in match.riskReasons {
            out.append(reason.titleKey)
        }
        if profile.comedogenicMax >= 3 {
            out.append("compatibility.concern.comedogenic")
        }
        if profile.hasOnlyTraceActives {
            out.append("compatibility.concern.traceActives")
        }
        let conflicts = detectConflicts(in: profile)
        if !conflicts.isEmpty {
            out.append("compatibility.concern.interactions")
        }

        return Array(out.prefix(4)).map { LocalizedKeyWrapper(key: $0) }
    }

    // MARK: Conflict detection

    private static func detectConflicts(in profile: ProductProfile) -> [IngredientConflict] {
        let keys = Set(profile.ingredients.map { IngredientKnowledgeBase.normalizeKey($0.name) })
        var found: [IngredientConflict] = []
        for pair in conflictPairs {
            if keys.contains(pair.a) && keys.contains(pair.b) {
                found.append(IngredientConflict(
                    ingredientA: pair.a,
                    ingredientB: pair.b,
                    reasonKey: pair.reasonKey
                ))
            }
        }
        return found
    }

    // MARK: Skin type recommendation

    private static func recommendedSkinTypes(profile: ProductProfile) -> [SkinType] {
        var types: [SkinType] = []

        let hasHumectants = profile.ingredients.contains { $0.classes.contains(.humectant) }
        let hasEmollients = profile.ingredients.contains { $0.classes.contains(.emollient) }
        let hasSoothing = profile.prominentActives.contains {
            let k = IngredientKnowledgeBase.normalizeKey($0.name)
            return ["centella asiatica", "allantoin", "panthenol", "niacinamide"].contains(k)
        }
        let hasOilControl = profile.prominentActives.contains {
            let k = IngredientKnowledgeBase.normalizeKey($0.name)
            return ["niacinamide", "salicylic acid"].contains(k)
        }
        let noComedogenic = profile.comedogenicMax <= 1
        let noFragrance = !profile.hasFragrance

        if hasHumectants || hasEmollients { types.append(.dry) }
        if hasOilControl && noComedogenic { types.append(.oily) }
        if hasSoothing && noFragrance { types.append(.sensitive) }
        if noComedogenic && hasOilControl && hasHumectants { types.append(.combination) }
        if types.isEmpty { types.append(.normal) }

        return types
    }
}

// MARK: - Clamping helper (private)

private extension Double {
    func clamped(to range: ClosedRange<Double>) -> Double {
        Swift.min(Swift.max(self, range.lowerBound), range.upperBound)
    }
}
