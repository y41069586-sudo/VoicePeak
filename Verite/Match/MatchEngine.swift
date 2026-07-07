import Foundation
import SwiftUI

/// The user's skin picture at match time: declared profile + latest scan estimates.
struct SkinContext {
    let concerns: Set<SkinConcern>
    let sensitivities: [String]          // user's own typed sensitivities (lowercased)
    let skinType: SkinType?
    let attributes: [SkinAttribute: Double]  // latest scan estimates (0...1)

    func attribute(_ a: SkinAttribute) -> Double { attributes[a] ?? 0 }

    /// Reactive / redness-prone skin — the group most at risk from irritants.
    var isReactive: Bool {
        skinType == .sensitive
        || concerns.contains(.redness) || concerns.contains(.sensitivity)
        || attribute(.redness) > 0.5 || attribute(.sensitivity) > 0.5
    }
    var isOilyAcne: Bool {
        concerns.contains(.oiliness) || concerns.contains(.acne) || concerns.contains(.pores)
        || attribute(.oiliness) > 0.5 || attribute(.pores) > 0.5
    }
    var isDry: Bool {
        skinType == .dry || concerns.contains(.dryness) || attribute(.hydration) < 0.4
    }

    /// Build from stored scans + profile; nil when there's no scan to match against.
    static func build(scans: [Scan], profile: UserProfile?) -> SkinContext? {
        guard let latest = BaselineTracker.latest(scans) ?? BaselineTracker.baseline(scans) else { return nil }
        var attrs: [SkinAttribute: Double] = [:]
        for attribute in SkinAttribute.allCases {
            if let v = latest.score(for: attribute) { attrs[attribute] = v }
        }
        return SkinContext(
            concerns: Set(profile?.concerns ?? []),
            sensitivities: (profile?.sensitivities ?? []).map { $0.lowercased() },
            skinType: profile?.skinType,
            attributes: attrs
        )
    }
}

/// Crosses a product's ingredient profile against the user's skin context to
/// produce an honest, risk-first `MatchResult`. Documented heuristics only.
enum MatchEngine {

    /// Which concerns each active is known to help (normalized ingredient keys).
    static let activeBenefits: [String: Set<SkinConcern>] = [
        "niacinamide": [.redness, .pores, .oiliness],
        "salicylic acid": [.pores, .oiliness, .acne],
        "glycolic acid": [.texture, .dullness],
        "lactic acid": [.texture, .dryness],
        "retinol": [.texture, .aging],
        "ascorbic acid": [.dullness, .aging],
        "sodium hyaluronate": [.dryness],
        "glycerin": [.dryness],
        "panthenol": [.redness, .dryness],
        "centella asiatica": [.redness, .sensitivity],
        "azelaic acid": [.redness, .acne],
        "allantoin": [.sensitivity],
    ]
    private static let soothingActives: Set<String> = ["centella asiatica", "panthenol", "allantoin", "niacinamide", "azelaic acid"]
    private static let oilControlActives: Set<String> = ["niacinamide", "salicylic acid"]

    static func evaluate(profile: ProductProfile, context: SkinContext) -> MatchResult {
        // Only actives above the ~1% line count as real benefit — a trace active
        // listed near the end ("fairy dusting") shouldn't earn credit.
        let activeKeys = Set(profile.prominentActives.map { IngredientKnowledgeBase.normalizeKey($0.name) })

        var reasons: [MatchReason] = []
        var risk = 0
        var benefit = 0

        // --- RISK (leads) ---
        if context.isReactive {
            var chips: [MatchChip] = []
            if profile.hasIrritant { chips.append(.init(content: .localized(IngredientClass.irritant.localizationKey))); risk += 2 }
            if profile.hasFragrance { chips.append(.init(content: .localized(IngredientClass.fragrance.localizationKey))); risk += 2 }
            if profile.hasAlcohol { chips.append(.init(content: .localized(IngredientClass.alcohol.localizationKey))); risk += 2 }
            if !chips.isEmpty {
                reasons.append(MatchReason(kind: .risk, titleKey: "match.reason.irritate", chips: chips))
            }
        } else if profile.hasFragrance || profile.hasAlcohol {
            risk += 1 // minor, non-reactive skin — noted in score, not surfaced loudly
        }

        // Explicitly flagged sensitivities.
        var flagged: [MatchChip] = []
        for sensitivity in context.sensitivities where !sensitivity.isEmpty {
            if (sensitivity.contains("fragrance") || sensitivity.contains("parfum") || sensitivity.contains("perfume")) && profile.hasFragrance {
                flagged.append(.init(content: .verbatim(sensitivity)))
            } else if sensitivity.contains("alcohol") && profile.hasAlcohol {
                flagged.append(.init(content: .verbatim(sensitivity)))
            } else if profile.ingredients.contains(where: { $0.name.lowercased().contains(sensitivity) }) {
                flagged.append(.init(content: .verbatim(sensitivity)))
            }
        }
        if !flagged.isEmpty {
            reasons.append(MatchReason(kind: .risk, titleKey: "match.reason.flagged", chips: flagged))
            risk += 3
        }

        if profile.comedogenicMax >= 3 && context.isOilyAcne {
            reasons.append(MatchReason(kind: .risk, titleKey: "match.reason.comedogenic", chips: []))
            risk += 2
        }

        // --- BENEFIT ---
        var matchedConcerns = Set<SkinConcern>()
        for ingredient in profile.prominentActives {
            let key = IngredientKnowledgeBase.normalizeKey(ingredient.name)
            if let helps = activeBenefits[key] {
                matchedConcerns.formUnion(helps.intersection(context.concerns))
            }
        }
        if !matchedConcerns.isEmpty {
            let chips = matchedConcerns.sorted { $0.rawValue < $1.rawValue }
                .map { MatchChip(content: .localized($0.localizationKey)) }
            reasons.append(MatchReason(kind: .benefit, titleKey: "match.reason.targets", chips: chips))
            benefit += 2 + min(2, matchedConcerns.count)
        }
        let hydrating = profile.ingredients.contains { $0.classes.contains(.humectant) }
        if hydrating && context.isDry {
            reasons.append(MatchReason(kind: .benefit, titleKey: "match.reason.hydrates", chips: []))
            benefit += 2
        }
        if !activeKeys.intersection(soothingActives).isEmpty && context.isReactive {
            reasons.append(MatchReason(kind: .benefit, titleKey: "match.reason.soothes", chips: []))
            benefit += 2
        }

        // --- VERDICT (risk-first) ---
        let verdict: MatchVerdict
        if risk >= 4 { verdict = .avoid }
        else if risk >= 2 { verdict = .caution }
        else if benefit >= 2 { verdict = .favorable }
        else { verdict = .neutral }

        let ordered = reasons.sorted { rank($0.kind) < rank($1.kind) }
        let zones = zoneMap(profile: profile, context: context, activeKeys: activeKeys)
        return MatchResult(verdict: verdict, reasons: ordered, zones: zones)
    }

    private static func rank(_ kind: MatchReason.Kind) -> Int { kind == .risk ? 0 : 1 }

    /// Map product effects onto facial zones for the heatmap. Risk wins ties
    /// (honesty over flattery).
    private static func zoneMap(profile: ProductProfile, context: SkinContext, activeKeys: Set<String>) -> [FaceRegion: ZoneLevel] {
        let irritating = profile.hasFragrance || profile.hasAlcohol || profile.hasIrritant
        let comedogenic = profile.comedogenicMax >= 3
        let soothingOrHydrating = !activeKeys.intersection(soothingActives).isEmpty
            || profile.ingredients.contains { $0.classes.contains(.humectant) }
        let oilControl = !activeKeys.intersection(oilControlActives).isEmpty

        func cheekLevel() -> ZoneLevel {
            if irritating && context.isReactive { return .risk }
            if soothingOrHydrating && (context.isReactive || context.isDry) { return .benefit }
            return .neutral
        }
        func tZoneLevel() -> ZoneLevel {
            if comedogenic && context.isOilyAcne { return .risk }
            if oilControl && context.isOilyAcne { return .benefit }
            if irritating && context.isReactive { return .risk }
            return .neutral
        }

        return [
            .forehead: tZoneLevel(),
            .nose: tZoneLevel(),
            .leftCheek: cheekLevel(),
            .rightCheek: cheekLevel(),
            .chin: cheekLevel(),
        ]
    }
}
