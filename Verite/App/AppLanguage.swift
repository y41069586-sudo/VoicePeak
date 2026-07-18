import Foundation
import ObjectiveC.runtime

// ============================================================
// MARK: — In-app language override for String(localized:)
// ============================================================
//
// The Settings language picker writes `languageOverride` and RootView applies
// it to SwiftUI via `.environment(\.locale, …)`. That switches every
// `Text(LocalizedStringKey(…))`, but it does NOT reach plain `String(localized:)`
// / `NSLocalizedString` calls — those resolve against `Bundle.main` using the
// device language. The result is a UI that is mostly in the chosen language
// but with stray strings (built in view models, e.g. the plan CTA) still in
// the device language.
//
// Fix: reclass `Bundle.main` so its `localizedString(forKey:value:table:)` —
// the funnel every localized-string API ultimately calls — routes through the
// chosen language's `.lproj`. Reads the override fresh each call, so changing
// the picker takes effect immediately, no relaunch.

enum AppLanguage {
    static let overrideKey = "languageOverride"

    /// The `.lproj` bundle for the chosen language, or nil to follow the system.
    static var overrideBundle: Bundle? {
        let code = UserDefaults.standard.string(forKey: overrideKey) ?? ""
        guard !code.isEmpty,
              let path = Bundle.main.path(forResource: code, ofType: "lproj"),
              let bundle = Bundle(path: path) else { return nil }
        return bundle
    }

    /// Install once at launch. Idempotent.
    static func install() {
        object_setClass(Bundle.main, LanguageAwareBundle.self)
    }
}

/// `Bundle.main` reclassed so localized-string lookups honor the override.
final class LanguageAwareBundle: Bundle, @unchecked Sendable {
    override func localizedString(forKey key: String,
                                  value: String?,
                                  table tableName: String?) -> String {
        if let bundle = AppLanguage.overrideBundle, bundle !== self {
            return bundle.localizedString(forKey: key, value: value, table: tableName)
        }
        return super.localizedString(forKey: key, value: value, table: tableName)
    }
}
