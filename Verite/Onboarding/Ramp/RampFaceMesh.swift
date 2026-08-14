import SwiftUI

// ============================================================
// MARK: — The scan mesh
// ============================================================
//
// The landmark wireframe the capture screen lays over a face — built from a
// parametric head model, not a bitmap. It scales to any size, animates, and
// never goes stale the way a flattened screenshot does.
//
// The geometry, in one paragraph. The head is treated as a half-ellipsoid.
// A vertical parameter `v` runs hairline (0) → chin (1) and reads a silhouette
// profile for the half-width at that height. A horizontal parameter `u` runs
// -1 → 1 across that width and is wrapped through `sin`, so columns bunch
// toward the silhouette exactly as they would on a curved surface; rows sag by
// `1 - cos` for the same reason. That single trick is what separates a mesh
// that sits ON a face from a grid stuck in front of one. The feature contours
// — brows, eyes, nose, lips — are placed against the standard vertical thirds,
// so the mesh lands correctly on any frontal portrait without being told
// anything about it.

enum RampFaceMeshGeometry {

    // MARK: The coordinate system
    //
    // Everything below is authored in ONE system, and it is worth stating it
    // plainly because the first cut of this file did not have one and the mesh
    // came out two-thirds too narrow.
    //
    //   · Horizontals are offsets from the midline in units of the face's own
    //     HALF-WIDTH: 0 is the midline, ±1 is the silhouette at its widest.
    //   · Verticals run 0 (hairline) → 1 (chin), in units of the face box.
    //
    // `place` maps both onto the 0…1 face box the renderer draws into. Nothing
    // in this file should ever carry a raw box coordinate.

    private static func place(_ offset: CGFloat, _ v: CGFloat) -> CGPoint {
        CGPoint(x: 0.5 + offset * 0.5, y: v)
    }

    // MARK: Silhouette

    /// Half-width, sampled hairline → chin, as a fraction of the widest point.
    /// Widest at the cheekbone about a third of the way down, then following
    /// the jaw in to a rounded chin.
    private static let profile: [CGFloat] = [
        0.700, 0.802, 0.879, 0.934, 0.973, 0.995,
        1.000, 0.989, 0.962, 0.912, 0.838, 0.732,
        0.598, 0.430, 0.232
    ]

    /// The silhouette half-width at `v`, smoothstepped between samples so the
    /// outline carries no visible facets at any size.
    static func halfWidth(at v: CGFloat) -> CGFloat {
        let clamped = min(max(v, 0), 1)
        let x = clamped * CGFloat(profile.count - 1)
        let i = min(Int(x), profile.count - 2)
        let t = x - CGFloat(i)
        let s = t * t * (3 - 2 * t)
        return profile[i] + (profile[i + 1] - profile[i]) * s
    }

    /// A surface vertex in the face box. `u` is -1 (left silhouette) → 1
    /// (right silhouette); it is wrapped through `sin` so the columns bunch
    /// toward the edge as they would on a curved surface, and the row sags by
    /// `1 - cos` for the same reason. That pair is what makes the grid sit ON
    /// a face instead of hanging in front of one.
    static func vertex(u: CGFloat, v: CGFloat) -> CGPoint {
        let theta = u * .pi / 2
        // Part straight, part wrapped. A pure `sin` stacks the outer columns
        // almost on top of each other and the silhouette reads as a bright
        // rim; blending in the linear term spreads them out while still
        // landing the last column exactly on the outline (0.35 + 0.65 = 1
        // at u = ±1).
        let across = u * 0.35 + sin(theta) * 0.65
        return CGPoint(x: 0.5 + across * halfWidth(at: v) * 0.5,
                       y: v + (1 - cos(theta)) * 0.020)
    }

    // MARK: Feature contours
    //
    // Canonical proportions, measured from the hairline: brow 0.29, eye 0.39,
    // nose base 0.67, lip line 0.79, chin 1.0 — the classic vertical thirds.
    // The pupils sit just over half a half-width out from the midline.

    private static let eyeOffset: CGFloat = 0.52
    private static let eyeLine: CGFloat = 0.390

    private static func mirrored(_ points: [CGPoint]) -> [CGPoint] {
        points.map { CGPoint(x: 1 - $0.x, y: $0.y) }
    }

    /// One eye. The upper lid rides higher than the lower and the outer corner
    /// sits a touch below the inner; without that asymmetry it reads as a
    /// circle stuck on a cheek.
    static func eye(right: Bool) -> [CGPoint] {
        let cx = eyeOffset, cy = eyeLine
        let rx: CGFloat = 0.175      // half-widths
        let ry: CGFloat = 0.037      // box height
        let points = [
            place(cx - rx,        cy + 0.002),
            place(cx - rx * 0.56, cy - ry * 0.84),
            place(cx + rx * 0.02, cy - ry),
            place(cx + rx * 0.60, cy - ry * 0.74),
            place(cx + rx,        cy + 0.008),
            place(cx + rx * 0.58, cy + ry * 0.78),
            place(cx,             cy + ry * 0.96),
            place(cx - rx * 0.58, cy + ry * 0.82),
        ]
        return right ? points : mirrored(points)
    }

    /// The iris ring, drawn a shade brighter than the lid. The radius is in
    /// half-widths, like every other horizontal here.
    static func iris(right: Bool) -> (center: CGPoint, radius: CGFloat) {
        (place(right ? eyeOffset : -eyeOffset, eyeLine + 0.004), 0.075 * 0.5)
    }

    /// The brow, arcing up and out over the eye.
    static func brow(right: Bool) -> [CGPoint] {
        let points = [
            place(0.20, 0.316),
            place(0.39, 0.292),
            place(0.57, 0.286),
            place(0.72, 0.299),
            place(0.83, 0.321),
        ]
        return right ? points : mirrored(points)
    }

    /// The bridge, running from between the brows to the tip.
    static let noseBridge: [CGPoint] = [
        place(0, 0.318), place(0, 0.430), place(0, 0.545), place(0, 0.632),
    ]

    /// Tip, wings and nostril base as one open contour.
    static let noseBase: [CGPoint] = [
        place(-0.215, 0.668), place(-0.160, 0.694), place(-0.080, 0.703),
        place( 0.000, 0.694),
        place( 0.080, 0.703), place( 0.160, 0.694), place( 0.215, 0.668),
    ]

    /// The outer lip line, closed — cupid's bow up, corners narrow.
    static let lipOuter: [CGPoint] = [
        place(-0.345, 0.792), place(-0.198, 0.755), place(-0.078, 0.767),
        place( 0.000, 0.752),
        place( 0.078, 0.767), place( 0.198, 0.755), place( 0.345, 0.792),
        place( 0.184, 0.848), place( 0.000, 0.862), place(-0.184, 0.848),
    ]

    /// Where the lips part.
    static let lipLine: [CGPoint] = [
        place(-0.345, 0.792), place(-0.159, 0.799), place(0.000, 0.795),
        place( 0.159, 0.799), place(0.345, 0.792),
    ]

    /// Every feature contour, flagged closed or open, in draw order.
    static var contours: [(points: [CGPoint], closed: Bool)] {
        [
            (brow(right: false), false), (brow(right: true), false),
            (eye(right: false), true),   (eye(right: true), true),
            (noseBridge, false), (noseBase, false),
            (lipOuter, true), (lipLine, false),
        ]
    }
}

// ============================================================
// MARK: — The mesh itself
// ============================================================

/// The animated scan overlay: a wireframe that writes itself onto the face top
/// down, a light bar sweeping the surface behind it, and the landmark points
/// lighting as the bar crosses them.
///
/// Drawn on a `TimelineView` clock rather than an animated `@State`. A `Canvas`
/// closure reads plain values, and SwiftUI does not interpolate those the way
/// it interpolates a `Shape`'s `animatableData` — driving it from state renders
/// the finished mesh in one frame on device. The timeline hands over a real
/// per-frame date, so every frame is genuinely different.
struct RampFaceMesh: View {
    /// Where the face sits inside the view, in fractions of its bounds.
    var faceRect: CGRect = CGRect(x: 0.115, y: 0.203, width: 0.716, height: 0.467)
    var tint: Color = .white
    /// Grid density. 15 × 19 is the point where the mesh reads as a surface at
    /// mockup scale without turning into a solid sheet of ink.
    var columns: Int = 15
    var rows: Int = 19
    /// Seconds for the mesh to finish writing itself on.
    var writeOn: Double = 1.5
    /// Seconds per sweep of the light bar.
    var sweepPeriod: Double = 3.4

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var epoch: Date?

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: reduceMotion)) { timeline in
            Canvas { context, size in
                draw(in: &context, size: size, at: elapsed(to: timeline.date))
            }
        }
        .onAppear { epoch = Date() }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func elapsed(to date: Date) -> Double {
        guard !reduceMotion else { return writeOn }
        guard let epoch else { return 0 }
        return date.timeIntervalSince(epoch)
    }

    // MARK: Drawing

    private func draw(in context: inout GraphicsContext, size: CGSize, at time: Double) {
        let box = CGRect(x: faceRect.minX * size.width,
                         y: faceRect.minY * size.height,
                         width: faceRect.width * size.width,
                         height: faceRect.height * size.height)

        /// Unit face space → view space.
        func place(_ p: CGPoint) -> CGPoint {
            CGPoint(x: box.minX + p.x * box.width, y: box.minY + p.y * box.height)
        }

        // How far down the face the write-on has reached, and where the light
        // bar is. The bar only starts once the mesh is fully drawn.
        let written = writeOn > 0 ? min(max(time / writeOn, 0), 1) : 1.0
        let sweeping = time > writeOn
        let sweep = sweeping
            ? ((time - writeOn).truncatingRemainder(dividingBy: sweepPeriod) / sweepPeriod)
            : -1

        /// A vertex's opacity: zero until the write-on reaches it, then a short
        /// ramp so the leading edge is a soft front rather than a hard line.
        func reveal(_ v: CGFloat) -> Double {
            let front = (written * 1.12) - Double(v)
            return min(max(front / 0.16, 0), 1)
        }

        /// Extra brightness for anything the light bar is currently crossing.
        func lit(_ v: CGFloat) -> Double {
            guard sweep >= 0 else { return 0 }
            let d = abs(Double(v) - sweep)
            return d > 0.14 ? 0 : (1 - d / 0.14) * (1 - d / 0.14)
        }

        drawSurface(in: &context, place: place, reveal: reveal, lit: lit)
        drawSweepBar(in: &context, box: box, sweep: sweep)
        drawContours(in: &context, place: place, reveal: reveal, lit: lit)
        drawVertices(in: &context, place: place, reveal: reveal, lit: lit)
    }

    /// The grid — rows first, then columns. One path per line rather than one
    /// per segment: a row sits at a single `v`, so it has one opacity anyway,
    /// and a column takes the opacity of its newest row so it grows in instead
    /// of popping. Per-segment strokes would be ~290 draw calls a frame to buy
    /// a gradient nobody can see at mockup scale.
    private func drawSurface(in context: inout GraphicsContext,
                             place: (CGPoint) -> CGPoint,
                             reveal: (CGFloat) -> Double,
                             lit: (CGFloat) -> Double) {
        let line = StrokeStyle(lineWidth: 0.6, lineCap: .round)

        for row in 0..<rows {
            let v = CGFloat(row) / CGFloat(rows - 1)
            let alpha = reveal(v)
            guard alpha > 0.01 else { continue }
            var path = Path()
            for col in 0..<columns {
                let u = CGFloat(col) / CGFloat(columns - 1) * 2 - 1
                let point = place(RampFaceMeshGeometry.vertex(u: u, v: v))
                if col == 0 { path.move(to: point) } else { path.addLine(to: point) }
            }
            context.stroke(path,
                           with: .color(tint.opacity(alpha * (0.26 + 0.42 * lit(v)))),
                           style: line)
        }

        for col in 0..<columns {
            let u = CGFloat(col) / CGFloat(columns - 1) * 2 - 1
            var path = Path()
            var started = false
            var alpha = 0.0
            for row in 0..<rows {
                let v = CGFloat(row) / CGFloat(rows - 1)
                guard reveal(v) > 0.01 else { continue }
                alpha = reveal(v)   // the lowest revealed row wins
                let point = place(RampFaceMeshGeometry.vertex(u: u, v: v))
                if started { path.addLine(to: point) } else { path.move(to: point); started = true }
            }
            guard started else { continue }
            context.stroke(path, with: .color(tint.opacity(alpha * 0.20)), style: line)
        }
    }

    /// The light bar: a soft band of the tint, laid across the face at the
    /// sweep position and faded out at both ends.
    private func drawSweepBar(in context: inout GraphicsContext, box: CGRect, sweep: Double) {
        guard sweep >= 0 else { return }
        let y = box.minY + CGFloat(sweep) * box.height
        let band = CGRect(x: box.minX - box.width * 0.06, y: y - box.height * 0.055,
                          width: box.width * 1.12, height: box.height * 0.11)
        context.fill(
            Path(band),
            with: .linearGradient(
                Gradient(colors: [tint.opacity(0), tint.opacity(0.26), tint.opacity(0)]),
                startPoint: CGPoint(x: band.midX, y: band.minY),
                endPoint: CGPoint(x: band.midX, y: band.maxY)))
    }

    /// Brows, eyes, nose and lips — brighter and heavier than the grid, since
    /// these are the lines that tell you it is reading a face.
    private func drawContours(in context: inout GraphicsContext,
                              place: (CGPoint) -> CGPoint,
                              reveal: (CGFloat) -> Double,
                              lit: (CGFloat) -> Double) {
        for contour in RampFaceMeshGeometry.contours {
            guard let first = contour.points.first else { continue }
            let v = contour.points.reduce(CGFloat(0)) { $0 + $1.y } / CGFloat(contour.points.count)
            let alpha = reveal(v)
            guard alpha > 0.01 else { continue }

            var path = Path()
            path.move(to: place(first))
            for point in contour.points.dropFirst() { path.addLine(to: place(point)) }
            if contour.closed { path.closeSubpath() }
            context.stroke(path,
                           with: .color(tint.opacity(alpha * (0.70 + 0.30 * lit(v)))),
                           style: StrokeStyle(lineWidth: 1.0, lineCap: .round, lineJoin: .round))

            for point in contour.points {
                let placed = place(point)
                let r: CGFloat = 1.1
                context.fill(Path(ellipseIn: CGRect(x: placed.x - r, y: placed.y - r,
                                                    width: r * 2, height: r * 2)),
                             with: .color(tint.opacity(alpha * 0.95)))
            }
        }

        for side in [true, false] {
            let iris = RampFaceMeshGeometry.iris(right: side)
            let alpha = reveal(iris.center.y)
            guard alpha > 0.01 else { continue }
            // The radius is in unit face space, so it has to be *placed* too —
            // measured as the distance between the centre and its own edge
            // once both have been mapped into the view.
            let c = place(iris.center)
            let r = place(CGPoint(x: iris.center.x + iris.radius, y: iris.center.y)).x - c.x
            context.stroke(Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r,
                                                  width: r * 2, height: r * 2)),
                           with: .color(tint.opacity(alpha * 0.55)),
                           style: StrokeStyle(lineWidth: 0.8))
        }
    }

    /// The grid vertices. Small and quiet, except where the bar is crossing —
    /// there they bloom, which is the whole reason the bar exists.
    private func drawVertices(in context: inout GraphicsContext,
                              place: (CGPoint) -> CGPoint,
                              reveal: (CGFloat) -> Double,
                              lit: (CGFloat) -> Double) {
        for row in 0..<rows {
            let v = CGFloat(row) / CGFloat(rows - 1)
            let alpha = reveal(v)
            guard alpha > 0.01 else { continue }
            let glow = lit(v)
            let r: CGFloat = 0.75 + 0.85 * CGFloat(glow)
            for col in 0..<columns {
                let u = CGFloat(col) / CGFloat(columns - 1) * 2 - 1
                let p = place(RampFaceMeshGeometry.vertex(u: u, v: v))
                context.fill(Path(ellipseIn: CGRect(x: p.x - r, y: p.y - r,
                                                    width: r * 2, height: r * 2)),
                             with: .color(tint.opacity(alpha * (0.38 + 0.55 * glow))))
            }
        }
    }
}

#Preview {
    ZStack {
        Color(hex: "2A2622")
        RampFaceMesh()
    }
    .frame(width: 320, height: 560)
}
