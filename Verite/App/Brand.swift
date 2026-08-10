import Foundation

/// Single point of truth for the product name so a rename is a one-line change.
/// "Glowé" is the shipping brand; the bundle identifier keeps its original
/// `com.verite` root (changing it would invalidate the signing profiles).
enum Brand {
    static let name = "Glowé"
    /// Bundle identifier root, mirrored in project.yml.
    static let bundlePrefix = "com.verite"
}
