import SwiftUI
import UIKit

// ============================================================
// MARK: — Screen 5: The Potential Reveal
// ============================================================

/// The emotional peak: current photo vs the generated 10/10 Potential image
/// with a draggable divider. The Potential render started back in Screen 3;
/// until it lands, the right side shimmers: "Rendering your potential…".
struct DermiqPotentialView: View {
    let model: ScanFlowModel
    let onContinue: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 6) {
                Text("You at 100.")
                    .font(DQFont.title)
                    .foregroundStyle(DQColor.textPrimary)
                Text("This is your skin's ceiling. The next 14 days close the gap.")
                    .font(DQFont.body)
                    .foregroundStyle(DQColor.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 28)
            .padding(.top, 24)

            Spacer()

            if let current = model.capturedImage {
                DQBeforeAfterSlider(before: current, after: model.potentialImage)
                    .frame(maxHeight: 470)
                    .padding(.horizontal, 24)
            }

            Spacer()

            VStack(spacing: 12) {
                if let current = model.capturedImage,
                   let potential = model.potentialImage,
                   let overall = model.analysis?.overall {
                    DQShareButton(current: current, potential: potential, overall: overall)
                }
                DQPrimaryButton(title: "Get my 14-day plan") { onContinue() }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 30)
        }
        .background(DQBackdrop())
    }
}

// ============================================================
// MARK: — Before/after slider
// ============================================================

struct DQBeforeAfterSlider: View {
    let before: UIImage
    let after: UIImage?

    /// Divider position, 0...1 across the width.
    @State private var split: CGFloat = 0.5

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            ZStack {
                photo(before, size: size)

                if let after {
                    photo(after, size: size)
                        .mask(alignment: .trailing) {
                            Rectangle().frame(width: size.width * (1 - split))
                        }
                } else {
                    renderingPlaceholder(size: size)
                        .mask(alignment: .trailing) {
                            Rectangle().frame(width: size.width * (1 - split))
                        }
                }

                divider(size: size)
                labels(size: size)
            }
            .clipShape(RoundedRectangle(cornerRadius: DQRadius.card, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: DQRadius.card, style: .continuous)
                    .strokeBorder(DQColor.stroke, lineWidth: 1)
            )
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        split = min(max(value.location.x / size.width, 0.08), 0.92)
                    }
            )
        }
    }

    private func photo(_ image: UIImage, size: CGSize) -> some View {
        Image(uiImage: image)
            .resizable()
            .scaledToFill()
            .frame(width: size.width, height: size.height)
            .clipped()
    }

    private func divider(size: CGSize) -> some View {
        ZStack {
            Rectangle()
                .fill(DQColor.textPrimary)
                .frame(width: 2)
                .shadow(color: DQColor.accent.opacity(0.8), radius: 6)
            Circle()
                .fill(DQColor.surfaceElevated)
                .frame(width: 34, height: 34)
                .overlay(Circle().strokeBorder(DQColor.textPrimary.opacity(0.6), lineWidth: 1))
                .overlay(
                    Image(systemName: "arrow.left.and.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(DQColor.textPrimary)
                )
        }
        .frame(height: size.height)
        .position(x: size.width * split, y: size.height / 2)
    }

    private func labels(size: CGSize) -> some View {
        VStack {
            Spacer()
            HStack {
                tag("NOW")
                Spacer()
                tag(after == nil ? "RENDERING" : "POTENTIAL", accent: true)
            }
            .padding(12)
        }
        .frame(width: size.width, height: size.height)
    }

    private func tag(_ text: String, accent: Bool = false) -> some View {
        Text(text)
            .font(DQFont.mono(10, weight: .bold))
            .tracking(1.5)
            .foregroundStyle(accent ? DQColor.accentBright : DQColor.textSecondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(DQColor.background.opacity(0.72), in: Capsule())
    }

    private func renderingPlaceholder(size: CGSize) -> some View {
        ZStack {
            photo(before, size: size)
                .saturation(0.4)
                .overlay(DQColor.background.opacity(0.55))
            VStack(spacing: 10) {
                Image(systemName: "sparkles")
                    .font(.system(size: 26, weight: .light))
                    .foregroundStyle(DQColor.accentBright)
                Text("Rendering your potential…")
                    .font(DQFont.mono(12))
                    .foregroundStyle(DQColor.textPrimary)
            }
        }
        .dqShimmer()
    }
}

// ============================================================
// MARK: — Share card (the viral asset)
// ============================================================

struct DQShareButton: View {
    let current: UIImage
    let potential: UIImage
    let overall: Int

    @State private var rendered: Image?

    var body: some View {
        Group {
            if let rendered {
                ShareLink(
                    item: rendered,
                    preview: SharePreview("My Vérité score", image: rendered)
                ) {
                    shareLabel
                }
            } else {
                shareLabel.opacity(0.4)
            }
        }
        .task { await render() }
    }

    private var shareLabel: some View {
        HStack(spacing: 8) {
            Image(systemName: "square.and.arrow.up")
            Text("Share")
        }
        .font(DQFont.headline)
        .foregroundStyle(DQColor.textPrimary)
        .frame(maxWidth: .infinity, minHeight: 50)
        .background(DQColor.surfaceElevated, in: Capsule())
        .overlay(Capsule().strokeBorder(DQColor.stroke, lineWidth: 1))
    }

    @MainActor
    private func render() async {
        let renderer = ImageRenderer(
            content: DQShareCard(current: current, potential: potential, overall: overall)
        )
        renderer.scale = 3
        if let image = renderer.uiImage {
            rendered = Image(uiImage: image)
        }
    }
}

/// The rendered share asset: split image + score + wordmark. Premium, dark.
struct DQShareCard: View {
    let current: UIImage
    let potential: UIImage
    let overall: Int

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 2) {
                sharePhoto(current, label: "NOW")
                sharePhoto(potential, label: "POTENTIAL")
            }
            .frame(height: 340)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 1) {
                    Text("SKIN SCORE")
                        .font(DQFont.mono(9, weight: .semibold))
                        .foregroundStyle(DQColor.textSecondary)
                        .tracking(2)
                    Text(verbatim: "\(overall)")
                        .font(DQFont.score(40))
                        .foregroundStyle(DQColor.textPrimary)
                }
                Spacer()
                Text("VÉRITÉ")
                    .font(.system(size: 17, weight: .semibold, design: .monospaced))
                    .tracking(5)
                    .foregroundStyle(DQColor.textPrimary)
            }
            .padding(.horizontal, 4)
            .padding(.top, 14)
        }
        .padding(18)
        .frame(width: 340)
        .background(DQColor.background)
    }

    private func sharePhoto(_ image: UIImage, label: String) -> some View {
        Image(uiImage: image)
            .resizable()
            .scaledToFill()
            .frame(width: 150, height: 340)
            .clipped()
            .overlay(alignment: .bottom) {
                Text(label)
                    .font(DQFont.mono(9, weight: .bold))
                    .tracking(1.5)
                    .foregroundStyle(DQColor.textPrimary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(DQColor.background.opacity(0.7), in: Capsule())
                    .padding(.bottom, 10)
            }
    }
}
