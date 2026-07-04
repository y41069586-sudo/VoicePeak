import CoreGraphics

/// Spacing grid (DESIGN_SPEC §4). Never use raw numbers in view code — always these.
enum VSpace {
    static let xs: CGFloat = 4
    static let sm: CGFloat = 8
    static let md: CGFloat = 16
    static let lg: CGFloat = 24
    static let xl: CGFloat = 32
    static let xxl: CGFloat = 48
}

/// Corner radii (DESIGN_SPEC §4).
enum VRadius {
    static let sm: CGFloat = 12    // chips, tags
    static let md: CGFloat = 20    // standard cards
    static let lg: CGFloat = 28    // hero cards, sheets
    static let full: CGFloat = 999 // pills, buttons
}
