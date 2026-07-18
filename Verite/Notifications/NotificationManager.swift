import UserNotifications
import Foundation

/// Local notifications for routine + test-scan reminders (UserNotifications).
/// Notification copy is resolved to the active language at schedule time.
@MainActor
enum NotificationManager {

    private static let routineIDs = ["routine.am", "routine.pm"]
    private static let nudgeID = "nudge.daily"
    private static let testID = "test.scan"

    private static let desiredKey = "notif.routine.desired"
    private static let pmHourKey = "notif.routine.pmHour"
    private static let pmMinuteKey = "notif.routine.pmMinute"

    static func requestAuthorization() async -> Bool {
        (try? await UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound, .badge])) ?? false
    }

    // MARK: Routine preference (deferred scheduling)

    /// Store the user's reminder wish WITHOUT arming anything yet. The
    /// onboarding ritual screen runs before the first scan, so there's no plan
    /// to remind about — we only remember the choice + preferred evening time,
    /// then `syncReminders` arms the right one later (the routine reminder once
    /// Pro, otherwise a conversion nudge).
    static func setRoutinePreference(enabled: Bool, pmHour: Int, pmMinute: Int) {
        let d = UserDefaults.standard
        d.set(enabled, forKey: desiredKey)
        d.set(pmHour, forKey: pmHourKey)
        d.set(pmMinute, forKey: pmMinuteKey)
    }

    /// Reconcile the daily notification the user opted into, based on state:
    ///  • Pro + a real (unlocked) plan → the actual "do your routine" reminder.
    ///  • Not Pro yet (locked/blurred plan, or hasn't scanned) → a conversion
    ///    nudge that drives them back to the scan + paywall ("your score is
    ///    waiting…"), using the permission they already granted. This keeps the
    ///    opted-in channel alive to convert non-payers instead of going silent.
    /// Only ever ONE of the two is scheduled. Idempotent; call whenever Pro /
    /// scan state changes.
    static func syncReminders(planUnlocked: Bool) {
        let d = UserDefaults.standard
        guard d.bool(forKey: desiredKey) else {
            cancelRoutineReminders()
            cancelConversionNudge()
            return
        }
        let hour = d.object(forKey: pmHourKey) as? Int ?? 21
        let minute = d.object(forKey: pmMinuteKey) as? Int ?? 0
        if planUnlocked {
            cancelConversionNudge()
            scheduleRoutineReminders(hour: hour, minute: minute)
        } else {
            cancelRoutineReminders()
            scheduleConversionNudge(hour: hour, minute: minute)
        }
    }

    /// One daily marketing nudge for a non-Pro user — pushes toward the scan
    /// and the paywall. Localized at schedule time.
    static func scheduleConversionNudge(hour: Int, minute: Int) {
        cancelConversionNudge()
        add(id: nudgeID, hour: hour, minute: minute,
            title: String(localized: "notif.nudge.title"),
            body: String(localized: "notif.nudge.body"), route: "scan")
    }

    static func cancelConversionNudge() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [nudgeID])
    }

    /// The routine's display times: AM is the fixed 8:00 ritual, PM is the
    /// user's onboarding/Settings choice (default 21:00). Used by the routine
    /// tab to show WHEN each block should be done — independent of whether
    /// notifications are enabled.
    static var routineTimes: (am: DateComponents, pm: DateComponents) {
        let d = UserDefaults.standard
        let pmHour = d.object(forKey: pmHourKey) as? Int ?? 21
        let pmMinute = d.object(forKey: pmMinuteKey) as? Int ?? 0
        return (DateComponents(hour: 8, minute: 0),
                DateComponents(hour: pmHour, minute: pmMinute))
    }

    // MARK: Routine

    static func scheduleRoutineReminders() {
        scheduleRoutineReminders(hour: 21, minute: 0)
    }

    /// Schedule the AM nudge at a fixed morning hour and the PM nudge at the
    /// user-chosen evening time (from onboarding / Settings time picker).
    static func scheduleRoutineReminders(hour: Int, minute: Int) {
        cancelRoutineReminders()
        add(id: "routine.am", hour: 8, minute: 0,
            title: String(localized: "notif.routine.am.title"),
            body: String(localized: "notif.routine.am.body"), route: "routine")
        // Skip the PM reminder when it would land on the same 8:00 as the AM
        // one (e.g. the user chose a "morning" slot) — never fire two identical
        // daily notifications.
        guard !(hour == 8 && minute == 0) else { return }
        add(id: "routine.pm", hour: hour, minute: minute,
            title: String(localized: "notif.routine.pm.title"),
            body: String(localized: "notif.routine.pm.body"), route: "routine")
    }

    static func cancelRoutineReminders() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: routineIDs)
    }

    // MARK: Test-scan

    /// The day-14 "time to re-scan" nudge. Scheduled once a plan is created so
    /// the rescan the routine promises actually gets a reminder.
    static func scheduleTestReminder(afterDays days: Int) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [testID])
        let content = makeContent(title: String(localized: "notif.test.title"),
                                  body: String(localized: "notif.test.body"), route: "scan")
        let interval = max(3600, Double(days) * 86_400)
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
        UNUserNotificationCenter.current().add(
            UNNotificationRequest(identifier: testID, content: content, trigger: trigger))
    }

    // MARK: Helpers

    private static func add(id: String, hour: Int, minute: Int, title: String, body: String, route: String) {
        var components = DateComponents()
        components.hour = hour
        components.minute = minute
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        UNUserNotificationCenter.current().add(
            UNNotificationRequest(identifier: id, content: makeContent(title: title, body: body, route: route), trigger: trigger))
    }

    private static func makeContent(title: String, body: String, route: String) -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.userInfo = ["route": route]   // read on tap to deep-link
        return content
    }
}

// ============================================================
// MARK: — Tap routing + foreground presentation
// ============================================================

extension Notification.Name {
    /// Fired when a local notification is tapped; object is the route string.
    static let dqOpenRoute = Notification.Name("dq.notification.route")
}

/// Delegate so notifications show in the foreground and their taps deep-link
/// into the app (scan / routine) instead of just opening the last tab.
final class DQNotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    static let shared = DQNotificationDelegate()

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification) async
        -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse) async {
        let route = response.notification.request.content.userInfo["route"] as? String
        await MainActor.run {
            NotificationCenter.default.post(name: .dqOpenRoute, object: route)
        }
    }
}
