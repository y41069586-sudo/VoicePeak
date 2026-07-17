import UserNotifications
import Foundation

/// Local notifications for routine + test-scan reminders (UserNotifications).
/// Notification copy is resolved to the active language at schedule time.
@MainActor
enum NotificationManager {

    private static let routineIDs = ["routine.am", "routine.pm"]
    private static let testID = "test.scan"

    private static let desiredKey = "notif.routine.desired"
    private static let pmHourKey = "notif.routine.pmHour"
    private static let pmMinuteKey = "notif.routine.pmMinute"

    static func requestAuthorization() async -> Bool {
        (try? await UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound, .badge])) ?? false
    }

    // MARK: Routine preference (deferred scheduling)

    /// Store the user's routine-reminder wish WITHOUT arming anything yet. The
    /// onboarding ritual screen runs before the first scan, so there is no plan
    /// to remind about — we only remember the choice + preferred evening time
    /// and arm it later via `syncRoutineReminders` once a real, unlocked plan
    /// exists.
    static func setRoutinePreference(enabled: Bool, pmHour: Int, pmMinute: Int) {
        let d = UserDefaults.standard
        d.set(enabled, forKey: desiredKey)
        d.set(pmHour, forKey: pmHourKey)
        d.set(pmMinute, forKey: pmMinuteKey)
    }

    /// Arm the routine reminders only when the user asked for them AND has a
    /// plan they can actually see (Pro + at least one scan). Otherwise clear
    /// them — a non-Pro with a locked, blurred plan must never get a daily
    /// "time for your routine" ping for something they can't open. Idempotent;
    /// call whenever Pro / scan state changes.
    static func syncRoutineReminders(planUnlocked: Bool) {
        let d = UserDefaults.standard
        guard d.bool(forKey: desiredKey), planUnlocked else {
            cancelRoutineReminders()
            return
        }
        let hour = d.object(forKey: pmHourKey) as? Int ?? 21
        let minute = d.object(forKey: pmMinuteKey) as? Int ?? 0
        scheduleRoutineReminders(hour: hour, minute: minute)
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
            body: String(localized: "notif.routine.am.body"))
        add(id: "routine.pm", hour: hour, minute: minute,
            title: String(localized: "notif.routine.pm.title"),
            body: String(localized: "notif.routine.pm.body"))
    }

    static func cancelRoutineReminders() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: routineIDs)
    }

    // MARK: Test-scan

    static func scheduleTestReminder(afterDays days: Int) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [testID])
        let content = makeContent(title: String(localized: "notif.test.title"),
                                  body: String(localized: "notif.test.body"))
        let interval = max(3600, Double(days) * 86_400)
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
        UNUserNotificationCenter.current().add(
            UNNotificationRequest(identifier: testID, content: content, trigger: trigger))
    }

    // MARK: Helpers

    private static func add(id: String, hour: Int, minute: Int, title: String, body: String) {
        var components = DateComponents()
        components.hour = hour
        components.minute = minute
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        UNUserNotificationCenter.current().add(
            UNNotificationRequest(identifier: id, content: makeContent(title: title, body: body), trigger: trigger))
    }

    private static func makeContent(title: String, body: String) -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        return content
    }
}
