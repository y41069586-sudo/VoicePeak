import SwiftUI

/// Motion tokens (DESIGN_SPEC §7). Never use `.animation(.default)` — always one
/// of these, explicitly. Reduce Motion swaps spring/offset entrances for a 0.2s
/// crossfade (keep the haptics).
enum VMotion {
    static let standard = Animation.spring(response: 0.4, dampingFraction: 0.82)
    static let snappy   = Animation.spring(response: 0.25, dampingFraction: 0.7)
    static let gentle   = Animation.spring(response: 0.6, dampingFraction: 0.9)   // reveals, hero moments
    static let press    = Animation.spring(response: 0.25, dampingFraction: 0.6)  // button press
    static let crossfade = Animation.easeInOut(duration: 0.2)                     // Reduce Motion fallback

    static func resolved(_ base: Animation, reduceMotion: Bool) -> Animation {
        reduceMotion ? crossfade : base
    }
}

/// Staggered fade + rise entrance for list/data appearance (DESIGN_SPEC §7).
/// Index-delayed, capped so long lists don't feel slow.
struct VStaggeredAppear: ViewModifier {
    let index: Int
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shown = false

    func body(content: Content) -> some View {
        content
            .opacity(shown ? 1 : 0)
            .offset(y: shown || reduceMotion ? 0 : 8)
            .onAppear {
                let delay = reduceMotion ? 0 : Double(min(index, 10)) * 0.04
                withAnimation(VMotion.resolved(VMotion.gentle, reduceMotion: reduceMotion).delay(delay)) {
                    shown = true
                }
            }
    }
}

extension View {
    func vStaggeredAppear(index: Int) -> some View { modifier(VStaggeredAppear(index: index)) }
}
