import Foundation

// ============================================================
// MARK: — Analysis data model (MASTER PROMPT §3)
// ============================================================
//
// Naming note: the master prompt calls these `SkinAnalysis` / `SubScore` /
// `SkinAnalysisEngine`, but those names are already taken by the legacy v1
// pipeline in this module — the v2 family is prefixed `Dermiq*` instead,
// with identical shapes.

/// The seven rated categories.
enum DermiqCategory: String, Codable, CaseIterable, Identifiable, Sendable {
    case texture, redness, pores, evenness, glow, hydration, blemishes
    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .texture:   return "Texture"
        case .redness:   return "Redness"
        case .pores:     return "Pores"
        case .evenness:  return "Evenness"
        case .glow:      return "Glow"
        case .hydration: return "Hydration"
        case .blemishes: return "Blemishes"
        }
    }
}

enum DermiqTrend: String, Codable, Sendable {
    case up, down, flat
}

struct DermiqSubScore: Codable, Hashable, Identifiable, Sendable {
    let category: DermiqCategory
    let value: Int              // 0–100
    var trend: DermiqTrend?     // nil on first scan
    var id: String { category.rawValue }
}

/// Ranked issues; each maps 1:1 to routine building blocks.
enum DermiqIssue: String, Codable, CaseIterable, Sendable {
    case congestion       // texture
    case persistentRedness
    case enlargedPores
    case unevenTone
    case dullness
    case dehydration
    case activeBreakouts

    var sourceCategory: DermiqCategory {
        switch self {
        case .congestion:        return .texture
        case .persistentRedness: return .redness
        case .enlargedPores:     return .pores
        case .unevenTone:        return .evenness
        case .dullness:          return .glow
        case .dehydration:       return .hydration
        case .activeBreakouts:   return .blemishes
        }
    }

    static func issue(for category: DermiqCategory) -> DermiqIssue {
        switch category {
        case .texture:   return .congestion
        case .redness:   return .persistentRedness
        case .pores:     return .enlargedPores
        case .evenness:  return .unevenTone
        case .glow:      return .dullness
        case .hydration: return .dehydration
        case .blemishes: return .activeBreakouts
        }
    }
}

/// One complete Dermiq rating. (= the master prompt's `SkinAnalysis`.)
struct DermiqAnalysis: Codable, Sendable {
    let overall: Int                 // 0–100
    let subScores: [DermiqSubScore]  // all 7 categories
    let skinType: SkinType           // reuses the app-wide enum
    let topIssues: [DermiqIssue]     // max 3, ranked — drives the routine
    let honestSummary: String        // 2–3 sentences, direct tone
    /// Per-region readings for the zone map. Optional so scans stored before
    /// this existed still decode; nil → zones are derived from sub-scores.
    var zones: [DermiqZoneScore]? = nil

    /// Lowest three sub-scores, worst first (routine derivation input).
    var weakestThree: [DermiqSubScore] {
        Array(subScores.sorted { $0.value < $1.value }.prefix(3))
    }

    func subScore(for category: DermiqCategory) -> DermiqSubScore? {
        subScores.first { $0.category == category }
    }
}

// ============================================================
// MARK: — The honest summary (MASTER PROMPT §4)
// ============================================================
//
// Formula: [honest current state] + [the single biggest lever] + [what's
// achievable]. Direct, specific, forward-looking. Skin only — never
// attractiveness, structure, or anything else.

enum HonestSummaryBuilder {

    static func summary(overall: Int, weakest: DermiqSubScore) -> String {
        let achievable = min(overall + max(8, (88 - overall) / 2), 92)
        return state(for: weakest.category)
            + " That's your single biggest lever."
            + " Fix it and you're a \(achievable), not a \(overall)."
    }

    private static func state(for category: DermiqCategory) -> String {
        switch category {
        case .texture:
            return "Texture is holding your score back — visible congestion on the forehead and chin."
        case .redness:
            return "Redness is your weak point, concentrated around the nose and cheeks."
        case .pores:
            return "Pore visibility is dragging the whole picture down, mostly through the T-zone."
        case .evenness:
            return "Uneven tone is the main thing standing between you and a higher score."
        case .glow:
            return "Your skin reads flat right now — the glow score is the drag."
        case .hydration:
            return "Your skin is running dry, and it pulls down every other metric."
        case .blemishes:
            return "Active breakouts are the single biggest drag on your score."
        }
    }
}

// ============================================================
// MARK: — Routine building blocks (MASTER PROMPT §7 / Screen 7)
// ============================================================

/// One routine step: product TYPE + active ingredient + a why-line tied to the
/// user's actual sub-score. No brand pushing; `examples` is an optional
/// disclosure with 2–3 known products across price tiers.
struct RoutineStep: Codable, Hashable, Identifiable, Sendable {
    let key: String            // stable per-plan identity ("am.spf")
    let productType: String
    let active: String
    let why: String
    let examples: [String]
    var id: String { key }
}

enum RoutineBlock: String, Codable, CaseIterable, Sendable {
    case am, pm
}

// ============================================================
// MARK: — Pre-scan skin questionnaire (2 questions)
// ============================================================

/// Q1: "How does your skin usually feel?" — steers the BASE products
/// (cleanser, moisturizers), so two people with the same scores still get
/// different routines.
enum SkinFeel: String, Codable, CaseIterable, Identifiable, Sendable {
    case dry, oily, combo, sensitive, normal
    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .dry: return "Dry & tight"
        case .oily: return "Oily & shiny"
        case .combo: return "Combination"
        case .sensitive: return "Sensitive"
        case .normal: return "Pretty balanced"
        }
    }
    var icon: String {
        switch self {
        case .dry: return "wind"
        case .oily: return "drop.fill"
        case .combo: return "circle.lefthalf.filled"
        case .sensitive: return "exclamationmark.shield"
        case .normal: return "checkmark.circle"
        }
    }
}

/// Q2: "What describes your skin right now?" — nudges the targeting order.
enum SkinConcernNow: String, Codable, CaseIterable, Identifiable, Sendable {
    case breakouts, redness, dull, dehydrated, fine
    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .breakouts: return "Breaking out"
        case .redness: return "Red & irritated"
        case .dull: return "Dull, no glow"
        case .dehydrated: return "Dry patches"
        case .fine: return "Actually fine"
        }
    }
    var icon: String {
        switch self {
        case .breakouts: return "circle.grid.cross"
        case .redness: return "flame"
        case .dull: return "cloud"
        case .dehydrated: return "drop.degreesign"
        case .fine: return "hand.thumbsup"
        }
    }

    /// The score category this concern promotes to the front of targeting.
    var boostedCategory: DermiqCategory? {
        switch self {
        case .breakouts: return .blemishes
        case .redness: return .redness
        case .dull: return .glow
        case .dehydrated: return .hydration
        case .fine: return nil
        }
    }
}

/// The user's two quiz answers, persisted so rescans prefill them.
struct SkinPrefs: Sendable {
    var feel: SkinFeel
    var concern: SkinConcernNow

    private static let feelKey = "dq.pref.feel"
    private static let concernKey = "dq.pref.concern"

    static func load() -> SkinPrefs? {
        let defaults = UserDefaults.standard
        guard let f = defaults.string(forKey: feelKey).flatMap(SkinFeel.init(rawValue:)),
              let c = defaults.string(forKey: concernKey).flatMap(SkinConcernNow.init(rawValue:))
        else { return nil }
        return SkinPrefs(feel: f, concern: c)
    }

    func save() {
        let defaults = UserDefaults.standard
        defaults.set(feel.rawValue, forKey: Self.feelKey)
        defaults.set(concern.rawValue, forKey: Self.concernKey)
    }
}

/// Derives a 14-day routine from the user's weakest sub-scores. Base steps are
/// constant; the targeted middle steps come 1:1 from `DermiqIssue`s.
enum RoutineBuilder {

    /// `weightedToward` (rescan iterations): categories that improved least
    /// get promoted to the front of the targeting order. `prefs` (the two
    /// pre-scan questions) personalizes the base products and, when the user
    /// named an acute concern, promotes its category to the front.
    static func steps(
        targets: [DermiqSubScore],
        weightedToward: [DermiqCategory] = [],
        prefs: SkinPrefs? = nil
    ) -> (am: [RoutineStep], pm: [RoutineStep]) {
        var ordered = targets
        if !weightedToward.isEmpty {
            ordered.sort { a, b in
                let ai = weightedToward.firstIndex(of: a.category) ?? .max
                let bi = weightedToward.firstIndex(of: b.category) ?? .max
                return ai == bi ? a.value < b.value : ai < bi
            }
        }
        // "What's bothering you right now" jumps the queue — the routine should
        // visibly answer the thing the user just told us.
        if let boosted = prefs?.concern.boostedCategory,
           let index = ordered.firstIndex(where: { $0.category == boosted }), index > 0 {
            ordered.insert(ordered.remove(at: index), at: 0)
        }

        let feel = prefs?.feel
        var am: [RoutineStep] = [baseCleanser(feel: feel, block: .am)]
        var pm: [RoutineStep] = [baseCleanser(feel: feel, block: .pm)]

        // Targeted steps — at most two per block so blocks stay 3–5 steps.
        var amTargets = 0, pmTargets = 0
        for target in ordered {
            var step = targetedStep(for: target)
            if feel == .sensitive { step = soften(step) }
            switch preferredBlock(for: target.category) {
            case .am where amTargets < 2:
                am.append(step); amTargets += 1
            case .pm where pmTargets < 2:
                pm.append(step); pmTargets += 1
            default:
                // Preferred block is full — put it in the other one if it has room.
                if pmTargets < 2 { pm.append(step); pmTargets += 1 }
                else if amTargets < 2 { am.append(step); amTargets += 1 }
            }
        }

        am.append(baseMoisturizer(feel: feel, block: .am))
        am.append(RoutineStep(
            key: "am.spf",
            productType: feel == .oily ? "SPF 50, mattifying fluid" : "SPF 50 broad spectrum",
            active: "UV filters",
            why: "UV is the #1 score killer. Non-negotiable, every day.",
            examples: feel == .oily
                ? ["La Roche-Posay Anthelios Oil Control · $$", "Beauty of Joseon Matte Sun Stick · $"]
                : ["Beauty of Joseon Relief Sun · $", "La Roche-Posay Anthelios · $$", "Supergoop Unseen · $$$"]
        ))
        pm.append(baseMoisturizer(feel: feel, block: .pm))

        return (am, pm)
    }

    // MARK: Base products by skin feel (the quiz's first question)

    private static func baseCleanser(feel: SkinFeel?, block: RoutineBlock) -> RoutineStep {
        let key = block == .am ? "am.cleanse" : "pm.cleanse"
        let pmWhy = "Removes the day's oxidized sebum and SPF residue."
        let amWhy = "Preps skin without stripping — protects every step after it."
        let why = block == .am ? amWhy : pmWhy
        switch feel {
        case .dry:
            return RoutineStep(key: key, productType: "Cream cleanser (non-foaming)",
                active: "Ceramides + glycerin",
                why: why + " Cream texture, because your skin runs dry.",
                examples: ["CeraVe Hydrating Cleanser · $", "La Roche-Posay Toleriane Dermo · $$", "Avène Gentle Milk · $$"])
        case .oily:
            return RoutineStep(key: key, productType: "Gel cleanser, low-pH",
                active: "Mild surfactants + zinc",
                why: why + " Gel formula keeps the shine in check without over-drying.",
                examples: ["CeraVe Foaming Cleanser · $", "COSRX Low pH Good Morning · $", "Effaclar Purifying Gel · $$"])
        case .sensitive:
            return RoutineStep(key: key, productType: "Fragrance-free cream cleanser",
                active: "Amino-acid surfactants",
                why: why + " Zero fragrance, zero essential oils — your skin flagged sensitive.",
                examples: ["La Roche-Posay Toleriane Dermo · $$", "Bioderma Sensibio Gel · $$"])
        case .combo:
            return RoutineStep(key: key, productType: "Balancing gel-cream cleanser",
                active: "Low-pH surfactants + panthenol",
                why: why + " Balanced texture for a combination T-zone.",
                examples: ["CeraVe Foaming Cleanser · $", "Krave Matcha Hemp · $$"])
        default:
            return RoutineStep(key: key, productType: "Gentle gel cleanser",
                active: "Low-pH surfactants",
                why: why,
                examples: ["CeraVe Foaming Cleanser · $", "La Roche-Posay Toleriane · $$", "Fresh Soy Cleanser · $$$"])
        }
    }

    private static func baseMoisturizer(feel: SkinFeel?, block: RoutineBlock) -> RoutineStep {
        if block == .am {
            switch feel {
            case .dry:
                return RoutineStep(key: "am.moisturize", productType: "Rich day cream",
                    active: "Ceramides + shea + glycerin",
                    why: "Dry skin needs the fuller buffer under SPF.",
                    examples: ["CeraVe Moisturizing Cream · $", "Kiehl's Ultra Facial Cream · $$$"])
            case .oily:
                return RoutineStep(key: "am.moisturize", productType: "Oil-free gel moisturizer",
                    active: "HA + niacinamide",
                    why: "Hydration without weight — shine stays down.",
                    examples: ["Neutrogena Hydro Boost · $", "Clinique Dramatically Different Gel · $$"])
            case .sensitive:
                return RoutineStep(key: "am.moisturize", productType: "Barrier cream, fragrance-free",
                    active: "Ceramides + panthenol",
                    why: "Calm buffer that keeps the actives from nipping.",
                    examples: ["Avène Tolérance Control · $$", "CeraVe PM Lotion · $"])
            default:
                return RoutineStep(key: "am.moisturize", productType: "Lightweight moisturizer",
                    active: "Ceramides + glycerin",
                    why: "Seals the actives in and keeps the barrier calm.",
                    examples: ["CeraVe PM Lotion · $", "Neutrogena Hydro Boost · $", "Dr. Jart+ Ceramidin · $$$"])
            }
        } else {
            switch feel {
            case .dry:
                return RoutineStep(key: "pm.moisturize", productType: "Overnight repair cream",
                    active: "Ceramides + panthenol + squalane",
                    why: "Overnight is when repair happens — dry skin gets the richest seal.",
                    examples: ["CeraVe Moisturizing Cream · $", "Weleda Skin Food · $"])
            case .oily:
                return RoutineStep(key: "pm.moisturize", productType: "Light night gel-cream",
                    active: "Ceramides + niacinamide",
                    why: "Repair material without clogging a shine-prone skin.",
                    examples: ["CeraVe PM Lotion · $", "Belif Aqua Bomb · $$"])
            case .sensitive:
                return RoutineStep(key: "pm.moisturize", productType: "Soothing barrier balm",
                    active: "Panthenol + madecassoside",
                    why: "Overnight calm-down — fragrance-free, barrier-first.",
                    examples: ["Avène Cicalfate+ · $$", "La Roche-Posay Cicaplast B5 · $$"])
            default:
                return RoutineStep(key: "pm.moisturize", productType: "Barrier moisturizer",
                    active: "Ceramides + panthenol",
                    why: "Overnight is when repair happens — give it the material.",
                    examples: ["CeraVe Moisturizing Cream · $", "Avène Cicalfate+ · $$"])
            }
        }
    }

    /// Sensitive skin gets the gentler cousin of every harsh active.
    private static func soften(_ step: RoutineStep) -> RoutineStep {
        if step.active.contains("Glycolic") {
            return RoutineStep(key: step.key, productType: "Gentle PHA exfoliant (2×/week)",
                active: "Gluconolactone (PHA)",
                why: step.why + " Softened to PHA — sensitive skin flagged.",
                examples: ["The Inkey List PHA Toner · $", "Naturium PHA Toner · $$"])
        }
        if step.active.contains("Adapalene") || step.active.contains("Retinaldehyde") {
            return RoutineStep(key: step.key, productType: "Gentle retinol (start 2×/week)",
                active: "Retinol 0.3% encapsulated",
                why: step.why + " Softened entry dose — sensitive skin flagged.",
                examples: ["The Inkey List Retinol · $", "Geek & Gorgeous A-Game 5 · $$"])
        }
        if step.active.contains("Ascorbic") {
            return RoutineStep(key: step.key, productType: "Vitamin C derivative serum",
                active: "Ethylated ascorbic acid 10%",
                why: step.why + " Derivative form — kinder to reactive skin.",
                examples: ["Purito CID Serum · $$", "Geek & Gorgeous C-Glow · $$"])
        }
        return step
    }

    private static func preferredBlock(for category: DermiqCategory) -> RoutineBlock {
        switch category {
        case .redness, .evenness, .hydration: return .am
        case .texture, .pores, .glow, .blemishes: return .pm
        }
    }

    /// Below this, a metric counts as SEVERE and gets the stronger option.
    private static let severeThreshold = 55

    /// Two tiers per category: a stronger, proven active when the score is
    /// genuinely low, a gentler one for a moderate dip — so two people with
    /// different readings really do get different plans.
    private static func targetedStep(for target: DermiqSubScore) -> RoutineStep {
        let score = target.value
        let severe = score < severeThreshold
        switch target.category {
        case .texture:
            return severe
            ? RoutineStep(
                key: "t.texture",
                productType: "Retinal night serum",
                active: "Retinaldehyde 0.05%",
                why: "At \(score), texture is your biggest lever — retinoids are the proven route.",
                examples: ["Geek & Gorgeous A-Game 5 · $$", "Avène Retrinal 0.05 · $$$"]
            )
            : RoutineStep(
                key: "t.texture",
                productType: "BHA exfoliant",
                active: "Salicylic acid 2%",
                why: "Clears the congestion dragging your texture score (\(score)).",
                examples: ["The Ordinary Salicylic 2% · $", "COSRX BHA Power Liquid · $$", "Paula's Choice 2% BHA · $$$"]
            )
        case .redness:
            return severe
            ? RoutineStep(
                key: "t.redness",
                productType: "Azelaic acid treatment",
                active: "Azelaic acid 10%",
                why: "At \(score), redness needs the stronger calmer — azelaic is it.",
                examples: ["The Ordinary Azelaic 10% · $", "Paula's Choice Azelaic Booster · $$$"]
            )
            : RoutineStep(
                key: "t.redness",
                productType: "Niacinamide serum",
                active: "Niacinamide 10%",
                why: "Targets your redness score (\(score)).",
                examples: ["The Ordinary Niacinamide · $", "Naturium Niacinamide · $$", "Paula's Choice 10% · $$$"]
            )
        case .pores:
            return severe
            ? RoutineStep(
                key: "t.pores",
                productType: "Clay + BHA mask (2×/week)",
                active: "Kaolin + salicylic acid",
                why: "At \(score), pores need the deep-clean combo, not just a serum.",
                examples: ["Paula's Choice Pore Clarifying Mask · $$", "Innisfree Volcanic Clay · $"]
            )
            : RoutineStep(
                key: "t.pores",
                productType: "Niacinamide + zinc serum",
                active: "Niacinamide 10% + Zinc 1%",
                why: "Tightens the pore visibility pulling your score down (\(score)).",
                examples: ["The Ordinary Niacinamide+Zinc · $", "Geek & Gorgeous B-Bomb · $$"]
            )
        case .evenness:
            return severe
            ? RoutineStep(
                key: "t.evenness",
                productType: "Tranexamic acid serum",
                active: "Tranexamic acid 3% + niacinamide",
                why: "At \(score), tone needs the targeted fader — tranexamic acid.",
                examples: ["Naturium Tranexamic 5% · $$", "La Roche-Posay Mela B3 · $$$"]
            )
            : RoutineStep(
                key: "t.evenness",
                productType: "Vitamin C serum",
                active: "Ascorbic acid 10–15%",
                why: "Evens the tone variance behind your evenness score (\(score)).",
                examples: ["Timeless 10% C · $", "Geek & Gorgeous C-Glow · $$", "Skinceuticals CE Ferulic · $$$"]
            )
        case .glow:
            return severe
            ? RoutineStep(
                key: "t.glow",
                productType: "AHA exfoliant (2–3×/week)",
                active: "Glycolic acid 7%",
                why: "At \(score), glow needs real resurfacing — glycolic delivers it.",
                examples: ["The Ordinary Glycolic Toner · $", "Pixi Glow Tonic · $$"]
            )
            : RoutineStep(
                key: "t.glow",
                productType: "Gentle AHA (2×/week)",
                active: "Lactic acid 5%",
                why: "Brings back the surface light your glow score is missing (\(score)).",
                examples: ["The Ordinary Lactic 5% · $", "Good Molecules Lactic Toner · $"]
            )
        case .hydration:
            return severe
            ? RoutineStep(
                key: "t.hydration",
                productType: "Overnight hydration mask",
                active: "HA + squalane + panthenol",
                why: "At \(score), a serum alone won't refill the deficit — seal it overnight.",
                examples: ["Laneige Water Sleeping Mask · $$", "COSRX Rice Mask · $"]
            )
            : RoutineStep(
                key: "t.hydration",
                productType: "Hydrating serum",
                active: "Hyaluronic acid + B5",
                why: "Refills the water deficit behind your hydration score (\(score)).",
                examples: ["The Ordinary HA 2% · $", "La Roche-Posay Hyalu B5 · $$$"]
            )
        case .blemishes:
            return severe
            ? RoutineStep(
                key: "t.blemishes",
                productType: "Retinoid treatment",
                active: "Adapalene 0.1%",
                why: "At \(score), blemishes need the proven prescription-grade route.",
                examples: ["Differin Gel · $$", "La Roche-Posay Effaclar Adapalene · $$"]
            )
            : RoutineStep(
                key: "t.blemishes",
                productType: "BHA spot treatment",
                active: "Salicylic acid 2%",
                why: "Keeps the occasional breakout from settling in (\(score)).",
                examples: ["COSRX Pimple Patches · $", "Paula's Choice 2% BHA · $$$"]
            )
        }
    }
}
