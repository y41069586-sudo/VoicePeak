import SwiftUI

/// A premium drag-to-reveal before/after comparison view for the half-face simulation.
///
/// - Left side: original scan image.
/// - Right side: cosmetic simulation from `SimulationEngine`.
/// - A drag handle the user slides left/right to reveal more or less of each side.
///
/// On appear the handle sweeps from 0 → 0.5 to demonstrate the feature.
struct HalfFaceSimulationView: View {
    let original: UIImage
    let simulation: UIImage

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var dividerFraction: CGFloat = 0.50
    @State private var isDragging = false
    @State private var appeared = false

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                // 1. Simulation (right / "after") — full width, clipped on left.
                Image(uiImage: simulation)
                    .resizable()
                    .scaledToFill()
                    .frame(width: geo.size.width, height: geo.size.height)
                    .clipped()

                // 2. Original (left / "before") — clipped to divider position.
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
            Label("Before", systemImage: "circle.lefthalf.filled")
                .font(VType.captionBold)
                .foregroundStyle(.white)
                .padding(.horizontal, 12).padding(.vertical, 6)
                .background(.ultraThinMaterial, in: Capsule())

            Spacer()

            Label("After", systemImage: "sparkles")
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

// MARK: - Wrapper with async simulation loading

/// Convenience wrapper that loads the simulation asynchronously and shows a
/// placeholder during processing.
struct HalfFaceSimulationLoader: View {
    let original: UIImage
    let side: FaceSide
    let intensity: Double
    let midlineX: Double?

    @State private var simulation: UIImage?
    @State private var isLoading = true

    var body: some View {
        ZStack {
            if let sim = simulation {
                HalfFaceSimulationView(original: original, simulation: sim)
                    .transition(.opacity)
            } else {
                simulationPlaceholder
            }
        }
        .animation(.easeInOut(duration: 0.4), value: simulation != nil)
        .task { await loadSimulation() }
    }

    private var simulationPlaceholder: some View {
        ZStack {
            Image(uiImage: original)
                .resizable()
                .scaledToFill()
                .overlay(Color.black.opacity(0.35))

            VStack(spacing: 12) {
                ProgressView()
                    .tint(.white)
                    .scaleEffect(1.2)
                Text("Generating preview…")
                    .font(VType.body)
                    .foregroundStyle(.white.opacity(0.8))
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private func loadSimulation() async {
        let result = await SimulationEngine.simulate(
            image: original,
            side: side,
            intensity: intensity,
            midlineX: midlineX
        )
        simulation = result ?? original
        isLoading = false
    }
}
