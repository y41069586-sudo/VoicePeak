import Foundation

/// Implements hybrid fusion of heuristic and CoreML predictions.
/// Intelligently blends scores based on confidence and operating mode.
actor HybridFusionEngine: Sendable {
    private var config: CoreMLAnalysisConfig
    
    // MARK: - Initialization
    
    init(config: CoreMLAnalysisConfig = CoreMLAnalysisConfig()) {
        self.config = config
    }
    
    // MARK: - Public API
    
    /// Update operating configuration.
    func updateConfig(_ newConfig: CoreMLAnalysisConfig) {
        self.config = newConfig
    }
    
    /// Fuse heuristic and CoreML predictions based on mode.
    func fuseScores(
        heuristicResult: ScanAnalysisResult,
        coreMLResult: CoreMLInferenceResult,
        input: AnalysisInput
    ) -> ScanAnalysisResult {
        switch config.mode {
        case .heuristic:
            return heuristicResult
            
        case .coreML:
            return convertCoreMLToScanResult(
                coreMLResult: coreMLResult,
                timestamp: input.timestamp
            )
            
        case .hybrid:
            return hybridFuse(
                heuristic: heuristicResult,
                coreML: coreMLResult,
                input: input
            )
        }
    }
    
    // MARK: - Private
    
    /// Pure hybrid fusion: weighted blend of heuristic and CoreML.
    private func hybridFuse(
        heuristic: ScanAnalysisResult,
        coreML: CoreMLInferenceResult,
        input: AnalysisInput
    ) -> ScanAnalysisResult {
        // If CoreML failed, fallback to heuristic
        guard coreML.isSuccessful && !coreML.regionPredictions.isEmpty else {
            return heuristic
        }
        
        // Fuse each attribute
        let rednessScore = fuseAttribute(
            heuristicValue: heuristic.rednesScore,
            coreMLRegions: coreML.regionPredictions,
            extractor: { $0.scaledScores().redness }
        )
        
        let acneScore = fuseAttribute(
            heuristicValue: heuristic.acneScore,
            coreMLRegions: coreML.regionPredictions,
            extractor: { $0.scaledScores().acne }
        )
        
        let oilinessScore = fuseAttribute(
            heuristicValue: heuristic.oilinessScore,
            coreMLRegions: coreML.regionPredictions,
            extractor: { $0.scaledScores().oiliness }
        )
        
        let textureScore = fuseAttribute(
            heuristicValue: heuristic.textureScore,
            coreMLRegions: coreML.regionPredictions,
            extractor: { $0.scaledScores().texture }
        )
        
        let poreScore = fuseAttribute(
            heuristicValue: heuristic.poreScore,
            coreMLRegions: coreML.regionPredictions,
            extractor: { $0.scaledScores().pore }
        )
        
        let hydrationScore = fuseAttribute(
            heuristicValue: heuristic.hydrationScore,
            coreMLRegions: coreML.regionPredictions,
            extractor: { $0.scaledScores().hydration }
        )
        
        let sensitivityScore = fuseAttribute(
            heuristicValue: heuristic.sensitivityScore,
            coreMLRegions: coreML.regionPredictions,
            extractor: { $0.scaledScores().sensitivity }
        )
        
        // Recompute overall score with fused attributes
        let overallScore = computeFusedOverallScore(
            redness: rednessScore.value,
            acne: acneScore.value,
            oiliness: oilinessScore.value,
            texture: textureScore.value,
            pore: poreScore.value,
            hydration: hydrationScore.value,
            sensitivity: sensitivityScore.value
        )
        
        return ScanAnalysisResult(
            timestamp: input.timestamp,
            overallSkinScore: overallScore,
            rednesScore: rednessScore,
            acneScore: acneScore,
            oilinessScore: oilinessScore,
            textureScore: textureScore,
            poreScore: poreScore,
            hydrationScore: hydrationScore,
            sensitivityScore: sensitivityScore
        )
    }
    
    /// Fuse a single attribute from heuristic and CoreML.
    private func fuseAttribute(
        heuristicValue: SkinAttribute,
        coreMLRegions: [FaceRegion: CoreMLRegionPrediction],
        extractor: (CoreMLRegionPrediction) -> Float
    ) -> SkinAttribute {
        // Extract per-region CoreML scores
        var coreMLScores: [FaceRegion: Float] = [:]
        var coreMLConfidences: [FaceRegion: Float] = [:]
        
        for (region, prediction) in coreMLRegions {
            let score = extractor(prediction)
            coreMLScores[region] = score
            coreMLConfidences[region] = prediction.overallConfidence
        }
        
        // For each region, blend scores
        let fusedBreakdown = RegionBreakdown(
            forehead: fuseRegionScore(
                heuristic: heuristicValue.regionContributions.forehead,
                coreML: coreMLScores[.forehead],
                confidence: coreMLConfidences[.forehead]
            ),
            leftCheek: fuseRegionScore(
                heuristic: heuristicValue.regionContributions.leftCheek,
                coreML: coreMLScores[.leftCheek],
                confidence: coreMLConfidences[.leftCheek]
            ),
            rightCheek: fuseRegionScore(
                heuristic: heuristicValue.regionContributions.rightCheek,
                coreML: coreMLScores[.rightCheek],
                confidence: coreMLConfidences[.rightCheek]
            ),
            chin: fuseRegionScore(
                heuristic: heuristicValue.regionContributions.chin,
                coreML: coreMLScores[.chin],
                confidence: coreMLConfidences[.chin]
            )
        )
        
        // Recompute weighted average
        let fusedValue = fusedBreakdown.weightedAverage
        
        // Fused confidence: higher of the two, or blend if both available
        let mlConfidence = coreMLConfidences.values.max() ?? 0
        let fusedConfidence = max(heuristicValue.confidence, mlConfidence * 0.9)
        
        return SkinAttribute(
            value: fusedValue,
            confidence: clamp(fusedConfidence, 0, 1),
            regionContributions: fusedBreakdown
        )
    }
    
    /// Fuse a single region score with optional CoreML value.
    private func fuseRegionScore(
        heuristic: Float,
        coreML: Float?,
        confidence: Float?
    ) -> Float {
        guard let coreML = coreML, let confidence = confidence,
              confidence >= config.confidenceThreshold else {
            // Below threshold or no CoreML score: use heuristic
            return heuristic
        }
        
        // Blend scores weighted by confidence
        let blended = heuristic * config.fallbackWeight + coreML * config.mlWeight
        return blended
    }
    
    /// Convert pure CoreML result to ScanAnalysisResult format.
    private func convertCoreMLToScanResult(
        coreMLResult: CoreMLInferenceResult,
        timestamp: Date
    ) -> ScanAnalysisResult {
        // Build attributes from CoreML predictions
        let rednesScore = coreMLAttributeFromRegions(
            coreMLResult.regionPredictions,
            extractor: { $0.scaledScores().redness }
        )
        
        let acneScore = coreMLAttributeFromRegions(
            coreMLResult.regionPredictions,
            extractor: { $0.scaledScores().acne }
        )
        
        let oilinessScore = coreMLAttributeFromRegions(
            coreMLResult.regionPredictions,
            extractor: { $0.scaledScores().oiliness }
        )
        
        let textureScore = coreMLAttributeFromRegions(
            coreMLResult.regionPredictions,
            extractor: { $0.scaledScores().texture }
        )
        
        let poreScore = coreMLAttributeFromRegions(
            coreMLResult.regionPredictions,
            extractor: { $0.scaledScores().pore }
        )
        
        let hydrationScore = coreMLAttributeFromRegions(
            coreMLResult.regionPredictions,
            extractor: { $0.scaledScores().hydration }
        )
        
        let sensitivityScore = coreMLAttributeFromRegions(
            coreMLResult.regionPredictions,
            extractor: { $0.scaledScores().sensitivity }
        )
        
        let overallScore = computeFusedOverallScore(
            redness: rednesScore.value,
            acne: acneScore.value,
            oiliness: oilinessScore.value,
            texture: textureScore.value,
            pore: poreScore.value,
            hydration: hydrationScore.value,
            sensitivity: sensitivityScore.value
        )
        
        return ScanAnalysisResult(
            timestamp: timestamp,
            overallSkinScore: overallScore,
            rednesScore: rednesScore,
            acneScore: acneScore,
            oilinessScore: oilinessScore,
            textureScore: textureScore,
            poreScore: poreScore,
            hydrationScore: hydrationScore,
            sensitivityScore: sensitivityScore
        )
    }
    
    /// Extract SkinAttribute from CoreML region predictions.
    private func coreMLAttributeFromRegions(
        _ predictions: [FaceRegion: CoreMLRegionPrediction],
        extractor: (CoreMLRegionPrediction) -> Float
    ) -> SkinAttribute {
        var scores: [FaceRegion: Float] = [:]
        var confidences: [FaceRegion: Float] = [:]
        
        for (region, prediction) in predictions {
            scores[region] = extractor(prediction)
            confidences[region] = prediction.overallConfidence
        }
        
        let breakdown = RegionBreakdown(
            forehead: scores[.forehead] ?? 50,
            leftCheek: scores[.leftCheek] ?? 50,
            rightCheek: scores[.rightCheek] ?? 50,
            chin: scores[.chin] ?? 50
        )
        
        let avgConfidence = confidences.values.isEmpty ? 0.7 : confidences.values.reduce(0, +) / Float(confidences.count)
        
        return SkinAttribute(
            value: breakdown.weightedAverage,
            confidence: clamp(avgConfidence, 0, 1),
            regionContributions: breakdown
        )
    }
    
    /// Compute overall score using same formula as heuristic engine.
    private func computeFusedOverallScore(
        redness: Float,
        acne: Float,
        oiliness: Float,
        texture: Float,
        pore: Float,
        hydration: Float,
        sensitivity: Float
    ) -> Float {
        let rednessInverted = 100 - redness
        let acneInverted = 100 - acne
        let oilinessInverted = 100 - oiliness
        let textureInverted = 100 - texture
        let poreInverted = 100 - pore
        let sensitivityInverted = 100 - sensitivity
        
        let score = (
            rednessInverted * 0.15 +
            acneInverted * 0.20 +
            oilinessInverted * 0.12 +
            textureInverted * 0.15 +
            poreInverted * 0.10 +
            hydration * 0.15 +
            sensitivityInverted * 0.13
        )
        
        return clamp(score, 0, 100)
    }
}

// MARK: - Helpers

private func clamp(_ value: Float, _ min: Float, _ max: Float) -> Float {
    Swift.max(Swift.min(value, max), min)
}
