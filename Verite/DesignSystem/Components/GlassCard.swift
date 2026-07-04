import SwiftUI

/// The Card (DESIGN_SPEC §6.1): `bgSurface`, radius `md`, 1pt `strokeSubtle`
/// hairline, `md` padding, dual tinted `vCardShadow`. The hairline + lifted
/// shadow are what separate "designed" from "flat". Set `featured` for a 2pt
/// signature accent line at the top edge.
struct GlassCard<Content: View>: View {
    var padding: CGFloat = VSpace.md
    var cornerRadius: CGFloat = VRadius.md
    var featured: Bool = false
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(VColor.bgSurface, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(alignment: .top) {
                if featured {
                    VColor.heroGradient
                        .frame(height: 2)
                        .clipShape(Capsule())
                        .padding(.horizontal, cornerRadius)
                }
            }
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(VColor.strokeSubtle, lineWidth: 1)
            )
            .vCardShadow()
    }
}

/// Tappable card variant with press feedback + a chevron affordance.
struct GlassActionCard<Content: View>: View {
    var cornerRadius: CGFloat = VRadius.md
    let action: () -> Void
    @ViewBuilder var content: () -> Content

    var body: some View {
        Button(action: action) {
            HStack {
                content()
                Spacer(minLength: VSpace.sm)
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(VColor.textTertiary)
            }
            .padding(VSpace.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(VColor.bgSurface, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(VColor.strokeSubtle, lineWidth: 1)
            )
            .vCardShadow()
        }
        .buttonStyle(PressableStyle())
    }
}
