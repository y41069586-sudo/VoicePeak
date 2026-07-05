import XCTest
import XCTest
import CoreVideo

@testable import Verite

// MARK: - ModelLoader Tests

class ModelLoaderTests: XCTestCase {
    var modelLoader: ModelLoader!
    
    override func setUp() {
        super.setUp()
        // Use a bundle that doesn't have the model to test fallback
        modelLoader = ModelLoader(modelName: "NonExistentModel", bundle: .main)
    }
    
    override func tearDown() {
        modelLoader = nil
        super.tearDown()
    }
    
    func testModelNotFoundHandling() async {
        let model = await modelLoader.loadModel()
        // Model should fail gracefully
        XCTAssertNil(model, "Should handle missing model gracefully")
    }
    
    func testModelAvailabilityCheck() {
        let available = modelLoader.isModelAvailable()
        // Should return false for non-existent model
        XCTAssertFalse(available)
    }
    
    func testCacheClear() async {
        // Clear cache (should not crash)
        modelLoader.clearCache()
        XCTAssertTrue(true, "Cache clear should not crash")
    }
}

// MARK: - AnalysisMode Tests

class AnalysisModeTests: XCTestCase {
    func testAnalysisModeEncoding() throws {
        let mode = AnalysisMode.hybrid
        let encoder = JSONEncoder()
        let data = try encoder.encode(mode)
        
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(AnalysisMode.self, from: data)
        
        XCTAssertEqual(mode, decoded)
    }
    
    func testCoreMLConfigDefaults() {
        let config = CoreMLAnalysisConfig()
        
        XCTAssertEqual(config.mode, .hybrid)
        XCTAssertEqual(config.mlWeight, 0.7)
        XCTAssertEqual(config.fallbackWeight, 0.3)
        XCTAssertEqual(config.confidenceThreshold, 0.5)
        XCTAssertTrue(config.enableFallback)
    }
    
    func testFallbackWeightComputation() {
        var config = CoreMLAnalysisConfig()
        config.mlWeight = 0.6
        
        XCTAssertEqual(config.fallbackWeight, 0.4, accuracy: 0.001)
    }
}

// MARK: - CoreMLInferenceResult Tests

class CoreMLInferenceResultTests: XCTestCase {
    func testSuccessfulResult() {
        let prediction = CoreMLRegionPrediction(
            region: .forehead,
            rednessProbability: 0.3,
            acneProbability: 0.2,
            oilinessProbability: 0.4,
            textureQuality: 0.7,
            poreVisibility: 0.5,
            hydrationEstimate: 0.6,
            sensitivityScore: 0.3,
            modelConfidence: 0.85,
            regionQuality: 0.8,
            lightingQuality: 0.75
        )
        
        let result = CoreMLInferenceResult(
            regionPredictions: [.forehead: prediction]
        )
        
        XCTAssertTrue(result.isSuccessful)
        XCTAssertNil(result.error)
        XCTAssertEqual(result.regionPredictions.count, 1)
    }
    
    func testFailureResult() {
        let result = CoreMLInferenceResult.failure(error: "Test error")
        
        XCTAssertFalse(result.isSuccessful)
        XCTAssertEqual(result.error, "Test error")
        XCTAssertTrue(result.regionPredictions.isEmpty)
    }
    
    func testPredictionConfidence() {
        let prediction = CoreMLRegionPrediction(
            region: .forehead,
            rednessProbability: 0.5,
            acneProbability: 0.5,
            oilinessProbability: 0.5,
            textureQuality: 0.5,
            poreVisibility: 0.5,
            hydrationEstimate: 0.5,
            sensitivityScore: 0.5,
            modelConfidence: 0.8,
            regionQuality: 0.9,
            lightingQuality: 0.7
        )
        
        let confidence = prediction.overallConfidence
        XCTAssertGreater(confidence, 0.5)
        XCTAssertLess(confidence, 1.0)
    }
    
    func testScaledScores() {
        let prediction = CoreMLRegionPrediction(
            region: .forehead,
            rednessProbability: 0.3,
            acneProbability: 0.2,
            oilinessProbability: 0.4,
            textureQuality: 0.8,  // Will be inverted
            poreVisibility: 0.5,
            hydrationEstimate: 0.6,
            sensitivityScore: 0.3,
            modelConfidence: 0.85,
            regionQuality: 0.8,
            lightingQuality: 0.75
        )
        
        let scaled = prediction.scaledScores()
        
        XCTAssertEqual(scaled.redness, 30, accuracy: 0.1)
        XCTAssertEqual(scaled.acne, 20, accuracy: 0.1)
        XCTAssertEqual(scaled.oiliness, 40, accuracy: 0.1)
        XCTAssertEqual(scaled.texture, 20, accuracy: 0.1)  // 1 - 0.8 = 0.2 → 20
        XCTAssertEqual(scaled.hydration, 60, accuracy: 0.1)
    }
}

// MARK: - HybridFusionEngine Tests

class HybridFusionEngineTests: XCTestCase {
    var fusionEngine: HybridFusionEngine!
    
    override func setUp() {
        super.setUp()
        fusionEngine = HybridFusionEngine()
    }
    
    override func testHeuristicOnlyMode() async {
        var config = CoreMLAnalysisConfig()
        config.mode = .heuristic
        await fusionEngine.updateConfig(config)
        
        let heuristic = createMockScanResult()
        let coreML = CoreMLInferenceResult.failure(error: "Model not loaded")
        let input = createMockAnalysisInput()
        
        let result = await fusionEngine.fuseScores(
            heuristicResult: heuristic,
            coreMLResult: coreML,
            input: input
        )
        
        XCTAssertEqual(result.overallSkinScore, heuristic.overallSkinScore)
    }
    
    func testCoreMLOnlyMode() async {
        var config = CoreMLAnalysisConfig()
        config.mode = .coreML
        await fusionEngine.updateConfig(config)
        
        let coreMLResult = createMockCoreMLResult()
        let coreMLScanResult = await fusionEngine.convertCoreMLToScanResult(
            coreMLResult: coreMLResult,
            timestamp: Date()
        )
        
        XCTAssertNotNil(coreMLScanResult)
        XCTAssertGreater(coreMLScanResult.overallSkinScore, 0)
    }
    
    func testHybridMode() async {
        var config = CoreMLAnalysisConfig()
        config.mode = .hybrid
        config.mlWeight = 0.5
        await fusionEngine.updateConfig(config)
        
        let heuristic = createMockScanResult()
        let coreML = createMockCoreMLResult()
        let input = createMockAnalysisInput()
        
        let result = await fusionEngine.fuseScores(
            heuristicResult: heuristic,
            coreMLResult: coreML,
            input: input
        )
        
        // Result should be different from pure heuristic (if CoreML succeeded)
        XCTAssertNotNil(result)
        XCTAssertGreater(result.overallSkinScore, 0)
    }
    
    func testFallbackOnCoreMLFailure() async {
        var config = CoreMLAnalysisConfig()
        config.mode = .hybrid
        await fusionEngine.updateConfig(config)
        
        let heuristic = createMockScanResult()
        let coreML = CoreMLInferenceResult.failure(error: "Inference failed")
        let input = createMockAnalysisInput()
        
        let result = await fusionEngine.fuseScores(
            heuristicResult: heuristic,
            coreMLResult: coreML,
            input: input
        )
        
        // Should fallback to heuristic result
        XCTAssertEqual(result.overallSkinScore, heuristic.overallSkinScore)
    }
}

// MARK: - SkinAnalysisEngineCoreML Tests

class SkinAnalysisEngineCoreMLTests: XCTestCase {
    var engine: SkinAnalysisEngineCoreML!
    
    override func setUp() {
        super.setUp()
        engine = SkinAnalysisEngineCoreML()
    }
    
    override func tearDown() {
        engine = nil
        super.tearDown()
    }
    
    func testEngineInitialization() async {
        let config = await engine.getConfig()
        XCTAssertEqual(config.mode, .hybrid)
    }
    
    func testModeSwitch() async {
        await engine.setMode(.heuristic)
        var config = await engine.getConfig()
        XCTAssertEqual(config.mode, .heuristic)
        
        await engine.setMode(.hybrid)
        config = await engine.getConfig()
        XCTAssertEqual(config.mode, .hybrid)
    }
    
    func testModelAvailabilityCheck() async {
        let available = await engine.isModelAvailable()
        // Will be false unless model is actually in bundle
        XCTAssertFalse(available)
    }
    
    func testPreloadModel() async {
        // Should not crash
        await engine.preloadModel()
        XCTAssertTrue(true)
    }
    
    func testClearModelCache() async {
        await engine.clearModelCache()
        XCTAssertTrue(true)
    }
    
    func testPerformanceMetrics() async {
        let input = createMockAnalysisInput()
        
        _ = await engine.analyze(input: input)
        
        let metrics = await engine.getMetrics()
        XCTAssertGreater(metrics.analysisCount, 0)
    }
    
    func testAnalysisHeuristicMode() async {
        await engine.setMode(.heuristic)
        let input = createMockAnalysisInput()
        
        let result = await engine.analyze(input: input)
        
        XCTAssertGreaterOrEqual(result.overallSkinScore, 0)
        XCTAssertLessOrEqual(result.overallSkinScore, 100)
        XCTAssertGreaterOrEqual(result.rednesScore.confidence, 0)
        XCTAssertLessOrEqual(result.rednesScore.confidence, 1)
    }
    
    func testOutputContractIntegrity() async {
        let input = createMockAnalysisInput()
        let result = await engine.analyze(input: input)
        
        // Verify all attributes exist and are valid
        XCTAssertGreaterOrEqual(result.rednesScore.value, 0)
        XCTAssertLessOrEqual(result.rednesScore.value, 100)
        
        XCTAssertGreaterOrEqual(result.acneScore.value, 0)
        XCTAssertLessOrEqual(result.acneScore.value, 100)
        
        XCTAssertGreaterOrEqual(result.oilinessScore.value, 0)
        XCTAssertLessOrEqual(result.oilinessScore.value, 100)
        
        // Verify region breakdown
        let breakdown = result.rednesScore.regionContributions
        XCTAssertGreaterOrEqual(breakdown.forehead, 0)
        XCTAssertGreaterOrEqual(breakdown.leftCheek, 0)
        XCTAssertGreaterOrEqual(breakdown.rightCheek, 0)
        XCTAssertGreaterOrEqual(breakdown.chin, 0)
    }
}

// MARK: - Mock Data Helpers

private func createMockAnalysisInput() -> AnalysisInput {
    let pixelBuffer = createMockPixelBuffer(width: 224, height: 224)
    
    let skinRegions = [
        SkinRegionData(
            region: .forehead,
            pixelBuffer: pixelBuffer,
            size: CGSize(width: 224, height: 224),
            extractionConfidence: 0.85,
            avgLuminance: 128
        ),
        SkinRegionData(
            region: .leftCheek,
            pixelBuffer: pixelBuffer,
            size: CGSize(width: 224, height: 224),
            extractionConfidence: 0.80,
            avgLuminance: 125
        ),
        SkinRegionData(
            region: .rightCheek,
            pixelBuffer: pixelBuffer,
            size: CGSize(width: 224, height: 224),
            extractionConfidence: 0.82,
            avgLuminance: 126
        ),
        SkinRegionData(
            region: .chin,
            pixelBuffer: pixelBuffer,
            size: CGSize(width: 224, height: 224),
            extractionConfidence: 0.78,
            avgLuminance: 124
        )
    ]
    
    let quality = CaptureQuality(
        lightingQuality: 0.8,
        faceStability: 0.9,
        alignmentQuality: 0.85
    )
    
    return AnalysisInput(
        faceMeshPoints: Array(repeating: SIMD3<Float>(0, 0, 0), count: 468),
        skinRegions: skinRegions,
        captureQuality: quality
    )
}

private func createMockPixelBuffer(width: Int, height: Int) -> CVPixelBuffer {
    var pixelBuffer: CVPixelBuffer?
    
    let attributes: [String: Any] = [
        kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
        kCVPixelBufferWidthKey as String: width,
        kCVPixelBufferHeightKey as String: height
    ]
    
    CVPixelBufferCreate(
        kCFAllocatorDefault,
        width,
        height,
        kCVPixelFormatType_32BGRA,
        attributes as CFDictionary,
        &pixelBuffer
    )
    
    return pixelBuffer!
}

private func createMockScanResult() -> ScanAnalysisResult {
    let breakdown = RegionBreakdown(forehead: 50, leftCheek: 45, rightCheek: 48, chin: 52)
    
    return ScanAnalysisResult(
        overallSkinScore: 60,
        rednesScore: SkinAttribute(value: 40, confidence: 0.75, regionContributions: breakdown),
        acneScore: SkinAttribute(value: 35, confidence: 0.70, regionContributions: breakdown),
        oilinessScore: SkinAttribute(value: 45, confidence: 0.72, regionContributions: breakdown),
        textureScore: SkinAttribute(value: 50, confidence: 0.68, regionContributions: breakdown),
        poreScore: SkinAttribute(value: 48, confidence: 0.60, regionContributions: breakdown),
        hydrationScore: SkinAttribute(value: 65, confidence: 0.65, regionContributions: breakdown),
        sensitivityScore: SkinAttribute(value: 38, confidence: 0.70, regionContributions: breakdown)
    )
}

private func createMockCoreMLResult() -> CoreMLInferenceResult {
    let predictions: [FaceRegion: CoreMLRegionPrediction] = [
        .forehead: CoreMLRegionPrediction(
            region: .forehead,
            rednessProbability: 0.35,
            acneProbability: 0.30,
            oilinessProbability: 0.40,
            textureQuality: 0.55,
            poreVisibility: 0.48,
            hydrationEstimate: 0.65,
            sensitivityScore: 0.32,
            modelConfidence: 0.82,
            regionQuality: 0.80,
            lightingQuality: 0.78
        ),
        .leftCheek: CoreMLRegionPrediction(
            region: .leftCheek,
            rednessProbability: 0.32,
            acneProbability: 0.28,
            oilinessProbability: 0.38,
            textureQuality: 0.58,
            poreVisibility: 0.45,
            hydrationEstimate: 0.68,
            sensitivityScore: 0.30,
            modelConfidence: 0.85,
            regionQuality: 0.82,
            lightingQuality: 0.80
        ),
        .rightCheek: CoreMLRegionPrediction(
            region: .rightCheek,
            rednessProbability: 0.33,
            acneProbability: 0.29,
            oilinessProbability: 0.39,
            textureQuality: 0.56,
            poreVisibility: 0.46,
            hydrationEstimate: 0.66,
            sensitivityScore: 0.31,
            modelConfidence: 0.84,
            regionQuality: 0.81,
            lightingQuality: 0.79
        ),
        .chin: CoreMLRegionPrediction(
            region: .chin,
            rednessProbability: 0.36,
            acneProbability: 0.31,
            oilinessProbability: 0.41,
            textureQuality: 0.54,
            poreVisibility: 0.50,
            hydrationEstimate: 0.63,
            sensitivityScore: 0.33,
            modelConfidence: 0.81,
            regionQuality: 0.79,
            lightingQuality: 0.77
        )
    ]
    
    return CoreMLInferenceResult(regionPredictions: predictions)
}
