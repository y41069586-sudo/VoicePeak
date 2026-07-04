import SwiftUI

/// Back-compat alias for the living gradient mesh. New code should use
/// `VBackground` directly (DESIGN_SPEC §5); existing `.background(GradientMeshBackground())`
/// call sites route here so every screen gets the atmospheric background.
struct GradientMeshBackground: View {
    var body: some View { VBackground() }
}

#Preview {
    GradientMeshBackground()
}
