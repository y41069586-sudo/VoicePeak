import Foundation

// ============================================================
// MARK: — Approximate product prices for the shopping kit
// ============================================================
//
// The routine's example products carry only a "$ / $$ / $$$" tier. Users
// asked for a real number to budget against, so this maps each example to a
// rough EU street price in whole euros.
//
// These are ESTIMATES, on purpose. Skincare prices swing with retailer,
// pack size, currency and sales, so every price shown in the UI is prefixed
// "~" and the kit footer says so plainly. The goal is "will this cost me €10
// or €40", not a checkout total. Keep the keys in sync with the example
// strings in DermiqModels.swift (name before the " · $" tier).

enum RoutinePrices {

    /// Product name (the part before " · $") → approximate EU price in euros.
    static let euro: [String: Int] = [
        // The Ordinary — the budget backbone
        "The Ordinary Niacinamide": 7,
        "The Ordinary Niacinamide+Zinc": 7,
        "The Ordinary Azelaic 10%": 10,
        "The Ordinary HA 2%": 8,
        "The Ordinary Salicylic 2%": 8,
        "The Ordinary Glycolic Toner": 10,
        "The Ordinary Lactic 5%": 9,
        "The Ordinary Clay Mask": 9,
        // CeraVe
        "CeraVe Foaming Cleanser": 12,
        "CeraVe Hydrating Cleanser": 12,
        "CeraVe Moisturizing Cream": 15,
        "CeraVe PM Lotion": 13,
        // COSRX
        "COSRX Low pH Good Morning": 12,
        "COSRX BHA Power Liquid": 22,
        "COSRX Pimple Patches": 6,
        "COSRX Rice Mask": 20,
        // La Roche-Posay
        "La Roche-Posay Anthelios": 18,
        "La Roche-Posay Anthelios Oil Control": 18,
        "La Roche-Posay Toleriane": 13,
        "La Roche-Posay Toleriane Dermo": 15,
        "La Roche-Posay Cicaplast B5": 12,
        "La Roche-Posay Hyalu B5": 30,
        "La Roche-Posay Mela B3": 35,
        "Effaclar Purifying Gel": 13,
        // Beauty of Joseon
        "Beauty of Joseon Relief Sun": 13,
        "Beauty of Joseon Matte Sun Stick": 15,
        // Geek & Gorgeous
        "Geek & Gorgeous A-Game 5": 18,
        "Geek & Gorgeous A-Game 10": 20,
        "Geek & Gorgeous B-Bomb": 14,
        "Geek & Gorgeous C-Glow": 17,
        // Paula's Choice — the premium tier
        "Paula's Choice 2% BHA": 35,
        "Paula's Choice 10%": 42,
        "Paula's Choice Azelaic Booster": 40,
        "Paula's Choice Pore Clarifying Mask": 30,
        // Naturium
        "Naturium Niacinamide": 15,
        "Naturium PHA Toner": 18,
        "Naturium Tranexamic 5%": 20,
        // The Inkey List
        "The Inkey List Retinol": 12,
        "The Inkey List Bakuchiol": 11,
        "The Inkey List PHA Toner": 11,
        // Avène
        "Avène Retrinal 0.05": 30,
        "Avène Retrinal 0.1": 38,
        "Avène Tolérance Control": 25,
        "Avène Gentle Milk": 15,
        // Everything else
        "Neutrogena Hydro Boost": 13,
        "Belif Aqua Bomb": 35,
        "Krave Matcha Hemp": 28,
        "Bioderma Sensibio Gel": 15,
        "Fresh Soy Cleanser": 40,
        "Dr. Jart+ Ceramidin": 40,
        "Kiehl's Ultra Facial Cream": 32,
        "Weleda Skin Food": 12,
        "Laneige Water Sleeping Mask": 28,
        "Innisfree Volcanic Clay": 12,
        "Good Molecules Lactic Toner": 10,
        "Pixi Glow Tonic": 18,
        "Purito CID Serum": 20,
        "Timeless 10% C": 15,
        "Skinceuticals CE Ferulic": 165,
        "Supergoop Unseen": 38,
        "By Wishtrend Bakuchiol": 22,
    ]

    /// The bare product name from an example string like "CeraVe … · $$".
    private static func name(from example: String) -> String {
        if let range = example.range(of: " · ") {
            return String(example[..<range.lowerBound])
        }
        return example
    }

    /// Euros for a single example string, if we have a price on file.
    static func price(for example: String) -> Int? {
        euro[name(from: example)]
    }

    /// "CeraVe Foaming Cleanser · ~12 €" — the name with a real price in place
    /// of the "· $" tier. Falls back to the original string when the product
    /// isn't in the table, so an added example can never render blank.
    static func pricedLabel(for example: String) -> String {
        guard let price = price(for: example) else { return example }
        return "\(name(from: example)) · ~\(price) €"
    }

    /// The price span across a step's examples: "~7 €" for one, "~7–30 €" for
    /// a range. Returns nil when none of the examples are priced (caller keeps
    /// the old "$ – $$$" tier).
    static func range(for examples: [String]) -> String? {
        let prices = examples.compactMap(price(for:)).sorted()
        guard let low = prices.first, let high = prices.last else { return nil }
        return low == high ? "~\(low) €" : "~\(low)–\(high) €"
    }
}
