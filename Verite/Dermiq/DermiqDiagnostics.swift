import Foundation

/// A tiny on-device breadcrumb for the live-analysis path, shown in Settings.
/// Lets us tell — without Xcode — whether a scan actually hit Perfect Corp or
/// fell back to the mock, and exactly why (bad key, 401, face too small, …).
enum DermiqDiagnostics {
    private static let store = UserDefaults.standard
    private static let kText = "dq.diag.text"
    private static let kAt = "dq.diag.at"

    /// Overwrites with the latest outcome (failure point or success). The last
    /// write of an analyze() pass wins, so it reflects where the pass ended.
    static func record(_ text: String) {
        store.set(text, forKey: kText)
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        store.set(formatter.string(from: Date()), forKey: kAt)
    }

    static var lastText: String { store.string(forKey: kText) ?? "No scan yet" }
    static var lastAt: String { store.string(forKey: kAt) ?? "—" }
}
