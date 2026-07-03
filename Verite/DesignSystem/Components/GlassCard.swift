import SwiftUI

/// Frosted-glass card (`.ultraThinMaterial`) with a subtle stroke, used over the
/// animated gradient mesh. The building block for nearly every surface in Vérité.
struct GlassCard<Content: View>: View {
    var padding: CGFloat = 18
    var cornerRadius: CGFloat = 22
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(Theme.strokeSubtle, lineWidth: 1)
            )
    }
}

/// A tappable variant that adds press feedback + a chevron affordance.
struct GlassActionCard<Content: View>: View {
    var cornerRadius: CGFloat = 22
    let action: () -> Void
    @ViewBuilder var content: () -> Content

    var body: some View {
        Button(action: action) {
            HStack {
                content()
                Spacer(minLength: 8)
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Theme.textSecondary)
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(Theme.strokeSubtle, lineWidth: 1)
            )
        }
        .buttonStyle(PressableStyle())
    }
}
