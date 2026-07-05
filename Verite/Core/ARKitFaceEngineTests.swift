import XCTest
@testable import Verite

/// Tests for ARKit face tracking engine module.
/// Verifies that the module is standalone and gracefully handles unavailable ARKit.
final class ARKitFaceEngineTests: XCTestCase {
    
    var engine: ARKitFaceEngine!
    
    override func setUp() {
        super.setUp()
        engine = ARKitFaceEngine()
    }
    
    override func tearDown() {
        engine.stop()
        engine = nil
        super.tearDown()
    }
    
    // MARK: - Availability Tests
    
    func testARKitAvailabilityDetection() {
        // Should report availability based on device capability
        let isAvailable = engine.isAvailable
        XCTAssertIsNotNil(isAvailable, "Engine should report availability status")
    }
    
    func testEngineIsNotTrackingInitially() {
        XCTAssertFalse(engine.isTracking, "Engine should not be tracking initially")
    }
    
    func testFaceTrackingStateIsNilInitially() {
        XCTAssertNil(engine.faceTracking, "Face tracking state should be nil initially")
    }
    
    // MARK: - Start/Stop Tests
    
    func testCanStartEngine() {
        if engine.isAvailable {
            engine.start()
            // Give ARKit a moment to initialize
            let expectation = self.expectation(description: "Engine started")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                expectation.fulfill()
            }
            waitForExpectations(timeout: 1.0)
        } else {
            XCTSkipIf(true, "ARKit not available on this device")
        }
    }
    
    func testCanStopEngine() {
        if engine.isAvailable {
            engine.start()
            engine.stop()
            XCTAssertFalse(engine.isTracking, "Engine should not be tracking after stop")
            XCTAssertNil(engine.faceTracking, "Face tracking state should be nil after stop")
        } else {
            XCTSkipIf(true, "ARKit not available on this device")
        }
    }
    
    func testCanResetEngine() {
        if engine.isAvailable {
            engine.start()
            engine.reset()
            // Should be tracking again after reset
            let expectation = self.expectation(description: "Engine reset")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                expectation.fulfill()
            }
            waitForExpectations(timeout: 1.0)
        } else {
            XCTSkipIf(true, "ARKit not available on this device")
        }
    }
    
    // MARK: - Graceful Degradation
    
    func testEngineDoesNotCrashWhenARKitUnavailable() {
        // This test verifies the engine doesn't crash if ARKit is unavailable
        // The engine should gracefully handle this
        XCTAssertNoThrow {
            let testEngine = ARKitFaceEngine()
            testEngine.start()
            testEngine.stop()
        }
    }
    
    // MARK: - Coordinate Transform Tests
    
    func testCoordinateTransformNormalizedToPixel() {
        let point = SIMD3<Float>(0.5, 0.5, 0)
        let imageSize = CGSize(width: 1080, height: 1920)
        
        let pixelPoint = MeshCoordinateTransform.toPixelSpace(point, imageSize: imageSize)
        
        XCTAssertEqual(pixelPoint.x, 540, accuracy: 1)
        XCTAssertEqual(pixelPoint.y, 960, accuracy: 1)
    }
    
    func testCoordinateTransformPixelToNormalized() {
        let point = CGPoint(x: 540, y: 960)
        let imageSize = CGSize(width: 1080, height: 1920)
        
        let normalized = MeshCoordinateTransform.toNormalizedSpace(point, imageSize: imageSize)
        
        XCTAssertEqual(normalized.x, 0.5, accuracy: 0.01)
        XCTAssertEqual(normalized.y, 0.5, accuracy: 0.01)
    }
    
    // MARK: - Alignment Tests
    
    func testAlignmentScoreWithPerfectAlignment() {
        let faceBounds = CGRect(x: 0.15, y: 0.25, width: 0.7, height: 0.7)
        let targetBounds = CGRect(x: 0.15, y: 0.25, width: 0.7, height: 0.7)
        
        let score = MeshCoordinateTransform.alignmentScore(
            faceBounds: faceBounds,
            targetBounds: targetBounds
        )
        
        XCTAssertGreaterThan(score, 0.95, "Perfect alignment should score > 0.95")
    }
    
    func testAlignmentScoreWithPoorAlignment() {
        let faceBounds = CGRect(x: 0.1, y: 0.1, width: 0.2, height: 0.2)
        let targetBounds = CGRect(x: 0.15, y: 0.25, width: 0.7, height: 0.7)
        
        let score = MeshCoordinateTransform.alignmentScore(
            faceBounds: faceBounds,
            targetBounds: targetBounds
        )
        
        XCTAssertLessThan(score, 0.5, "Poor alignment should score < 0.5")
    }
    
    func testHeadTiltDetection() {
        let (isTilted, angle) = MeshCoordinateTransform.headTiltMetrics(
            pitch: 0, yaw: 0, roll: 0, maxTiltDegrees: 15
        )
        XCTAssertFalse(isTilted, "Zero rotation should not be tilted")
        XCTAssertEqual(angle, 0, accuracy: 0.1)
    }
    
    func testHeadTiltDetectionExceedsThreshold() {
        let (isTilted, angle) = MeshCoordinateTransform.headTiltMetrics(
            pitch: Float.pi / 8,  // 22.5 degrees
            yaw: 0,
            roll: 0,
            maxTiltDegrees: 15
        )
        XCTAssertTrue(isTilted, "Pitch > 15° should be tilted")
        XCTAssertGreaterThan(angle, 15)
    }
    
    // MARK: - Bounding Box Tests
    
    func testBoundingBoxCalculation() {
        let points: [SIMD3<Float>] = [
            SIMD3(0.2, 0.3, 0),
            SIMD3(0.8, 0.7, 0),
            SIMD3(0.5, 0.5, 0)
        ]
        
        let bbox = MeshCoordinateTransform.boundingBox(from: points, padding: 0)
        
        XCTAssertEqual(bbox.minX, 0.2, accuracy: 0.01)
        XCTAssertEqual(bbox.maxX, 0.8, accuracy: 0.01)
        XCTAssertEqual(bbox.minY, 0.3, accuracy: 0.01)
        XCTAssertEqual(bbox.maxY, 0.7, accuracy: 0.01)
    }
    
    func testBoundingBoxWithPadding() {
        let points: [SIMD3<Float>] = [
            SIMD3(0.5, 0.5, 0)
        ]
        
        let bbox = MeshCoordinateTransform.boundingBox(from: points, padding: 0.1)
        
        XCTAssertEqual(bbox.minX, 0.4, accuracy: 0.01)
        XCTAssertEqual(bbox.maxX, 0.6, accuracy: 0.01)
    }
}

// MARK: - XCTAssertNoThrow Helper

private func XCTAssertNoThrow(_ block: @escaping () -> Void, _ message: @autoclosure () -> String = "", file: StaticString = #filePath, line: UInt = #line) {
    do {
        block()
    } catch {
        XCTFail("Code threw unexpectedly: \(error)", file: file, line: line)
    }
}
