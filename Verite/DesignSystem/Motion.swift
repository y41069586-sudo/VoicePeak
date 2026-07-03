import SwiftUI

/// Centralized motion language. Every animation runs off precomputed values;
/// nothing heavy happens during animation frames. Respect Reduce Motion via
/// `Motion.animation(reduceMotion:)` so the app degrades to calm crossfades.
enum Motion {

    /// The house spring — used for the vast majority of transitions.
    static let spring: Animation = .spring(response: 0.4, dampingFraction: 0.82)

    /// Slightly softer spring for large elements (cards, sheets).
    static let springSoft: Animation = .spring(response: 0.55, dampingFraction: 0.9)

    /// Snappy spring for taps / toggles.
    static let springSnappy: Animation = .spring(response: 0.28, dampingFraction: 0.78)

    /// Gentle crossfade fallback when Reduce Motion is on.
    static let crossfade: Animation = .easeInOut(duration: 0.25)

    /// Pick the right animation given the user's Reduce Motion setting.
    static func animation(reduceMotion: Bool, _ base: Animation = spring) -> Animation {
        reduceMotion ? crossfade : base
    }
}

extension View {
    /// Apply the house spring, automatically honoring Reduce Motion.
    /// Usage: `.veriteAnimation(value: someState)`
    func veriteAnimation<V: Equatable>(_ base: Animation = Motion.spring, value: V) -> some View {
        modifier(VeriteAnimationModifier(base: base, value: value))
    }
}

private struct VeriteAnimationModifier<V: Equatable>: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let base: Animation
    let value: V

    func body(content: Content) -> some View {
        content.animation(Motion.animation(reduceMotion: reduceMotion, base), value: value)
    }
}
