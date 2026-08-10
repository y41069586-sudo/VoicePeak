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

    // ---- Region → currency ------------------------------------------------
    //
    // The euro table above is the single source of truth. For a user outside
    // the eurozone we convert it to their currency with a fixed rate — no
    // network, so this is a rough, offline conversion, which is exactly why
    // every price stays prefixed "~" and the kit footer says the numbers are
    // estimates. It answers "£10 or £40", not a checkout total. Skincare
    // prices genuinely differ per market beyond FX, so precise per-country
    // tables would be false precision; a labelled approximation is the honest
    // version. A currency we have no rate for falls back to euros.

    /// Euros per one unit of the currency is the wrong way round — this is
    /// units-of-currency per one euro. Rounded, refreshed occasionally.
    private static let ratePerEuro: [String: Double] = [
        "EUR": 1, "USD": 1.08, "GBP": 0.86, "CHF": 0.96, "CAD": 1.48,
        "AUD": 1.63, "SEK": 11.4, "NOK": 11.7, "DKK": 7.46, "PLN": 4.30,
    ]
    private static let symbol: [String: String] = [
        "EUR": "€", "USD": "$", "GBP": "£", "CHF": "CHF", "CAD": "$",
        "AUD": "$", "SEK": "kr", "NOK": "kr", "DKK": "kr", "PLN": "zł",
    ]
    private static let symbolLeads: Set<String> = ["USD", "GBP", "CAD", "AUD", "CHF"]

    /// The device-region currency, but only if we can convert to it; else EUR.
    static var currencyCode: String {
        let code = Locale.current.currency?.identifier ?? "EUR"
        return ratePerEuro[code] != nil ? code : "EUR"
    }

    /// Convert a euro amount into the display currency, rounded to a clean
    /// unit (whole, or nearest 5 for the high-denomination krona currencies).
    private static func converted(_ euro: Int) -> Int {
        let code = currencyCode
        let value = Double(euro) * (ratePerEuro[code] ?? 1)
        if ["SEK", "NOK", "DKK"].contains(code) { return Int((value / 5).rounded()) * 5 }
        return Int(value.rounded())
    }

    /// A single amount formatted in the user's currency: "~12 €", "~$13".
    static func format(euro: Int) -> String {
        let code = currencyCode
        let sym = symbol[code] ?? "€"
        let n = converted(euro)
        return symbolLeads.contains(code) ? "~\(sym)\(n)" : "~\(n) \(sym)"
    }

    /// A low–high span with one currency symbol: "~7–30 €", "~$6–$35".
    private static func formatSpan(_ low: Int, _ high: Int) -> String {
        let code = currencyCode
        let sym = symbol[code] ?? "€"
        let lo = converted(low), hi = converted(high)
        return symbolLeads.contains(code)
            ? "~\(sym)\(lo)–\(sym)\(hi)"
            : "~\(lo)–\(hi) \(sym)"
    }

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

    /// "CeraVe Foaming Cleanser · ~12 €" — the name with the price in the
    /// user's currency in place of the "· $" tier. Falls back to the original
    /// string when the product isn't in the table, so an added example can
    /// never render blank.
    static func pricedLabel(for example: String) -> String {
        guard let price = price(for: example) else { return example }
        return "\(name(from: example)) · \(format(euro: price))"
    }

    /// The price span across a step's examples, in the user's currency:
    /// "~7 €" for one, "~7–30 €" for a range. Returns nil when none of the
    /// examples are priced (caller keeps the old "$ – $$$" tier).
    static func range(for examples: [String]) -> String? {
        let prices = examples.compactMap(price(for:)).sorted()
        guard let low = prices.first, let high = prices.last else { return nil }
        return low == high ? format(euro: low) : formatSpan(low, high)
    }
}
