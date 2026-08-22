import Foundation

// ============================================================
// MARK: — Shared widget data (App Group)
// ============================================================
//
// Compiled into BOTH the app and the widget extension. The app writes the
// snapshot to the shared App Group container whenever the routine changes; the
// widget reads it. No SwiftData here — the widget can't see the app's store,
// so we pass a tiny flat snapshot across the group boundary.

/// The glanceable routine state shown on the Home Screen.
struct VeriteWidgetSnapshot: Codable {
    var hasPlan: Bool
    var day: Int          // 1…14
    var totalDays: Int    // 14
    var doneToday: Int
    var totalToday: Int
    var streak: Int

    var fractionToday: Double {
        totalToday > 0 ? Double(doneToday) / Double(totalToday) : 0
    }
    var allDoneToday: Bool { totalToday > 0 && doneToday >= totalToday }

    static let placeholder = VeriteWidgetSnapshot(
        hasPlan: true, day: 6, totalDays: 14, doneToday: 2, totalToday: 3, streak: 5)
    static let empty = VeriteWidgetSnapshot(
        hasPlan: false, day: 0, totalDays: 14, doneToday: 0, totalToday: 0, streak: 0)
}

enum VeriteWidgetStore {
    /// Must match the App Group enabled in the developer portal for BOTH
    /// com.verite.com and com.verite.com.widget.
    static let appGroup = "group.verite.com"
    private static let key = "widget.snapshot.v1"

    static func write(_ snapshot: VeriteWidgetSnapshot) {
        guard let defaults = UserDefaults(suiteName: appGroup),
              let data = try? JSONEncoder().encode(snapshot) else { return }
        defaults.set(data, forKey: key)
    }

    static func read() -> VeriteWidgetSnapshot {
        guard let defaults = UserDefaults(suiteName: appGroup),
              let data = defaults.data(forKey: key),
              let snapshot = try? JSONDecoder().decode(VeriteWidgetSnapshot.self, from: data) else {
            return .empty
        }
        return snapshot
    }
}
