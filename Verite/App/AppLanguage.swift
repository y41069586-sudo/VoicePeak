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
// Fix: both mechanisms key off ONE decision, `resolution(for:)`, which says how
// (or whether) a chosen language can be served — a compiled `.lproj`, the source
// language, or not at all. A language we cannot serve makes BOTH fall back to
// the system together, so a half-translated screen is structurally impossible.

enum AppLanguage {
    static let overrideKey = "languageOverride"

    /// How a chosen language can be served.
    enum Resolution {
        /// No override, or one we cannot serve — follow the device language.
        case system
        /// A compiled `.lproj` exists; resolve strings against it.
        case bundle(Bundle)
        /// The development language (English). A String Catalog keeps the
        /// source language AS THE KEY, so there may be no `en.lproj` at all.
        /// Serving it means returning the key itself — NOT the device
        /// translation, which is what a plain `super` call would hand back.
        case sourceLanguage
    }

    /// Resolve the picker's value. Read fresh on every call, so changing the
    /// picker takes effect immediately with no relaunch.
    static func resolution(for code: String) -> Resolution {
        guard !code.isEmpty else { return .system }
        if let bundle = lprojBundle(for: code) { return .bundle(bundle) }
        if String(code.prefix(2)) == developmentCode { return .sourceLanguage }
        return .system
    }

    /// The override code, but only when we can actually serve that language —
    /// nil means "follow the system". Both override mechanisms key off this, so
    /// the environment locale and the bundle reclass can never disagree.
    ///
    /// Takes the code as a parameter (rather than reading UserDefaults) so the
    /// caller in `VeriteApp` keeps its `@AppStorage` dependency and re-renders
    /// the moment the picker changes.
    static func resolvedCode(for code: String) -> String? {
        if case .system = resolution(for: code) { return nil }
        return code
    }

    /// The current override's resolution, read from UserDefaults.
    static var currentResolution: Resolution {
        resolution(for: UserDefaults.standard.string(forKey: overrideKey) ?? "")
    }

    /// Two-letter code of the bundle's development language (normally "en").
    private static var developmentCode: String {
        String((Bundle.main.developmentLocalization ?? "en").prefix(2))
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
        if short == developmentCode,
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
        switch AppLanguage.currentResolution {
        case .bundle(let bundle) where bundle !== self:
            return bundle.localizedString(forKey: key, value: value, table: tableName)
        case .sourceLanguage:
            // English chosen, no en.lproj to read: the key IS the English
            // string. Falling through to `super` here would return the DEVICE
            // language instead — the exact mismatch this file exists to prevent.
            if let value, !value.isEmpty { return value }
            return key
        case .bundle, .system:
            return super.localizedString(forKey: key, value: value, table: tableName)
        }
    }
}
