import Foundation

/// Value paired with a running buffer of previous observations.
struct SmootherState {
    /// History buffer storing up to the last 30 frames.
    var history: [Double] = []
    /// Current EMA smoothed value.
    var smoothedValue: Double?
    
    /// Blend incoming value into the running average, using confidence to scale adaptation rate
    /// and a 2-sigma rule approximation to reject outliers.
    mutating func smooth(_ value: Double, confidence: Double) -> Double {
        // Linear mapping: if confidence is 0.0 -> weight (alpha) = 0.2
        //                 if confidence is 1.0 -> weight (alpha) = 0.8
        let alpha = 0.2 + 0.6 * confidence.clamped01
        
        // Outlier rejection (approximating 2-sigma rule)
        if history.count >= 5 {
            let mean = history.reduce(0.0, +) / Double(history.count)
            let variance = history.map { ($0 - mean) * ($0 - mean) }.reduce(0.0, +) / Double(history.count)
            let stdDev = sqrt(variance)
            
            // Define minimum threshold to prevent rejecting normal tiny fluctuations
            let threshold = max(0.02, 2.0 * stdDev)
            if abs(value - mean) > threshold {
                // Outlier detected: reject updating history, return current smoothed value or historical mean
                return smoothedValue ?? mean
            }
        }
        
        // Valid frame value: append to history
        history.append(value)
        if history.count > 30 {
            history.removeFirst()
        }
        
        let prev = smoothedValue ?? value
        let newSmoothedValue = alpha * value + (1.0 - alpha) * prev
        smoothedValue = newSmoothedValue
        return newSmoothedValue
    }
}

/// Actor-isolated stabilization queue that handles per-attribute and per-region smoothing.
///
/// Blends incoming analysis signals with historical moving averages weighted by frame-level confidence.
actor TemporalSmoother {
    
    // MARK: - State
    
    private var attributeStates: [SkinAttribute: SmootherState] = [:]
    private var regionStates: [String: [String: SmootherState]] = [:] // region -> (metricKey -> state)
    
    // MARK: - API
    
    /// Smooths a dictionary of skin attributes.
    func smooth(attributes: [SkinAttribute: Double], confidence: Double) -> [SkinAttribute: Double] {
        var results: [SkinAttribute: Double] = [:]
        for (attr, value) in attributes {
            var state = attributeStates[attr, default: SmootherState()]
            let smoothed = state.smooth(value, confidence: confidence)
            attributeStates[attr] = state
            results[attr] = smoothed
        }
        return results
    }
    
    /// Smooths raw per-region metrics individually.
    func smooth(regions: [String: RegionMetrics], confidence: Double) -> [String: RegionMetrics] {
        var results: [String: RegionMetrics] = [:]
        for (regionKey, metrics) in regions {
            var metricsStates = regionStates[regionKey, default: [:]]
            
            func smoothField(_ value: Double, key: String) -> Double {
                var state = metricsStates[key, default: SmootherState()]
                let smoothed = state.smooth(value, confidence: confidence)
                metricsStates[key] = state
                return smoothed
            }
            
            let smoothedMetrics = RegionMetrics(
                redness: smoothField(metrics.redness, key: "redness"),
                shine: smoothField(metrics.shine, key: "shine"),
                texture: smoothField(metrics.texture, key: "texture"),
                pores: smoothField(metrics.pores, key: "pores"),
                spots: smoothField(metrics.spots, key: "spots"),
                radiance: smoothField(metrics.radiance, key: "radiance"),
                meanLuma: smoothField(metrics.meanLuma, key: "meanLuma")
            )
            
            regionStates[regionKey] = metricsStates
            results[regionKey] = smoothedMetrics
        }
        return results
    }
    
    /// Reset the running history buffers.
    func reset() {
        attributeStates.removeAll()
        regionStates.removeAll()
    }
}

// MARK: - Live-frame smoother (lightweight synchronous EMA)

/// A lightweight synchronous EMA buffer for the live video stream.
final class LiveSmoother {
    private let alpha: Double
    private var history: [SkinAttribute: Double] = [:]

    init(alpha: Double = 0.18) {
        self.alpha = alpha.clamped01
    }

    func smooth(_ value: Double, for attribute: SkinAttribute) -> Double {
        let prev = history[attribute] ?? value
        let smoothed = alpha * value + (1 - alpha) * prev
        history[attribute] = smoothed
        return smoothed
    }

    func reset() { history = [:] }
}
