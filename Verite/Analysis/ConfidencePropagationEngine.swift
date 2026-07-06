import Foundation

/// Value paired with a calculated confidence rating.
struct SkinMetricWithConfidence: Sendable {
    /// Measured attribute or metric score (0...1)
    let value: Double
    /// Confidence in the measurement (0...1)
    let confidence: Double
}

/// Dynamic confidence propagation engine for aggregating measurements.
///
/// Propagates confidence values from individual region samplings up to the aggregate scores,
/// ensuring final scores are weighted by region-level confidence to avoid lighting skew.
enum ConfidencePropagationEngine {
    
    /// Computes the final weighted score of a skin attribute based on region values and their confidences.
    ///
    /// Formula:
    ///   finalValue = Σ(value * confidence) / Σ(confidence)
    static func propagate(metrics: [SkinMetricWithConfidence]) -> Double {
        var totalWeightedValue = 0.0
        var totalConfidence = 0.0
        
        for metric in metrics {
            let val = metric.value.clamped01
            let conf = metric.confidence.clamped01
            totalWeightedValue += val * conf
            totalConfidence += conf
        }
        
        guard totalConfidence > 0 else { return 0.0 }
        return (totalWeightedValue / totalConfidence).clamped01
    }
    
    /// Calculates region-level confidence based on exposure, target variance and frame-level metrics.
    static func computeRegionConfidence(
        baseConfidence: Double,
        regionLuma: Double,
        overallLuma: Double,
        textureVariance: Double
    ) -> Double {
        // Lower confidence if regional brightness deviates strongly from the face average luma.
        let lumaDelta = abs(regionLuma - overallLuma)
        let lumaPenalty = lumaDelta > 0.20 ? (lumaDelta - 0.20) * 1.8 : 0.0
        
        // Lower confidence if texture analysis variance suggests excessive blur/underexposure.
        let texturePenalty = textureVariance < 0.05 ? 0.25 : 0.0
        
        return max(0.1, baseConfidence - lumaPenalty - texturePenalty).clamped01
    }
}
