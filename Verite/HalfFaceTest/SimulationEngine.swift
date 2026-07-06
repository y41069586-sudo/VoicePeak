import CoreImage
import CoreGraphics
import UIKit

/// CoreImage-based cosmetic simulation for the half-face preview.
///
/// Applies a subtle, texture-preserving "what could this product do" visual
/// to one half of the face image only. The other half stays pixel-perfect.
///
/// **What this is NOT:**
/// - A medical prediction.
/// - An AI hallucination.
/// - A beauty filter.
///
/// **What this is:**
/// A cosmetic visualization that simulates reduced redness, smoother
/// texture, calmer shine and a subtle glow — the kind of visible
/// improvement associated with consistent, well-formulated skincare.
///
/// All effects are blended via a soft gradient mask so the split is
/// imperceptible at the edge; texture (pores, micro-detail) is preserved
/// by blending the smoothed output at ≤ 30 %.
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
            return render(cgImage: cgImage, side: side, intensity: intensity, midlineX: midlineX)
        }.value
    }

    // MARK: Render pipeline

    private static func render(cgImage: CGImage,
                               side: FaceSide,
                               intensity: Double,
                               midlineX: Double?) -> UIImage? {
        let ci = CIImage(cgImage: cgImage)
        let extent = ci.extent
        let clampedIntensity = intensity.clamped01

        // 1. Build the processed half.
        guard let processed = applyEffects(to: ci, intensity: clampedIntensity) else { return nil }

        // 2. Build a gradient mask that softly separates left / right.
        let splitX = (midlineX ?? 0.5) * extent.width
        guard let mask = splitMask(extent: extent, splitX: CGFloat(splitX), side: side) else { return nil }

        // 3. Blend: processed on the treated side, original on the control side.
        guard let blended = blend(original: ci, processed: processed, mask: mask) else { return nil }

        // 4. Render to CGImage and back to UIImage (preserves orientation).
        guard let output = context.createCGImage(blended, from: extent) else { return nil }
        return UIImage(cgImage: output, scale: image.scale, orientation: image.imageOrientation)
    }

    // MARK: Effect chain

    private static func applyEffects(to image: CIImage, intensity: Double) -> CIImage? {
        var current = image

        // Step 1: Mild redness reduction (hue rotate warm/red tones toward neutral).
        if let hueFilter = CIFilter(name: "CIHueAdjust", parameters: [
            kCIInputImageKey: current,
            kCIInputAngleKey: Float(0.04 * intensity),   // very subtle push away from warm red
        ]) {
            current = hueFilter.outputImage ?? current
        }

        // Step 2: Brightness + saturation tweak → fresher, less tired appearance.
        if let colorCtrl = CIFilter(name: "CIColorControls", parameters: [
            kCIInputImageKey: current,
            kCIInputBrightnessKey: Float(0.025 * intensity),
            kCIInputSaturationKey: Float(1.0 - 0.04 * intensity),
            kCIInputContrastKey: Float(1.0 + 0.03 * intensity),
        ]) {
            current = colorCtrl.outputImage ?? current
        }

        // Step 3: Texture-preserving bilateral-approximate smooth.
        //   Full Gaussian at small radius + blend 25% with original → softens without destroying pores.
        if let blurFilter = CIFilter(name: "CIGaussianBlur", parameters: [
            kCIInputImageKey: current,
            kCIInputRadiusKey: Float(0.7 * intensity),
        ]), let blurred = blurFilter.outputImage {
            // Blend: mostly original (texture preserved), slightly smoothed.
            let blendAmount = Float(0.22 * intensity)
            if let blendFilter = CIFilter(name: "CIBlend", parameters: [
                kCIInputImageKey: blurred,
                kCIInputBackgroundImageKey: current,
            ]) {
                // CIBlend replaces — use CIColorMatrix to lerp manually.
                // Simpler: use CISourceAtopCompositing with alpha-scaled processed.
                let alphaScaled = blurred.applyingFilter("CIColorMatrix", parameters: [
                    "inputAVector": CIVector(x: 0, y: 0, z: 0, w: CGFloat(blendAmount)),
                ])
                _ = blendFilter  // unused after simpler approach below
                if let composited = CIFilter(name: "CISourceAtopCompositing", parameters: [
                    kCIInputImageKey: alphaScaled,
                    kCIInputBackgroundImageKey: current,
                ])?.outputImage {
                    current = composited
                }
            }
        }

        // Step 4: Subtle glow (bloom) — adds a soft luminosity highlight.
        if let bloom = CIFilter(name: "CIBloom", parameters: [
            kCIInputImageKey: current,
            kCIInputRadiusKey: Float(3.5 * intensity),
            kCIInputIntensityKey: Float(0.10 * intensity),
        ]) {
            current = bloom.outputImage ?? current
        }

        // Step 5: Reduce specular shine.
        if let hilightShadow = CIFilter(name: "CIHighlightShadowAdjust", parameters: [
            kCIInputImageKey: current,
            "inputHighlightAmount": Float(1.0 - 0.12 * intensity),
            "inputShadowAmount": Float(0.0),
        ]) {
            current = hilightShadow.outputImage ?? current
        }

        return current
    }

    // MARK: Mask

    /// A CIImage gradient mask that smoothly isolates one half of the frame.
    private static func splitMask(extent: CGRect, splitX: CGFloat, side: FaceSide) -> CIImage? {
        // Soft gradient ±5 % of image width at the split.
        let softness = extent.width * 0.05
        let (start, end): (CGPoint, CGPoint)
        let (startColor, endColor): (CIColor, CIColor)

        let white = CIColor.white, black = CIColor.black

        switch side {
        case .left:
            // Left side = processed (white mask); right = original (black mask).
            start = CGPoint(x: splitX - softness, y: extent.midY)
            end   = CGPoint(x: splitX + softness, y: extent.midY)
            (startColor, endColor) = (white, black)
        case .right:
            start = CGPoint(x: splitX - softness, y: extent.midY)
            end   = CGPoint(x: splitX + softness, y: extent.midY)
            (startColor, endColor) = (black, white)
        case .full:
            // Full face — use an all-white mask.
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
