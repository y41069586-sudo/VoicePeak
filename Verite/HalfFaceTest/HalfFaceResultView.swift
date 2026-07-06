import SwiftUI
import UIKit

/// Full-screen split-face result shown after a half-face test capture.
/// Left half = treated side (product applied), right half = control side (untreated).
/// A draggable divider lets the user scrub between the two halves.
/// Per-side attribute scores are overlaid on each half.
struct HalfFaceResultView: View {
    let image: UIImage
    let testSide: FaceSide          // which side has the product
    let sideAnalysis: SideAnalysis
    let onDone: () -> Void

    @State private var dividerX: CGFloat = 0.5   // 0...1, normalised
    @State private var appeared = false
    @Environment(\.dismiss) private var dismiss

    // Pre-split the image into two cropped halves.
    private var leftHalf: UIImage  { image.croppedLeft() }
    private var rightHalf: UIImage { image.croppedRight() }

    private var treatedIsLeft: Bool { testSide == .left }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            GeometryReader { geo in
                let w = geo.size.width
                let h = geo.size.height
                let splitX = w * dividerX

                // ── Background: right half fills whole frame ──
                Image(uiImage: rightHalf)
                    .resizable()
                    .scaledToFill()
                    .frame(width: w, height: h)
                    .clipped()

                // ── Foreground: left half clipped to left of divider ──
                Image(uiImage: leftHalf)
                    .resizable()
                    .scaledToFill()
                    .frame(width: w, height: h)
                    .clipped()
                    .mask(alignment: .leading) {
                        Rectangle()
                            .frame(width: splitX, height: h)
                    }

                // ── Divider line ──
                Rectangle()
                    .fill(Color.white.opacity(0.85))
                    .frame(width: 2, height: h)
                    .position(x: splitX, y: h / 2)
                    .shadow(color: .black.opacity(0.4), radius: 4)

                // ── Drag handle ──
                Circle()
                    .fill(.ultraThinMaterial)
                    .overlay(Circle().strokeBorder(.white.opacity(0.6), lineWidth: 1.5))
                    .overlay(
                        Image(systemName: "arrow.left.and.right")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.white)
                    )
                    .frame(width: 44, height: 44)
                    .position(x: splitX, y: h / 2)
                    .shadow(radius: 8)
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                let newX = (value.location.x / w).clamped(to: 0.08...0.92)
                                dividerX = newX
                            }
                    )

                // ── Side labels ──
                sideLabel(
                    title: treatedIsLeft ? "Treated" : "Control",
                    subtitle: treatedIsLeft ? "With product" : "No product",
                    color: treatedIsLeft ? Theme.primary : Theme.textSecondary,
                    scores: sideAnalysis.scores(for: treatedIsLeft ? testSide : testSide.opposite),
                    alignment: .leading,
                    geo: geo,
                    splitX: splitX
                )

                sideLabel(
                    title: treatedIsLeft ? "Control" : "Treated",
                    subtitle: treatedIsLeft ? "No product" : "With product",
                    color: treatedIsLeft ? Theme.textSecondary : Theme.primary,
                    scores: sideAnalysis.scores(for: treatedIsLeft ? testSide.opposite : testSide),
                    alignment: .trailing,
                    geo: geo,
                    splitX: splitX
                )
            }
            .ignoresSafeArea()

            // ── Top bar ──
            VStack {
                HStack {
                    Button { dismiss(); onDone() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.white.opacity(0.85))
                            .padding()
                    }
                    Spacer()
                    Text("Half-Face Comparison")
                        .font(VType.bodyMedium.weight(.semibold))
                        .foregroundStyle(.white)
                    Spacer()
                    // Balance the X button
                    Color.clear.frame(width: 56, height: 56)
                }
                .background(.ultraThinMaterial.opacity(0.7))
                Spacer()

                // ── Bottom hint ──
                Text("Drag the divider to compare sides")
                    .font(VType.caption)
                    .foregroundStyle(.white.opacity(0.8))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(.black.opacity(0.5), in: Capsule())
                    .padding(.bottom, 36)
                    .opacity(appeared ? 1 : 0)
                    .animation(.easeIn(duration: 0.5).delay(0.8), value: appeared)
            }
        }
        .onAppear {
            dividerX = 0.5
            appeared = true
        }
    }

    // MARK: – Side score overlay

    @ViewBuilder
    private func sideLabel(
        title: String,
        subtitle: String,
        color: Color,
        scores: [String: Double],
        alignment: HorizontalAlignment,
        geo: GeometryProxy,
        splitX: CGFloat
    ) -> some View {
        let isLeft = alignment == .leading
        let panelWidth = isLeft ? splitX : geo.size.width - splitX
        // Only show label if panel is wide enough
        if panelWidth > 80 {
            VStack(alignment: alignment, spacing: 4) {
                Spacer().frame(height: 80)
                Text(title)
                    .font(VType.captionBold)
                    .foregroundStyle(.white)
                Text(subtitle)
                    .font(VType.micro)
                    .foregroundStyle(.white.opacity(0.7))
                Spacer()
                // Top 3 attribute scores
                VStack(alignment: alignment, spacing: 6) {
                    ForEach(topAttributes(scores), id: \.key) { pair in
                        attributeChip(label: pair.key, value: pair.value, alignment: alignment)
                    }
                }
                .padding(.bottom, 90)
            }
            .padding(.horizontal, 12)
            .frame(width: panelWidth, height: geo.size.height,
                   alignment: isLeft ? .topLeading : .topTrailing)
            .position(x: isLeft ? splitX / 2 : splitX + (geo.size.width - splitX) / 2,
                      y: geo.size.height / 2)
        }
    }

    private func topAttributes(_ scores: [String: Double]) -> [(key: String, value: Double)] {
        scores
            .sorted { $0.value > $1.value }
            .prefix(3)
            .map { (key: $0.key.capitalized, value: $0.value) }
    }

    @ViewBuilder
    private func attributeChip(label: String, value: Double, alignment: HorizontalAlignment) -> some View {
        HStack(spacing: 6) {
            if alignment == .trailing {
                Text(String(format: "%.0f%%", value * 100))
                    .font(Typography.number(12))
                    .foregroundStyle(.white)
            }
            Text(label)
                .font(VType.micro)
                .foregroundStyle(.white.opacity(0.85))
            if alignment == .leading {
                Text(String(format: "%.0f%%", value * 100))
                    .font(Typography.number(12))
                    .foregroundStyle(.white)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(.black.opacity(0.45), in: Capsule())
    }
}

// MARK: – UIImage crop helpers

private extension UIImage {
    /// Returns the left half of the image.
    func croppedLeft() -> UIImage {
        let halfW = size.width / 2
        let rect = CGRect(x: 0, y: 0, width: halfW, height: size.height)
        guard let cg = cgImage?.cropping(to: rect.scaled(by: scale)) else { return self }
        return UIImage(cgImage: cg, scale: scale, orientation: imageOrientation)
    }

    /// Returns the right half of the image.
    func croppedRight() -> UIImage {
        let halfW = size.width / 2
        let rect = CGRect(x: halfW, y: 0, width: halfW, height: size.height)
        guard let cg = cgImage?.cropping(to: rect.scaled(by: scale)) else { return self }
        return UIImage(cgImage: cg, scale: scale, orientation: imageOrientation)
    }
}

private extension CGRect {
    func scaled(by scale: CGFloat) -> CGRect {
        CGRect(x: origin.x * scale, y: origin.y * scale,
               width: width * scale, height: height * scale)
    }
}

// MARK: – Clamp helper (if not already global)

private extension CGFloat {
    func clamped(to range: ClosedRange<CGFloat>) -> CGFloat {
        Swift.max(range.lowerBound, Swift.min(range.upperBound, self))
    }
}
