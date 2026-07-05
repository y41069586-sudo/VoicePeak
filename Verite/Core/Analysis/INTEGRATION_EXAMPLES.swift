import Foundation

// MARK: - Integration Examples

/// Examples showing how to integrate the Skin Analysis Engine with other modules.
/// These are reference implementations for Phase 3B and UI layers.

// MARK: - Example 1: Basic Analysis Pipeline

/// Demonstrates the complete analysis pipeline from ARKit + Vision → Results
func example_basicAnalysisPipeline(
    arKitEngine: ARKitFaceEngine,
    visionExtractor: SkinRegionExtractor,
    cgImage: CGImage
) {
    // Step 1: Extract face regions from image using Vision module
    let regions = SkinRegionExtractor.extractRegions(from: cgImage)
    
    // Guard we got all regions
    guard !regions.isEmpty else {
        print("No face detected")
        return
    }
    
    // Step 2: Get current mesh points from ARKit
    guard let meshPoints = arKitEngine.meshPointsInNormalizedImageSpace else {
        print("No mesh tracking")
        return
    }
    
    // Step 3: Assess capture quality
    let quality = CaptureQuality(
        lightingQuality: 0.85,      // Derived from image analysis
        faceStability: arKitEngine.isTracking ? 0.9 : 0.5,
        alignmentQuality: 0.88      // Derived from mesh position
    )
    
    // Step 4: Convert Vision regions to AnalysisInput format
    let skinRegionData = regions.map { crop -> SkinRegionData in
        SkinRegionData(
            region: crop.region,
            pixelBuffer: crop.pixelBuffer,
            size: crop.size,
            extractionConfidence: crop.confidence,
            avgLuminance: Float(crop.avgLuminance ?? 128)
        )
    }
    
    // Step 5: Create analysis input
    let analysisInput = AnalysisInput(
        faceMeshPoints: meshPoints,
        skinRegions: skinRegionData,
        captureQuality: quality
    )
    
    // Step 6: Run analysis
    let result = SkinAnalysisEngine.analyze(input: analysisInput)
    
    // Step 7: Use result
    print("Overall Score: \(result.overallSkinScore)")
    print("Redness: \(result.rednesScore.value)")
    print("Acne: \(result.acneScore.value)")
    print("Confidence: \(result.rednesScore.confidence)")
}

// MARK: - Example 2: Per-Region Feedback

/// Demonstrates how to extract and display per-region insights
func example_perRegionAnalysis(result: ScanAnalysisResult) {
    let regions: [FaceRegion] = [.forehead, .leftCheek, .rightCheek, .chin]
    
    for region in regions {
        let foreheadRedness = result.rednesScore.regionContributions.forehead
        let leftCheekRedness = result.rednesScore.regionContributions.leftCheek
        let rightCheekRedness = result.rednesScore.regionContributions.rightCheek
        let chinRedness = result.rednesScore.regionContributions.chin
        
        print("Region: \(region.displayName)")
        print("  Redness: \(foreheadRedness)")
        print("  Acne: \(result.acneScore.regionContributions.forehead)")
        print("  Texture: \(result.textureScore.regionContributions.forehead)")
    }
    
    // Find problem regions
    let breakdown = result.acneScore.regionContributions
    let problemRegions = [
        ("Forehead", breakdown.forehead),
        ("Left Cheek", breakdown.leftCheek),
        ("Right Cheek", breakdown.rightCheek),
        ("Chin", breakdown.chin)
    ]
    .sorted { $0.1 > $1.1 }
    .prefix(2)
    
    print("\nMost problematic regions (acne):")
    for (region, score) in problemRegions {
        print("  \(region): \(Int(score))")
    }
}

// MARK: - Example 3: Custom Region Weighting

/// Demonstrates how to use different weighting profiles for different analyses
func example_customWeighting(input: AnalysisInput) {
    // Standard analysis (balanced)
    let standardResult = SkinAnalysisEngine.analyze(
        input: input,
        regionWeighting: .default
    )
    
    // Acne-focused analysis (emphasize cheeks)
    let acneResult = SkinAnalysisEngine.analyze(
        input: input,
        regionWeighting: .cheekFocused
    )
    
    // T-zone focused (forehead + chin)
    let tZoneResult = SkinAnalysisEngine.analyze(
        input: input,
        regionWeighting: .tZoneFocused
    )
    
    // Compare insights
    print("Standard acne score: \(standardResult.acneScore.value)")
    print("Cheek-focused acne score: \(acneResult.acneScore.value)")
    print("T-zone acne score: \(tZoneResult.acneScore.value)")
    
    // Use case: Different analyses for different skin concerns
    let userProfile = UserProfile.current
    let recommendedWeighting = userProfile.recommendedWeighting // .cheekFocused, etc.
    let userResult = SkinAnalysisEngine.analyze(input: input, regionWeighting: recommendedWeighting)
}

// MARK: - Example 4: Baseline Tracking

/// Demonstrates baseline comparison for progress tracking (Phase 3B)
func example_baselineTracking(firstScan: ScanAnalysisResult, laterScans: [ScanAnalysisResult]) async {
    let baselineStore = BaselineStore()
    
    // First scan becomes baseline
    do {
        try await baselineStore.setBaseline(firstScan)
        print("Baseline set: \(firstScan.timestamp)")
    } catch {
        print("Failed to set baseline: \(error)")
        return
    }
    
    // Track progress over time
    for (index, scan) in laterScans.enumerated() {
        if let comparison = await baselineStore.compareToBaseline(scan) {
            print("\n--- Scan \(index + 2) ---")
            print("Redness change: \(comparison.deltas.rednes > 0 ? "+" : "")\(String(format: "%.1f", comparison.deltas.rednes))%")
            print("Acne change: \(comparison.deltas.acne > 0 ? "+" : "")\(String(format: "%.1f", comparison.deltas.acne))%")
            print("Oiliness change: \(comparison.deltas.oiliness > 0 ? "+" : "")\(String(format: "%.1f", comparison.deltas.oiliness))%")
            print("Hydration change: \(comparison.deltas.hydration > 0 ? "+" : "")\(String(format: "%.1f", comparison.deltas.hydration))%")
            print("Overall trend: \(comparison.trend.rawValue)")
            
            // UI feedback based on trend
            switch comparison.trend {
            case .improving:
                print("✅ Skin is improving! Keep up your routine.")
            case .stable:
                print("⚪ Skin is stable. Maintain current routine.")
            case .worsening:
                print("⚠️ Skin is worsening. Consider adjustments.")
            }
        }
    }
    
    // Check progress after 4 weeks
    let oneMonthLater = laterScans[3]
    if let comparison = await baselineStore.compareToBaseline(oneMonthLater) {
        let improvementScore = -(comparison.deltas.rednes + comparison.deltas.acne + comparison.deltas.texture) / 3
        print("\nOne-month progress score: \(String(format: "%.1f", improvementScore))%")
    }
}

// MARK: - Example 5: Confidence-Based Decision Making

/// Demonstrates using confidence values for UI decisions
func example_confidenceBasedUI(result: ScanAnalysisResult) {
    // High confidence → show score prominently
    // Low confidence → show as "reference only" or request retake
    
    for attribute in [
        ("Redness", result.rednesScore),
        ("Acne", result.acneScore),
        ("Texture", result.textureScore),
        ("Pore Size", result.poreScore),
    ] as [(String, SkinAttribute)] {
        let confidence = attribute.1.confidence
        
        if confidence >= 0.8 {
            print("\(attribute.0): \(Int(attribute.1.value)) (highly confident)")
        } else if confidence >= 0.6 {
            print("\(attribute.0): \(Int(attribute.1.value)) (confident)")
        } else {
            print("\(attribute.0): \(Int(attribute.1.value)) (reference only)")
        }
    }
    
    // Overall: Only show detailed results if capture was good
    if result.rednesScore.confidence >= 0.7 && result.acneScore.confidence >= 0.7 {
        // Show detailed breakdown
        print("Showing detailed analysis...")
    } else {
        // Show summary, suggest retake
        print("Analysis confidence low. For best results, retake in bright, even lighting.")
    }
}

// MARK: - Example 6: Quality-Adjusted Scores

/// Demonstrates how quality affects scoring
func example_qualityAdjustment(input: AnalysisInput) {
    // With quality penalty (default: accounts for poor lighting/stability)
    let resultWithQuality = SkinAnalysisEngine.analyze(input: input, qualityPenalty: true)
    
    // Without quality penalty (for testing or specific use cases)
    let resultWithoutQuality = SkinAnalysisEngine.analyze(input: input, qualityPenalty: false)
    
    print("Score with quality penalty: \(resultWithQuality.overallSkinScore)")
    print("Score without quality penalty: \(resultWithoutQuality.overallSkinScore)")
    
    // If capture quality is poor, the penalty is significant
    if input.captureQuality.overallQuality < 0.7 {
        print("Poor capture quality detected. Score may not be accurate.")
    }
}

// MARK: - Example 7: JSON Serialization

/// Demonstrates persistence of results
func example_jsonPersistence(result: ScanAnalysisResult) throws {
    // Encode to JSON
    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .iso8601
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    
    let data = try encoder.encode(result)
    let jsonString = String(data: data, encoding: .utf8)
    
    print("Encoded result:")
    print(jsonString ?? "Failed to decode")
    
    // Save to file
    let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    let fileURL = documentsDirectory.appendingPathComponent("scan_\(result.id).json")
    try data.write(to: fileURL, options: .atomic)
    print("Saved to: \(fileURL)")
    
    // Load from file
    let loadedData = try Data(contentsOf: fileURL)
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    let loadedResult = try decoder.decode(ScanAnalysisResult.self, from: loadedData)
    
    print("Loaded result ID: \(loadedResult.id)")
    print("Original ID: \(result.id)")
    assert(loadedResult.id == result.id, "Round-trip failed")
}

// MARK: - Example 8: Phase 3B CoreML Integration (Placeholder)

/// Placeholder showing how CoreML will integrate in Phase 3B
// NOTE: This is pseudo-code showing the integration point
/*
// Phase 3B: Will look like this:

class SkinAnalysisEngineCoreML {
    private let rednessModel = try RednessClassifier(configuration: MLModelConfiguration())
    private let acneModel = try AcneGrader(configuration: MLModelConfiguration())
    private let oilinessModel = try OilinessDetector(configuration: MLModelConfiguration())
    
    func analyzeWithML(input: AnalysisInput) -> ScanAnalysisResult {
        // Replace heuristic functions with ML models
        let rednessScores = analyzeRednessWithML(input: input)  // Uses rednessModel
        let acneScores = analyzeAcneWithML(input: input)        // Uses acneModel
        let oilinessScores = analyzeOilinessWithML(input: input) // Uses oilinessModel
        
        // Rest of the pipeline unchanged
        return SkinAnalysisEngine.aggregate(scores: rednessScores, ...)
    }
}

// Usage (Phase 3B):
let mlEngine = SkinAnalysisEngineCoreML()
let result = mlEngine.analyzeWithML(input: input)
// Returns identical ScanAnalysisResult structure
*/

// MARK: - Example 9: Bulk Processing

/// Demonstrates processing multiple scans efficiently
func example_bulkProcessing(
    images: [CGImage],
    arKitPositions: [(meshPoints: [SIMD3<Float>], quality: CaptureQuality)]
) -> [ScanAnalysisResult] {
    var results: [ScanAnalysisResult] = []
    
    for (index, image) in images.enumerated() {
        let regions = SkinRegionExtractor.extractRegions(from: image)
        guard !regions.isEmpty else { continue }
        
        let (meshPoints, quality) = arKitPositions[index]
        
        let skinRegionData = regions.map { crop in
            SkinRegionData(
                region: crop.region,
                pixelBuffer: crop.pixelBuffer,
                size: crop.size,
                extractionConfidence: crop.confidence,
                avgLuminance: Float(crop.avgLuminance ?? 128)
            )
        }
        
        let input = AnalysisInput(
            faceMeshPoints: meshPoints,
            skinRegions: skinRegionData,
            captureQuality: quality
        )
        
        let result = SkinAnalysisEngine.analyze(input: input)
        results.append(result)
    }
    
    return results
}

// MARK: - Example 10: Custom Confidence Weighting

/// Demonstrates how to adjust base confidence per attribute
// Note: For Phase 3C personalization
func example_personalizedConfidence(
    userProfile: UserProfile,
    input: AnalysisInput
) -> ScanAnalysisResult {
    // User with oily skin: higher confidence in oiliness scores
    // User with sensitive skin: higher confidence in sensitivity/redness scores
    
    var result = SkinAnalysisEngine.analyze(input: input)
    
    // Adjust confidence based on user type
    if userProfile.skinType == .oily {
        // Oiliness measurement more reliable for oily skin
        let oiliness = result.oilinessScore
        result = ScanAnalysisResult(
            overallSkinScore: result.overallSkinScore,
            rednesScore: result.rednesScore,
            acneScore: result.acneScore,
            oilinessScore: SkinAttribute(
                value: oiliness.value,
                confidence: min(1.0, oiliness.confidence * 1.2),  // Boost confidence
                regionContributions: oiliness.regionContributions
            ),
            textureScore: result.textureScore,
            poreScore: result.poreScore,
            hydrationScore: result.hydrationScore,
            sensitivityScore: result.sensitivityScore
        )
    }
    
    return result
}

// MARK: - Placeholder Types (for examples to compile)

// These would be real in the actual application
class ARKitFaceEngine {
    var isTracking: Bool { true }
    var meshPointsInNormalizedImageSpace: [SIMD3<Float>]? { [] }
}

class SkinRegionExtractor {
    static func extractRegions(from: CGImage) -> [SkinRegionCrop] { [] }
}

struct SkinRegionCrop {
    let region: FaceRegion
    let pixelBuffer: CVPixelBuffer
    let size: CGSize
    let confidence: Float
    let avgLuminance: Double?
}

struct UserProfile {
    enum SkinType { case oily, dry, combination, normal }
    static let current = UserProfile()
    let skinType: SkinType = .normal
    let recommendedWeighting: RegionWeighting = .default
}

// MARK: - Note

/*
 These examples demonstrate:

 1. Complete analysis pipeline
 2. Per-region insights
 3. Custom weighting strategies
 4. Baseline comparison workflows
 5. Confidence-based UI decisions
 6. Quality adjustment effects
 7. JSON persistence
 8. CoreML integration point (Phase 3B)
 9. Bulk processing
 10. Personalization (Phase 3C)

 All examples show how to integrate SkinAnalysisEngine with:
 - ARKit + Vision modules
 - UI layers (Phase 4)
 - Persistence layers (Phase 4)
 - User profiles (Phase 4+)
 - CoreML models (Phase 3B)

 The engine itself remains unchanged; these are integration examples
 for calling code.
 */
