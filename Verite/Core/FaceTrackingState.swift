import ARKit
import Foundation
import simd

/// Complete snapshot of tracked face state at a moment in time.
/// All coordinates are normalized to 0...1 image space.
struct FaceTrackingState: Sendable {
    /// Face bounding box in normalized image coordinates (0...1).
    let boundingBoxNormalized: CGRect
    
    /// Face mesh vertices transformed to normalized image space.
    /// ARFaceGeometry has 468 vertices; stored as SIMD3<Float> (x, y, z).
    /// x, y are normalized 0...1; z is depth relative to camera.
    let meshPointsNormalized: [SIMD3<Float>]
    
    /// Head rotation in radians (pitch, yaw, roll).
    /// Useful for determining face angle relative to camera.
    let headRotation: (pitch: Float, yaw: Float, roll: Float)
    
    /// Head position relative to camera (in meters).
    /// Can be used to estimate distance / face size.
    let headPosition: SIMD3<Float>
    
    /// Face scale factor (relative to some reference). 
    /// Larger = closer to camera.
    let faceScale: Float
    
    /// Timestamp of this tracking state.
    let timestamp: Date
    
    /// True if tracking confidence is high.
    let isConfident: Bool
    
    // MARK: - Computed Properties
    
    /// Center of the face in normalized image space.
    var center: CGPoint {
        CGPoint(x: boundingBoxNormalized.midX,
                y: boundingBoxNormalized.midY)
    }
    
    /// Approximate eye center line (midpoint between eyes).
    /// Uses mesh landmarks if available (simplified estimate).
    var eyeMidline: Float? {
        // Left eye approximated at indices 33, 133
        // Right eye approximated at indices 362, 263
        let leftEyeIdx = 33
        let rightEyeIdx = 362
        
        guard meshPointsNormalized.count > rightEyeIdx else { return nil }
        let leftX = meshPointsNormalized[leftEyeIdx].x
        let rightX = meshPointsNormalized[rightEyeIdx].x
        
        return (leftX + rightX) / 2
    }
    
    // MARK: - Initializer
    
    /// Create from ARFaceAnchor and camera frame.
    init(from faceAnchor: ARFaceAnchor, cameraFrame: ARFrame) {
        let transform = faceAnchor.transform
        self.headPosition = transform.translation
        
        // Extract rotation from transform matrix
        let rotation = transform.extractRotation()
        self.headRotation = (pitch: rotation.x, yaw: rotation.y, roll: rotation.z)
        
        // Face scale (proxy: geometry extent)
        if let geometry = faceAnchor.geometry {
            let extent = geometry.extent
            self.faceScale = max(extent.x, max(extent.y, extent.z))
        } else {
            self.faceScale = 1.0
        }
        
        // Mesh points in normalized image space
        var meshPoints: [SIMD3<Float>] = []
        if let geometry = faceAnchor.geometry {
            let vertices = geometry.vertices
            let imageSize = CGSize(width: CGFloat(cameraFrame.camera.imageResolution.width),
                                   height: CGFloat(cameraFrame.camera.imageResolution.height))
            
            for vertex in vertices {
                // Project 3D point to 2D image space
                if let imagePoint = cameraFrame.camera.projectPoint(
                    vertex,
                    orientation: UIInterfaceOrientation.portrait.rawValue,
                    viewportSize: imageSize
                ) {
                    let normalized = SIMD3<Float>(
                        Float(imagePoint.x / imageSize.width),
                        Float(imagePoint.y / imageSize.height),
                        vertex.z
                    )
                    meshPoints.append(normalized)
                }
            }
        }
        self.meshPointsNormalized = meshPoints
        
        // Bounding box from mesh
        if !meshPoints.isEmpty {
            let xs = meshPoints.map { CGFloat($0.x) }
            let ys = meshPoints.map { CGFloat($0.y) }
            let minX = xs.min() ?? 0
            let maxX = xs.max() ?? 1
            let minY = ys.min() ?? 0
            let maxY = ys.max() ?? 1
            
            // Add small padding
            let padding: CGFloat = 0.05
            self.boundingBoxNormalized = CGRect(
                x: max(0, minX - padding),
                y: max(0, minY - padding),
                width: min(1, maxX - minX + 2 * padding),
                height: min(1, maxY - minY + 2 * padding)
            )
        } else {
            self.boundingBoxNormalized = .zero
        }
        
        self.timestamp = Date()
        self.isConfident = faceAnchor.isTracked
    }
}

// MARK: - Matrix Extensions

extension simd_float4x4 {
    var translation: SIMD3<Float> {
        SIMD3(columns.3.x, columns.3.y, columns.3.z)
    }
    
    func extractRotation() -> SIMD3<Float> {
        // Simplified Euler angle extraction from rotation matrix
        // Assumes standard column-major 4x4 transform matrix
        let m = self.columns
        
        let pitch = asin(-m.2.z)  // Y rotation
        let yaw = atan2(m.2.y, m.2.x)  // Z rotation
        let roll = atan2(m.1.z, m.0.z)  // X rotation
        
        return SIMD3(pitch, yaw, roll)
    }
}
