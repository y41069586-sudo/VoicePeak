import Foundation
import WidgetKit

// ============================================================
// MARK: — App-side widget bridge
// ============================================================
//
// The app owns the SwiftData store; the widget can't read it. So whenever the
// routine changes (plan created, step toggled, tab opened) we flatten the
// active plan into a tiny `VeriteWidgetSnapshot`, write it to the shared App
// Group container, and ask WidgetKit to refresh the timelines.
//
// Cheap and idempotent — safe to call on every routine mutation.

enum WidgetBridge {

    /// Publishes the current routine state to the Home Screen widget.
    @MainActor
    static func publish(_ plan: RoutinePlan?) {
        let snapshot: VeriteWidgetSnapshot
        if let plan {
            let today = plan.dayIndex()
            let amSteps = plan.scheduledSteps(.am, day: today)
            let pmSteps = plan.scheduledSteps(.pm, day: today)
            let total = amSteps.count + pmSteps.count
            let done = amSteps.filter { plan.isDone(day: today, block: .am, step: $0) }.count
                     + pmSteps.filter { plan.isDone(day: today, block: .pm, step: $0) }.count
            snapshot = VeriteWidgetSnapshot(
                hasPlan: true,
                day: today,
                totalDays: 14,
                doneToday: done,
                totalToday: total,
                streak: plan.streak
            )
        } else {
            snapshot = .empty
        }
        VeriteWidgetStore.write(snapshot)
        WidgetCenter.shared.reloadAllTimelines()
    }
}
