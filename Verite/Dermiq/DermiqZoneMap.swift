import SwiftUI

// ============================================================
// MARK: — Zone map card (tappable face, per-region readings)
// ============================================================
//
// A stylized face with five tappable zones. Fill intensity encodes how much
// attention a zone needs (stronger blue = lower score); tapping a zone shows
// its score, its focus concern and one practical tip. Live Perfect Corp scans
// carry real per-region data; otherwise zones are derived from the sub-scores.

struct DermiqZoneMapCard: View {
    let analysis: DermiqAnalysis

    @State private var selected: DermiqZone?

    private var zones: [DermiqZoneScore] { DermiqZoneDeriver.zones(for: analysis) }
    private var selectedScore: DermiqZoneScore? {
        zones.first { $0.zone == (selected ?? worst.zone) }
    }
    private var worst: DermiqZoneScore {
        zones.min { $0.value < $1.value } ?? zones[0]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("ZONE MAP")
                    .font(DQFont.mono(11, weight: .semibold))
                    .foregroundStyle(DQColor.textSecondary)
                    .tracking(2)
                Spacer()
                Text("Tap a zone")
                    .font(DQFont.micro)
                    .foregroundStyle(DQColor.textSecondary)
            }

            HStack(alignment: .center, spacing: 16) {
                DermiqFaceZones(
                    zones: zones,
                    selected: selected ?? worst.zone
                ) { zone in
                    Haptics.fire(.selection)
                    withAnimation(VMotion.snappy) { selected = zone }
                }
                .frame(width: 150, height: 190)

                if let score = selectedScore {
                    zoneDetail(score)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .id(score.zone)   // re-run transition per zone
                        .transition(.opacity.combined(with: .move(edge: .trailing)))
                }
            }

            // Legend: what the shading means.
            HStack(spacing: 6) {
                LinearGradient(colors: [DQColor.accentSoft, DQColor.accent],
                               startPoint: .leading, endPoint: .trailing)
                    .frame(width: 44, height: 6)
                    .clipShape(Capsule())
                Text("Deeper blue = needs more attention")
                    .font(DQFont.micro)
                    .foregroundStyle(DQColor.textSecondary)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(DQColor.surface, in: RoundedRectangle(cornerRadius: DQRadius.card, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: DQRadius.card, style: .continuous)
                .strokeBorder(DQColor.stroke, lineWidth: 1)
        )
    }

    private func zoneDetail(_ score: DermiqZoneScore) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(LocalizedStringKey(score.zone.displayName))
                .font(.system(size: 19, weight: .heavy, design: .rounded))
                .foregroundStyle(DQColor.textPrimary)

            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(verbatim: "\(score.value)")
                    .font(.system(size: 30, weight: .heavy, design: .rounded).monospacedDigit())
                    .foregroundStyle(DQColor.accentBright)
                Text(verbatim: "/100")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(DQColor.textSecondary)
            }

            HStack(spacing: 5) {
                Text("Focus")
                    .font(DQFont.micro)
                    .foregroundStyle(DQColor.textSecondary)
                Text(LocalizedStringKey(score.focus.displayName))
                    .font(.system(size: 11.5, weight: .semibold, design: .rounded))
                    .foregroundStyle(DQColor.accentBright)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(DQColor.accentSoft.opacity(0.7), in: Capsule())
            }

            Text(LocalizedStringKey(DermiqZoneDeriver.tip(for: score.focus)))
                .font(DQFont.micro)
                .foregroundStyle(DQColor.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

// ============================================================
// MARK: — The face drawing
// ============================================================

/// Face silhouette + five tappable zone shapes, authored in a 100×120 space
/// and scaled to the view.
private struct DermiqFaceZones: View {
    let zones: [DermiqZoneScore]
    let selected: DermiqZone
    let onTap: (DermiqZone) -> Void

    var body: some View {
        GeometryReader { geo in
            let s = geo.size
            ZStack {
                // Face outline — a soft egg with ears left out on purpose.
                faceOutline(s)
                    .stroke(DQColor.stroke, lineWidth: 1.5)
                    .background(faceOutline(s).fill(DQColor.surfaceElevated.opacity(0.55)))

                ForEach(zones) { score in
                    zoneShape(score.zone, s)
                        .fill(fill(for: score))
                        .overlay(
                            zoneShape(score.zone, s)
                                .stroke(
                                    selected == score.zone ? DQColor.accentBright : DQColor.accent.opacity(0.25),
                                    lineWidth: selected == score.zone ? 2 : 1
                                )
                        )
                        .overlay(
                            Text(verbatim: "\(score.value)")
                                .font(.system(size: 11, weight: .heavy, design: .rounded).monospacedDigit())
                                .foregroundStyle(labelColor(for: score))
                                .position(labelPoint(score.zone, s))
                        )
                        .scaleEffect(selected == score.zone ? 1.04 : 1)
                        .contentShape(zoneShape(score.zone, s))
                        .onTapGesture { onTap(score.zone) }
                        .animation(VMotion.snappy, value: selected)
                }
            }
        }
    }

    /// Attention shading: worse score → deeper blue.
    private func fill(for score: DermiqZoneScore) -> Color {
        let attention = 1 - Double(score.value) / 100      // 0 great … 1 bad
        return DQColor.accent.opacity(0.10 + attention * 0.55)
    }

    private func labelColor(for score: DermiqZoneScore) -> Color {
        // Deep fills need a light label.
        (1 - Double(score.value) / 100) > 0.35 ? .white : DQColor.accentBright
    }

    // MARK: Geometry (100 × 120 authoring space)

    private func pt(_ x: CGFloat, _ y: CGFloat, _ s: CGSize) -> CGPoint {
        CGPoint(x: x / 100 * s.width, y: y / 120 * s.height)
    }

    private func rect(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat, _ s: CGSize) -> CGRect {
        CGRect(x: x / 100 * s.width, y: y / 120 * s.height,
               width: w / 100 * s.width, height: h / 120 * s.height)
    }

    private func faceOutline(_ s: CGSize) -> Path {
        var p = Path()
        p.move(to: pt(50, 4, s))
        p.addCurve(to: pt(84, 52, s), control1: pt(74, 4, s), control2: pt(84, 26, s))
        p.addCurve(to: pt(50, 112, s), control1: pt(84, 82, s), control2: pt(70, 112, s))
        p.addCurve(to: pt(16, 52, s), control1: pt(30, 112, s), control2: pt(16, 82, s))
        p.addCurve(to: pt(50, 4, s), control1: pt(16, 26, s), control2: pt(26, 4, s))
        p.closeSubpath()
        return p
    }

    private func zoneShape(_ zone: DermiqZone, _ s: CGSize) -> Path {
        switch zone {
        case .forehead:
            return Path(roundedRect: rect(30, 12, 40, 18, s), cornerRadius: 9)
        case .eyes:
            var p = Path(ellipseIn: rect(26, 38, 18, 11, s))
            p.addEllipse(in: rect(56, 38, 18, 11, s))
            return p
        case .nose:
            return Path(roundedRect: rect(43, 42, 14, 28, s), cornerRadius: 7)
        case .cheeks:
            var p = Path(ellipseIn: rect(20, 56, 19, 22, s))
            p.addEllipse(in: rect(61, 56, 19, 22, s))
            return p
        case .chin:
            return Path(ellipseIn: rect(37, 88, 26, 16, s))
        }
    }

    private func labelPoint(_ zone: DermiqZone, _ s: CGSize) -> CGPoint {
        switch zone {
        case .forehead: return pt(50, 21, s)
        case .eyes: return pt(65, 43.5, s)   // label the right eye patch
        case .nose: return pt(50, 56, s)
        case .cheeks: return pt(70.5, 67, s) // label the right cheek
        case .chin: return pt(50, 96, s)
        }
    }
}
