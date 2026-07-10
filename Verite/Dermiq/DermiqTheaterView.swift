import SwiftUI
import Vision
import UIKit

// ============================================================
// MARK: — Screen 3: Analysis Sequence (the theater)
// ============================================================

/// 6–8 staged seconds that sell the app. No spinner anywhere. If the engine is
/// slower than the animation the status-label stage loops gracefully; if it's
/// faster, the full sequence still plays — the duration is intentional.
struct DermiqTheaterView: View {
    let model: ScanFlowModel
    let onDone: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var photoVisible = false
    @State private var clinical = false          // desaturated treatment
    @State private var sweepProgress: CGFloat = -0.15
    @State private var sweepVisible = false
    @State private var mesh: FaceMesh = .empty
    @State private var pointsVisible = false
    @State private var linesVisible = false
    @State private var collapsed = false
    @State private var statusLabel = ""

    // Honest, self-referential steps only — no invented corpus sizes (2.3.1).
    // The lifestyle line ties the scan back to the onboarding answers.
    private let statusLabels = [
        "Mapping texture…",
        "Measuring redness…",
        "Analyzing pore density…",
        "Weighing your lifestyle answers…",
    ]

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                DQBackdrop()

                if let image = model.capturedImage {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: proxy.size.width, height: proxy.size.height)
                        .clipped()
                        .saturation(clinical ? 0.55 : 1)
                        .opacity(photoVisible ? (clinical ? 0.85 : 1) : 0)
                        .ignoresSafeArea()

                    meshLayer(size: proxy.size, imageSize: image.size)

                    if sweepVisible {
                        scanLine(size: proxy.size)
                    }
                }

                statusOverlay
            }
        }
        .ignoresSafeArea()
        .task { await run() }
    }

    // MARK: Scan line (thin bright line + trailing gradient)

    private func scanLine(size: CGSize) -> some View {
        VStack(spacing: 0) {
            LinearGradient(
                colors: [.clear, DQColor.accent.opacity(0.35)],
                startPoint: .top, endPoint: .bottom
            )
            .frame(height: 90)
            Rectangle()
                .fill(DQColor.accentBright)
                .frame(height: 2)
                .shadow(color: DQColor.accent, radius: 8)
        }
        .frame(width: size.width)
        .position(x: size.width / 2, y: size.height * sweepProgress)
        .allowsHitTesting(false)
    }

    // MARK: Mesh layer

    private func meshLayer(size: CGSize, imageSize: CGSize) -> some View {
        Canvas { context, _ in
            guard pointsVisible, !mesh.points.isEmpty else { return }
            let mapped = mesh.points.map { map($0, imageSize: imageSize, viewSize: size) }

            if linesVisible {
                var path = Path()
                for (a, b) in mesh.edges {
                    path.move(to: mapped[a])
                    path.addLine(to: mapped[b])
                }
                context.stroke(path, with: .color(DQColor.accent.opacity(0.35)), lineWidth: 0.6)
            }
            for point in mapped {
                let dot = CGRect(x: point.x - 1.3, y: point.y - 1.3, width: 2.6, height: 2.6)
                context.fill(Path(ellipseIn: dot), with: .color(DQColor.accentBright.opacity(0.9)))
            }
        }
        .opacity(pointsVisible ? (collapsed ? 0 : 1) : 0)
        .scaleEffect(collapsed ? 0.005 : 1, anchor: mesh.anchor)
        .animation(.easeIn(duration: 0.5), value: collapsed)
        .animation(.easeInOut(duration: 0.8), value: pointsVisible)
        .animation(.easeInOut(duration: 0.8), value: linesVisible)
        .allowsHitTesting(false)
    }

    /// Maps a normalized (0–1, y-down) image point through the aspect-fill crop.
    private func map(_ point: CGPoint, imageSize: CGSize, viewSize: CGSize) -> CGPoint {
        guard imageSize.width > 0, imageSize.height > 0 else { return .zero }
        let scale = max(viewSize.width / imageSize.width, viewSize.height / imageSize.height)
        let displayed = CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
        let origin = CGPoint(
            x: (viewSize.width - displayed.width) / 2,
            y: (viewSize.height - displayed.height) / 2
        )
        return CGPoint(
            x: origin.x + point.x * displayed.width,
            y: origin.y + point.y * displayed.height
        )
    }

    // MARK: Status labels

    private var statusOverlay: some View {
        VStack {
            Spacer()
            Text(statusLabel)
                .font(DQFont.mono(14))
                .foregroundStyle(DQColor.textPrimary)
                .padding(.horizontal, 18)
                .padding(.vertical, 10)
                .background(DQColor.surface.opacity(0.82), in: Capsule())
                .opacity(statusLabel.isEmpty ? 0 : 1)
                .id(statusLabel)
                .transition(.opacity)
                .animation(VMotion.crossfade, value: statusLabel)
                .padding(.bottom, 110)
        }
    }

    // MARK: Sequence

    private func run() async {
        guard let image = model.capturedImage else { onDone(); return }

        // Stage 1 — photo appears
        withAnimation(.easeOut(duration: 0.3)) { photoVisible = true }
        async let meshTask = FaceMesh.detect(in: image)
        try? await Task.sleep(for: .milliseconds(450))

        if reduceMotion {
            // Reduced sequence: clinical treatment + labels, no sweeps/mesh motion.
            clinical = true
            mesh = await meshTask
            pointsVisible = true; linesVisible = true
            await cycleLabels(minimumCycles: 2)
            onDone()
            return
        }

        // Stage 2 — two sweeps + clinical desaturation
        Haptics.fire(.transition)
        sweepVisible = true
        withAnimation(.easeInOut(duration: 1.0)) { clinical = true }
        for _ in 0..<2 {
            sweepProgress = -0.12
            withAnimation(.easeInOut(duration: 1.05)) { sweepProgress = 1.1 }
            try? await Task.sleep(for: .milliseconds(1100))
        }
        sweepVisible = false

        // Stage 3 — landmark points, then connecting lines
        Haptics.fire(.transition)
        mesh = await meshTask
        pointsVisible = true
        try? await Task.sleep(for: .milliseconds(700))
        linesVisible = true
        try? await Task.sleep(for: .milliseconds(700))

        // Stage 4 — status labels (~1s each); loops while the engine is slow
        Haptics.fire(.transition)
        await cycleLabels(minimumCycles: 1)

        // Stage 5 — mesh collapses into a single point → cut to results
        Haptics.fire(.transition)
        statusLabel = ""
        collapsed = true
        try? await Task.sleep(for: .milliseconds(560))
        onDone()
    }

    /// Shows each label ~1s; keeps looping until the analysis has landed.
    private func cycleLabels(minimumCycles: Int) async {
        var index = 0
        var shown = 0
        let minimum = statusLabels.count * minimumCycles
        while (shown < minimum || model.analysis == nil), !Task.isCancelled {
            statusLabel = statusLabels[index % statusLabels.count]
            index += 1
            shown += 1
            try? await Task.sleep(for: .milliseconds(950))
        }
    }
}

// ============================================================
// MARK: — Face mesh extraction (Vision)
// ============================================================

/// Landmark points (normalized, y-down) + nearest-neighbor edges.
struct FaceMesh: Sendable {
    let points: [CGPoint]
    let edges: [(Int, Int)]
    /// Collapse anchor — the mesh centroid in unit coordinates.
    let anchor: UnitPoint

    static let empty = FaceMesh(points: [], edges: [], anchor: .center)

    static func detect(in image: UIImage) async -> FaceMesh {
        await Task.detached(priority: .userInitiated) {
            guard let cgImage = image.cgImage else { return .empty }
            let request = VNDetectFaceLandmarksRequest()
            let handler = VNImageRequestHandler(
                cgImage: cgImage,
                orientation: CGImagePropertyOrientation(image.imageOrientation),
                options: [:]
            )
            try? handler.perform([request])

            guard let face = request.results?.max(by: { $0.boundingBox.height < $1.boundingBox.height }),
                  let all = face.landmarks?.allPoints else {
                return .empty
            }

            let box = face.boundingBox // Vision: origin bottom-left
            let points: [CGPoint] = all.normalizedPoints.map { p in
                CGPoint(
                    x: box.minX + CGFloat(p.x) * box.width,
                    y: 1 - (box.minY + CGFloat(p.y) * box.height) // flip to y-down
                )
            }
            return FaceMesh(points: points, edges: edges(for: points), anchor: centroid(of: points))
        }.value
    }

    /// Connect each point to its 2 nearest neighbors (n ≈ 80 → trivial O(n²)).
    private static func edges(for points: [CGPoint]) -> [(Int, Int)] {
        var result: [(Int, Int)] = []
        var seen = Set<Int>()
        for i in points.indices {
            let nearest = points.indices
                .filter { $0 != i }
                .sorted {
                    hypot(points[$0].x - points[i].x, points[$0].y - points[i].y)
                    < hypot(points[$1].x - points[i].x, points[$1].y - points[i].y)
                }
                .prefix(2)
            for j in nearest {
                let key = i < j ? i * 10_000 + j : j * 10_000 + i
                if seen.insert(key).inserted {
                    result.append((min(i, j), max(i, j)))
                }
            }
        }
        return result
    }

    private static func centroid(of points: [CGPoint]) -> UnitPoint {
        guard !points.isEmpty else { return .center }
        let x = points.map(\.x).reduce(0, +) / CGFloat(points.count)
        let y = points.map(\.y).reduce(0, +) / CGFloat(points.count)
        return UnitPoint(x: x, y: y)
    }
}

private extension CGImagePropertyOrientation {
    init(_ orientation: UIImage.Orientation) {
        switch orientation {
        case .up: self = .up
        case .down: self = .down
        case .left: self = .left
        case .right: self = .right
        case .upMirrored: self = .upMirrored
        case .downMirrored: self = .downMirrored
        case .leftMirrored: self = .leftMirrored
        case .rightMirrored: self = .rightMirrored
        @unknown default: self = .up
        }
    }
}
