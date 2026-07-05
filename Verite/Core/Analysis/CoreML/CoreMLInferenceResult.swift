import Foundation

/// Single prediction for one skin region from CoreML model.
struct CoreMLRegionPrediction: Sendable {
    /// Which region this prediction is for.
    let region: FaceRegion
    
    /// Redness probability (0–1).
    let rednessProbability: Float
    
    /// Acne probability (0–1).
    let acneProbability: Float
    
    /// Oiliness probability (0–1).
    let oilinessProbability: Float
    
    /// Texture quality score (0–1, where 1 = best).
    let textureQuality: Float
    
    /// Pore visibility score (0–1).
    let poreVisibility: Float
    
    /// Hydration estimate (0–1, where 1 = best).
    let hydrationEstimate: Float
    
    /// Sensitivity score (0–1).
    let sensitivityScore: Float
    
    /// Model confidence in this prediction (0–1).
    let modelConfidence: Float
    
    /// Region quality assessment (0–1).
    /// Based on region coverage, lighting, stability.
    let regionQuality: Float
    
    /// Lighting quality factor (0–1).
    /// Used to weight final confidence.
    let lightingQuality: Float
    
    // MARK: - Computed Properties
    
    /// Overall confidence for this region prediction.
    /// Combines model confidence, region quality, and lighting quality.
    var overallConfidence: Float {
        let weights: [Float] = [0.5, 0.3, 0.2]
        let values: [Float] = [modelConfidence, regionQuality, lightingQuality]
        let weighted = zip(weights, values).map(*)
        return weighted.reduce(0, +)
    }
    
    /// Convert prediction to 0–100 scale for integration.
    func scaledScores() -> ScaledCoreMlScores {
        ScaledCoreMlScores(
            redness: rednessProbability * 100,
            acne: acneProbability * 100,
            oiliness: oilinessProbability * 100,
            texture: (1 - textureQuality) * 100,  // Invert: low quality = high score
            pore: poreVisibility * 100,
            hydration: hydrationEstimate * 100,
            sensitivity: sensitivityScore * 100
        )
    }
}

/// Scaled scores ready for integration into SkinAttribute.
struct ScaledCoreMlScores: Sendable {
    let redness: Float
    let acne: Float
    let oiliness: Float
    let texture: Float
    let pore: Float
    let hydration: Float
    let sensitivity: Float
}

/// Complete inference result from CoreML model.
struct CoreMLInferenceResult: Sendable {
    /// Per-region predictions.
    let regionPredictions: [FaceRegion: CoreMLRegionPrediction]
    
    /// Timestamp of inference.
    let timestamp: Date
    
    /// Whether inference succeeded.
    let isSuccessful: Bool
    
    /// Error message if inference failed.
    let error: String?
    
    // MARK: - Initialization
    
    init(
        regionPredictions: [FaceRegion: CoreMLRegionPrediction],
        timestamp: Date = Date(),
        isSuccessful: Bool = true,
        error: String? = nil
    ) {
        self.regionPredictions = regionPredictions
        self.timestamp = timestamp
        self.isSuccessful = isSuccessful
        self.error = error
    }
    
    /// Create error result.
    static func failure(error: String) -> CoreMLInferenceResult {
        CoreMLInferenceResult(
            regionPredictions: [:],
            isSuccessful: false,
            error: error
        )
    }
}
