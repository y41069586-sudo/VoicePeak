import XCTest
import CoreVideo
@testable import Verite

final class SkinAnalysisEngineTests: XCTestCase {
    
    // MARK: - Test Helpers
    
    /// Create a dummy pixel buffer for testing.
    private func createTestPixelBuffer(
        width: Int = 224,
        height: Int = 224,
        luminance: UInt8 = 128
    ) -> CVPixelBuffer {
        var pixelBuffer: CVPixelBuffer?
        let attrs: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
        ]
        
        CVPixelBufferCreate(
            kCFAllocatorDefault,
            width,
            height,
            kCVPixelFormatType_32BGRA,
            attrs as CFDictionary,
            &pixelBuffer
        )
        
        guard let buffer = pixelBuffer else {
            fatalError("Failed to create test pixel buffer")
        }
        
        CVPixelBufferLockBaseAddress(buffer, .readAndWrite)
        defer { CVPixelBufferUnlockBaseAddress(buffer, .readAndWrite) }
        
        let baseAddress = CVPixelBufferGetBaseAddress(buffer)!.assumingMemoryBound(to: UInt8.self)
        let bytesPerRow = CVPixelBufferGetBytesPerRow(buffer)
        
        for y in 0..<height {
            for x in 0..<width {
                let offset = y * bytesPerRow + x * 4
                baseAddress[offset] = luminance  // B
                baseAddress[offset + 1] = luminance  // G
                baseAddress[offset + 2] = luminance  // R
                baseAddress[offset + 3] = 255  // A
            }
        }
        
        return buffer
    }
    
    /// Create a test pixel buffer with specific red component.
    private func createRedPixelBuffer(redLevel: UInt8 = 200, width: Int = 224, height: Int = 224) -> CVPixelBuffer {
        var pixelBuffer: CVPixelBuffer?
        let attrs: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
        ]
        
        CVPixelBufferCreate(
            kCFAllocatorDefault,
            width,
            height,
            kCVPixelFormatType_32BGRA,
            attrs as CFDictionary,
            &pixelBuffer
        )
        
        guard let buffer = pixelBuffer else {
            fatalError("Failed to create red test pixel buffer")
        }
        
        CVPixelBufferLockBaseAddress(buffer, .readAndWrite)
        defer { CVPixelBufferUnlockBaseAddress(buffer, .readAndWrite) }
        
        let baseAddress = CVPixelBufferGetBaseAddress(buffer)!.assumingMemoryBound(to: UInt8.self)
        let bytesPerRow = CVPixelBufferGetBytesPerRow(buffer)
        
        for y in 0..<height {
            for x in 0..<width {
                let offset = y * bytesPerRow + x * 4
                baseAddress[offset] = 100  // B
                baseAddress[offset + 1] = 100  // G
                baseAddress[offset + 2] = redLevel  // R
                baseAddress[offset + 3] = 255  // A
            }
        }
        
        return buffer
    }
    
    /// Create a test AnalysisInput with dummy data.
    private func createTestInput(
        regionCount: Int = 4,
        captureQuality: CaptureQuality = CaptureQuality(
            lightingQuality: 0.8,
            faceStability: 0.9,
            alignmentQuality: 0.85
        )
    ) -> AnalysisInput {
        var regions: [SkinRegionData] = []
        let regionsToUse: [FaceRegion] = [.forehead, .leftCheek, .rightCheek, .chin]
        
        for i in 0..<min(regionCount, regionsToUse.count) {
            let region = regionsToUse[i]
            regions.append(SkinRegionData(
                region: region,
                pixelBuffer: createTestPixelBuffer(),
                size: CGSize(width: 224, height: 224),
                extractionConfidence: 0.85,
                avgLuminance: 128
            ))
        }
        
        return AnalysisInput(
            faceMeshPoints: [],
            skinRegions: regions,
            captureQuality: captureQuality
        )
    }
    
    // MARK: - Tests: Determinism
    
    func testAnalysisDeterminism() {
        let input = createTestInput()
        
        let result1 = SkinAnalysisEngine.analyze(input: input)
        let result2 = SkinAnalysisEngine.analyze(input: input)
        
        XCTAssertEqual(result1.overallSkinScore, result2.overallSkinScore, accuracy: 0.01)
        XCTAssertEqual(result1.rednesScore.value, result2.rednesScore.value, accuracy: 0.01)
        XCTAssertEqual(result1.acneScore.value, result2.acneScore.value, accuracy: 0.01)
    }
    
    // MARK: - Tests: Region Weighting
    
    func testDefaultWeighting() {
        let weights = RegionWeighting.default
        
        XCTAssertEqual(weights.forehead, 0.2, accuracy: 0.001)
        XCTAssertEqual(weights.leftCheek, 0.3, accuracy: 0.001)
        XCTAssertEqual(weights.rightCheek, 0.3, accuracy: 0.001)
        XCTAssertEqual(weights.chin, 0.2, accuracy: 0.001)
    }
    
    func testWeightingAggregation() {
        let weights = RegionWeighting.default
        let values: [FaceRegion: Float] = [
            .forehead: 50,
            .leftCheek: 60,
            .rightCheek: 60,
            .chin: 40
        ]
        
        let aggregated = weights.aggregate(values)
        
        // Expected: 50*0.2 + 60*0.3 + 60*0.3 + 40*0.2 = 10 + 18 + 18 + 8 = 54
        XCTAssertEqual(aggregated, 54, accuracy: 0.1)
    }
    
    func testCheekFocusedWeighting() {
        let weights = RegionWeighting.cheekFocused
        let values: [FaceRegion: Float] = [
            .forehead: 0,
            .leftCheek: 100,
            .rightCheek: 100,
            .chin: 0
        ]
        
        let aggregated = weights.aggregate(values)
        
        // Expected: 0*0.15 + 100*0.35 + 100*0.35 + 0*0.15 = 70
        XCTAssertEqual(aggregated, 70, accuracy: 0.1)
    }
    
    // MARK: - Tests: Score Ranges
    
    func testScoreRanges() {
        let input = createTestInput()
        let result = SkinAnalysisEngine.analyze(input: input)
        
        XCTAssert(result.overallSkinScore >= 0 && result.overallSkinScore <= 100)
        XCTAssert(result.rednesScore.value >= 0 && result.rednesScore.value <= 100)
        XCTAssert(result.acneScore.value >= 0 && result.acneScore.value <= 100)
        XCTAssert(result.oilinessScore.value >= 0 && result.oilinessScore.value <= 100)
        XCTAssert(result.textureScore.value >= 0 && result.textureScore.value <= 100)
        XCTAssert(result.poreScore.value >= 0 && result.poreScore.value <= 100)
        XCTAssert(result.hydrationScore.value >= 0 && result.hydrationScore.value <= 100)
        XCTAssert(result.sensitivityScore.value >= 0 && result.sensitivityScore.value <= 100)
    }
    
    func testConfidenceRanges() {
        let input = createTestInput()
        let result = SkinAnalysisEngine.analyze(input: input)
        
        XCTAssert(result.rednesScore.confidence >= 0 && result.rednesScore.confidence <= 1)
        XCTAssert(result.acneScore.confidence >= 0 && result.acneScore.confidence <= 1)
        XCTAssert(result.textureScore.confidence >= 0 && result.textureScore.confidence <= 1)
    }
    
    // MARK: - Tests: Quality Penalty
    
    func testQualityPenalty() {
        let goodQuality = CaptureQuality(
            lightingQuality: 0.95,
            faceStability: 0.95,
            alignmentQuality: 0.95
        )
        
        let poorQuality = CaptureQuality(
            lightingQuality: 0.5,
            faceStability: 0.5,
            alignmentQuality: 0.5
        )
        
        var inputGood = createTestInput(captureQuality: goodQuality)
        var inputPoor = createTestInput(captureQuality: poorQuality)
        
        let resultGood = SkinAnalysisEngine.analyze(input: inputGood)
        let resultPoor = SkinAnalysisEngine.analyze(input: inputPoor)
        
        // Poor quality should result in lower overall score
        XCTAssertGreater(resultGood.overallSkinScore, resultPoor.overallSkinScore)
    }
    
    // MARK: - Tests: Region Contribution
    
    func testRegionContributionBreakdown() {
        let input = createTestInput()
        let result = SkinAnalysisEngine.analyze(input: input)
        
        // Region breakdown should have values for all regions
        let breakdown = result.rednesScore.regionContributions
        XCTAssertGreaterThanOrEqual(breakdown.forehead, 0)
        XCTAssertGreaterThanOrEqual(breakdown.leftCheek, 0)
        XCTAssertGreaterThanOrEqual(breakdown.rightCheek, 0)
        XCTAssertGreaterThanOrEqual(breakdown.chin, 0)
        
        XCTAssertLessThanOrEqual(breakdown.forehead, 100)
        XCTAssertLessThanOrEqual(breakdown.leftCheek, 100)
        XCTAssertLessThanOrEqual(breakdown.rightCheek, 100)
        XCTAssertLessThanOrEqual(breakdown.chin, 100)
    }
    
    // MARK: - Tests: Redness Detection
    
    func testRednessDetection() {
        let normalBuffer = createTestPixelBuffer(luminance: 128)
        let redBuffer = createRedPixelBuffer(redLevel: 220)
        
        var inputNormal = createTestInput()
        inputNormal.skinRegions[0] = SkinRegionData(
            region: .forehead,
            pixelBuffer: normalBuffer,
            size: CGSize(width: 224, height: 224),
            extractionConfidence: 0.85,
            avgLuminance: 128
        )
        
        var inputRed = createTestInput()
        inputRed.skinRegions[0] = SkinRegionData(
            region: .forehead,
            pixelBuffer: redBuffer,
            size: CGSize(width: 224, height: 224),
            extractionConfidence: 0.85,
            avgLuminance: 128
        )
        
        let resultNormal = SkinAnalysisEngine.analyze(input: inputNormal)
        let resultRed = SkinAnalysisEngine.analyze(input: inputRed)
        
        // Red buffer should show higher redness score
        XCTAssertGreater(resultRed.rednesScore.value, resultNormal.rednesScore.value)
    }
    
    // MARK: - Tests: Codability
    
    func testScanAnalysisResultCodable() throws {
        let input = createTestInput()
        let result = SkinAnalysisEngine.analyze(input: input)
        
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(result)
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(ScanAnalysisResult.self, from: data)
        
        XCTAssertEqual(result.id, decoded.id)
        XCTAssertEqual(result.overallSkinScore, decoded.overallSkinScore, accuracy: 0.01)
    }
}

// MARK: - Baseline Tests

final class BaselineStoreTests: XCTestCase {
    
    private var testDirectory: URL!
    
    override func setUp() {
        super.setUp()
        testDirectory = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: testDirectory, withIntermediateDirectories: true)
    }
    
    override func tearDown() {
        try? FileManager.default.removeItem(at: testDirectory)
        super.tearDown()
    }
    
    private func createTestResult(overallScore: Float = 75) -> ScanAnalysisResult {
        return ScanAnalysisResult(
            overallSkinScore: overallScore,
            rednesScore: SkinAttribute(
                value: 30,
                confidence: 0.8,
                regionContributions: RegionBreakdown(forehead: 25, leftCheek: 30, rightCheek: 35, chin: 28)
            ),
            acneScore: SkinAttribute(
                value: 20,
                confidence: 0.7,
                regionContributions: RegionBreakdown(forehead: 15, leftCheek: 25, rightCheek: 22, chin: 18)
            ),
            oilinessScore: SkinAttribute(
                value: 40,
                confidence: 0.75,
                regionContributions: RegionBreakdown(forehead: 45, leftCheek: 40, rightCheek: 40, chin: 35)
            ),
            textureScore: SkinAttribute(
                value: 35,
                confidence: 0.7,
                regionContributions: RegionBreakdown(forehead: 32, leftCheek: 38, rightCheek: 36, chin: 34)
            ),
            poreScore: SkinAttribute(
                value: 30,
                confidence: 0.65,
                regionContributions: RegionBreakdown(forehead: 28, leftCheek: 32, rightCheek: 31, chin: 28)
            ),
            hydrationScore: SkinAttribute(
                value: 65,
                confidence: 0.7,
                regionContributions: RegionBreakdown(forehead: 60, leftCheek: 68, rightCheek: 68, chin: 62)
            ),
            sensitivityScore: SkinAttribute(
                value: 25,
                confidence: 0.7,
                regionContributions: RegionBreakdown(forehead: 22, leftCheek: 26, rightCheek: 28, chin: 24)
            )
        )
    }
    
    func testBaselineStorage() async throws {
        let store = BaselineStore(storageDirectory: testDirectory)
        let baseline = createTestResult()
        
        try await store.setBaseline(baseline)
        let retrieved = await store.getBaseline()
        
        XCTAssertNotNil(retrieved)
        XCTAssertEqual(retrieved?.id, baseline.id)
    }
    
    func testBaselineComparison() async throws {
        let store = BaselineStore(storageDirectory: testDirectory)
        let baseline = createTestResult(overallScore: 75)
        
        try await store.setBaseline(baseline)
        
        let currentScan = createTestResult(overallScore: 70)
        let comparison = await store.compareToBaseline(currentScan)
        
        XCTAssertNotNil(comparison)
        XCTAssertEqual(comparison?.baselineId, baseline.id)
    }
    
    func testTrendDetermination() async throws {
        let store = BaselineStore(storageDirectory: testDirectory)
        let baseline = createTestResult()
        
        try await store.setBaseline(baseline)
        
        // Create a scan with slight improvements
        var improved = createTestResult()
        improved = ScanAnalysisResult(
            overallSkinScore: improved.overallSkinScore,
            rednesScore: SkinAttribute(value: 25, confidence: 0.8, regionContributions: improved.rednesScore.regionContributions),
            acneScore: SkinAttribute(value: 15, confidence: 0.7, regionContributions: improved.acneScore.regionContributions),
            oilinessScore: SkinAttribute(value: 35, confidence: 0.75, regionContributions: improved.oilinessScore.regionContributions),
            textureScore: SkinAttribute(value: 30, confidence: 0.7, regionContributions: improved.textureScore.regionContributions),
            poreScore: SkinAttribute(value: 25, confidence: 0.65, regionContributions: improved.poreScore.regionContributions),
            hydrationScore: SkinAttribute(value: 70, confidence: 0.7, regionContributions: improved.hydrationScore.regionContributions),
            sensitivityScore: SkinAttribute(value: 20, confidence: 0.7, regionContributions: improved.sensitivityScore.regionContributions)
        )
        
        let comparison = await store.compareToBaseline(improved)
        
        XCTAssertNotNil(comparison)
        // Most scores improved (negative delta), should be improving trend
        XCTAssertEqual(comparison?.trend, .improving)
    }
}
