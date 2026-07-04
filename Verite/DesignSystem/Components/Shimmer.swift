import SwiftUI

/// Skeleton placeholder (DESIGN_SPEC loaders): a token-filled rounded block with a
/// soft highlight sweeping across it. Reduce-Motion collapses it to a static fill.
/// Prefer this over a bare `ProgressView` for content that will fill in shortly.
struct SkeletonBlock: View {
    var cornerRadius: CGFloat = VRadius.sm
    var height: CGFloat? = nil

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var phase: CGFloat = -1

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(VColor.bgElevated2)
            .frame(height: height)
            .overlay {
                if !reduceMotion {
                    GeometryReader { geo in
                        LinearGradient(colors: [.clear, VColor.bgSurface.opacity(0.75), .clear],
                                       startPoint: .leading, endPoint: .trailing)
                            .frame(width: geo.size.width * 0.55)
                            .offset(x: phase * geo.size.width * 1.6)
                    }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(.linear(duration: 1.1).repeatForever(autoreverses: false)) { phase = 1 }
            }
            .accessibilityHidden(true)
    }
}

/// A thumbnail-plus-two-lines skeleton row, matching a typical list item.
struct SkeletonRow: View {
    var body: some View {
        HStack(spacing: VSpace.sm) {
            SkeletonBlock(cornerRadius: VRadius.sm)
                .frame(width: 48, height: 48)
            VStack(alignment: .leading, spacing: VSpace.xs) {
                SkeletonBlock(cornerRadius: VRadius.sm, height: 12).frame(maxWidth: 120)
                SkeletonBlock(cornerRadius: VRadius.sm, height: 12).frame(maxWidth: .infinity)
            }
        }
        .padding(.vertical, VSpace.xs)
    }
}
