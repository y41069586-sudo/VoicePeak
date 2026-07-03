import Foundation

/// Single point of truth for the product name so a rename is a one-line change.
/// "Vérité" is a working name (French for *truth*) that reads across all five
/// supported languages.
enum Brand {
    static let name = "Vérité"
    /// Bundle identifier root, mirrored in project.yml.
    static let bundlePrefix = "com.verite"
}
