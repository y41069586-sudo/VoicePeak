import Foundation

/// Single point of truth for the product name so a rename is a one-line change.
/// "Glowé" is the product name and reads across all five supported languages.
enum Brand {
    static let name = "Glowé"
    /// Bundle identifier root, mirrored in project.yml. Internal identifier —
    /// unrelated to the display name above, so a rebrand leaves it untouched.
    static let bundlePrefix = "com.verite"
}
