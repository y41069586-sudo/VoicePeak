import UIKit
import CoreImage
import CoreImage.CIFilterBuiltins
import Vision

// ============================================================
// MARK: — Config (MASTER PROMPT §2)
// ============================================================

/// Empty values ⇒ the factory serves the mock engines so every screen is
/// fully demo-able without the live APIs.
enum DermiqConfig {
    /// Live analysis = Perfect Corp YouCam AI API. The keys live in
    /// `DermiqSecrets` (committed empty, overwritten by CI from the
    /// PERFECTCORP_API_KEY / PERFECTCORP_RSA_KEY Codemagic variables).
    static var hasLiveAnalysis: Bool {
        !DermiqSecrets.perfectCorpAPIKey.isEmpty
            && !DermiqSecrets.perfectCorpRSAPublicKey.isEmpty
    }

    /// Live "Potential" enhancement = Google Gemini (gemini-2.5-flash-image).
    /// Key lives in `DermiqSecrets` (CI-injected from GEMINI_API_KEY).
    static var hasLiveEnhancement: Bool { !DermiqSecrets.geminiAPIKey.isEmpty }
}

// ============================================================
// MARK: — Analysis engine (Dermiq)
// ============================================================

/// The master prompt's `SkinAnalysisEngine` protocol (renamed: that identifier
/// belongs to the legacy v1 pipeline in this module).
protocol DermiqAnalysisEngine: Sendable {
    func analyze(image: UIImage) async throws -> DermiqAnalysis
}

enum DermiqEngineError: Error {
    case badResponse
    case notConfigured
}

// The production conformance is `PerfectCorpSkinEngine` (PerfectCorpEngine.swift).

/// Realistic fixture data so the full app runs end-to-end without the API.
/// Calibrated per §4: most results land 55–75; above 85 is rare.
final class MockDermiqEngine: DermiqAnalysisEngine {
    /// When rescanning, the mock trends upward from the previous overall so
    /// the delta screen demos honestly.
    private let previousOverall: Int?

    init(previousOverall: Int? = nil) {
        self.previousOverall = previousOverall
    }

    func analyze(image: UIImage) async throws -> DermiqAnalysis {
        try? await Task.sleep(for: .milliseconds(1400)) // realistic latency

        let overall: Int
        if let previousOverall {
            overall = min(previousOverall + Int.random(in: 3...9), 92)
        } else {
            overall = Int.random(in: 55...75)
        }

        let subScores: [DermiqSubScore] = DermiqCategory.allCases.map { category in
            let spread = Int.random(in: -14...12)
            return DermiqSubScore(
                category: category,
                value: max(30, min(95, overall + spread)),
                trend: nil
            )
        }

        let weakest = subScores.sorted { $0.value < $1.value }
        let topIssues = weakest.prefix(3).map { DermiqIssue.issue(for: $0.category) }

        return DermiqAnalysis(
            overall: overall,
            subScores: subScores,
            skinType: [.oily, .dry, .combination, .normal].randomElement() ?? .combination,
            topIssues: Array(topIssues),
            honestSummary: HonestSummaryBuilder.summary(overall: overall, weakest: weakest[0])
        )
    }
}

// ============================================================
// MARK: — Potential image engine (face enhancement)
// ============================================================

protocol FaceEnhancementEngine: Sendable {
    func enhance(image: UIImage) async throws -> UIImage
}

// The production conformance is `GeminiEnhancementEngine` (GeminiEngine.swift).

/// On-device enhancement (used as the mock AND as the fallback): a real skin
/// retouch of the user's own photo, not just a brightness bump.
///
/// Pipeline: Vision finds the face → a radial mask limits the effect to the
/// face → heavy noise-reduction + blur smooths skin inside the mask (pores,
/// blemishes, texture) → edges/eyes are re-sharpened → bloom adds the
/// "glass skin" glow → gentle warm grade. Identity is trivially preserved
/// because it IS the same photo — only skin changes, which is exactly the
/// product's identity rule.
final class MockEnhancementEngine: FaceEnhancementEngine {

    func enhance(image: UIImage) async throws -> UIImage {
        try? await Task.sleep(for: .milliseconds(2200)) // it's the "slowest call" — keep the drama
        return await Task.detached(priority: .userInitiated) {
            Self.retouch(image)
        }.value
    }

    private static func retouch(_ image: UIImage) -> UIImage {
        guard let input = CIImage(image: image) else { return image }
        let extent = input.extent

        // 1 — Skin-smoothing layer: strong noise reduction + soft blur.
        let noise = CIFilter.noiseReduction()
        noise.inputImage = input
        noise.noiseLevel = 0.08
        noise.sharpness = 0.2

        let blur = CIFilter.gaussianBlur()
        blur.inputImage = (noise.outputImage ?? input).clampedToExtent()
        blur.radius = Float(max(extent.width, extent.height) / 220) // scale-invariant
        let smoothed = (blur.outputImage ?? input).cropped(to: extent)

        // 2 — Apply the smoothing through a face-shaped mask so hair,
        //     eyes-region edges and background stay crisp.
        let mask = faceMask(for: input)
        let masked = CIFilter.blendWithMask()
        masked.inputImage = smoothed
        masked.backgroundImage = input
        masked.maskImage = mask
        var result = masked.outputImage ?? input

        // 3 — Restore edge definition lost to the smoothing.
        let sharpen = CIFilter.sharpenLuminance()
        sharpen.inputImage = result
        sharpen.sharpness = 0.28
        result = sharpen.outputImage ?? result

        // 4 — "Glass skin" glow.
        let bloom = CIFilter.bloom()
        bloom.inputImage = result.clampedToExtent()
        bloom.intensity = 0.38
        bloom.radius = 9
        result = (bloom.outputImage ?? result).cropped(to: extent)

        // 5 — Gentle warm, even grade.
        let warmth = CIFilter.temperatureAndTint()
        warmth.inputImage = result
        warmth.neutral = CIVector(x: 6500, y: 0)
        warmth.targetNeutral = CIVector(x: 6100, y: 3)

        let tone = CIFilter.colorControls()
        tone.inputImage = warmth.outputImage ?? result
        tone.brightness = 0.02
        tone.saturation = 1.05
        tone.contrast = 1.01
        result = tone.outputImage ?? result

        let context = CIContext()
        guard let cgImage = context.createCGImage(result, from: extent) else { return image }
        return UIImage(cgImage: cgImage, scale: image.scale, orientation: image.imageOrientation)
    }

    /// Soft radial mask over the detected face (white = smooth here).
    /// Both Vision and Core Image use lower-left-origin normalized/pixel
    /// coordinates, so the box converts directly. Falls back to a centered
    /// oval when no face is found.
    private static func faceMask(for image: CIImage) -> CIImage {
        let extent = image.extent

        var faceBox = CGRect(x: 0.25, y: 0.3, width: 0.5, height: 0.45) // fallback
        let request = VNDetectFaceRectanglesRequest()
        let handler = VNImageRequestHandler(ciImage: image, options: [:])
        try? handler.perform([request])
        if let face = request.results?.max(by: { $0.boundingBox.height < $1.boundingBox.height }) {
            faceBox = face.boundingBox
        }

        let center = CIVector(
            x: extent.origin.x + (faceBox.midX * extent.width),
            y: extent.origin.y + (faceBox.midY * extent.height)
        )
        let faceRadius = max(faceBox.width * extent.width, faceBox.height * extent.height) / 2

        let gradient = CIFilter.radialGradient()
        gradient.center = CGPoint(x: center.x, y: center.y)
        gradient.radius0 = Float(faceRadius * 0.55)
        gradient.radius1 = Float(faceRadius * 1.15)
        // 0.7 alpha peak = ~70% smoothing strength; never a plastic 100%.
        gradient.color0 = CIColor(red: 1, green: 1, blue: 1, alpha: 0.7)
        gradient.color1 = CIColor(red: 0, green: 0, blue: 0, alpha: 0)
        return (gradient.outputImage ?? CIImage(color: CIColor(red: 0.4, green: 0.4, blue: 0.4)))
            .cropped(to: extent)
    }
}

// ============================================================
// MARK: — Factory
// ============================================================

enum EngineFactory {
    static func analysis(previousOverall: Int? = nil) -> DermiqAnalysisEngine {
        DermiqConfig.hasLiveAnalysis
            ? PerfectCorpSkinEngine()
            : MockDermiqEngine(previousOverall: previousOverall)
    }

    static func enhancement() -> FaceEnhancementEngine {
        DermiqConfig.hasLiveEnhancement ? GeminiEnhancementEngine() : MockEnhancementEngine()
    }
}

// ============================================================
// MARK: — Local image store
// ============================================================

/// Scan + Potential images live as JPEGs in Application Support; SwiftData
/// stores only the filename. Nothing leaves the device except explicit shares.
enum DermiqImageStore {

    private static var directory: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let dir = base.appendingPathComponent("DermiqImages", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    @discardableResult
    static func save(_ image: UIImage, quality: CGFloat = 0.88) -> String? {
        guard let data = image.jpegData(compressionQuality: quality) else { return nil }
        let filename = UUID().uuidString + ".jpg"
        do {
            try data.write(to: directory.appendingPathComponent(filename), options: .atomic)
            return filename
        } catch {
            return nil
        }
    }

    static func load(_ filename: String?) -> UIImage? {
        guard let filename else { return nil }
        return UIImage(contentsOfFile: directory.appendingPathComponent(filename).path)
    }

    /// Delete-account support: removes every stored scan/potential image.
    static func wipeAll() {
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: directory, includingPropertiesForKeys: nil) else { return }
        for file in files {
            try? FileManager.default.removeItem(at: file)
        }
    }
}
