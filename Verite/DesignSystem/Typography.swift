import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// Two-font system: an elegant editorial serif for hero moments + big numbers,
/// SF Pro for everything functional. See docs/DESIGN_SPEC.md.
///
/// The display font (Playfair Display Italic, SIL OFL) is **not bundled** in the
/// repo — licensing lives with the shipping developer (see SETUP.md). Until the
/// font file is dropped into Resources/Fonts and registered in Info.plist, all
/// display styles fall back to the system serif so the app never shows tofu and
/// never sacrifices legibility.
enum Typography {

    /// PostScript name of the bundled display face. Change here if you bundle a
    /// different OFL face (e.g. "Cormorant-Italic", "Marcellus-Regular").
    static let displayFontName = "PlayfairDisplay-Italic"

    /// Whether the custom display font is actually registered on this device.
    static let displayFontAvailable: Bool = {
        #if canImport(UIKit)
        return UIFont(name: displayFontName, size: 12) != nil
        #else
        return false
        #endif
    }()

    /// Display / script-accented style for headlines and hero numbers only.
    /// Falls back to an italic system serif when the custom font isn't present.
    static func display(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        if displayFontAvailable {
            return .custom(displayFontName, size: size)
        } else {
            return .system(size: size, weight: weight, design: .serif).italic()
        }
    }

    // MARK: Functional (SF Pro)
    static func title(_ size: CGFloat = 28) -> Font { .system(size: size, weight: .bold) }
    static func headline() -> Font { .system(.headline, design: .default) }
    static func body() -> Font { .system(.body, design: .default) }
    static func caption() -> Font { .system(.caption, design: .default) }

    /// Big numeric readouts (scores, %, day counters) — tabular figures.
    static func number(_ size: CGFloat, weight: Font.Weight = .semibold) -> Font {
        .system(size: size, weight: weight, design: .rounded).monospacedDigit()
    }
}

extension Text {
    /// Convenience for hero/section headlines in the display face.
    func displayStyle(_ size: CGFloat = 34) -> Text {
        self.font(Typography.display(size))
    }
}
