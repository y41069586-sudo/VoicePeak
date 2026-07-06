import CoreImage
import CoreGraphics
import UIKit
import Vision

/// CoreImage-based cosmetic simulation for the half-face preview.
///
/// Applies a subtle, texture-preserving "what could this product do" visual
/// to one half of the face image only. The other half stays pixel-perfect.
///
/// Uses landmark-guided masking to follow the face curvature instead of a straight split.
enum SimulationEngine {

    private static let context = CIContext(options: [
        .workingColorSpace: CGColorSpace(name: CGColorSpace.sRGB) as Any,
        .useSoftwareRenderer: false,
    ])

    // MARK: Public API

    /// Produce a simulated image where `side` has the treatment applied.
    ///
    /// - Parameters:
    ///   - image: The full-face capture.
    ///   - side: Which half receives the simulated effect.
    ///   - intensity: 0.0 (no change) … 1.0 (full effect). Default 0.65.
    ///   - midlineX: Normalized (0…1) x-position of the face midline.
    ///     When nil, the image centre is used.
    /// - Returns: The composited UIImage, or nil on CoreImage failure.
    static func simulate(
        image: UIImage,
        side: FaceSide,
        intensity: Double = 0.65,
        midlineX: Double? = nil
    ) async -> UIImage? {
        await Task.detached(priority: .userInitiated) {
            guard let cgImage = image.normalizedUp().cgImage else { return nil }
            return render(cgImage: cgImage, side: side, intensity: intensity, midlineX: midlineX, originalImage: image)
        }.value
    }

    // MARK: Render pipeline

    private static func render(cgImage: CGImage,
                               side: FaceSide,
                               intensity: Double,
                               midlineX: Double?,
                               originalImage: UIImage) -> UIImage? {
        let ci = CIImage(cgImage: cgImage)
        let extent = ci.extent
        let clampedIntensity = intensity.clamped01

        // Detect face landmarks for curvature-aware mask generation
        var faceObservation: VNFaceObservation? = nil
        let request = VNDetectFaceLandmarksRequest()
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        try? handler.perform([request])
        
        if let face = (request.results ?? []).max(by: { $0.boundingBox.height < $1.boundingBox.height }) {
            faceObservation = face
        }

        // 1. Build the mask: use FaceMaskGenerator if face landmarks are available, else fallback to naive split
        let maskImage: CIImage
        if let face = faceObservation, let maskCG = FaceMaskGenerator.generateSplitMask(imageSize: extent.size, face: face, side: side) {
            maskImage = CIImage(cgImage: maskCG)
        } else {
            let splitX = (midlineX ?? 0.5) * extent.width
            guard let fallbackMask = splitMask(extent: extent, splitX: CGFloat(splitX), side: side) else { return nil }
            maskImage = fallbackMask
        }

        // 2. Build the processed frame with high-pass texture preservation
        guard let processed = applyHighPassEffects(to: ci, intensity: clampedIntensity) else { return nil }

        // 3. Blend: processed on the treated side, original on the control side
        guard let blended = blend(original: ci, processed: processed, mask: maskImage) else { return nil }

        // 4. Render to CGImage and back to UIImage (preserves orientation)
        guard let output = context.createCGImage(blended, from: extent) else { return nil }
        return UIImage(cgImage: output, scale: originalImage.scale, orientation: originalImage.imageOrientation)
    }

    // MARK: High-Pass Effect chain

    /// Apply skin smoothing while preserving fine pores and texture details using frequency separation.
    private static func applyHighPassEffects(to image: CIImage, intensity: Double) -> CIImage? {
        // 1. Generate smoothed base image (removes color blemishes and redness)
        guard let smoothed = applyEffects(to: image, intensity: intensity) else { return image }
        
        // 2. Blur the original to isolate low-frequency tones
        guard let blurredOrig = CIFilter(name: "CIGaussianBlur", parameters: [
            kCIInputImageKey: image,
            kCIInputRadiusKey: Float(2.0)
        ])?.outputImage?.cropped(to: image.extent) else { return smoothed }
        
        // 3. Subtract low-frequency tones from original to get the high-frequency detail map:
        //    highPass = original - blurredOrig + 0.5
        let invertMatrix = blurredOrig.applyingFilter("CIColorMatrix", parameters: [
            "inputRVector": CIVector(x: -1, y: 0, z: 0, w: 0),
            "inputGVector": CIVector(x: 0, y: -1, z: 0, w: 0),
            "inputBVector": CIVector(x: 0, y: 0, z: -1, w: 0),
            "inputAVector": CIVector(x: 0, y: 0, z: 0, w: 1),
            "inputBiasVector": CIVector(x: 0.5, y: 0.5, z: 0.5, w: 0)
        ])
        
        guard let highPass = CIFilter(name: "CIOverlayBlendMode", parameters: [
            kCIInputImageKey: image,
            kCIInputBackgroundImageKey: invertMatrix
        ])?.outputImage else { return smoothed }
        
        // 4. Composite the detail map back onto the smoothed base using soft-light
        guard let blendedWithTexture = CIFilter(name: "CISoftLightBlendMode", parameters: [
            kCIInputImageKey: highPass,
            kCIInputBackgroundImageKey: smoothed
        ])?.outputImage else { return smoothed }
        
        return blendedWithTexture
    }

    private static func applyEffects(to image: CIImage, intensity: Double) -> CIImage? {
        var current = image

        // Step 1: Mild redness reduction (hue rotate warm/red tones toward neutral)
        if let hueFilter = CIFilter(name: "CIHueAdjust", parameters: [
            kCIInputImageKey: current,
            kCIInputAngleKey: Float(0.04 * intensity),
        ]) {
            current = hueFilter.outputImage ?? current
        }

        // Step 2: Brightness + saturation tweak -> fresher appearance
        if let colorCtrl = CIFilter(name: "CIColorControls", parameters: [
            kCIInputImageKey: current,
            kCIInputBrightnessKey: Float(0.025 * intensity),
            kCIInputSaturationKey: Float(1.0 - 0.04 * intensity),
            kCIInputContrastKey: Float(1.0 + 0.03 * intensity),
        ]) {
            current = colorCtrl.outputImage ?? current
        }

        // Step 3: Base blur for smoothing (blends out color variations, details restored later via high-pass)
        if let blurFilter = CIFilter(name: "CIGaussianBlur", parameters: [
            kCIInputImageKey: current,
            kCIInputRadiusKey: Float(0.85 * intensity),
        ]), let blurred = blurFilter.outputImage?.cropped(to: current.extent) {
            current = blurred
        }

        // Step 4: Subtle glow (bloom) -> soft luminosity highlight
        if let bloom = CIFilter(name: "CIBloom", parameters: [
            kCIInputImageKey: current,
            kCIInputRadiusKey: Float(3.5 * intensity),
            kCIInputIntensityKey: Float(0.10 * intensity),
        ]) {
            current = bloom.outputImage ?? current
        }

        // Step 5: Reduce specular shine
        if let hilightShadow = CIFilter(name: "CIHighlightShadowAdjust", parameters: [
            kCIInputImageKey: current,
            "inputHighlightAmount": Float(1.0 - 0.12 * intensity),
            "inputShadowAmount": Float(0.0),
        ]) {
            current = hilightShadow.outputImage ?? current
        }

        return current
    }

    // MARK: Fallback split mask

    private static func splitMask(extent: CGRect, splitX: CGFloat, side: FaceSide) -> CIImage? {
        let softness = extent.width * 0.05
        let (start, end): (CGPoint, CGPoint)
        let (startColor, endColor): (CIColor, CIColor)

        let white = CIColor.white, black = CIColor.black

        switch side {
        case .left:
            start = CGPoint(x: splitX - softness, y: extent.midY)
            end   = CGPoint(x: splitX + softness, y: extent.midY)
            (startColor, endColor) = (white, black)
        case .right:
            start = CGPoint(x: splitX - softness, y: extent.midY)
            end   = CGPoint(x: splitX + softness, y: extent.midY)
            (startColor, endColor) = (black, white)
        case .full:
            return CIImage(color: white).cropped(to: extent)
        }

        return CIFilter(name: "CISmoothLinearGradient", parameters: [
            "inputPoint0": CIVector(cgPoint: start),
            "inputPoint1": CIVector(cgPoint: end),
            "inputColor0": startColor,
            "inputColor1": endColor,
        ])?.outputImage?.cropped(to: extent)
    }

    // MARK: Blend

    private static func blend(original: CIImage, processed: CIImage, mask: CIImage) -> CIImage? {
        CIFilter(name: "CIBlendWithMask", parameters: [
            kCIInputImageKey: processed.cropped(to: original.extent),
            kCIInputBackgroundImageKey: original,
            kCIInputMaskImageKey: mask,
        ])?.outputImage
    }
}
