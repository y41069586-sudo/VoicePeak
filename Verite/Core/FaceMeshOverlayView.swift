import SwiftUI
import simd

/// Displays real-time ARKit face mesh on top of camera preview.
/// Provides visual feedback for face alignment and tracking quality.
/// Can be placed directly over CameraPreviewView as a ZStack layer.
struct FaceMeshOverlayView: View {
    let arEngine: ARKitFaceEngine
    let imageSize: CGSize
    
    var body: some View {
        Canvas { context, canvasSize in
            guard let tracking = arEngine.faceTracking else { return }
            
            // Scale factor from canvas size to normalized image space
            let scaleX = canvasSize.width / imageSize.width
            let scaleY = canvasSize.height / imageSize.height
            
            // Convert mesh points to canvas space
            let meshPoints = MeshCoordinateTransform.toPixelSpace(
                tracking.meshPointsNormalized,
                imageSize: imageSize
            )
            .map { point in
                CGPoint(x: point.x * scaleX, y: point.y * scaleY)
            }
            
            // Draw mesh face outline (simplified: just key points)
            drawFaceOutline(meshPoints: meshPoints, context: &context, canvasSize: canvasSize)
            
            // Draw alignment guide
            drawAlignmentGuide(tracking: tracking, context: &context, canvasSize: canvasSize)
            
            // Draw tracking status indicator
            drawTrackingStatus(tracking: tracking, context: &context, canvasSize: canvasSize)
        }
        .ignoresSafeArea()
    }
    
    // MARK: - Drawing
    
    private func drawFaceOutline(
        meshPoints: [CGPoint],
        context: inout GraphicsContext,
        canvasSize: CGSize
    ) {
        guard !meshPoints.isEmpty else { return }
        
        // Draw face contour using mesh points
        // Simplified: draw convex hull or outer perimeter
        var path = Path()
        
        // Simplified contour: connect key mesh indices that form face outline
        // Indices 0-16 form right contour, 16-32 form bottom, 32-48 form left
        let contourIndices = (0...48).filter { i in i < meshPoints.count }
        
        if let first = contourIndices.first, first < meshPoints.count {
            path.move(to: meshPoints[first])
            
            for i in contourIndices.dropFirst() {
                if i < meshPoints.count {
                    path.addLine(to: meshPoints[i])
                }
            }
            
            path.closeSubpath()
        }
        
        var stroke = StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round)
        context.stroke(
            path,
            with: .color(.cyan.opacity(0.6)),
            style: stroke
        )
        
        // Draw mesh points as small circles (every 10th to avoid clutter)
        for (i, point) in meshPoints.enumerated() where i % 10 == 0 {
            var pathPoint = Path()
            pathPoint.addEllipse(in: CGRect(x: point.x - 2, y: point.y - 2, width: 4, height: 4))
            context.fill(pathPoint, with: .color(.cyan.opacity(0.4)))
        }
    }
    
    private func drawAlignmentGuide(
        tracking: FaceTrackingState,
        context: inout GraphicsContext,
        canvasSize: CGSize
    ) {
        // Target frame: center of screen, 70% width
        let targetWidth = canvasSize.width * 0.7
        let targetHeight = canvasSize.height * 0.7
        let targetX = (canvasSize.width - targetWidth) / 2
        let targetY = (canvasSize.height - targetHeight) / 2
        let targetRect = CGRect(x: targetX, y: targetY, width: targetWidth, height: targetHeight)
        
        // Draw target frame
        var framePath = Path()
        framePath.addRect(targetRect)
        
        let isWellFramed = MeshCoordinateTransform.isWellFramed(
            faceBounds: tracking.boundingBoxNormalized
        )
        let frameColor: Color = isWellFramed ? .green : .yellow
        
        context.stroke(framePath, with: .color(frameColor.opacity(0.5)), lineWidth: 2)
        
        // Draw corner indicators
        let cornerSize: CGFloat = 12
        let corners: [CGPoint] = [
            CGPoint(x: targetRect.minX, y: targetRect.minY),
            CGPoint(x: targetRect.maxX, y: targetRect.minY),
            CGPoint(x: targetRect.minX, y: targetRect.maxY),
            CGPoint(x: targetRect.maxX, y: targetRect.maxY)
        ]
        
        for corner in corners {
            var cornerPath = Path()
            cornerPath.move(to: CGPoint(x: corner.x - cornerSize/2, y: corner.y))
            cornerPath.addLine(to: CGPoint(x: corner.x + cornerSize/2, y: corner.y))
            cornerPath.move(to: CGPoint(x: corner.x, y: corner.y - cornerSize/2))
            cornerPath.addLine(to: CGPoint(x: corner.x, y: corner.y + cornerSize/2))
            
            context.stroke(cornerPath, with: .color(frameColor.opacity(0.7)), lineWidth: 1.5)
        }
    }
    
    private func drawTrackingStatus(
        tracking: FaceTrackingState,
        context: inout GraphicsContext,
        canvasSize: CGSize
    ) {
        // Draw status indicator in top-left corner
        let statusSize: CGFloat = 12
        var statusCircle = Path()
        statusCircle.addEllipse(in: CGRect(x: 16, y: 16, width: statusSize, height: statusSize))
        
        let statusColor: Color = tracking.isConfident ? .green : .yellow
        context.fill(statusCircle, with: .color(statusColor))
        
        // Draw status outline
        context.stroke(statusCircle, with: .color(statusColor.opacity(0.7)), lineWidth: 1)
    }
}

// MARK: - Preview

#if DEBUG
#Preview {
    ZStack {
        Color.black
        
        FaceMeshOverlayView(
            arEngine: ARKitFaceEngine(),
            imageSize: CGSize(width: 1080, height: 1920)
        )
    }
}
#endif
