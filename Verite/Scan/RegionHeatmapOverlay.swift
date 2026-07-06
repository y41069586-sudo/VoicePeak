import SwiftUI

/// Color mapping for region heatmap overlays.
enum HeatmapColorScheme {
    /// Concern heatmap: low → teal, mid → amber, high → coral/red.
    case concern
    /// Benefit heatmap: low → neutral, mid → soft green, high → vibrant green.
    case benefit
    /// Match-zone: risk is red, benefit is green, neutral is invisible.
    case matchZone
}

/// Renders a semi-transparent heatmap of per-region skin values over the face oval.
///
/// The overlay draws filled, blurred ellipses for each `FaceRegion`, sized
/// proportionally to the face oval and positioned via the same fractional
/// coordinate system used by `FaceRegion.fractionalRect`.
///
/// Usage:
/// ```swift
/// RegionHeatmapOverlay(regionValues: [.forehead: 0.8, .nose: 0.6], colorScheme: .concern)
///     .frame(width: ovalWidth, height: ovalHeight)
/// ```
struct RegionHeatmapOverlay: View {
    let regionValues: [FaceRegion: Double]
    var colorScheme: HeatmapColorScheme = .concern
    var opacity: Double = 0.55

    var body: some View {
        GeometryReader { geo in
            ZStack {
                ForEach(FaceRegion.allCases, id: \.rawValue) { region in
                    if let value = regionValues[region], value > 0.01 {
                        regionBlob(region: region, value: value, size: geo.size)
                    }
                }
            }
        }
        .allowsHitTesting(false)
        .animation(.easeInOut(duration: 0.6), value: regionValues.values.map { $0 })
    }

    // MARK: Private helpers

    private func regionBlob(region: FaceRegion, value: Double, size: CGSize) -> some View {
        let frac = region.fractionalRect
        let cx = (frac.x0 + frac.x1) / 2 * size.width
        let cy = (frac.y0 + frac.y1) / 2 * size.height
        let w  = (frac.x1 - frac.x0) * size.width  * 1.1   // slight bleed
        let h  = (frac.y1 - frac.y0) * size.height * 1.1

        let color = blobColor(value: value)
        let blurRadius: CGFloat = max(8, min(w, h) * 0.35)

        return Ellipse()
            .fill(
                RadialGradient(
                    colors: [color.opacity(opacity * 0.9), color.opacity(0)],
                    center: .center,
                    startRadius: 0,
                    endRadius: max(w, h) * 0.55
                )
            )
            .frame(width: w, height: h)
            .blur(radius: blurRadius)
            .position(x: cx, y: cy)
    }

    private func blobColor(value: Double) -> Color {
        switch colorScheme {
        case .concern:
            // 0…0.35 → teal, 0.35…0.65 → amber, 0.65…1 → coral
            if value < 0.35 { return Color(hue: 0.49, saturation: 0.7, brightness: 0.85) }
            if value < 0.65 { return Color(hue: 0.10, saturation: 0.9, brightness: 0.95) }
            return Color(hue: 0.03, saturation: 0.85, brightness: 0.95)

        case .benefit:
            // Scales from near-invisible gray to vivid green.
            return Color(hue: 0.38, saturation: 0.55 + value * 0.35, brightness: 0.75 + value * 0.2)

        case .matchZone:
            // Used by ZoneHeatmapView — caller maps ZoneLevel to a 0/0.5/1 value.
            if value < 0.4 { return Color.clear }
            if value < 0.6 { return Theme.warning.opacity(0.5) }
            return value > 0.8 ? Theme.danger : Theme.success
        }
    }
}

// MARK: - Convenience: build regionValues from ScanAnalysis

extension RegionHeatmapOverlay {
    /// Build a concern heatmap from the analysis engine's region output.
    /// Picks the most visually impactful attribute per region.
    static func concernMap(from regions: [String: RegionMetrics],
                           attribute keyPath: KeyPath<RegionMetrics, Double>) -> [FaceRegion: Double] {
        var result: [FaceRegion: Double] = [:]
        for region in FaceRegion.allCases {
            if let m = regions[region.rawValue] {
                result[region] = m[keyPath: keyPath]
            }
        }
        return result
    }

    /// Build a zone map from a `MatchResult` for the product-match heatmap.
    static func zoneMap(from zones: [FaceRegion: ZoneLevel]) -> [FaceRegion: Double] {
        zones.compactMapValues { level in
            switch level {
            case .risk: return 1.0
            case .neutral: return 0.0
            case .benefit: return 0.75
            }
        }
    }
}
