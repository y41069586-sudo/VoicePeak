import Foundation

/// Pure deterministic skin analysis engine.
/// Takes AnalysisInput and produces ScanAnalysisResult using heuristic scoring.
/// NO randomness, NO UI coupling, NO CoreML, ONLY deterministic math.
enum SkinAnalysisEngine {
    
    // MARK: - Main Analysis API
    
    /// Perform complete skin analysis on input data.
    /// This is the primary entry point for the analysis pipeline.
    static func analyze(
        input: AnalysisInput,
        regionWeighting: RegionWeighting = .default,
        qualityPenalty: Bool = true
    ) -> ScanAnalysisResult {
        // Extract scores per region
        let rednesScores = analyzeRedness(input: input)
        let acneScores = analyzeAcne(input: input)
        let oilinessScores = analyzeOiliness(input: input)
        let textureScores = analyzeTexture(input: input)
        let poreScores = analyzePores(input: input)
        let hydrationScores = analyzeHydration(input: input)
        let sensitivityScores = analyzeSensitivity(input: input)
        
        // Aggregate to final scores with region weighting
        let rednesAttribute = aggregateAttribute(
            rednesScores,
            regionWeighting: regionWeighting,
            baseConfidence: 0.75
        )
        let acneAttribute = aggregateAttribute(
            acneScores,
            regionWeighting: regionWeighting,
            baseConfidence: 0.70
        )
        let oilinessAttribute = aggregateAttribute(
            oilinessScores,
            regionWeighting: regionWeighting,
            baseConfidence: 0.72
        )
        let textureAttribute = aggregateAttribute(
            textureScores,
            regionWeighting: regionWeighting,
            baseConfidence: 0.68
        )
        let poreAttribute = aggregateAttribute(
            poreScores,
            regionWeighting: regionWeighting,
            baseConfidence: 0.60
        )
        let hydrationAttribute = aggregateAttribute(
            hydrationScores,
            regionWeighting: regionWeighting,
            baseConfidence: 0.65
        )
        let sensitivityAttribute = aggregateAttribute(
            sensitivityScores,
            regionWeighting: regionWeighting,
            baseConfidence: 0.70
        )
        
        // Compute overall skin score
        let overallScore = computeOverallScore(
            rednes: rednesAttribute.value,
            acne: acneAttribute.value,
            oiliness: oilinessAttribute.value,
            texture: textureAttribute.value,
            pore: poreAttribute.value,
            hydration: hydrationAttribute.value,
            sensitivity: sensitivityAttribute.value,
            captureQuality: input.captureQuality,
            applyQualityPenalty: qualityPenalty
        )
        
        return ScanAnalysisResult(
            timestamp: input.timestamp,
            overallSkinScore: overallScore,
            rednesScore: rednesAttribute,
            acneScore: acneAttribute,
            oilinessScore: oilinessAttribute,
            textureScore: textureAttribute,
            poreScore: poreAttribute,
            hydrationScore: hydrationAttribute,
            sensitivityScore: sensitivityAttribute
        )
    }
    
    // MARK: - Per-Attribute Analysis
    
    /// Analyze redness based on red channel prominence and luminance variance.
    private static func analyzeRedness(input: AnalysisInput) -> [FaceRegion: Float] {
        var scores: [FaceRegion: Float] = [:]
        
        for regionData in input.skinRegions {
            let rednessMetric = PixelAnalysis.rednessMetric(pixelBuffer: regionData.pixelBuffer)
            let (lumaMean, lumaStdDev, _, _) = PixelAnalysis.luminanceStats(pixelBuffer: regionData.pixelBuffer)
            
            // Redness is red excess, scaled to 0–100
            // Red excess normalized: assume typical range is -30 to +30
            let normalizedRedness = ((rednessMetric + 30) / 60) * 100
            
            // Higher variance in luminance can indicate redness
            let varianceFactor = (lumaStdDev / 50) * 10  // Assume typical std dev ~50
            
            let score = clamp(normalizedRedness + varianceFactor * 0.2, 0, 100)
            scores[regionData.region] = score
        }
        
        return scores
    }
    
    /// Analyze acne/breakouts based on edge density and pore frequency.
    private static func analyzeAcne(input: AnalysisInput) -> [FaceRegion: Float] {
        var scores: [FaceRegion: Float] = [:]
        
        for regionData in input.skinRegions {
            let poreFreq = PixelAnalysis.poreFrequency(pixelBuffer: regionData.pixelBuffer)
            let textureVar = PixelAnalysis.textureVariance(pixelBuffer: regionData.pixelBuffer)
            
            // High texture variance + pore frequency suggests bumpy/acne skin
            // Normalize: assume typical pore freq 5–20, texture 10–50
            let poreComponent = clamp((poreFreq / 20) * 40, 0, 50)
            let textureComponent = clamp((textureVar / 50) * 60, 0, 50)
            
            let score = clamp(poreComponent + textureComponent, 0, 100)
            scores[regionData.region] = score
        }
        
        return scores
    }
    
    /// Analyze oiliness based on specular highlight detection.
    private static func analyzeOiliness(input: AnalysisInput) -> [FaceRegion: Float] {
        var scores: [FaceRegion: Float] = [:]
        
        for regionData in input.skinRegions {
            // Specularity as proxy for oiliness
            let specularity = PixelAnalysis.specularity(pixelBuffer: regionData.pixelBuffer, threshold: 200)
            
            // Also consider luminance: bright regions tend to be oilier
            let (lumaMean, _, _, _) = PixelAnalysis.luminanceStats(pixelBuffer: regionData.pixelBuffer)
            
            // Specularity is 0–1; scale to 0–100
            let specularityScore = specularity * 70  // Cap at 70
            
            // High luminance suggests more oil/shine
            let lumaFactor = clamp((lumaMean - 100) / 50 * 30, 0, 30)
            
            let score = clamp(specularityScore + lumaFactor, 0, 100)
            scores[regionData.region] = score
        }
        
        return scores
    }
    
    /// Analyze texture based on local variance and edge density.
    private static func analyzeTexture(input: AnalysisInput) -> [FaceRegion: Float] {
        var scores: [FaceRegion: Float] = [:]
        
        for regionData in input.skinRegions {
            let variance = PixelAnalysis.textureVariance(pixelBuffer: regionData.pixelBuffer, kernelSize: 5)
            
            // Normalize variance to 0–100 score (higher variance = rougher texture)
            // Assume typical range 5–100
            let score = clamp((variance / 100) * 100, 0, 100)
            scores[regionData.region] = score
        }
        
        return scores
    }
    
    /// Analyze pore visibility based on high-frequency patterns.
    private static func analyzePores(input: AnalysisInput) -> [FaceRegion: Float] {
        var scores: [FaceRegion: Float] = [:]
        
        for regionData in input.skinRegions {
            let poreFreq = PixelAnalysis.poreFrequency(pixelBuffer: regionData.pixelBuffer)
            
            // Normalize pore frequency (higher = more visible pores)
            // Assume typical range 0–30
            let score = clamp((poreFreq / 30) * 100, 0, 100)
            scores[regionData.region] = score
        }
        
        return scores
    }
    
    /// Analyze hydration based on luminance uniformity and brightness.
    private static func analyzeHydration(input: AnalysisInput) -> [FaceRegion: Float] {
        var scores: [FaceRegion: Float] = [:]
        
        for regionData in input.skinRegions {
            let (lumaMean, lumaStdDev, _, _) = PixelAnalysis.luminanceStats(pixelBuffer: regionData.pixelBuffer)
            let textureVar = PixelAnalysis.textureVariance(pixelBuffer: regionData.pixelBuffer)
            
            // Well-hydrated skin: uniform luminance (low variance) + high brightness
            // Dehydrated skin: rough texture, dull appearance
            
            // Lower variance = better hydration
            let uniformityScore = clamp((1 - lumaStdDev / 100) * 100, 0, 100)
            
            // Higher brightness = better hydration (plump appearance)
            let brightnessScore = clamp((lumaMean / 200) * 100, 0, 100)
            
            // Lower texture variance = better hydration
            let textureInverse = clamp((1 - textureVar / 100) * 50, 0, 50)
            
            let score = clamp(uniformityScore * 0.5 + brightnessScore * 0.3 + textureInverse, 0, 100)
            scores[regionData.region] = score
        }
        
        return scores
    }
    
    /// Analyze sensitivity based on redness, luminance instability, and quality factors.
    private static func analyzeSensitivity(input: AnalysisInput) -> [FaceRegion: Float] {
        var scores: [FaceRegion: Float] = [:]
        
        let rednessScores = analyzeRedness(input: input)
        
        for regionData in input.skinRegions {
            let redness = rednessScores[regionData.region] ?? 0
            let (_, lumaStdDev, _, _) = PixelAnalysis.luminanceStats(pixelBuffer: regionData.pixelBuffer)
            
            // Sensitivity markers: redness + luminance instability + lighting sensitivity
            let rednessComponent = redness * 0.5  // 0–50
            
            // High luminance variance suggests sensitive/reactive skin
            let instabilityComponent = clamp((lumaStdDev / 80) * 50, 0, 50)
            
            let score = clamp(rednessComponent + instabilityComponent, 0, 100)
            scores[regionData.region] = score
        }
        
        return scores
    }
    
    // MARK: - Aggregation & Scoring
    
    /// Aggregate per-region scores into a single SkinAttribute with confidence.
    private static func aggregateAttribute(
        _ regionScores: [FaceRegion: Float],
        regionWeighting: RegionWeighting,
        baseConfidence: Float
    ) -> SkinAttribute {
        // Compute weighted average
        let weighted = regionWeighting.aggregate(regionScores)
        
        // Build region breakdown
        let breakdown = RegionBreakdown(
            forehead: regionScores[.forehead] ?? 0,
            leftCheek: regionScores[.leftCheek] ?? 0,
            rightCheek: regionScores[.rightCheek] ?? 0,
            chin: regionScores[.chin] ?? 0
        )
        
        // Confidence: reduce if region coverage is incomplete
        let coverage = Float(regionScores.count) / 4.0
        let confidence = baseConfidence * coverage
        
        return SkinAttribute(
            value: weighted,
            confidence: confidence,
            regionContributions: breakdown
        )
    }
    
    /// Compute overall skin health score from individual attributes.
    private static func computeOverallScore(
        rednes: Float,
        acne: Float,
        oiliness: Float,
        texture: Float,
        pore: Float,
        hydration: Float,
        sensitivity: Float,
        captureQuality: CaptureQuality,
        applyQualityPenalty: Bool
    ) -> Float {
        // Healthy skin: low redness, low acne, balanced oiliness, smooth texture, small pores, good hydration, low sensitivity
        
        // Invert problem attributes (lower is better)
        let rednessInverted = 100 - rednes
        let acneInverted = 100 - acne
        let oilinessInverted = 100 - oiliness
        let textureInverted = 100 - texture
        let poreInverted = 100 - pore
        let sensitivityInverted = 100 - sensitivity
        
        // Hydration is already good when high
        
        // Weighted combination
        let score = (
            rednessInverted * 0.15 +
            acneInverted * 0.20 +
            oilinessInverted * 0.12 +
            textureInverted * 0.15 +
            poreInverted * 0.10 +
            hydration * 0.15 +
            sensitivityInverted * 0.13
        )
        
        let qualityAdjusted: Float
        if applyQualityPenalty {
            // Reduce score confidence if capture quality is poor
            let qualityFactor = 0.7 + (captureQuality.overallQuality * 0.3)
            qualityAdjusted = score * qualityFactor
        } else {
            qualityAdjusted = score
        }
        
        return clamp(qualityAdjusted, 0, 100)
    }
}

// MARK: - Helpers

private func clamp(_ value: Float, _ min: Float, _ max: Float) -> Float {
    Swift.max(Swift.min(value, max), min)
}
