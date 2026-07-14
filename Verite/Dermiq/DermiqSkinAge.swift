import Foundation

// ============================================================
// MARK: — Skin age (the shareable hook)
// ============================================================
//
// A single, honest-ish number: how old the skin *looks*, from the traits that
// actually drive perceived age (texture, tone evenness, glow — far more than
// redness or the odd blemish). Anchored to the user's real age band when we
// have it, so a great complexion reads "younger than you" rather than an
// absurd unanchored number. Framed everywhere as an estimate, never a fact.

enum DermiqSkinAge {

    /// 0–100 "youthfulness" score, weighted toward perceived-age drivers.
    private static func youthScore(_ a: DermiqAnalysis) -> Double {
        func v(_ c: DermiqCategory) -> Double { Double(a.subScore(for: c)?.value ?? a.overall) }
        let weighted =
            v(.texture)   * 0.28 +
            v(.evenness)  * 0.24 +
            v(.glow)      * 0.22 +
            v(.pores)     * 0.14 +
            v(.hydration) * 0.12
        // Blend a little overall for stability.
        return weighted * 0.8 + Double(a.overall) * 0.2
    }

    /// Midpoint age for a stored onboarding age band, if any.
    static func realAge(_ band: String?) -> Int? {
        switch band {
        case "under25":    return 22
        case "from25to34": return 30
        case "from35to44": return 40
        case "over45":     return 50
        default:           return nil
        }
    }

    /// Estimated apparent skin age, plus how many years younger than the user's
    /// real age it reads (positive = younger; nil when we don't know their age).
    static func estimate(_ analysis: DermiqAnalysis, ageBand: String?) -> (age: Int, delta: Int?) {
        let score = youthScore(analysis)
        if let real = realAge(ageBand) {
            let adjust = max(-9.0, min(9.0, (score - 60) / 4.5))   // good skin → younger
            let age = max(16, min(70, Int((Double(real) - adjust).rounded())))
            return (age, real - age)
        } else {
            let age = max(18, min(60, Int((54 - 0.36 * score).rounded())))
            return (age, nil)
        }
    }
}
