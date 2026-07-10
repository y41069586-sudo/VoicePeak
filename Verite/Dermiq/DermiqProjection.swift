import Foundation

// ============================================================
// MARK: — Honest 14-day projection
// ============================================================

/// Projects what the score could look like after 14 days IF the plan is
/// followed — deliberately conservative and rule-based so it stays honest:
///
/// - Only the plan's target metrics (the weakest three) get meaningful gains;
///   everything else moves barely at all.
/// - Gains scale with headroom (a 40 can climb; a 90 can't) and are capped
///   per category by how fast that trait realistically responds in two weeks
///   (hydration/glow fast; texture/pores slow — structural change takes
///   longer than 14 days).
/// - The result is a PROJECTION, and every surface that shows it says so.
enum DermiqProjection {

    struct Projected {
        let overall: Int
        /// Category → projected value (same order as the analysis subScores).
        let subScores: [DermiqCategory: Int]

        func value(for category: DermiqCategory) -> Int? { subScores[category] }
    }

    /// Max realistic 14-day gain per category, at full headroom + targeted.
    private static func cap(_ category: DermiqCategory) -> Double {
        switch category {
        case .hydration: return 14   // responds within days
        case .glow:      return 12
        case .redness:   return 10
        case .blemishes: return 10
        case .evenness:  return 7
        case .texture:   return 6    // structural — slow
        case .pores:     return 5    // mostly appearance management
        }
    }

    static func project(_ analysis: DermiqAnalysis) -> Projected {
        let targeted = Set(analysis.weakestThree.map(\.category))

        var projected: [DermiqCategory: Int] = [:]
        var totalNow = 0
        var totalThen = 0

        for score in analysis.subScores {
            let headroom = Double(100 - score.value) / 100.0
            // Targeted metrics get the plan's full attention; the rest only
            // drift up slightly from general consistency.
            let focus = targeted.contains(score.category) ? 1.0 : 0.25
            let gain = min(cap(score.category) * focus,
                           Double(100 - score.value) * 0.5) * headroom.squareRoot()
            let value = min(score.value + Int(gain.rounded()), 96)
            projected[score.category] = value
            totalNow += score.value
            totalThen += value
        }

        // The overall moves with the average sub-score gain — never more.
        let count = max(analysis.subScores.count, 1)
        let overallGain = (totalThen - totalNow) / count
        let overall = min(analysis.overall + overallGain, 96)

        return Projected(overall: overall, subScores: projected)
    }
}
