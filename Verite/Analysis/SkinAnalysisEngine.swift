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
