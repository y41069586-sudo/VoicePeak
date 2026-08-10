import Foundation

// ============================================================
// MARK: — Honest percentile estimate
// ============================================================

/// A TRANSPARENT "better than X%" estimate for the score card.
///
/// We do not run a live leaderboard, so this is NOT a real ranking against
/// other users. Instead it maps the overall score onto a fixed, documented
/// reference distribution (skin scores in this app cluster in the low-to-mid
/// 60s), giving a rough, honest sense of standing.
///
/// Because it is an ESTIMATE and not a measured rank, every surface that shows
/// it must label it clearly (e.g. "est." + a one-line explanation). If a real
/// cohort baseline is ever added, replace the fixed distribution here with the
/// measured one — the call sites stay the same.
enum DermiqPercentile {

    /// Reference distribution assumption (documented, not measured).
    private static let mean = 63.0
    private static let sd   = 14.0

    /// Estimated share of the reference population this score is at or above,
    /// clamped to a believable 1–99 so we never claim "top 0%" or "bottom 0%".
    static func betterThanPercent(overall: Int) -> Int {
        let z = (Double(overall) - mean) / sd
        // Standard-normal CDF via erf.
        let cdf = 0.5 * (1.0 + erf(z / 2.0.squareRoot()))
        return min(max(Int((cdf * 100).rounded()), 1), 99)
    }

    /// The "top X%" complement — how the badge is phrased.
    static func topPercent(overall: Int) -> Int {
        max(100 - betterThanPercent(overall: overall), 1)
    }
}
