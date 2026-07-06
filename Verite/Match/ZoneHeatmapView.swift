import SwiftUI
import UIKit

/// Overlays the predicted risk/benefit zones on the user's **real** scan — green
/// where a product likely helps, red where it may irritate. This is an honest
/// prediction heatmap, never a fabricated "after" photo.
struct ZoneHeatmapView: View {
    let image: UIImage
    let zones: [FaceRegion: ZoneLevel]

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: geo.size.width, height: geo.size.height)
                    .clipped()

                ForEach(FaceRegion.allCases, id: \.self) { region in
                    if let color = zones[region]?.color {
                        let center = Self.center(for: region)
                        Ellipse()
                            .fill(color.opacity(0.45))
                            .frame(width: geo.size.width * 0.36, height: geo.size.height * 0.24)
                            .blur(radius: 18)
                            .blendMode(.plusLighter)
                            .position(x: geo.size.width * center.x, y: geo.size.height * center.y)
                    }
                }
            }
            .drawingGroup()
        }
        .aspectRatio(3.0 / 4.0, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(Theme.strokeSubtle, lineWidth: 1))
        .accessibilityLabel("match.section.heatmap")
    }

    /// Normalized centers of each zone on a standardized, centered face capture.
    static func center(for region: FaceRegion) -> CGPoint {
        switch region {
        case .forehead:   return CGPoint(x: 0.50, y: 0.22)
        case .leftCheek:  return CGPoint(x: 0.32, y: 0.56)
        case .rightCheek: return CGPoint(x: 0.68, y: 0.56)
        case .nose:       return CGPoint(x: 0.50, y: 0.50)
        case .chin:       return CGPoint(x: 0.50, y: 0.80)
        case .underEye:   return CGPoint(x: 0.50, y: 0.36)
        }
    }
}

/// The green/red legend shown under the heatmap.
struct HeatmapLegend: View {
    var body: some View {
        HStack(spacing: 16) {
            legendItem(color: Theme.success, key: "match.heatmap.legend.help")
            legendItem(color: Theme.danger, key: "match.heatmap.legend.irritate")
        }
        .font(.caption2)
    }

    private func legendItem(color: Color, key: LocalizedStringKey) -> some View {
        HStack(spacing: 5) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(key).foregroundStyle(Theme.textSecondary)
        }
    }
}
