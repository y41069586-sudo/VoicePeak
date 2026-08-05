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

    // MARK: Honest expectations (how soon each trait realistically moves)

    /// How quickly a trait shows visible change on a 14-day horizon. Derived
    /// straight from `cap` so the words and the numbers can never disagree.
    enum Horizon: Int {
        case fast     // clearly visible within the two weeks
        case gradual  // starts moving in 14 days, keeps going after
        case slow     // a longer play — weeks to months

        /// Grouping header shown to the user.
        var heading: String {
            switch self {
            case .fast:    return "Likely by day 14"
            case .gradual: return "Starts now, more with time"
            case .slow:    return "A longer play"
            }
        }
        var icon: String {
            switch self {
            case .fast:    return "bolt.fill"
            case .gradual: return "chart.line.uptrend.xyaxis"
            case .slow:    return "hourglass"
            }
        }
    }

    static func horizon(for category: DermiqCategory) -> Horizon {
        switch cap(category) {
        case 10...: return .fast
        case 7..<10: return .gradual
        default:     return .slow
        }
    }

    /// One honest, specific sentence about what to expect for a trait — no
    /// promises, and it names the real caveats (purging, structural limits).
    static func expectation(for category: DermiqCategory) -> String {
        switch category {
        case .hydration: return "Plumper, less tight skin — usually within days."
        case .glow:      return "A brighter, fresher look as dull surface cells clear."
        case .redness:   return "Calmer, less flushed skin over the two weeks."
        case .evenness:  return "Tone begins to even out; full fading takes longer."
        case .blemishes: return "Fewer new breakouts — it can briefly purge before it clears."
        case .texture:   return "Smoother texture is structural change — think weeks, not days."
        case .pores:     return "Pore size is largely fixed; you manage the look, not shrink them."
        }
    }

    /// Max realistic 14-day gain as a function of the CURRENT score — the
    /// curve the Now⇄14-days toggle swipes along. Low scores have the most
    /// headroom and climb hard; near the ceiling almost nothing moves, so a
    /// 90 barely ticks up while a 55 jumps a lot. Anchored to feel right:
    ///   55 → ~20 · 70 → ~18 · 80 → ~15 · 85 → ~10 · 90 → ~4 · 95 → ~1.
    /// Piecewise-linear between the anchors, flat below 55.
    private static func curveGain(for score: Int) -> Double {
        let anchors: [(x: Int, y: Double)] = [
            (0, 22), (55, 20), (70, 18), (80, 15), (85, 10), (90, 4), (95, 1), (100, 0),
        ]
        for i in 1..<anchors.count where score <= anchors[i].x {
            let a = anchors[i - 1], b = anchors[i]
            let t = Double(score - a.x) / Double(max(b.x - a.x, 1))
            return a.y + (b.y - a.y) * t
        }
        return 0
    }

    /// How much of that curve a trait realistically captures in 14 days —
    /// derived from `cap` (√ so the spread stays gentle), floored at 0.55 so
    /// even the slow structural traits still move visibly. Fast traits
    /// (hydration, glow, redness) take nearly the full curve; texture/pores
    /// take less, because a 20-point texture jump in two weeks would be a lie
    /// the day-14 rescan exposes.
    private static func responsiveness(_ category: DermiqCategory) -> Double {
        max(0.55, (cap(category) / 14).squareRoot())
    }

    static func project(_ analysis: DermiqAnalysis) -> Projected {
        let targeted = Set(analysis.weakestThree.map(\.category))

        var projected: [DermiqCategory: Int] = [:]
        var totalNow = 0
        var totalThen = 0

        for score in analysis.subScores {
            // Score-driven curve × trait responsiveness. Targeted metrics get
            // the full curve; the rest drift up from general consistency only.
            let focus = targeted.contains(score.category) ? 1.0 : 0.4
            let gain = curveGain(for: score.value)
                     * responsiveness(score.category)
                     * focus
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
