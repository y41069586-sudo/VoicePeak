import Foundation
import AVFoundation
import CoreImage
import CoreGraphics

/// Protocol that `CameraController` calls on every video frame (after throttling).
/// The monitor conforms to this and processes frames off the main thread.
protocol FrameConsumer: AnyObject {
    func didReceiveSampleBuffer(_ sampleBuffer: CMSampleBuffer)
}

/// Lightweight realtime skin monitor: produces stable per-attribute estimates from
/// the live video stream at ~5 Hz, without a full-face analysis run.
///
/// The approach:
///   1. Receive CMSampleBuffer from `CameraController` (off main thread).
///   2. Downscale to 64×64 px via a CIContext (fast).
///   3. Run a single-pass redness + shine + luma extraction — no Vision requests.
///   4. Apply `LiveSmoother` (EMA, α=0.18) to prevent flickering.
///   5. Publish `liveAttributes` on the MainActor.
///
/// This is intentionally less accurate than `SkinAnalysisCore`; it's a preview
/// metric that guides the user and makes the scanner feel alive, not the final read.
@Observable
final class RealtimeSkinMonitor: FrameConsumer, @unchecked Sendable {

    // MARK: Published state (read on MainActor)

    private(set) var liveAttributes: [SkinAttribute: Double] = [:]
    private(set) var isReady = false   // true once the first valid frame arrives

    // MARK: Private

    private let ciContext = CIContext(options: [
        .workingColorSpace: CGColorSpace(name: CGColorSpace.sRGB) as Any,
        .useSoftwareRenderer: false,
    ])
    private let smoother = LiveSmoother(alpha: 0.18)
    private var lastProcessed: CFTimeInterval = 0
    private let processInterval: CFTimeInterval = 0.20   // 5 Hz cap

    // MARK: FrameConsumer

    /// Called by `CameraController.captureOutput` on the video queue.
    /// Must be fast; heavy work is dispatched inline but stays off main.
    nonisolated func didReceiveSampleBuffer(_ sampleBuffer: CMSampleBuffer) {
        let now = CACurrentMediaTime()
        guard now - lastProcessed >= processInterval else { return }
        lastProcessed = now

        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        let raw = extractMetrics(from: pixelBuffer)

        Task { @MainActor [weak self] in
            guard let self else { return }
            self.liveAttributes = raw
            self.isReady = true
        }
    }

    // MARK: Extraction

    private func extractMetrics(from pixelBuffer: CVPixelBuffer) -> [SkinAttribute: Double] {
        let ci = CIImage(cvPixelBuffer: pixelBuffer)
        let extent = ci.extent

        // Downscale to 64×64 for speed.
        let targetSize = CGSize(width: 64, height: 64)
        let scaleX = targetSize.width / extent.width
        let scaleY = targetSize.height / extent.height
        let scaled = ci.transformed(by: CGAffineTransform(scaleX: scaleX, y: scaleY))

        // Render to a bitmap.
        var bytes = [UInt8](repeating: 0, count: 64 * 64 * 4)
        ciContext.render(scaled,
                         toBitmap: &bytes,
                         rowBytes: 64 * 4,
                         bounds: CGRect(origin: .zero, size: targetSize),
                         format: .RGBA8,
                         colorSpace: CGColorSpaceCreateDeviceRGB())

        // Single-pass metrics.
        var sumRed = 0.0, sumLuma = 0.0, shineCount = 0
        let n = 64 * 64

        for i in stride(from: 0, to: n * 4, by: 4) {
            let r = Double(bytes[i])
            let g = Double(bytes[i + 1])
            let b = Double(bytes[i + 2])
            let luma = 0.299 * r + 0.587 * g + 0.114 * b
            sumLuma += luma
            sumRed += max(0, r - (g + b) / 2)
            let maxC = max(r, max(g, b))
            let minC = min(r, min(g, b))
            let sat = maxC > 0 ? (maxC - minC) / maxC : 0
            if luma >= 208, sat <= 0.20 { shineCount += 1 }
        }

        let meanLuma = sumLuma / Double(n)
        let redness = smoother.smooth((sumRed / Double(n) / 34.0).clamped01, for: .redness)
        let oiliness = smoother.smooth((Double(shineCount) / Double(n)).clamped01, for: .oiliness)
        let radiance = smoother.smooth((meanLuma / 255.0).clamped01, for: .hydration)

        // The live monitor only estimates the three most visually responsive
        // attributes — the rest need a full landmark-based analysis pass.
        return [
            .redness: redness,
            .oiliness: oiliness,
            .hydration: radiance,
        ]
    }
}
