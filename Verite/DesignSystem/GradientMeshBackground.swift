import SwiftUI

/// A slowly drifting, GPU-friendly gradient "mesh" built from a handful of
/// blurred radial blobs over the deep-indigo base. Cheap enough to sit behind
/// every screen at 60fps.
///
/// Implemented with `Canvas` (radial gradients + a blur filter) rather than
/// iOS 18's `MeshGradient` so it runs on the iOS 17 deployment target. When
/// Reduce Motion is on, the blobs are frozen to a static composition.
struct GradientMeshBackground: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Base "warmth" of the drift, in seconds per full cycle. Slow = calm.
    var period: Double = 22

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: reduceMotion)) { timeline in
            let t = reduceMotion
                ? 0
                : timeline.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: period) / period

            Canvas { context, size in
                // Base fill.
                context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(Theme.bgBase))

                context.addFilter(.blur(radius: 90))
                context.drawLayer { layer in
                    for blob in Self.blobs {
                        let phase = (t + blob.phase) * 2 * .pi
                        let cx = size.width * (blob.center.x + blob.travel.x * sin(phase))
                        let cy = size.height * (blob.center.y + blob.travel.y * cos(phase))
                        let radius = size.width * blob.radius
                        let rect = CGRect(x: cx - radius, y: cy - radius,
                                          width: radius * 2, height: radius * 2)
                        let gradient = Gradient(colors: [blob.color.opacity(blob.opacity), .clear])
                        layer.fill(
                            Path(ellipseIn: rect),
                            with: .radialGradient(gradient,
                                                  center: CGPoint(x: cx, y: cy),
                                                  startRadius: 0,
                                                  endRadius: radius)
                        )
                    }
                }
            }
            .drawingGroup() // flatten to a single Metal layer
            .ignoresSafeArea()
        }
        .background(Theme.bgBase.ignoresSafeArea())
    }

    // Precomputed blob definitions — no allocation during animation frames.
    private struct Blob {
        let center: CGPoint     // fractional position (0...1)
        let travel: CGPoint     // fractional drift amplitude
        let radius: CGFloat     // fraction of width
        let color: Color
        let opacity: Double
        let phase: Double       // 0...1 offset so blobs don't move in lockstep
    }

    private static let blobs: [Blob] = [
        Blob(center: CGPoint(x: 0.20, y: 0.18), travel: CGPoint(x: 0.06, y: 0.05),
             radius: 0.60, color: Theme.primary, opacity: 0.55, phase: 0.0),
        Blob(center: CGPoint(x: 0.82, y: 0.30), travel: CGPoint(x: 0.05, y: 0.07),
             radius: 0.52, color: Theme.accent, opacity: 0.32, phase: 0.35),
        Blob(center: CGPoint(x: 0.55, y: 0.88), travel: CGPoint(x: 0.08, y: 0.05),
             radius: 0.70, color: Theme.primaryBright, opacity: 0.28, phase: 0.68),
    ]
}

#Preview {
    GradientMeshBackground()
}
