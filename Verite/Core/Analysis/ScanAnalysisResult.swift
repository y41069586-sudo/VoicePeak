import Foundation

/// Immutable, strongly-typed result of skin analysis.
/// This is the final output contract for the entire analysis pipeline.
struct ScanAnalysisResult: Codable, Sendable {
    /// Unique identifier for this scan.
    let id: UUID
    
    /// Timestamp when scan was performed.
    let timestamp: Date
    
    /// Overall composite skin score (0–100).
    let overallSkinScore: Float
    
    /// Redness assessment.
    let rednesScore: SkinAttribute
    
    /// Acne/breakout assessment.
    let acneScore: SkinAttribute
    
    /// Oil production assessment.
    let oilinessScore: SkinAttribute
    
    /// Surface texture assessment.
    let textureScore: SkinAttribute
    
    /// Pore visibility assessment.
    let poreScore: SkinAttribute
    
    /// Skin hydration assessment.
    let hydrationScore: SkinAttribute
    
    /// Skin sensitivity assessment.
    let sensitivityScore: SkinAttribute
    
    /// Baseline comparison if available.
    let baselineComparison: BaselineComparison?
    
    // MARK: - Initialization
    
    init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        overallSkinScore: Float,
        rednesScore: SkinAttribute,
        acneScore: SkinAttribute,
        oilinessScore: SkinAttribute,
        textureScore: SkinAttribute,
        poreScore: SkinAttribute,
        hydrationScore: SkinAttribute,
        sensitivityScore: SkinAttribute,
        baselineComparison: BaselineComparison? = nil
    ) {
        self.id = id
        self.timestamp = timestamp
        self.overallSkinScore = overallSkinScore
        self.rednesScore = rednesScore
        self.acneScore = acneScore
        self.oilinessScore = oilinessScore
        self.textureScore = textureScore
        self.poreScore = poreScore
        self.hydrationScore = hydrationScore
        self.sensitivityScore = sensitivityScore
        self.baselineComparison = baselineComparison
    }
}

/// Individual skin attribute with score, confidence, and per-region breakdown.
struct SkinAttribute: Codable, Sendable {
    /// Score value (0–100).
    let value: Float
    
    /// Confidence in this measurement (0–1).
    let confidence: Float
    
    /// Per-region score contributions.
    let regionContributions: RegionBreakdown
    
    /// Optional explanation or notes.
    let notes: String?
    
    init(
        value: Float,
        confidence: Float,
        regionContributions: RegionBreakdown,
        notes: String? = nil
    ) {
        self.value = clamp(value, 0, 100)
        self.confidence = clamp(confidence, 0, 1)
        self.regionContributions = regionContributions
        self.notes = notes
    }
}

/// Per-region score breakdown for an attribute.
struct RegionBreakdown: Codable, Sendable {
    let forehead: Float
    let leftCheek: Float
    let rightCheek: Float
    let chin: Float
    
    /// Compute weighted average using standard weights.
    var weightedAverage: Float {
        weightedAverage(using: RegionWeighting.default)
    }
    
    /// Compute weighted average with custom weights.
    func weightedAverage(using weights: RegionWeighting) -> Float {
        let sum = (forehead * weights.forehead) +
                  (leftCheek * weights.leftCheek) +
                  (rightCheek * weights.rightCheek) +
                  (chin * weights.chin)
        return sum
    }
}

/// Comparison to baseline scan.
struct BaselineComparison: Codable, Sendable {
    /// ID of the baseline scan.
    let baselineId: UUID
    
    /// Timestamp of baseline scan.
    let baselineTimestamp: Date
    
    /// Delta changes from baseline (positive = worse, negative = better).
    let deltas: AttributeDeltas
    
    /// Trend description ("improving", "stable", "worsening").
    let trend: SkinTrend
}

/// Per-attribute changes from baseline.
struct AttributeDeltas: Codable, Sendable {
    let rednes: Float
    let acne: Float
    let oiliness: Float
    let texture: Float
    let pore: Float
    let hydration: Float
    let sensitivity: Float
}

/// Overall skin trend classification.
enum SkinTrend: String, Codable, Sendable {
    case improving
    case stable
    case worsening
}

// MARK: - Helpers

/// Clamp value to range [min, max].
private func clamp(_ value: Float, _ min: Float, _ max: Float) -> Float {
    Swift.max(Swift.min(value, max), min)
}
