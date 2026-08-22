import Foundation

// ============================================================
// MARK: — Recovery mode (adaptive back-off when skin is irritated)
// ============================================================
//
// Real skin doesn't read the schedule. If actives sting, flake or flare, the
// right move is to PULL them for a few days and let the barrier recover — not
// push through. The user taps "my skin feels irritated" and the plan quietly
// drops every strong active (retinoid, acids, masks) for a short window, keeping
// only the gentle base (cleanse / moisturise / SPF) plus daily-safe serums.
//
// Stored per-plan in UserDefaults (the day recovery began) — no @Model change,
// no migration. `RoutinePlan.scheduledSteps` reads this so the whole app — the
// routine screen, completion, and the widget — reflects the back-off at once.

enum RoutineRecovery {

    /// How many days the actives stay paused after a report.
    static let window = 4

    private static func key(_ plan: RoutinePlan) -> String {
        "dq.recovery.begin.\(plan.id.uuidString)"
    }

    /// The day index recovery was started on, if any.
    private static func beganDay(_ plan: RoutinePlan) -> Int? {
        let value = UserDefaults.standard.integer(forKey: key(plan))
        return value > 0 ? value : nil
    }

    /// Actives are paused on this day.
    static func isActive(_ plan: RoutinePlan, on day: Int) -> Bool {
        guard let start = beganDay(plan) else { return false }
        return day >= start && day < start + window
    }

    /// Days of pause remaining, counting the current day. 0 when not recovering.
    static func daysLeft(_ plan: RoutinePlan, on day: Int) -> Int {
        guard let start = beganDay(plan), day >= start else { return 0 }
        return max(0, start + window - day)
    }

    /// Start a recovery window from today.
    static func begin(_ plan: RoutinePlan) {
        UserDefaults.standard.set(plan.dayIndex(), forKey: key(plan))
    }

    /// End recovery early (skin settled).
    static func end(_ plan: RoutinePlan) {
        UserDefaults.standard.removeObject(forKey: key(plan))
    }
}
