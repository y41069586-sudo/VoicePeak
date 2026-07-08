import UIKit
import CoreImage
import CoreImage.CIFilterBuiltins

// ============================================================
// MARK: — Config (MASTER PROMPT §2)
// ============================================================

/// Endpoint + auth injected via config. Empty values ⇒ the factory serves the
/// mock engines so every screen is fully demo-able without the live APIs.
enum DermiqConfig {
    // TODO: PRODUCTION KEY — inject the live Dermiq endpoint + API key here.
    static let analysisEndpoint = ""       // e.g. "https://api.dermiq.ai/v1/analyze"
    static let analysisAPIKey = ""

    // TODO: PRODUCTION KEY — image-to-image enhancement endpoint + key.
    static let enhancementEndpoint = ""    // e.g. "https://api.example.com/v1/img2img"
    static let enhancementAPIKey = ""

    static var hasLiveAnalysis: Bool { !analysisEndpoint.isEmpty && !analysisAPIKey.isEmpty }
    static var hasLiveEnhancement: Bool { !enhancementEndpoint.isEmpty && !enhancementAPIKey.isEmpty }
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

/// Production conformance — network call to the Dermiq API.
final class DermiqEngine: DermiqAnalysisEngine {

    func analyze(image: UIImage) async throws -> DermiqAnalysis {
        guard DermiqConfig.hasLiveAnalysis,
              let url = URL(string: DermiqConfig.analysisEndpoint),
              let jpeg = image.jpegData(compressionQuality: 0.85) else {
            throw DermiqEngineError.notConfigured
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(DermiqConfig.analysisAPIKey)", forHTTPHeaderField: "Authorization")
        request.setValue("image/jpeg", forHTTPHeaderField: "Content-Type")
        request.httpBody = jpeg

        let (data, response) = try await URLSession.shared.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else {
            throw DermiqEngineError.badResponse
        }
        // The Dermiq response is expected to decode 1:1 onto DermiqAnalysis.
        return try JSONDecoder().decode(DermiqAnalysis.self, from: data)
    }
}

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

/// Production conformance — image-to-image API call.
final class PotentialImageEngine: FaceEnhancementEngine {

    /// IDENTITY PRESERVATION IS NON-NEGOTIABLE. This exact instruction ships
    /// with every request: same person, same structure — only skin improved.
    static let identityPrompt = """
    Enhance ONLY the skin of this exact person. Preserve identity completely: \
    same person, same facial structure, same angle, same lighting, same \
    expression. Improve ONLY skin clarity, texture, tone evenness, and glow \
    to a realistic optimal state. Never alter bone structure, eyes, nose, \
    lips, hair, or face shape.
    """

    func enhance(image: UIImage) async throws -> UIImage {
        guard DermiqConfig.hasLiveEnhancement,
              let url = URL(string: DermiqConfig.enhancementEndpoint),
              let jpeg = image.jpegData(compressionQuality: 0.9) else {
            throw DermiqEngineError.notConfigured
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(DermiqConfig.enhancementAPIKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode([
            "prompt": Self.identityPrompt,
            "image_b64": jpeg.base64EncodedString(),
            "strength": "0.35", // low denoise strength — skin only, identity intact
        ])

        let (data, response) = try await URLSession.shared.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200,
              let result = UIImage(data: data) else {
            throw DermiqEngineError.badResponse
        }
        return result
    }
}

/// Mock enhancement: a Core Image "optimal skin" grade of the user's own
/// photo (noise-smoothed, warmed, subtly brightened). Identity is trivially
/// preserved because it IS the same photo.
final class MockEnhancementEngine: FaceEnhancementEngine {

    func enhance(image: UIImage) async throws -> UIImage {
        try? await Task.sleep(for: .seconds(3)) // it's the slowest call — simulate that
        return await Task.detached(priority: .userInitiated) {
            Self.grade(image)
        }.value
    }

    private static func grade(_ image: UIImage) -> UIImage {
        guard let input = CIImage(image: image) else { return image }

        let smooth = CIFilter.noiseReduction()
        smooth.inputImage = input
        smooth.noiseLevel = 0.06
        smooth.sharpness = 0.45

        let tone = CIFilter.colorControls()
        tone.inputImage = smooth.outputImage ?? input
        tone.brightness = 0.03
        tone.saturation = 1.06
        tone.contrast = 1.01

        let warmth = CIFilter.temperatureAndTint()
        warmth.inputImage = tone.outputImage ?? input
        warmth.neutral = CIVector(x: 6500, y: 0)
        warmth.targetNeutral = CIVector(x: 6050, y: 4)

        let highlight = CIFilter.highlightShadowAdjust()
        highlight.inputImage = warmth.outputImage ?? input
        highlight.highlightAmount = 0.95
        highlight.shadowAmount = 0.25

        let context = CIContext()
        guard let output = highlight.outputImage,
              let cgImage = context.createCGImage(output, from: input.extent) else {
            return image
        }
        return UIImage(cgImage: cgImage, scale: image.scale, orientation: image.imageOrientation)
    }
}

// ============================================================
// MARK: — Factory
// ============================================================

enum EngineFactory {
    static func analysis(previousOverall: Int? = nil) -> DermiqAnalysisEngine {
        DermiqConfig.hasLiveAnalysis ? DermiqEngine() : MockDermiqEngine(previousOverall: previousOverall)
    }

    static func enhancement() -> FaceEnhancementEngine {
        DermiqConfig.hasLiveEnhancement ? PotentialImageEngine() : MockEnhancementEngine()
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
}
