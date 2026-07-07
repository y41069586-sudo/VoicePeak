import SwiftUI

/// A drag-to-reveal comparison of two **real** scans of the treated side:
/// the Day-0 baseline (left / "before") and the most recent scan (right /
/// "after"). No predicted or generated imagery — both frames are the user's own
/// photos, so the comparison is honest, per the app's "no fake after" invariant.
///
/// On appear the handle sweeps toward the left to reveal both sides.
struct HalfFaceSimulationView: View {
    let original: UIImage
    let after: UIImage

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var dividerFraction: CGFloat = 0.50
    @State private var isDragging = false
    @State private var appeared = false

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                // 1. Latest real scan (right / "after") — full width, clipped on left.
                Image(uiImage: after)
                    .resizable()
                    .scaledToFill()
                    .frame(width: geo.size.width, height: geo.size.height)
                    .clipped()

                // 2. Baseline scan (left / "before") — clipped to divider position.
                Image(uiImage: original)
                    .resizable()
                    .scaledToFill()
                    .frame(width: geo.size.width, height: geo.size.height)
                    .clipped()
                    .mask(
                        Rectangle()
                            .frame(width: geo.size.width * dividerFraction)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    )

                // 3. Divider line + handle.
                dividerView(geo: geo)
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .contentShape(Rectangle())
            .gesture(dragGesture(in: geo))
        }
        .onAppear { runIntroAnimation() }
        .overlay(alignment: .bottom) { labels }
    }

    // MARK: Divider

    private func dividerView(geo: GeometryProxy) -> some View {
        let x = geo.size.width * dividerFraction

        return ZStack {
            // Soft glow line.
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [Theme.accent.opacity(0.0), Theme.accent, Theme.accent.opacity(0.0)],
                        startPoint: .top, endPoint: .bottom
                    )
                )
                .frame(width: 2)
                .shadow(color: Theme.accent.opacity(0.6), radius: 6)

            // Draggable circle handle.
            ZStack {
                Circle()
                    .fill(.ultraThinMaterial)
                    .overlay(Circle().strokeBorder(Theme.accent.opacity(0.7), lineWidth: 1.5))
                    .shadow(color: .black.opacity(0.25), radius: 6, y: 2)
                    .frame(width: 44, height: 44)

                // Chevron icons.
                HStack(spacing: 3) {
                    Image(systemName: "chevron.left").font(.caption2.weight(.bold))
                    Image(systemName: "chevron.right").font(.caption2.weight(.bold))
                }
                .foregroundStyle(Theme.accent)
            }
            .scaleEffect(isDragging ? 1.12 : 1.0)
            .animation(Motion.springSnappy, value: isDragging)
        }
        .frame(width: 44)
        .frame(maxHeight: .infinity)
        .position(x: x, y: 0)
        .frame(maxHeight: .infinity, alignment: .center)
    }

    // MARK: Labels

    private var labels: some View {
        HStack {
            Label("halfface.compare.before", systemImage: "clock")
                .font(VType.captionBold)
                .foregroundStyle(.white)
                .padding(.horizontal, 12).padding(.vertical, 6)
                .background(.ultraThinMaterial, in: Capsule())

            Spacer()

            Label("halfface.compare.after", systemImage: "clock.badge.checkmark")
                .font(VType.captionBold)
                .foregroundStyle(.white)
                .padding(.horizontal, 12).padding(.vertical, 6)
                .background(.ultraThinMaterial, in: Capsule())
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 16)
    }

    // MARK: Gesture

    private func dragGesture(in geo: GeometryProxy) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                isDragging = true
                let fraction = value.location.x / geo.size.width
                dividerFraction = min(0.92, max(0.08, fraction))
            }
            .onEnded { _ in
                isDragging = false
                Haptics.fire(.selection)
            }
    }

    // MARK: Intro animation

    private func runIntroAnimation() {
        guard !appeared else { return }
        appeared = true
        guard !reduceMotion else { return }

        // Sweep from centre → left → centre to show both sides.
        dividerFraction = 0.50
        withAnimation(.easeInOut(duration: 0.9).delay(0.3)) {
            dividerFraction = 0.18
        }
        withAnimation(.spring(response: 0.8, dampingFraction: 0.75).delay(1.3)) {
            dividerFraction = 0.50
        }
    }
}
