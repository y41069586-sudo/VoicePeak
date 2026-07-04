import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// Typography system (DESIGN_SPEC §3). Two fonts: Playfair Display for hero
/// moments + big numerals (≥ 20pt only), SF Pro for everything functional.
///
/// Playfair Display ships as two **variable** TTFs (upright + italic, SIL OFL) in
/// Resources/Fonts/, registered in Info.plist under the family name "Playfair
/// Display". We select weight via the variable `wght` axis (`.weight`) and pick
/// the italic face via `.italic`. If the family isn't available for any reason,
/// every display style falls back to the system serif so nothing shows tofu.
enum VType {
    /// Family name shared by both (upright + italic) variable font files.
    private static let playfair = "Playfair Display"

    private static var hasPlayfair: Bool {
        #if canImport(UIKit)
        return UIFont(name: playfair, size: 12) != nil
        #else
        return false
        #endif
    }

    private static func display(size: CGFloat, italic: Bool, weight: Font.Weight) -> Font {
        if hasPlayfair {
            let face = Font.custom(playfair, size: size).weight(weight)
            return italic ? face.italic() : face
        }
        let base = Font.system(size: size, weight: weight, design: .serif)
        return italic ? base.italic() : base
    }

    // Display — Playfair, hero moments ONLY (never < 20pt, never body/buttons)
    static var heroTitle: Font    { display(size: 34, italic: true, weight: .semibold) }
    static var scoreNumber: Font  { display(size: 56, italic: false, weight: .medium) }
    static var sectionTitle: Font { display(size: 22, italic: true, weight: .medium) }
    /// Scaled display for arbitrary hero sizes (still Playfair/serif).
    static func hero(_ size: CGFloat) -> Font { display(size: max(20, size), italic: true, weight: .semibold) }
    static func number(_ size: CGFloat) -> Font { display(size: max(20, size), italic: false, weight: .medium) }

    // Body — SF Pro
    static let title       = Font.system(size: 20, weight: .semibold)
    static let bodyLarge   = Font.system(size: 17, weight: .regular)
    static let body        = Font.system(size: 15, weight: .regular)
    static let bodyMedium  = Font.system(size: 15, weight: .medium)
    static let caption     = Font.system(size: 13, weight: .regular)
    static let captionBold = Font.system(size: 12, weight: .semibold)
    static let micro       = Font.system(size: 11, weight: .medium) // timestamps, badges
}

extension View {
    /// Uppercase eyebrow label: micro + tracking 1.2 + textSecondary (DESIGN_SPEC §3).
    func vEyebrow() -> some View {
        self.font(VType.micro)
            .tracking(1.2)
            .textCase(.uppercase)
            .foregroundStyle(VColor.textSecondary)
    }
}
