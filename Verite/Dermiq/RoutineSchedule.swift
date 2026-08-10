import Foundation

// ============================================================
// MARK: — Routine schedule (which steps run on which day)
// ============================================================
//
// A real 14-day routine is NOT the same 8 products every day. The base
// (cleanse / moisturize / SPF) is daily; the active treatments run on a
// cadence and are staggered so conflicting actives never land on the same
// evening (retinoid vs acid = irritated skin).
//
// This is a PURE function of the step's identity — no model change, no
// migration. Existing plans just start showing the correct per-day set.

enum RoutineSchedule {

    // Ease-in ("ramp") + non-overlapping tracks across days 1…14.
    //
    // Days 1–3 are a BARRIER RESET: base only, zero strong actives. The single
    // biggest beginner mistake is hitting fresh skin with every acid and a
    // retinoid on night one — that irritates, the barrier breaks, scores drop,
    // and people quit. So we hold, then introduce actives gently from day 4 and
    // let the frequency climb into week 2 as the skin proves it can take it.
    //
    // Retinoids and the two acid families never share an evening, and masks sit
    // on their own night — no stacking, ever.
    private static let barrierResetDays = 3

    private static let retinoidDays: Set<Int> = [4, 8, 11, 14]   // 1× wk1 → 3× wk2
    private static let bhaDays: Set<Int>      = [5, 9, 12]        // eases in from day 5
    private static let ahaDays: Set<Int>      = [6, 10, 13]       // opposite the BHA
    private static let maskDays: Set<Int>     = [7]              // one deep-clean, its own night

    /// The days (1…14) a step is scheduled on.
    static func days(for step: RoutineStep) -> Set<Int> {
        let key = step.key.lowercased()
        let active = step.active.lowercased()
        let type = step.productType.lowercased()

        // Base routine — every day.
        if key.contains("cleanse") || key.contains("moisturize") || key.contains("spf") {
            return Set(1...14)
        }
        // Retinoids (evening, ramped).
        if active.contains("retina") || active.contains("adapalene") || active.contains("retinol") {
            return retinoidDays
        }
        // Clay/deep-clean masks — weekly, not a leave-on.
        if type.contains("mask") {
            return maskDays
        }
        // BHA (salicylic).
        if active.contains("salicylic") || active.contains("bha") {
            return bhaDays
        }
        // AHA / PHA (glycolic, lactic, gluconolactone).
        if active.contains("glycolic") || active.contains("lactic")
            || active.contains("aha") || active.contains("gluconolactone") {
            return ahaDays
        }
        // Gentle leave-on serums (niacinamide, HA, vitamin C, azelaic,
        // tranexamic, B5) — safe to use daily.
        return Set(1...14)
    }

    static func isScheduled(_ step: RoutineStep, on day: Int) -> Bool {
        // Barrier-reset invariant: never a strong active in the first days,
        // whatever the track literals say.
        if day <= barrierResetDays && isStrongActive(step) { return false }
        return days(for: step).contains(day)
    }

    /// A "strong" active — retinoid, AHA, BHA or a clay/BHA mask. These are the
    /// irritating ones: they're what the barrier-reset holds back, and what the
    /// recovery mode pulls when the user reports their skin is upset. Gentle
    /// daily serums (niacinamide, HA, vitamin C, azelaic, B5) are never touched.
    static func isStrongActive(_ step: RoutineStep) -> Bool {
        let active = step.active.lowercased()
        let type = step.productType.lowercased()
        if type.contains("mask") { return true }
        return active.contains("retina") || active.contains("adapalene")
            || active.contains("retinol") || active.contains("salicylic")
            || active.contains("bha") || active.contains("glycolic")
            || active.contains("lactic") || active.contains("aha")
            || active.contains("gluconolactone")
    }

    // MARK: Ramp phase (drives an honest "why so few steps today" line)

    enum Phase { case reset, easing, full }

    static func phase(for day: Int) -> Phase {
        if day <= barrierResetDays { return .reset }
        if day <= 9 { return .easing }
        return .full
    }

    /// Short status headline for the day, e.g. shown in the routine header.
    static func phaseTitle(for day: Int) -> String {
        switch phase(for: day) {
        case .reset:  return "Settling in"
        case .easing: return "Easing in actives"
        case .full:   return "Full strength"
        }
    }

    /// One honest line explaining the day's intensity.
    static func phaseDetail(for day: Int) -> String {
        switch phase(for: day) {
        case .reset:  return "Barrier first — cleanse, moisturise, SPF. Actives start day 4."
        case .easing: return "Actives come in gently, a few nights a week — no overload."
        case .full:   return "Your skin has settled in — actives at their planned pace."
        }
    }

    /// A short cadence label for the step row — nil when it's a daily step
    /// (no label needed).
    static func frequencyLabel(for step: RoutineStep) -> String? {
        let count = days(for: step).count
        guard count < 13 else { return nil }
        let perWeek = max(1, Int((Double(count) / 2).rounded()))
        return String(localized: "\(perWeek)×/week")
    }
}
