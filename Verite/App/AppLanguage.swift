import Foundation
import ObjectiveC.runtime

// ============================================================
// MARK: — In-app language override
// ============================================================
//
// Switching the UI language from inside the app needs TWO mechanisms, because
// the two string APIs resolve differently:
//
//   • `Text("literal")` / `Text(LocalizedStringKey(…))` follows the SwiftUI
//     environment locale, applied in VeriteApp via `.environment(\.locale, …)`.
//   • `String(localized:)` / `NSLocalizedString` resolve against `Bundle.main`
//     using the DEVICE language and ignore that environment entirely. They are
//     reached by reclassing `Bundle.main` (see `LanguageAwareBundle`) so the
//     lookup routes through the chosen language's `.lproj`.
//
// The trap: if only ONE of the two resolves, a screen renders half in the
// chosen language and half in the device language — worse than not translating
// at all. That happened for the English option on a German device: the picker
// set the environment locale to `en` (so `Text` went English) while the bundle
// lookup for `en.lproj` failed and silently fell back to the device language
// (so `String(localized:)` stayed German).
//
// Fix: both mechanisms key off the SINGLE value `resolvedCode(for:)`, which
// returns an override only when a matching bundle actually exists. If it can't
// be resolved, both fall back to the system together — consistent either way.

enum AppLanguage {
    static let overrideKey = "languageOverride"

    /// The override code, but ONLY when a matching compiled `.lproj` exists.
    /// Returns nil to mean "follow the system" — which both the environment
    /// locale and the bundle reclass then do, so they can never disagree.
    ///
    /// Takes the code as a parameter (rather than reading UserDefaults) so the
    /// caller in `VeriteApp` keeps its `@AppStorage` dependency and re-renders
    /// the moment the picker changes.
    static func resolvedCode(for code: String) -> String? {
        guard !code.isEmpty, lprojBundle(for: code) != nil else { return nil }
        return code
    }

    /// The `.lproj` bundle for the chosen language, or nil to follow the system.
    /// Read fresh on every call, so changing the picker takes effect
    /// immediately with no relaunch.
    static var overrideBundle: Bundle? {
        let code = UserDefaults.standard.string(forKey: overrideKey) ?? ""
        guard !code.isEmpty else { return nil }
        return lprojBundle(for: code)
    }

    /// Resolve a language code to its compiled bundle, tolerant of the folder
    /// shapes Xcode actually produces: an exact `de.lproj`, a regional variant
    /// such as `en-US.lproj`, and the development language, which a String
    /// Catalog may compile into `Base.lproj` instead of `en.lproj`.
    private static func lprojBundle(for code: String) -> Bundle? {
        let short = String(code.prefix(2))
        let available = Bundle.main.localizations
        let match = available.first { $0 == code }
            ?? available.first { $0 == short }
            ?? available.first { $0.hasPrefix(short + "-") }

        if let match,
           let path = Bundle.main.path(forResource: match, ofType: "lproj"),
           let bundle = Bundle(path: path) {
            return bundle
        }

        // Development language — its strings can sit in Base.lproj.
        let development = String((Bundle.main.developmentLocalization ?? "").prefix(2))
        if short == development,
           let path = Bundle.main.path(forResource: "Base", ofType: "lproj"),
           let bundle = Bundle(path: path) {
            return bundle
        }
        return nil
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
