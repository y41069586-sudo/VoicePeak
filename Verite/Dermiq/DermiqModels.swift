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
            + " " + String(localized: "That's your single biggest lever.")
            + " " + String(localized: "Fix it and you're a \(achievable), not a \(overall).")
    }

    // Localized at build time (String(localized:)) because the summary is a
    // plain String by the time it reaches the results card — a raw literal
    // here would render as English on every device.
    private static func state(for category: DermiqCategory) -> String {
        switch category {
        case .texture:
            return String(localized: "Texture is holding your score back — visible congestion on the forehead and chin.")
        case .redness:
            return String(localized: "Redness is your weak point, concentrated around the nose and cheeks.")
        case .pores:
            return String(localized: "Pore visibility is dragging the whole picture down, mostly through the T-zone.")
        case .evenness:
            return String(localized: "Uneven tone is the main thing standing between you and a higher score.")
        case .glow:
            return String(localized: "Your skin reads flat right now — the glow score is the drag.")
        case .hydration:
            return String(localized: "Your skin is running dry, and it pulls down every other metric.")
        case .blemishes:
            return String(localized: "Active breakouts are the single biggest drag on your score.")
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

// ============================================================
// MARK: — THE CANONICAL ROUTINE (locked, evidence-based)
// ============================================================
//
// This is THE structure. It is the dermatological consensus, not a style
// choice — do not "improve" it without a study. Sources: AAD skin-care basics;
// derm-consensus reporting (NBC/Healthline) that a 3–4-step routine done daily
// beats a long one, ordered thin → thick.
//
//   FIXED SKELETON (same for everyone):
//     AM  ·  Cleanser → [1 treatment] → Moisturizer → SPF     (≤ 4 steps)
//     PM  ·  Cleanser → [1 treatment] → Moisturizer            (≤ 3 steps)
//
//   THE RULES:
//   1. The core three — cleanser, moisturizer, SPF — are non-negotiable and
//      daily, forever. SPF is the single best-proven anti-aging step.
//   2. ONE leave-on active per session, max. Never stack. Consistency beats
//      intensity; stacking is what breaks barriers and makes people quit.
//   3. Skin type changes ONLY the texture of the cleanser + moisturizer,
//      never the actives:
//        dry        → cream cleanser · rich cream (lighter AM, richer PM)
//        oily       → gel cleanser   · oil-free gel moisturizer
//        combination→ balanced gel-cream both
//        sensitive  → fragrance-free everything · gentler active forms
//        normal     → gentle gel cleanser · ceramide moisturizer
//   4. The (up to two) actives target the two worst-scoring metrics — one for
//      the AM slot, one for the PM slot. Photolabile / photosensitizing
//      actives (retinoids, AHAs) are PM-ONLY; a slot is skipped before one is
//      ever put under the sun.
//   5. Ease-in: days 1–3 are a barrier reset (core only); actives ramp in from
//      day 4 (see RoutineSchedule). Retinoid / BHA / AHA / mask never share an
//      evening.
//
/// Derives the 14-day routine from the user's weakest sub-scores, following the
/// canonical structure above. Base steps are constant per skin type; the one
/// targeted step per block comes 1:1 from the worst-scoring `DermiqCategory`s.
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

        // Targeted steps — ONE active per block, for everyone. A lean routine
        // (cleanse → one treatment → moisturize → SPF) is what people actually
        // stick to, and consistency beats stacking; the two slots still go to
        // the two worst-scoring families, so the plan stays personal.
        let totalCap = 2
        // One product per active FAMILY: without this, two low scores could
        // both resolve to salicylic (texture + blemishes), niacinamide
        // (redness + pores) or two retinoids (texture + blemishes severe) —
        // duplicate products at best, a double retinoid dose at worst.
        var usedFamilies: Set<String> = []
        var amTargets = 0, pmTargets = 0
        for target in ordered {
            guard amTargets + pmTargets < totalCap else { break }
            var step = targetedStep(for: target)
            if feel == .sensitive { step = soften(step) }
            let family = activeFamily(of: step)
            guard !usedFamilies.contains(family) else { continue }
            switch preferredBlock(for: target.category) {
            case .am where amTargets < 1:
                am.append(step); amTargets += 1; usedFamilies.insert(family)
            case .pm where pmTargets < 1:
                pm.append(step); pmTargets += 1; usedFamilies.insert(family)
            default:
                // Preferred block is full — overflow to the other one, EXCEPT
                // that photolabile / photosensitizing actives (retinoids, AHAs)
                // never move into the morning. Better a skipped step than a
                // retinoid under the sun.
                if pmTargets < 1 {
                    pm.append(step); pmTargets += 1; usedFamilies.insert(family)
                } else if amTargets < 1, !isEveningOnly(step) {
                    am.append(step); amTargets += 1; usedFamilies.insert(family)
                }
            }
        }

        am.append(baseMoisturizer(feel: feel, block: .am))
        am.append(RoutineStep(
            key: "am.spf",
            productType: feel == .oily ? "SPF 50, mattifying fluid" : "SPF 50 broad spectrum",
            active: "UV filters",
            why: String(localized: "UV is the #1 score killer. Non-negotiable, every day."),
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
        let pmWhy = String(localized: "Removes the day's oxidized sebum and SPF residue.")
        let amWhy = String(localized: "Preps skin without stripping — protects every step after it.")
        let why = block == .am ? amWhy : pmWhy
        switch feel {
        case .dry:
            return RoutineStep(key: key, productType: "Cream cleanser (non-foaming)",
                active: "Ceramides + glycerin",
                why: why + " " + String(localized: "Cream texture, because your skin runs dry."),
                examples: ["CeraVe Hydrating Cleanser · $", "La Roche-Posay Toleriane Dermo · $$", "Avène Gentle Milk · $$"])
        case .oily:
            return RoutineStep(key: key, productType: "Gel cleanser, low-pH",
                active: "Mild surfactants + zinc",
                why: why + " " + String(localized: "Gel formula keeps the shine in check without over-drying."),
                examples: ["CeraVe Foaming Cleanser · $", "COSRX Low pH Good Morning · $", "Effaclar Purifying Gel · $$"])
        case .sensitive:
            return RoutineStep(key: key, productType: "Fragrance-free cream cleanser",
                active: "Amino-acid surfactants",
                why: why + " " + String(localized: "Zero fragrance, zero essential oils — your skin flagged sensitive."),
                examples: ["La Roche-Posay Toleriane Dermo · $$", "Bioderma Sensibio Gel · $$"])
        case .combo:
            return RoutineStep(key: key, productType: "Balancing gel-cream cleanser",
                active: "Low-pH surfactants + panthenol",
                why: why + " " + String(localized: "Balanced texture for a combination T-zone."),
                examples: ["CeraVe Foaming Cleanser · $", "Krave Matcha Hemp · $$"])
        default:
            return RoutineStep(key: key, productType: "Gentle gel cleanser",
                active: "Low-pH surfactants",
                why: why,
                examples: ["CeraVe Foaming Cleanser · $", "La Roche-Posay Toleriane · $$", "Fresh Soy Cleanser · $$$"])
        }
    }

    private static func baseMoisturizer(feel: SkinFeel?, block: RoutineBlock) -> RoutineStep {
        let key = block == .am ? "am.moisturize" : "pm.moisturize"
        // Dry skin genuinely benefits from a lighter day cream AND a richer
        // overnight repair — that's two products, on purpose. Everyone else uses
        // ONE moisturizer morning and night: same productType in both blocks, so
        // the shopping kit dedupes it to a single item and the count stays lean.
        switch feel {
        case .dry where block == .am:
            return RoutineStep(key: key, productType: "Rich day cream",
                active: "Ceramides + shea + glycerin",
                why: String(localized: "Dry skin needs the fuller buffer under SPF."),
                examples: ["CeraVe Moisturizing Cream · $", "Kiehl's Ultra Facial Cream · $$$"])
        case .dry:
            return RoutineStep(key: key, productType: "Overnight repair cream",
                active: "Ceramides + panthenol + squalane",
                why: String(localized: "Overnight is when repair happens — dry skin gets the richest seal."),
                examples: ["CeraVe Moisturizing Cream · $", "Weleda Skin Food · $"])
        case .oily:
            return RoutineStep(key: key, productType: "Oil-free gel moisturizer",
                active: "Ceramides + niacinamide + HA",
                why: block == .am
                    ? String(localized: "Hydration without weight — shine stays down.")
                    : String(localized: "Same gel at night — repair material without clogging."),
                examples: ["Neutrogena Hydro Boost · $", "CeraVe PM Lotion · $", "Belif Aqua Bomb · $$"])
        case .sensitive:
            return RoutineStep(key: key, productType: "Barrier cream, fragrance-free",
                active: "Ceramides + panthenol",
                why: block == .am
                    ? String(localized: "Calm buffer that keeps the actives from nipping.")
                    : String(localized: "The same fragrance-free barrier for an overnight calm-down."),
                examples: ["Avène Tolérance Control · $$", "La Roche-Posay Cicaplast B5 · $$", "CeraVe PM Lotion · $"])
        default:
            return RoutineStep(key: key, productType: "Ceramide moisturizer",
                active: "Ceramides + glycerin",
                why: block == .am
                    ? String(localized: "Seals the actives in and keeps the barrier calm.")
                    : String(localized: "The same barrier cream at night — that's when repair happens."),
                examples: ["CeraVe PM Lotion · $", "Neutrogena Hydro Boost · $", "Dr. Jart+ Ceramidin · $$$"])
        }
    }

    /// Sensitive skin gets the gentler cousin of every harsh active.
    private static func soften(_ step: RoutineStep) -> RoutineStep {
        if step.active.contains("Glycolic") {
            return RoutineStep(key: step.key, productType: "Gentle PHA exfoliant (2×/week)",
                active: "Gluconolactone (PHA)",
                why: step.why + " " + String(localized: "Softened to PHA — sensitive skin flagged."),
                examples: ["The Inkey List PHA Toner · $", "Naturium PHA Toner · $$"])
        }
        if step.active.contains("Adapalene") || step.active.contains("Retinaldehyde") {
            return RoutineStep(key: step.key, productType: "Gentle retinol (start 2×/week)",
                active: "Retinol 0.3% encapsulated",
                why: step.why + " " + String(localized: "Softened entry dose — sensitive skin flagged."),
                examples: ["The Inkey List Retinol · $", "Geek & Gorgeous A-Game 5 · $$"])
        }
        if step.active.contains("Ascorbic") {
            return RoutineStep(key: step.key, productType: "Vitamin C derivative serum",
                active: "Ethylated ascorbic acid 10%",
                why: step.why + " " + String(localized: "Derivative form — kinder to reactive skin."),
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

    /// Coarse active family for deduping (one retinoid, one BHA, one
    /// niacinamide … per plan, regardless of which score selected it).
    private static func activeFamily(of step: RoutineStep) -> String {
        let a = step.active.lowercased()
        if a.contains("retina") || a.contains("retinol") || a.contains("adapalene") { return "retinoid" }
        if a.contains("salicylic") || a.contains("bha") { return "bha" }
        if a.contains("glycolic") || a.contains("lactic") || a.contains("gluconolactone") { return "aha" }
        if a.contains("niacinamide") { return "niacinamide" }
        if a.contains("ascorbic") || a.contains("vitamin c") { return "vitc" }
        if a.contains("azelaic") { return "azelaic" }
        if a.contains("tranexamic") { return "txa" }
        if a.contains("hyaluronic") || a.contains("squalane") { return "hydrators" }
        return a
    }

    /// Retinoids are photolabile, AHAs photosensitizing — evening only, ever.
    private static func isEveningOnly(_ step: RoutineStep) -> Bool {
        let family = activeFamily(of: step)
        return family == "retinoid" || family == "aha"
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
                why: String(localized: "At \(score), texture is your biggest lever — retinoids are the proven route."),
                examples: ["Geek & Gorgeous A-Game 5 · $$", "Avène Retrinal 0.05 · $$$"]
            )
            : RoutineStep(
                key: "t.texture",
                productType: "BHA exfoliant",
                active: "Salicylic acid 2%",
                why: String(localized: "Clears the congestion dragging your texture score (\(score))."),
                examples: ["The Ordinary Salicylic 2% · $", "COSRX BHA Power Liquid · $$", "Paula's Choice 2% BHA · $$$"]
            )
        case .redness:
            return severe
            ? RoutineStep(
                key: "t.redness",
                productType: "Azelaic acid treatment",
                active: "Azelaic acid 10%",
                why: String(localized: "At \(score), redness needs the stronger calmer — azelaic is it."),
                examples: ["The Ordinary Azelaic 10% · $", "Paula's Choice Azelaic Booster · $$$"]
            )
            : RoutineStep(
                key: "t.redness",
                productType: "Niacinamide serum",
                active: "Niacinamide 10%",
                why: String(localized: "Targets your redness score (\(score))."),
                examples: ["The Ordinary Niacinamide · $", "Naturium Niacinamide · $$", "Paula's Choice 10% · $$$"]
            )
        case .pores:
            return severe
            ? RoutineStep(
                key: "t.pores",
                productType: "Clay + BHA mask (2×/week)",
                active: "Kaolin + salicylic acid",
                why: String(localized: "At \(score), pores need the deep-clean combo, not just a serum."),
                examples: ["Paula's Choice Pore Clarifying Mask · $$", "Innisfree Volcanic Clay · $"]
            )
            : RoutineStep(
                key: "t.pores",
                productType: "Niacinamide + zinc serum",
                active: "Niacinamide 10% + Zinc 1%",
                why: String(localized: "Tightens the pore visibility pulling your score down (\(score))."),
                examples: ["The Ordinary Niacinamide+Zinc · $", "Geek & Gorgeous B-Bomb · $$"]
            )
        case .evenness:
            return severe
            ? RoutineStep(
                key: "t.evenness",
                productType: "Tranexamic acid serum",
                active: "Tranexamic acid 3% + niacinamide",
                why: String(localized: "At \(score), tone needs the targeted fader — tranexamic acid."),
                examples: ["Naturium Tranexamic 5% · $$", "La Roche-Posay Mela B3 · $$$"]
            )
            : RoutineStep(
                key: "t.evenness",
                productType: "Vitamin C serum",
                active: "Ascorbic acid 10–15%",
                why: String(localized: "Evens the tone variance behind your evenness score (\(score))."),
                examples: ["Timeless 10% C · $", "Geek & Gorgeous C-Glow · $$", "Skinceuticals CE Ferulic · $$$"]
            )
        case .glow:
            return severe
            ? RoutineStep(
                key: "t.glow",
                productType: "AHA exfoliant (2–3×/week)",
                active: "Glycolic acid 7%",
                why: String(localized: "At \(score), glow needs real resurfacing — glycolic delivers it."),
                examples: ["The Ordinary Glycolic Toner · $", "Pixi Glow Tonic · $$"]
            )
            : RoutineStep(
                key: "t.glow",
                productType: "Gentle AHA (2×/week)",
                active: "Lactic acid 5%",
                why: String(localized: "Brings back the surface light your glow score is missing (\(score))."),
                examples: ["The Ordinary Lactic 5% · $", "Good Molecules Lactic Toner · $"]
            )
        case .hydration:
            return severe
            ? RoutineStep(
                key: "t.hydration",
                productType: "Overnight hydration mask",
                active: "HA + squalane + panthenol",
                why: String(localized: "At \(score), a serum alone won't refill the deficit — seal it overnight."),
                examples: ["Laneige Water Sleeping Mask · $$", "COSRX Rice Mask · $"]
            )
            : RoutineStep(
                key: "t.hydration",
                productType: "Hydrating serum",
                active: "Hyaluronic acid + B5",
                why: String(localized: "Refills the water deficit behind your hydration score (\(score))."),
                examples: ["The Ordinary HA 2% · $", "La Roche-Posay Hyalu B5 · $$$"]
            )
        case .blemishes:
            // Retinal, not adapalene: adapalene is prescription-only in the EU
            // (incl. Germany) — recommending it OTC would dead-end most users.
            // Retinaldehyde is the strongest retinoid freely available there,
            // with solid acne evidence.
            return severe
            ? RoutineStep(
                key: "t.blemishes",
                productType: "Retinal treatment",
                active: "Retinaldehyde 0.1%",
                why: String(localized: "At \(score), breakouts need a retinoid — the proven route, no prescription needed."),
                examples: ["Geek & Gorgeous A-Game 10 · $$", "Avène Retrinal 0.1 · $$$"]
            )
            : RoutineStep(
                key: "t.blemishes",
                productType: "BHA spot treatment",
                active: "Salicylic acid 2%",
                why: String(localized: "Keeps the occasional breakout from settling in (\(score))."),
                examples: ["COSRX Pimple Patches · $", "Paula's Choice 2% BHA · $$$"]
            )
        }
    }
}
