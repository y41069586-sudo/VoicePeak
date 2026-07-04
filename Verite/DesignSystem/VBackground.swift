import SwiftUI

/// The living gradient mesh (DESIGN_SPEC §5) — every screen sits on this, never a
/// flat fill. Three heavily-blurred radial blobs of primary/accent drift slowly
/// over the base, reading as ambient light, not shapes. Frozen under Reduce Motion.
/// GPU-friendly (`Canvas` + `.drawingGroup()`). Decorative → hidden from VoiceOver.
struct VBackground: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var period: Double = 24

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: reduceMotion)) { timeline in
            let t = reduceMotion ? 0
                : timeline.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: period) / period

            Canvas { context, size in
                context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(VColor.bgBase))
                context.addFilter(.blur(radius: 80))
                context.drawLayer { layer in
                    for blob in Self.blobs {
                        let phase = (t + blob.phase) * 2 * .pi
                        let cx = size.width * (blob.center.x + blob.travel.x * sin(phase))
                        let cy = size.height * (blob.center.y + blob.travel.y * cos(phase))
                        let radius = size.width * blob.radius
                        let rect = CGRect(x: cx - radius, y: cy - radius, width: radius * 2, height: radius * 2)
                        let gradient = Gradient(colors: [blob.color.opacity(blob.opacity), .clear])
                        layer.fill(Path(ellipseIn: rect),
                                   with: .radialGradient(gradient, center: CGPoint(x: cx, y: cy),
                                                         startRadius: 0, endRadius: radius))
                    }
                }
            }
            .drawingGroup()
            .ignoresSafeArea()
        }
        .background(VColor.bgBase.ignoresSafeArea())
        .accessibilityHidden(true)
    }

    private struct Blob {
        let center: CGPoint
        let travel: CGPoint
        let radius: CGFloat
        let color: Color
        let opacity: Double
        let phase: Double
    }

    private static let blobs: [Blob] = [
        Blob(center: CGPoint(x: 0.20, y: 0.16), travel: CGPoint(x: 0.06, y: 0.05),
             radius: 0.62, color: VColor.primary, opacity: 0.14, phase: 0.0),
        Blob(center: CGPoint(x: 0.84, y: 0.30), travel: CGPoint(x: 0.05, y: 0.07),
             radius: 0.54, color: VColor.accent, opacity: 0.12, phase: 0.35),
        Blob(center: CGPoint(x: 0.55, y: 0.90), travel: CGPoint(x: 0.08, y: 0.05),
             radius: 0.72, color: VColor.primaryBright, opacity: 0.10, phase: 0.68),
    ]
}
