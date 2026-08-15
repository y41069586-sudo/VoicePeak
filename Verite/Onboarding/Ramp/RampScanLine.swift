import SwiftUI

// ============================================================
// MARK: — The scan line
// ============================================================

/// The capture overlay: a bright edge sweeping down the frame, with the part
/// it has already crossed left faintly ruled and lit.
///
/// This replaced a face mesh, and the reason is worth keeping. A wireframe
/// over a portrait fights the portrait — it is drawn densest exactly where the
/// face is, so the one thing the screen exists to show ends up underneath a
/// net. It also only sits correctly on a head-on shot; on the three-quarter
/// portraits people actually take, a frontal mesh skews and reads as broken.
///
/// A line has neither problem. It crosses the face without covering it, it is
/// orientation-agnostic, and it says the one thing the screen needs to say —
/// something is being read, top to bottom, right now. `DQTheme` already names
/// a scan line as the treatment; this is it.
struct RampScanLine: View {
    /// 0 = top of the frame, 1 = bottom. Animate this to sweep.
    var progress: CGFloat = 0.52
    /// Height of the lit trail behind the line, in points.
    var trail: CGFloat = 132
    var tint: Color = Color(hex: "C9B387")

    var body: some View {
        GeometryReader { geo in
            let y = geo.size.height * progress

            ZStack(alignment: .top) {
                // Everything above the line has been read: a fine rule and a
                // wash that strengthens toward the line, so the sweep has a
                // direction rather than being a stripe sitting on a photo.
                sweptRegion(width: geo.size.width, height: y)

                // The line itself, plus its bloom. Three shadows rather than
                // one: a tight white core for the edge, a mid accent halo, and
                // a wide soft one that lifts the skin around it.
                Capsule()
                    .fill(
                        LinearGradient(colors: [.white.opacity(0),
                                                .white, .white,
                                                .white.opacity(0)],
                                       startPoint: .leading, endPoint: .trailing)
                    )
                    .frame(width: geo.size.width * 1.12, height: 2.5)
                    .shadow(color: .white.opacity(0.85), radius: 5)
                    .shadow(color: tint.opacity(0.55), radius: 17)
                    .shadow(color: tint.opacity(0.30), radius: 35)
                    .offset(x: -geo.size.width * 0.06, y: y - 1.25)
            }
            .frame(width: geo.size.width, height: geo.size.height, alignment: .top)
            .clipped()
            .allowsHitTesting(false)
        }
    }

    private func sweptRegion(width: CGFloat, height: CGFloat) -> some View {
        ZStack {
            // Horizontal ruling, 1pt every 5 — visible as texture, never as
            // stripes competing with the face.
            Rectangle()
                .fill(.white.opacity(0.075))
                .mask(alignment: .top) {
                    VStack(spacing: 4) {
                        ForEach(0..<Int(max(height, 0) / 5) + 1, id: \.self) { _ in
                            Rectangle().frame(height: 1)
                        }
                    }
                }
            // The wash, brightest right behind the line.
            LinearGradient(colors: [.white.opacity(0), .white.opacity(0.20)],
                           startPoint: .top, endPoint: .bottom)
                .frame(height: min(trail, max(height, 0)))
                .frame(maxHeight: .infinity, alignment: .bottom)
        }
        .frame(width: width, height: max(height, 0), alignment: .top)
        // Fade the top so the swept region has no hard upper edge.
        .mask(
            LinearGradient(colors: [.clear, .black, .black],
                           startPoint: .top, endPoint: .bottom)
        )
    }
}

#Preview {
    ZStack {
        LinearGradient(colors: [Color(hex: "6B5A4C"), Color(hex: "3A322B")],
                       startPoint: .top, endPoint: .bottom)
        RampScanLine()
    }
    .frame(width: 402, height: 874)
}
