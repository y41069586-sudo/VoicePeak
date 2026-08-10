import SwiftUI

// ============================================================
// MARK: — Zone map card v2 (organic face, per-region readings)
// ============================================================
//
// A soft, organic face — hairline band, almond eye areas, keystone nose,
// tilted cheek ovals, jaw-following chin — with attention-shaded fills.
// Numbers live in the chip row below (cleaner than stamping digits on the
// face); tapping a zone or a chip selects it and the right panel explains
// the reading. Live Perfect Corp scans carry real per-region data.

struct DermiqZoneMapCard: View {
    let analysis: DermiqAnalysis

    @State private var selected: DermiqZone?

    private var zones: [DermiqZoneScore] { DermiqZoneDeriver.zones(for: analysis) }
    private var current: DermiqZone { selected ?? worst.zone }
    private var selectedScore: DermiqZoneScore? { zones.first { $0.zone == current } }
    private var worst: DermiqZoneScore { zones.min { $0.value < $1.value } ?? zones[0] }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("ZONE MAP")
                .font(DQFont.mono(11, weight: .semibold))
                .foregroundStyle(DQColor.textSecondary)
                .tracking(2)

            HStack(alignment: .center, spacing: 14) {
                DermiqFaceZones(zones: zones, selected: current) { zone in
                    select(zone)
                }
                .frame(width: 152, height: 188)

                if let score = selectedScore {
                    zoneDetail(score)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .id(score.zone)
                        .transition(.opacity.combined(with: .move(edge: .trailing)))
                }
            }

            // One chip per zone — the numbers live here, not on the face.
            HStack(spacing: 6) {
                ForEach(zones) { score in
                    zoneChip(score)
                }
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

    private func select(_ zone: DermiqZone) {
        Haptics.fire(.selection)
        withAnimation(VMotion.snappy) { selected = zone }
    }

    // MARK: Detail (right panel)

    private func zoneDetail(_ score: DermiqZoneScore) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(LocalizedStringKey(score.zone.displayName))
                .font(.system(size: 18, weight: .heavy, design: .rounded))
                .foregroundStyle(DQColor.textPrimary)

            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(verbatim: "\(score.value)")
                    .font(.system(size: 30, weight: .heavy, design: .rounded).monospacedDigit())
                    .foregroundStyle(DQColor.accentBright)
                Text(verbatim: "/100")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
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
                    .padding(.vertical, 3.5)
                    .background(DQColor.accentSoft.opacity(0.7), in: Capsule())
            }

            Text(LocalizedStringKey(DermiqZoneDeriver.tip(for: score.focus)))
                .font(DQFont.micro)
                .foregroundStyle(DQColor.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: Chips

    private func zoneChip(_ score: DermiqZoneScore) -> some View {
        let isSelected = current == score.zone
        return Button {
            select(score.zone)
        } label: {
            VStack(spacing: 1) {
                Text(verbatim: "\(score.value)")
                    .font(.system(size: 14, weight: .heavy, design: .rounded).monospacedDigit())
                    .foregroundStyle(isSelected ? .white : DQColor.textPrimary)
                Text(LocalizedStringKey(score.zone.shortName))
                    .font(.system(size: 8.5, weight: .semibold, design: .rounded))
                    .foregroundStyle(isSelected ? .white.opacity(0.85) : DQColor.textSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 7)
            .background(
                isSelected ? AnyShapeStyle(DQColor.accent) : AnyShapeStyle(DQColor.surfaceElevated),
                in: RoundedRectangle(cornerRadius: 11, style: .continuous)
            )
        }
        .buttonStyle(.plain)
        .animation(VMotion.snappy, value: isSelected)
    }
}

extension DermiqZone {
    /// Compact label for the chip row.
    var shortName: String {
        switch self {
        case .forehead: return "Forehead"
        case .eyes: return "Eyes"
        case .nose: return "Nose"
        case .cheeks: return "Cheeks"
        case .chin: return "Chin"
        }
    }
}

// ============================================================
// MARK: — The organic face drawing
// ============================================================

/// Face silhouette + five organic tappable zones, authored in a 100×120
/// space and scaled to the view. No numbers on the face — shading carries
/// the reading (deeper blue = needs more attention).
private struct DermiqFaceZones: View {
    let zones: [DermiqZoneScore]
    let selected: DermiqZone
    let onTap: (DermiqZone) -> Void

    var body: some View {
        GeometryReader { geo in
            let s = geo.size
            ZStack {
                facePath(s)
                    .fill(DQColor.surfaceElevated.opacity(0.6))
                facePath(s)
                    .stroke(DQColor.stroke, lineWidth: 1.2)

                ForEach(zones) { score in
                    let shape = zonePath(score.zone, s)
                    shape
                        .fill(DQColor.accent.opacity(0.10 + (1 - Double(score.value) / 100) * 0.52))
                    shape
                        .stroke(
                            selected == score.zone ? DQColor.accentBright : DQColor.accent.opacity(0.28),
                            lineWidth: selected == score.zone ? 2 : 0.8
                        )
                    // Tap target (fill-independent).
                    shape
                        .fill(Color.white.opacity(0.001))
                        .contentShape(shape)
                        .onTapGesture { onTap(score.zone) }
                }
            }
            .animation(VMotion.snappy, value: selected)
        }
    }

    // MARK: Geometry (100 × 120 authoring space)

    private func pt(_ x: CGFloat, _ y: CGFloat, _ s: CGSize) -> CGPoint {
        CGPoint(x: x / 100 * s.width, y: y / 120 * s.height)
    }

    private func facePath(_ s: CGSize) -> Path {
        var p = Path()
        p.move(to: pt(50, 4, s))
        p.addCurve(to: pt(84, 52, s), control1: pt(74, 4, s), control2: pt(84, 26, s))
        p.addCurve(to: pt(50, 112, s), control1: pt(84, 82, s), control2: pt(70, 112, s))
        p.addCurve(to: pt(16, 52, s), control1: pt(30, 112, s), control2: pt(16, 82, s))
        p.addCurve(to: pt(50, 4, s), control1: pt(16, 26, s), control2: pt(26, 4, s))
        p.closeSubpath()
        return p
    }

    private func tiltedEllipse(cx: CGFloat, cy: CGFloat, rx: CGFloat, ry: CGFloat,
                               degrees: CGFloat, _ s: CGSize) -> Path {
        let center = pt(cx, cy, s)
        let rect = CGRect(x: center.x - rx / 100 * s.width,
                          y: center.y - ry / 120 * s.height,
                          width: rx * 2 / 100 * s.width,
                          height: ry * 2 / 120 * s.height)
        let rotate = CGAffineTransform(translationX: center.x, y: center.y)
            .rotated(by: degrees * .pi / 180)
            .translatedBy(x: -center.x, y: -center.y)
        return Path(ellipseIn: rect).applying(rotate)
    }

    private func zonePath(_ zone: DermiqZone, _ s: CGSize) -> Path {
        switch zone {
        case .forehead:
            // Lens band between hairline and brows.
            var p = Path()
            p.move(to: pt(26, 40, s))
            p.addCurve(to: pt(74, 40, s), control1: pt(34, 12, s), control2: pt(66, 12, s))
            p.addCurve(to: pt(26, 40, s), control1: pt(62, 33, s), control2: pt(38, 33, s))
            p.closeSubpath()
            return p
        case .eyes:
            var p = tiltedEllipse(cx: 35.5, cy: 45.5, rx: 9.5, ry: 5.0, degrees: -5, s)
            p.addPath(tiltedEllipse(cx: 64.5, cy: 45.5, rx: 9.5, ry: 5.0, degrees: 5, s))
            return p
        case .nose:
            // Keystone with a soft flare at the tip.
            var p = Path()
            p.move(to: pt(46.5, 44, s))
            p.addCurve(to: pt(53.5, 44, s), control1: pt(46.5, 42, s), control2: pt(53.5, 42, s))
            p.addLine(to: pt(56, 64, s))
            p.addCurve(to: pt(50, 75, s), control1: pt(59.5, 70.5, s), control2: pt(54, 75, s))
            p.addCurve(to: pt(44, 64, s), control1: pt(46, 75, s), control2: pt(40.5, 70.5, s))
            p.closeSubpath()
            return p
        case .cheeks:
            var p = tiltedEllipse(cx: 29.5, cy: 64.5, rx: 10, ry: 13.5, degrees: 14, s)
            p.addPath(tiltedEllipse(cx: 70.5, cy: 64.5, rx: 10, ry: 13.5, degrees: -14, s))
            return p
        case .chin:
            // Jaw-following blob.
            var p = Path()
            p.move(to: pt(37, 90, s))
            p.addCurve(to: pt(63, 90, s), control1: pt(41, 84, s), control2: pt(59, 84, s))
            p.addCurve(to: pt(50, 105, s), control1: pt(62, 100, s), control2: pt(55, 105, s))
            p.addCurve(to: pt(37, 90, s), control1: pt(45, 105, s), control2: pt(38, 100, s))
            p.closeSubpath()
            return p
        }
    }
}
