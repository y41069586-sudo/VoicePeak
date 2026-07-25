import Foundation

// ============================================================
// MARK: — In-app language override
// ============================================================
//
// Overriding the UI language from inside the app has exactly ONE reliable
// lever: the `AppleLanguages` user default. Foundation and SwiftUI both read it
// when resolving any localized string, so there is nothing left to disagree.
//
// The previous approach used two levers, and they disagreed:
//
//   • `.environment(\.locale, …)` switched `Text("literal")`.
//   • A reclassed `Bundle.main` was meant to catch `String(localized:)`.
//
// The second never worked. `String(localized:)` is Foundation's own API and
// defaults to `locale: .current` — the DEVICE language — resolving through a
// path that never dispatches through `Bundle.localizedString(forKey:value:
// table:)`, so the reclass was invisible to it. Every string built in Swift
// (the plan CTA, notification bodies, share captions) therefore stayed in the
// device language while `Text(…)` followed the picker, and screens rendered
// half in each. Reproduced both ways round: English picked on a German device,
// and Italian picked on an English device — in both cases the plan CTA fell
// back to the device language.
//
// `AppleLanguages` has no such split, and it also covers system-supplied text
// (date formats, permission dialogs) that neither old mechanism could reach.
// The tradeoff: it is read once as the process starts, so a change applies on
// the next launch. That is the honest price for never showing a half-translated
// screen — and the Settings row says so when a change is pending.

enum AppLanguage {
    static let overrideKey = "languageOverride"
    private static let appleLanguagesKey = "AppleLanguages"

    /// The two-letter language the running process actually resolved to, and
    /// whether it launched under a forced override. Captured by `apply()`
    /// BEFORE it writes, so `needsRelaunch(for:)` can compare against reality
    /// rather than against what we just asked for.
    private(set) nonisolated(unsafe) static var launchLanguage = ""
    private nonisolated(unsafe) static var launchedWithOverride = false

    /// Push the stored override into `AppleLanguages`.
    ///
    /// Must run before any UI is built, on EVERY launch: Foundation reads the
    /// value as the process starts, so writing it later cannot affect the
    /// current session.
    static func apply() {
        let defaults = UserDefaults.standard
        let code = defaults.string(forKey: overrideKey) ?? ""

        // Read the effective language first — at this point it still reflects
        // whatever the previous session stored, which is what we are running in.
        launchLanguage = short(Bundle.main.preferredLocalizations.first)
        launchedWithOverride = !code.isEmpty

        if code.isEmpty {
            defaults.removeObject(forKey: appleLanguagesKey)
        } else {
            defaults.set([code], forKey: appleLanguagesKey)
        }
    }

    /// True when `code` is not the language this process is running in, so the
    /// user has to reopen the app for the change to show.
    static func needsRelaunch(for code: String) -> Bool {
        guard !code.isEmpty else { return launchedWithOverride }
        return short(code) != launchLanguage
    }

    private static func short(_ identifier: String?) -> String {
        String((identifier ?? "").prefix(2))
    }
}
