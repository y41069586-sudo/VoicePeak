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

    // Fixed, non-overlapping tracks across days 1…14. Retinoids and the two
    // acid families never share a day, and everything is evenly spaced.
    private static let retinoidDays: Set<Int> = [3, 7, 10, 14]   // ramps into week 2
    private static let bhaDays: Set<Int>      = [2, 5, 9, 12]    // 2–3×/week
    private static let ahaDays: Set<Int>      = [4, 8, 13]       // opposite the BHA
    private static let maskDays: Set<Int>     = [6, 11]          // ~weekly deep clean

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
        days(for: step).contains(day)
    }

    /// A short cadence label for the step row — nil when it's a daily step
    /// (no label needed).
    static func frequencyLabel(for step: RoutineStep) -> String? {
        let count = days(for: step).count
        guard count < 13 else { return nil }
        let perWeek = max(1, Int((Double(count) / 2).rounded()))
        return "\(perWeek)×/week"
    }
}
