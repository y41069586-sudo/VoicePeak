import Foundation

/// A tiny on-device breadcrumb for the live-analysis path, shown in Settings.
/// Lets us tell — without Xcode — whether a scan actually hit Perfect Corp or
/// fell back to the mock, and exactly why (bad key, 401, face too small, …).
///
/// `UserDefaults` isn't `Sendable`, so it is accessed inline per call rather
/// than held in a static (which Swift 6 rejects as shared mutable state).
enum DermiqDiagnostics {
    private static let kText = "dq.diag.text"
    private static let kAt = "dq.diag.at"

    /// Overwrites with the latest outcome (failure point or success). The last
    /// write of an analyze() pass wins, so it reflects where the pass ended.
    static func record(_ text: String) {
        let defaults = UserDefaults.standard
        defaults.set(text, forKey: kText)
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        defaults.set(formatter.string(from: Date()), forKey: kAt)
    }

    static var lastText: String { UserDefaults.standard.string(forKey: kText) ?? "No scan yet" }
    static var lastAt: String { UserDefaults.standard.string(forKey: kAt) ?? "—" }
}
