import SwiftUI
import Foundation
import Vision
import CoreGraphics

/// Observable façade over the analysis pipeline, so the UI can show an
/// "analyzing…" state. The heavy work runs on a background task via
/// `SkinAnalysisCore` (pure, testable, no main-thread contact).
@Observable
final class SkinAnalysisEngine {
    private(set) var isAnalyzing = false

    func analyze(cgImage: CGImage, captureQuality: Double) async -> ScanAnalysis {
        isAnalyzing = true
        defer { isAnalyzing = false }
        return await Task.detached(priority: .userInitiated) {
            SkinAnalysisCore.analyze(cgImage: cgImage, captureQuality: captureQuality)
        }.value
    }

    /// Per-side analysis for the half-face test (left vs right, each vs its own baseline).
    func analyzeSides(cgImage: CGImage) async -> SideAnalysis {
        isAnalyzing = true
        defer { isAnalyzing = false }
        return await Task.detached(priority: .userInitiated) {
            SkinAnalysisCore.analyzeSides(cgImage: cgImage)
        }.value
    }
}

/// The classical-CV pipeline: Vision face + landmarks → region rects → per-region
/// metrics → aggregated per-attribute estimates. Documented heuristics only; every
/// output is an estimate, tracked as change vs the user's own baseline.
enum SkinAnalysisCore {

    static func analyze(cgImage: CGImage, captureQuality: Double) -> ScanAnalysis {
        let w = cgImage.width, h = cgImage.height

        // 1. Face + landmarks (largest face).
        let request = VNDetectFaceLandmarksRequest()
        let handler = VNImageRequestHandler(cgImage: cgImage, orientation: .up, options: [:])
        try? handler.perform([request])
        guard let face = (request.results ?? []).max(by: { $0.boundingBox.height < $1.boundingBox.height }) else {
            return .empty
        }

        let faceRect = Sampling.pixelRect(fromVision: face.boundingBox, imageWidth: w, imageHeight: h)

        // 2. Sample each region.
        var regions: [FaceRegion: RegionMetrics] = [:]
        for region in FaceRegion.allCases {
            let rect = Sampling.regionRect(in: faceRect, region.fractionalRect)
            if let buffer = Sampling.readPixels(cgImage, rect: rect) {
                regions[region] = SkinMetrics.metrics(for: buffer)
            }
        }
        guard !regions.isEmpty else { return .empty }

        // 3. Aggregate region metrics → per-attribute estimates.
        let attributes = aggregate(regions)

        // 4. Left/right midline from eye landmarks (for the half-face test).
        let midlineX = eyeMidlineX(of: face)

        let stringKeyed = Dictionary(uniqueKeysWithValues: regions.map { ($0.key.rawValue, $0.value) })
        return ScanAnalysis(attributes: attributes, regions: stringKeyed, faceFound: true, midlineX: midlineX)
    }

    // MARK: Per-side analysis (half-face test)

    /// Analyze the left and right halves of the face independently. Splits the
    /// central regions (forehead/chin) at the midline and reads each cheek.
    static func analyzeSides(cgImage: CGImage) -> SideAnalysis {
        let w = cgImage.width, h = cgImage.height
        let request = VNDetectFaceLandmarksRequest()
        let handler = VNImageRequestHandler(cgImage: cgImage, orientation: .up, options: [:])
        try? handler.perform([request])
        guard let face = (request.results ?? []).max(by: { $0.boundingBox.height < $1.boundingBox.height }) else {
            return .empty
        }
        let faceRect = Sampling.pixelRect(fromVision: face.boundingBox, imageWidth: w, imageHeight: h)

        func metrics(_ f: (Double, Double, Double, Double)) -> RegionMetrics? {
            let rect = Sampling.regionRect(in: faceRect, (x0: f.0, y0: f.1, x1: f.2, y1: f.3))
            guard let buffer = Sampling.readPixels(cgImage, rect: rect) else { return nil }
            return SkinMetrics.metrics(for: buffer)
        }

        let leftCheek = metrics((0.12, 0.44, 0.36, 0.68))
        let leftForehead = metrics((0.28, 0.06, 0.50, 0.22))
        let leftChin = metrics((0.36, 0.80, 0.50, 0.95))
        let rightCheek = metrics((0.64, 0.44, 0.88, 0.68))
        let rightForehead = metrics((0.50, 0.06, 0.72, 0.22))
        let rightChin = metrics((0.50, 0.80, 0.64, 0.95))
        let nose = metrics((0.43, 0.32, 0.57, 0.60))

        guard leftCheek != nil || rightCheek != nil else { return .empty }

        return SideAnalysis(
            left: sideAttributes(cheek: leftCheek, forehead: leftForehead, chin: leftChin, nose: nose),
            right: sideAttributes(cheek: rightCheek, forehead: rightForehead, chin: rightChin, nose: nose),
            faceFound: true
        )
    }

    private static func sideAttributes(cheek: RegionMetrics?, forehead: RegionMetrics?,
                                       chin: RegionMetrics?, nose: RegionMetrics?) -> [SkinAttribute: Double] {
        func wavg(_ pairs: [(RegionMetrics?, Double, KeyPath<RegionMetrics, Double>)]) -> Double {
            var sum = 0.0, weight = 0.0
            for (metrics, w, keyPath) in pairs {
                if let metrics { sum += metrics[keyPath: keyPath] * w; weight += w }
            }
            return weight > 0 ? (sum / weight).clamped01 : 0
        }

        let redness = wavg([(cheek, 0.5, \.redness), (forehead, 0.25, \.redness), (chin, 0.25, \.redness)])
        let texture = wavg([(cheek, 0.5, \.texture), (forehead, 0.5, \.texture)])
        let pores = wavg([(cheek, 0.6, \.pores), (nose, 0.4, \.pores)])
        let blemishes = wavg([(cheek, 0.4, \.spots), (forehead, 0.3, \.spots), (chin, 0.3, \.spots)])
        let oiliness = wavg([(forehead, 0.5, \.shine), (nose, 0.5, \.shine)])
        let radiance = wavg([(cheek, 0.6, \.radiance), (forehead, 0.4, \.radiance)])
        let hydration = (0.6 * radiance + 0.4 * (1 - texture)).clamped01
        let reds = [cheek, forehead, chin].compactMap { $0?.redness }
        let sensitivity = (0.6 * redness + 0.4 * unevenness(reds)).clamped01

        return [
            .redness: redness, .oiliness: oiliness, .texture: texture, .pores: pores,
            .blemishes: blemishes, .hydration: hydration, .sensitivity: sensitivity,
        ]
    }

    // MARK: Aggregation

    private static func aggregate(_ r: [FaceRegion: RegionMetrics]) -> [SkinAttribute: Double] {
        func value(_ region: FaceRegion, _ keyPath: KeyPath<RegionMetrics, Double>) -> Double {
            r[region]?[keyPath: keyPath] ?? 0
        }
        func weighted(_ pairs: [(FaceRegion, Double)], _ keyPath: KeyPath<RegionMetrics, Double>) -> Double {
            var sum = 0.0, weight = 0.0
            for (region, w) in pairs where r[region] != nil {
                sum += value(region, keyPath) * w
                weight += w
            }
            return weight > 0 ? (sum / weight).clamped01 : 0
        }

        let redness = weighted([(.leftCheek, 0.4), (.rightCheek, 0.4), (.chin, 0.1), (.forehead, 0.1)], \.redness)
        let oiliness = weighted([(.forehead, 0.5), (.nose, 0.5)], \.shine)
        let texture = weighted([(.leftCheek, 0.35), (.rightCheek, 0.35), (.forehead, 0.30)], \.texture)
        let pores = weighted([(.nose, 0.5), (.leftCheek, 0.25), (.rightCheek, 0.25)], \.pores)
        let blemishes = weighted(FaceRegion.allCases.map { ($0, 1.0) }, \.spots)
        let radiance = weighted([(.leftCheek, 0.4), (.rightCheek, 0.4), (.forehead, 0.2)], \.radiance)

        // Hydration proxy: bright + smooth reads as more hydrated (higher = better).
        let hydration = (0.6 * radiance + 0.4 * (1 - texture)).clamped01

        // Sensitivity: overall redness plus how *uneven* redness is across regions.
        let rednessValues = FaceRegion.allCases.compactMap { r[$0]?.redness }
        let sensitivity = (0.6 * redness + 0.4 * unevenness(rednessValues)).clamped01

        return [
            .redness: redness,
            .oiliness: oiliness,
            .texture: texture,
            .pores: pores,
            .blemishes: blemishes,
            .hydration: hydration,
            .sensitivity: sensitivity,
        ]
    }

    /// Normalized dispersion (0...1) of a set of values — a rough "unevenness".
    private static func unevenness(_ values: [Double]) -> Double {
        guard values.count > 1 else { return 0 }
        let mean = values.reduce(0, +) / Double(values.count)
        let variance = values.reduce(0) { $0 + ($1 - mean) * ($1 - mean) } / Double(values.count)
        return (sqrt(variance) * 2).clamped01
    }

    // MARK: Landmarks

    private static func eyeMidlineX(of face: VNFaceObservation) -> Double? {
        guard let landmarks = face.landmarks,
              let left = landmarks.leftEye, let right = landmarks.rightEye else { return nil }
        func centroidX(_ points: [CGPoint]) -> CGFloat {
            guard !points.isEmpty else { return 0.5 }
            return points.reduce(0) { $0 + $1.x } / CGFloat(points.count)
        }
        // Landmark points are normalized within the face box; convert to image-x.
        let midInBox = (centroidX(left.normalizedPoints) + centroidX(right.normalizedPoints)) / 2
        return Double(face.boundingBox.minX + midInBox * face.boundingBox.width)
    }
}
