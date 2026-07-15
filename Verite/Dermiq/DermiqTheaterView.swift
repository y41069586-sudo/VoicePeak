import SwiftUI
import Vision
import UIKit

// ============================================================
// MARK: — Screen 3: Analysis Sequence (the theater)
// ============================================================

/// 6–8 staged seconds that sell the app. No spinner. Instead of a geometric
/// face-landmark mesh (which read as looks-rating), the skin itself is
/// sampled: a dense field of analysis points spreads across the WHOLE face and
/// is read top-to-bottom by a scan line — a skincare surface analysis, not a
/// face-geometry outline. If the engine is slower than the animation the
/// status-label stage loops gracefully.
struct DermiqTheaterView: View {
    let model: ScanFlowModel
    let onDone: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var photoVisible = false
    @State private var clinical = false          // desaturated treatment
    @State private var sweepProgress: CGFloat = -0.15
    @State private var sweepVisible = false
    @State private var field: FaceField = .empty
    @State private var fieldVisible = false
    @State private var collapsed = false
    @State private var detailsVisible = false
    @State private var statusLabel = ""

    // Corner readouts shown while the skin reads — labels + measuring bars, no
    // committed numbers (the honest score only lands at the end).
    private let readouts: [(label: String, fill: CGFloat, at: UnitPoint)] = [
        ("TEXTURE",   0.72, UnitPoint(x: 0.20, y: 0.24)),
        ("REDNESS",   0.55, UnitPoint(x: 0.80, y: 0.30)),
        ("HYDRATION", 0.80, UnitPoint(x: 0.19, y: 0.74)),
        ("PORES",     0.62, UnitPoint(x: 0.81, y: 0.68)),
    ]

    // Honest, self-referential steps only — no invented corpus sizes (2.3.1).
    private let statusLabels = [
        "Reading your skin surface…",
        "Mapping texture & pores…",
        "Measuring redness & tone…",
        "Weighing your lifestyle answers…",
    ]

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                DQColor.background.ignoresSafeArea()

                if let image = model.capturedImage {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: proxy.size.width, height: proxy.size.height)
                        .clipped()
                        .saturation(clinical ? 0.55 : 1)
                        .opacity(photoVisible ? (clinical ? 0.85 : 1) : 0)
                        .ignoresSafeArea()

                    skinFieldLayer(size: proxy.size, imageSize: image.size)

                    if sweepVisible {
                        scanLine(size: proxy.size)
                    }

                    readoutLayer(size: proxy.size)
                }

                statusOverlay
            }
        }
        .ignoresSafeArea()
        .task { await run() }
    }

    // MARK: The skin-sampling field (dots across the whole face)

    private func skinFieldLayer(size: CGSize, imageSize: CGSize) -> some View {
        ZStack {
            ForEach(Array(field.points.enumerated()), id: \.offset) { _, p in
                let pt = map(p, imageSize: imageSize, viewSize: size)
                // Top points light up first → the scan reads down the face.
                let delay = fieldVisible ? Double(p.y) * 1.5 : 0
                Circle()
                    .fill(DQColor.accentBright)
                    .frame(width: 3, height: 3)
                    .opacity(fieldVisible ? (collapsed ? 0 : 0.85) : 0)
                    .scaleEffect(fieldVisible ? 1 : 0.2)
                    .position(pt)
                    .animation(.easeOut(duration: 0.5).delay(delay), value: fieldVisible)
                    .animation(.easeIn(duration: 0.4), value: collapsed)
            }
        }
        .allowsHitTesting(false)
    }

    // MARK: Chart readouts (measuring chips around the face)

    private func readoutLayer(size: CGSize) -> some View {
        ForEach(Array(readouts.enumerated()), id: \.offset) { index, r in
            readoutChip(label: r.label, fill: r.fill)
                .position(x: size.width * r.at.x, y: size.height * r.at.y)
                .opacity(detailsVisible ? 1 : 0)
                .scaleEffect(detailsVisible ? 1 : 0.9, anchor: .center)
                .animation(.easeOut(duration: 0.45).delay(Double(index) * 0.12),
                           value: detailsVisible)
        }
        .allowsHitTesting(false)
    }

    private func readoutChip(label: String, fill: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 5) {
                Circle().fill(DQColor.accent).frame(width: 5, height: 5)
                Text(LocalizedStringKey(label))
                    .font(DQFont.mono(9, weight: .semibold))
                    .tracking(1.4)
                    .foregroundStyle(DQColor.textPrimary)
            }
            ZStack(alignment: .leading) {
                Capsule().fill(DQColor.stroke).frame(width: 66, height: 4)
                Capsule().fill(DQColor.accentGradient)
                    .frame(width: detailsVisible ? 66 * fill : 0, height: 4)
                    .animation(.easeInOut(duration: 1.1), value: detailsVisible)
            }
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 8)
        .background(DQColor.surface.opacity(0.92),
                    in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .shadow(color: .black.opacity(0.18), radius: 10, y: 4)
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
            Text(LocalizedStringKey(statusLabel))
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

        // Stage 1 — photo appears, skin field detected in the background.
        withAnimation(.easeOut(duration: 0.3)) { photoVisible = true }
        async let fieldTask = FaceField.detect(in: image)
        try? await Task.sleep(for: .milliseconds(400))
        field = await fieldTask

        if reduceMotion {
            clinical = true
            fieldVisible = true
            detailsVisible = true
            await cycleLabels(minimumCycles: 2)
            onDone()
            return
        }

        // Stage 2 — clinical desaturation + one downward read; the sampling
        // field lights up top-to-bottom in sync with the scan line.
        Haptics.fire(.transition)
        withAnimation(.easeInOut(duration: 0.9)) { clinical = true }
        sweepVisible = true
        sweepProgress = -0.12
        withAnimation(.easeInOut(duration: 1.7)) { sweepProgress = 1.12 }
        fieldVisible = true
        try? await Task.sleep(for: .milliseconds(1750))
        sweepVisible = false

        // Stage 3 — the measuring chips settle in.
        Haptics.fire(.transition)
        withAnimation { detailsVisible = true }
        try? await Task.sleep(for: .milliseconds(700))

        // Stage 4 — status labels (~1s each); loops while the engine is slow.
        Haptics.fire(.transition)
        await cycleLabels(minimumCycles: 1)

        // Stage 5 — everything dissolves → cut to results.
        Haptics.fire(.transition)
        statusLabel = ""
        withAnimation(.easeIn(duration: 0.35)) { detailsVisible = false }
        collapsed = true
        try? await Task.sleep(for: .milliseconds(520))
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
// MARK: — Skin sampling field (Vision face box → dot field)
// ============================================================

/// A dense field of sample points spread across the whole face region
/// (normalized, y-down). Not landmarks — a skin-surface sampling grid clipped
/// to the face oval, so the read looks like skincare, not face geometry.
struct FaceField: Sendable {
    let points: [CGPoint]
    /// Field centroid in unit coordinates (collapse/scale anchor).
    let anchor: UnitPoint

    static let empty = FaceField(points: [], anchor: .center)

    static func detect(in image: UIImage) async -> FaceField {
        await Task.detached(priority: .userInitiated) {
            // Face box fallback (y-down) so the field always draws.
            var box = CGRect(x: 0.28, y: 0.20, width: 0.44, height: 0.52)
            // Face box (y-down whole-image coords).
            if let cgImage = image.cgImage {
                let request = VNDetectFaceLandmarksRequest()
                let handler = VNImageRequestHandler(
                    cgImage: cgImage,
                    orientation: CGImagePropertyOrientation(image.imageOrientation),
                    options: [:]
                )
                try? handler.perform([request])
                if let face = request.results?.max(by: { $0.boundingBox.height < $1.boundingBox.height }) {
                    let b = face.boundingBox
                    box = CGRect(x: b.minX, y: 1 - b.minY - b.height, width: b.width, height: b.height)
                }
            }

            // Vision's box runs roughly brow→chin. Lift the top to take in the
            // forehead so the field covers the WHOLE face, not just nose→chin.
            let lift = box.height * 0.22
            let newTop = max(0, box.minY - lift)
            box = CGRect(x: box.minX, y: newTop,
                         width: box.width,
                         height: min(1 - newTop, box.height + (box.minY - newTop)))

            // Jittered grid across the box; keep a point only inside the
            // inscribed ellipse — it hugs the face and drops the ear/hair
            // corners on its own. Horizontal radius trimmed a touch so the
            // cheek edges stay on skin, never on the ears.
            let cols = 10, rows = 14
            var points: [CGPoint] = []
            for r in 0..<rows {
                for c in 0..<cols {
                    let seed = r * cols + c
                    let jx = (pseudo(seed, 12.9898) - 0.5) * 0.7
                    let jy = (pseudo(seed, 78.233) - 0.5) * 0.7
                    let u = (CGFloat(c) + 0.5) / CGFloat(cols) + jx / CGFloat(cols)
                    let v = (CGFloat(r) + 0.5) / CGFloat(rows) + jy / CGFloat(rows)
                    let dx = (u - 0.5) / 0.5 / 0.92
                    let dy = (v - 0.5) / 0.5
                    guard dx * dx + dy * dy <= 1.0 else { continue }
                    points.append(CGPoint(x: box.minX + u * box.width,
                                          y: box.minY + v * box.height))
                }
            }
            return FaceField(points: points,
                             anchor: UnitPoint(x: box.midX, y: box.midY))
        }.value
    }

    /// Deterministic pseudo-random in 0…1.
    private static func pseudo(_ i: Int, _ salt: Double) -> CGFloat {
        let v = sin(Double(i + 1) * salt) * 43758.5453
        return CGFloat(v - floor(v))
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
