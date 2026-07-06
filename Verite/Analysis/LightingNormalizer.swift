import CoreImage
import CoreGraphics

/// Quality tiers for evaluation during the image pre-pass
enum FrameQuality: String, Sendable {
    case excellent
    case acceptable
    case poor
    case reject
}

/// Pre-pass lighting normalization applied to captured frames before pixel analysis.
///
/// Purpose: make per-attribute estimates consistent across different lighting
/// conditions (office fluorescent vs. window daylight vs. warm evening light).
///
/// Uses CoreImage only — no Metal, no GPU shaders, runs safely on a background task.
/// The approach: shift exposure toward a target luma, do a mild white-balance
/// correction, then validate the frame is usable (not blurry, not clipped).
enum LightingNormalizer {

    // MARK: Target calibration

    /// Ideal mean luma for analysis (approximately 50 % grey, in 0…1).
    private static let targetLuma: Double = 0.48
    /// Max EV adjustment we allow (±1.5 stops). Beyond this, reject the frame.
    private static let maxEVAdjust: Float = 1.5
    /// Frames brighter than this are overexposed — reject.
    private static let overexposureThreshold: Double = 0.92
    /// Frames darker than this are underexposed — reject.
    private static let underexposureThreshold: Double = 0.15
    /// Laplacian-variance threshold below which the frame is too blurry to use.
    private static let blurThreshold: Double = 4.0
    /// Shared CI context — reused across calls to avoid repeated GPU context setup.
    private static let ciContext = CIContext(options: [
        .workingColorSpace: CGColorSpace(name: CGColorSpace.sRGB) as Any,
        .useSoftwareRenderer: false,
    ])

    // MARK: Public API

    /// Classify frame quality based on exposure, blur, and lighting evenness.
    ///
    /// - Parameters:
    ///   - image: The raw CGImage source frame.
    ///   - faceRect: The face bounding box in normalized/vision space, if known.
    /// - Returns: The classified FrameQuality.
    static func classify(image: CGImage, faceRect: CGRect? = nil) -> FrameQuality {
        let luma = meanLuma(image)

        // Rule 1: Reject if extreme underexposure or overexposure.
        if luma < underexposureThreshold || luma > overexposureThreshold {
            return .reject
        }

        // Rule 2: Reject if significant motion blur.
        if isBlurry(image) {
            return .reject
        }

        // Rule 3: Downgrade to poor if uneven lighting is detected across the face.
        if let face = faceRect {
            if isLightingUneven(image, faceRect: face) {
                return .poor
            }
        }

        // Rule 4: Mark excellent if close to our ideal 0.48 target luma.
        if abs(luma - targetLuma) <= 0.12 {
            return .excellent
        }

        return .acceptable
    }

    /// Normalize `image` for analysis and evaluate whether it is usable.
    ///
    /// - Returns: A tuple of the normalized `CGImage` and an `isAcceptable` flag.
    ///   When `isAcceptable` is false the image should be discarded and the scan
    ///   retried (typically because of extreme lighting or motion blur).
    static func normalize(_ image: CGImage) -> (image: CGImage, isAcceptable: Bool) {
        let quality = classify(image: image)
        guard quality != .reject else {
            return (image, isAcceptable: false)
        }

        let luma = meanLuma(image)

        // Apply exposure correction to bring luma toward target.
        let evShift = evAdjustment(currentLuma: luma)
        guard let adjusted = applyExposure(image, ev: evShift) else {
            return (image, isAcceptable: true)
        }

        // Apply a mild white-balance neutralization.
        let balanced = applyWhiteBalance(adjusted) ?? adjusted

        return (balanced, isAcceptable: true)
    }

    // MARK: Luma helpers

    /// Fast mean luma via a 1×1 CIAreaAverage reduction. Returns 0…1.
    static func meanLuma(_ image: CGImage) -> Double {
        let ci = CIImage(cgImage: image)
        guard let filter = CIFilter(name: "CIAreaAverage", parameters: [
            kCIInputImageKey: ci,
            kCIInputExtentKey: CIVector(cgRect: ci.extent),
        ]), let output = filter.outputImage else { return 0 }

        var bitmap = [UInt8](repeating: 0, count: 4)
        ciContext.render(output,
                         toBitmap: &bitmap,
                         rowBytes: 4,
                         bounds: CGRect(x: 0, y: 0, width: 1, height: 1),
                         format: .RGBA8,
                         colorSpace: CGColorSpaceCreateDeviceRGB())
        let r = Double(bitmap[0]), g = Double(bitmap[1]), b = Double(bitmap[2])
        return (0.299 * r + 0.587 * g + 0.114 * b) / 255.0
    }

    // MARK: Blur detection

    /// Returns true when the frame is too blurry for reliable analysis.
    /// Uses a fast Laplacian-variance estimate on a 48×48 downscale.
    static func isBlurry(_ image: CGImage) -> Bool {
        guard let small = Sampling.read(image, maxDim: 48) else { return false }
        let variance = laplacianVariance(small)
        return variance < blurThreshold
    }

    // MARK: Lighting evenness check

    /// Returns true if the difference in lighting between the left and right halves of the face exceeds 20%.
    static func isLightingUneven(_ image: CGImage, faceRect: CGRect) -> Bool {
        let w = Double(image.width)
        let h = Double(image.height)
        let pixelRect = Sampling.pixelRect(fromVision: faceRect, imageWidth: Int(w), imageHeight: Int(h))

        let halfWidth = pixelRect.width / 2
        let leftRect = CGRect(x: pixelRect.minX, y: pixelRect.minY, width: halfWidth, height: pixelRect.height)
        let rightRect = CGRect(x: pixelRect.minX + halfWidth, y: pixelRect.minY, width: halfWidth, height: pixelRect.height)

        guard let leftBuffer = Sampling.readPixels(image, rect: leftRect, maxDim: 32),
              let rightBuffer = Sampling.readPixels(image, rect: rightRect, maxDim: 32) else {
            return false
        }

        let leftLuma = bufferMeanLuma(leftBuffer)
        let rightLuma = bufferMeanLuma(rightBuffer)

        return abs(leftLuma - rightLuma) > 0.20
    }

    private static func bufferMeanLuma(_ buffer: PixelBuffer) -> Double {
        var sum = 0.0
        let n = buffer.count
        for y in 0..<buffer.height {
            for x in 0..<buffer.width {
                let (r, g, b) = buffer.rgb(x, y)
                sum += 0.299 * r + 0.587 * g + 0.114 * b
            }
        }
        return sum / Double(n) / 255.0
    }

    // MARK: Private helpers

    private static func evAdjustment(currentLuma: Double) -> Float {
        guard currentLuma > 0 else { return 0 }
        let ev = log2(targetLuma / currentLuma)
        return Float(ev.clamped(to: -Double(maxEVAdjust) ... Double(maxEVAdjust)))
    }

    private static func applyExposure(_ image: CGImage, ev: Float) -> CGImage? {
        guard abs(ev) > 0.05 else { return image }
        let ci = CIImage(cgImage: image)
        guard let filter = CIFilter(name: "CIExposureAdjust", parameters: [
            kCIInputImageKey: ci,
            kCIInputEVKey: ev,
        ]), let output = filter.outputImage else { return nil }
        return ciContext.createCGImage(output, from: output.extent)
    }

    private static func applyWhiteBalance(_ image: CGImage) -> CGImage? {
        let ci = CIImage(cgImage: image)
        guard let filter = CIFilter(name: "CITemperatureAndTint", parameters: [
            kCIInputImageKey: ci,
            "inputNeutral": CIVector(x: 6500, y: 0),
            "inputTargetNeutral": CIVector(x: 6500, y: 0),
        ]), let output = filter.outputImage else { return nil }
        return ciContext.createCGImage(output, from: output.extent)
    }

    private static func laplacianVariance(_ buffer: PixelBuffer) -> Double {
        let w = buffer.width, h = buffer.height
        guard w >= 3, h >= 3 else { return 0 }
        var luma = [Double](repeating: 0, count: w * h)
        for y in 0..<h {
            for x in 0..<w {
                let (r, g, b) = buffer.rgb(x, y)
                luma[y * w + x] = 0.299 * r + 0.587 * g + 0.114 * b
            }
        }
        var sum = 0.0, sumSq = 0.0, count = 0
        for y in 1..<(h - 1) {
            for x in 1..<(w - 1) {
                let lap = abs(4 * luma[y * w + x]
                    - luma[y * w + x - 1]
                    - luma[y * w + x + 1]
                    - luma[(y - 1) * w + x]
                    - luma[(y + 1) * w + x])
                sum += lap
                sumSq += lap * lap
                count += 1
            }
        }
        guard count > 0 else { return 0 }
        let mean = sum / Double(count)
        return sumSq / Double(count) - mean * mean
    }
}

private extension Double {
    func clamped(to range: ClosedRange<Double>) -> Double {
        Swift.min(Swift.max(self, range.lowerBound), range.upperBound)
    }
}
