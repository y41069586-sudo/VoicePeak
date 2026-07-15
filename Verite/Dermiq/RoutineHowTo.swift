import Foundation

// ============================================================
// MARK: — How-to-apply instructions + shopping kit
// ============================================================
//
// Two things the routine screen was missing: clear "how do I actually use
// this" guidance per step, and an honest answer to "do I really have to buy
// all this?" — the kit dedupes the steps into the handful of products you
// actually purchase (one cleanser covers AM + PM, etc.).

enum RoutineHowTo {

    /// One short application instruction for a step, derived from its active.
    static func instruction(for step: RoutineStep) -> String {
        let key = step.key.lowercased()
        let active = step.active.lowercased()
        let type = step.productType.lowercased()

        if key.contains("cleanse") {
            return "Massage onto damp skin for ~30 seconds, then rinse with lukewarm water."
        }
        if key.contains("spf") {
            return "Last morning step. Use two finger-lengths and reapply if you're outdoors."
        }
        if key.contains("moisturize") {
            return "Smooth a pea-to-almond amount over the face while skin is still slightly damp."
        }
        if type.contains("mask") {
            return "1–2× a week. Spread an even layer, leave 10 minutes, then rinse off."
        }
        if active.contains("retina") || active.contains("adapalene") || active.contains("retinol") {
            return "Evening only, on dry skin. A pea-sized amount for the whole face, avoid the eye area. If it stings, apply moisturizer first."
        }
        if active.contains("salicylic") || active.contains("bha") {
            return "Evening, on clean dry skin before moisturizer. Never the same night as your retinoid."
        }
        if active.contains("glycolic") || active.contains("lactic")
            || active.contains("aha") || active.contains("gluconolactone") {
            return "Evening, on dry skin before moisturizer. Don't layer with your retinoid or BHA the same night."
        }
        if active.contains("ascorbic") {
            return "Morning, after cleansing and before SPF. A few drops, pressed into the skin."
        }
        if active.contains("niacinamide") {
            return "A few drops after cleansing, before moisturizer. Works morning or evening."
        }
        if active.contains("hyaluronic") {
            return "Apply to slightly damp skin, then lock it in with your moisturizer."
        }
        if active.contains("azelaic") || active.contains("tranexamic") {
            return "A thin layer after cleansing, before moisturizer."
        }
        return "Apply after cleansing, before moisturizer."
    }
}

// ============================================================
// MARK: — Shopping kit (dedupes steps → products to actually buy)
// ============================================================

struct KitProduct: Identifiable {
    let id: String            // dedupe key
    let productType: String
    let active: String
    let usage: String         // "AM + PM", "PM · 2×/week", …
    let howTo: String         // one-line application instruction
    let cheapest: String?     // first example (the $ tier)
    let tiers: String         // "$ – $$$"
    /// The starter four: cleanser, moisturizer, SPF + the single highest-
    /// priority treatment. Everything else is "add when you're ready".
    let isEssential: Bool
}

extension RoutinePlan {

    /// The unique products behind the whole plan — one cleanser covers AM &
    /// PM, so the count is far smaller than the step count. This is what the
    /// user actually shops for.
    var shoppingKit: [KitProduct] {
        let all = steps(.am).map { ($0, RoutineBlock.am) } + steps(.pm).map { ($0, RoutineBlock.pm) }
        var order: [String] = []
        var byType: [String: (step: RoutineStep, blocks: Set<RoutineBlock>)] = [:]
        for (step, block) in all {
            let id = step.productType
            if var existing = byType[id] {
                existing.blocks.insert(block)
                byType[id] = existing
            } else {
                byType[id] = (step, [block])
                order.append(id)
            }
        }
        // Base products (cleanser, moisturizer, SPF) are always essential; of
        // the targeted treatments, only the first one — the top-priority active
        // — makes the starter kit. The rest are "add later".
        let baseKeys: Set<String> = [
            "am.cleanse", "pm.cleanse", "am.moisturize", "pm.moisturize", "am.spf",
        ]
        var heroAssigned = false
        return order.compactMap { id in
            guard let entry = byType[id] else { return nil }
            let step = entry.step
            let freq = RoutineSchedule.frequencyLabel(for: step)
            let time: String
            if entry.blocks.count == 2 { time = "AM + PM" }
            else if entry.blocks.contains(.am) { time = "AM" }
            else { time = "PM" }
            let usage = freq.map { "\(time) · \($0)" } ?? time
            let priceTier: String = {
                let count = step.examples.count
                if count >= 3 { return "$ – $$$" }
                if count == 2 { return "$ – $$" }
                return "$"
            }()
            let isEssential: Bool
            if baseKeys.contains(step.key) {
                isEssential = true
            } else if !heroAssigned {
                isEssential = true
                heroAssigned = true
            } else {
                isEssential = false
            }
            return KitProduct(
                id: id,
                productType: step.productType,
                active: step.active,
                usage: usage,
                howTo: RoutineHowTo.instruction(for: step),
                cheapest: step.examples.first,
                tiers: priceTier,
                isEssential: isEssential
            )
        }
    }
}
