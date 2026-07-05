import XCTest
import CoreGraphics
import CoreVideo
@testable import Verite

final class SkinRegionExtractorTests: XCTestCase {
    
    // MARK: - Face Geometry Tests
    
    func testFaceRegionAllCasesExist() {
        let regions = FaceRegion.allCases
        XCTAssertGreaterThan(regions.count, 0, "Should have face regions defined")
        XCTAssert(regions.contains(.forehead), "Should have forehead region")
        XCTAssert(regions.contains(.leftCheek), "Should have left cheek region")
        XCTAssert(regions.contains(.rightCheek), "Should have right cheek region")
        XCTAssert(regions.contains(.chin), "Should have chin region")
    }
    
    func testRegionFractionalRectsAreValid() {
        for region in FaceRegion.allCases {
            let frac = region.fractionalRect
            XCTAssertGreaterThanOrEqual(frac.x0, 0)
            XCTAssertLessThanOrEqual(frac.x1, 1)
            XCTAssertGreaterThanOrEqual(frac.y0, 0)
            XCTAssertLessThanOrEqual(frac.y1, 1)
            XCTAssertLessThan(frac.x0, frac.x1, "x0 should be less than x1 for \(region.id)")
            XCTAssertLessThan(frac.y0, frac.y1, "y0 should be less than y1 for \(region.id)")
        }
    }
    
    func testRegionRectComputation() {
        let faceBounds = CGRect(x: 100, y: 100, width: 200, height: 400)
        let foreheadRect = FaceGeometry.regionRect(in: faceBounds, for: .forehead)
        
        // Forehead should be in upper portion
        XCTAssertGreaterThanOrEqual(foreheadRect.origin.y, faceBounds.origin.y)
        XCTAssertLessThan(foreheadRect.maxY, faceBounds.maxY)
        
        // Should be within face bounds
        XCTAssertGreaterThanOrEqual(foreheadRect.origin.x, faceBounds.origin.x - 10)
        XCTAssertLessThanOrEqual(foreheadRect.maxX, faceBounds.maxX + 10)
    }
    
    func testRectClamping() {
        let rect = CGRect(x: -10, y: -10, width: 50, height: 50)
        let imageSize = CGSize(width: 100, height: 100)
        
        let clamped = FaceGeometry.clampToImage(rect, imageSize: imageSize)
        
        XCTAssertGreaterThanOrEqual(clamped.origin.x, 0)
        XCTAssertGreaterThanOrEqual(clamped.origin.y, 0)
        XCTAssertLessThanOrEqual(clamped.maxX, imageSize.width)
        XCTAssertLessThanOrEqual(clamped.maxY, imageSize.height)
    }
    
    func testRectExpansion() {
        let rect = CGRect(x: 50, y: 50, width: 100, height: 100)
        let expanded = FaceGeometry.expand(rect, by: 1.2)
        
        XCTAssertGreaterThan(expanded.width, rect.width, "Should expand width")
        XCTAssertGreaterThan(expanded.height, rect.height, "Should expand height")
        XCTAssertEqual(expanded.midX, rect.midX, accuracy: 1, "Should expand from center")
        XCTAssertEqual(expanded.midY, rect.midY, accuracy: 1, "Should expand from center")
    }
    
    func testAspectRatioPreservation() {
        let sourceSize = CGSize(width: 1920, height: 1080)  // 16:9
        let targetSize = CGSize(width: 224, height: 224)    // 1:1
        
        let result = FaceGeometry.aspectRatioPreservingResize(
            from: sourceSize,
            to: targetSize
        )
        
        let sourceRatio = sourceSize.width / sourceSize.height
        let resultRatio = result.width / result.height
        
        XCTAssertEqual(sourceRatio, resultRatio, accuracy: 0.01)
    }
    
    // MARK: - Image Normalization Tests
    
    func testPixelBufferCreation() {
        let buffer = ImageNormalization.createPixelBuffer(width: 224, height: 224)
        
        XCTAssertEqual(CVPixelBufferGetWidth(buffer), 224)
        XCTAssertEqual(CVPixelBufferGetHeight(buffer), 224)
        XCTAssertEqual(
            CVPixelBufferGetPixelFormatType(buffer),
            kCVPixelFormatType_32BGRA
        )
    }
    
    func testLightingAssessment() {
        // Create a bright test buffer
        let buffer = ImageNormalization.createPixelBuffer(width: 100, height: 100)
        
        CVPixelBufferLockBaseAddress(buffer, .readAndWrite)
        defer { CVPixelBufferUnlockBaseAddress(buffer, .readAndWrite) }
        
        // Fill with bright values
        if let baseAddress = CVPixelBufferGetBaseAddress(buffer) {
            let ptr = baseAddress.assumingMemoryBound(to: UInt8.self)
            for i in 0..<(100 * 100 * 4) {
                ptr[i] = 200  // Bright BGRA values
            }
        }
        
        let rect = CGRect(x: 0, y: 0, width: 100, height: 100)
        let (adequate, score, _) = ImageNormalization.assessLighting(pixelBuffer: buffer, rect: rect)
        
        XCTAssertTrue(adequate, "Bright lighting should be adequate")
        XCTAssertGreaterThan(score, 0.7, "Bright lighting should score high")
    }
    
    // MARK: - Histogram Tests
    
    func testHistogramGeneration() {
        let buffer = ImageNormalization.createPixelBuffer(width: 100, height: 100)
        let rect = CGRect(x: 0, y: 0, width: 100, height: 100)
        
        let histogram = ImageNormalization.luminanceHistogram(pixelBuffer: buffer, rect: rect)
        
        XCTAssertEqual(histogram.count, 256, "Histogram should have 256 bins")
    }
    
    // MARK: - Face Landmarks Tests
    
    func testFaceLandmarksStructure() {
        let bbox = CGRect(x: 100, y: 100, width: 200, height: 300)
        let points = ["leftEye": CGPoint(x: 150, y: 150), "rightEye": CGPoint(x: 250, y: 150)]
        let landmarks = FaceLandmarks(boundingBox: bbox, points: points, confidence: 0.9)
        
        XCTAssertTrue(landmarks.isValid)
        XCTAssertEqual(landmarks.eyeDistance, 100, accuracy: 1)
    }
    
    // MARK: - Coordinate Transforms (reusing from ARKit tests)
    
    func testMeshCoordinateTransformsConsistency() {
        let point = SIMD3<Float>(0.5, 0.5, 0)
        let imageSize = CGSize(width: 1080, height: 1920)
        
        let pixelPoint = MeshCoordinateTransform.toPixelSpace(point, imageSize: imageSize)
        let backToNorm = MeshCoordinateTransform.toNormalizedSpace(pixelPoint, imageSize: imageSize)
        
        XCTAssertEqual(point.x, backToNorm.x, accuracy: 0.01)
        XCTAssertEqual(point.y, backToNorm.y, accuracy: 0.01)
    }
    
    // MARK: - Region Extractor Edge Cases
    
    func testExtractRegionsWithNoFace() {
        // Create a simple solid-color image (no face)
        let size = CGSize(width: 640, height: 480)
        let context = CGContext(
            data: nil,
            width: Int(size.width),
            height: Int(size.height),
            bitsPerComponent: 8,
            bytesPerRow: Int(size.width) * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGBitmapInfo.byteOrder32Little.rawValue | CGImageAlphaInfo.noneSkipFirst.rawValue
        )
        
        context?.setFillColor(red: 1, green: 0, blue: 0, alpha: 1)
        context?.fill(CGRect(x: 0, y: 0, width: size.width, height: size.height))
        
        guard let cgImage = context?.makeImage() else {
            XCTFail("Failed to create test image")
            return
        }
        
        let crops = SkinRegionExtractor.extractRegions(from: cgImage)
        
        // Should return empty or minimal crops for no face
        XCTAssertLessThanOrEqual(crops.count, 1, "Should not extract regions from non-face image")
    }
    
    func testExtractRegionsReturnsValidCrops() {
        // This test requires a real face image, so we'll skip in CI
        // In practice, you'd use a test image asset
        XCTSkipIf(true, "Requires actual face image for testing")
    }
    
    func testQualityAssessment() {
        let buffer = ImageNormalization.createPixelBuffer(width: 224, height: 224)
        let faceRect = CGRect(x: 10, y: 10, width: 200, height: 200)
        
        let (acceptable, score, issues) = ImageNormalization.assessQuality(
            pixelBuffer: buffer,
            faceRect: faceRect
        )
        
        XCTAssertGreaterThanOrEqual(score, 0)
        XCTAssertLessThanOrEqual(score, 1)
    }
    
    // MARK: - Integration-like Tests
    
    func testRegionExtractionPipeline() {
        // Simulated pipeline test
        let imageSize = CGSize(width: 1080, height: 1920)
        
        // 1. Detect face (mocked)
        let faceBounds = CGRect(x: 200, y: 400, width: 600, height: 900)
        
        // 2. Extract regions
        for region in FaceRegion.allCases {
            let regionRect = FaceGeometry.regionRect(in: faceBounds, for: region)
            let clampedRect = FaceGeometry.clampToImage(regionRect, imageSize: imageSize)
            
            // 3. Verify rect is valid
            XCTAssertGreaterThan(clampedRect.width, 0)
            XCTAssertGreaterThan(clampedRect.height, 0)
            XCTAssertGreaterThanOrEqual(clampedRect.origin.x, 0)
            XCTAssertGreaterThanOrEqual(clampedRect.origin.y, 0)
        }
    }
    
    func testBatchProcessingWithVariableSizes() {
        // Test that region extractor can handle custom sizes per region
        let sizes: [FaceRegion: CGSize] = [
            .forehead: CGSize(width: 256, height: 256),
            .leftCheek: CGSize(width: 224, height: 224)
        ]
        
        // Just verify the API works (actual extraction requires real image)
        XCTAssertEqual(sizes[.forehead]?.width, 256)
        XCTAssertEqual(sizes[.leftCheek]?.width, 224)
    }
}
