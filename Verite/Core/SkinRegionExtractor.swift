import CoreGraphics
import CoreVideo
import Vision
import UIKit

/// One region extracted and ready for analysis.
struct SkinRegionCrop {
    /// Which region this is.
    let region: FaceRegion
    
    /// Normalized pixel buffer (BGRA) ready for analysis.
    let pixelBuffer: CVPixelBuffer
    
    /// Dimensions of the crop.
    let size: CGSize
    
    /// Confidence that this region was accurately extracted.
    let confidence: Float
    
    /// Average luminance in this region (for lighting assessment).
    let avgLuminance: Double?
    
    /// Whether lighting is adequate for analysis in this region.
    let lightingIsAdequate: Bool
}

/// Extracts and normalizes skin regions from a face image.
/// Handles face detection, region segmentation, lighting correction, and pixel buffer preparation.
/// Standalone service—can be used independently of other modules.
enum SkinRegionExtractor {
    
    // MARK: - Main Extraction API
    
    /// Extract all skin regions from an image.
    /// - Parameters:
    ///   - cgImage: Input image (CGImage)
    ///   - regions: Which regions to extract (default: all)
    ///   - targetSize: Output size for each region (default: 224×224 for ML models)
    /// - Returns: Array of extracted regions, or empty if face not detected
    static func extractRegions(
        from cgImage: CGImage,
        regions: [FaceRegion] = FaceRegion.allCases,
        targetSize: CGSize = CGSize(width: 224, height: 224)
    ) -> [SkinRegionCrop] {
        // 1. Detect face and landmarks
        guard let landmarks = FaceLandmarkDetector.detectLandmarks(in: cgImage) else {
            return []
        }
        
        guard landmarks.isValid else {
            return []
        }
        
        // 2. Create pixel buffer from CGImage
        guard let pixelBuffer = cvPixelBufferFromCGImage(cgImage) else {
            return []
        }
        
        // 3. Extract each requested region
        var crops: [SkinRegionCrop] = []
        
        for region in regions {
            if let crop = extractRegion(
                region: region,
                faceBounds: landmarks.boundingBox,
                pixelBuffer: pixelBuffer,
                targetSize: targetSize
            ) {
                crops.append(crop)
            }
        }
        
        return crops
    }
    
    /// Extract a single region.
    static func extractRegion(
        region: FaceRegion,
        faceBounds: CGRect,
        pixelBuffer: CVPixelBuffer,
        targetSize: CGSize = CGSize(width: 224, height: 224)
    ) -> SkinRegionCrop? {
        // Compute region rect in face space
        let regionRect = FaceGeometry.regionRect(in: faceBounds, for: region)
        
        // Add small margin for context
        let marginedRect = FaceGeometry.expand(regionRect, by: 1.1)
        
        // Clamp to image bounds
        let imageSize = CGSize(width: CVPixelBufferGetWidth(pixelBuffer),
                               height: CVPixelBufferGetHeight(pixelBuffer))
        let clampedRect = FaceGeometry.clampToImage(marginedRect, imageSize: imageSize)
        
        // Crop to region
        guard let regionBuffer = ImageNormalization.cropPixelBuffer(pixelBuffer, to: clampedRect) else {
            return nil
        }
        
        // Normalize brightness
        guard let normalizedBuffer = ImageNormalization.normalizeBrightness(
            pixelBuffer: regionBuffer,
            targetBrightness: 0.5
        ) else {
            return nil
        }
        
        // Resize to target size
        guard let resizedBuffer = ImageNormalization.resizePixelBuffer(
            normalizedBuffer,
            to: targetSize
        ) else {
            return nil
        }
        
        // Assess quality
        let avgLuma = ImageNormalization.averageLuminance(
            pixelBuffer: normalizedBuffer,
            rect: CGRect(x: 0, y: 0, width: CVPixelBufferGetWidth(normalizedBuffer), height: CVPixelBufferGetHeight(normalizedBuffer))
        )
        
        let (lightingOK, _, _) = ImageNormalization.assessLighting(
            pixelBuffer: normalizedBuffer,
            rect: CGRect(x: 0, y: 0, width: CVPixelBufferGetWidth(normalizedBuffer), height: CVPixelBufferGetHeight(normalizedBuffer))
        )
        
        return SkinRegionCrop(
            region: region,
            pixelBuffer: resizedBuffer,
            size: targetSize,
            confidence: 0.85,  // Conservative estimate
            avgLuminance: avgLuma,
            lightingIsAdequate: lightingOK
        )
    }
    
    /// Extract all regions with custom sizing per region.
    static func extractRegionsWithVariableSizes(
        from cgImage: CGImage,
        regionSizes: [FaceRegion: CGSize] = [:]
    ) -> [SkinRegionCrop] {
        let defaultSize = CGSize(width: 224, height: 224)
        
        guard let landmarks = FaceLandmarkDetector.detectLandmarks(in: cgImage) else {
            return []
        }
        
        guard let pixelBuffer = cvPixelBufferFromCGImage(cgImage) else {
            return []
        }
        
        var crops: [SkinRegionCrop] = []
        
        for region in FaceRegion.allCases {
            let size = regionSizes[region] ?? defaultSize
            if let crop = extractRegion(
                region: region,
                faceBounds: landmarks.boundingBox,
                pixelBuffer: pixelBuffer,
                targetSize: size
            ) {
                crops.append(crop)
            }
        }
        
        return crops
    }
    
    // MARK: - Batch Processing
    
    /// Extract regions and provide summary statistics.
    static func extractRegionsWithQualityAssessment(
        from cgImage: CGImage,
        targetSize: CGSize = CGSize(width: 224, height: 224)
    ) -> (crops: [SkinRegionCrop], qualityScore: Float, warnings: [String]) {
        let crops = extractRegions(from: cgImage, targetSize: targetSize)
        
        var warnings: [String] = []
        var qualityScore: Float = 1.0
        
        if crops.isEmpty {
            warnings.append("No face detected")
            qualityScore = 0
        } else {
            // Check lighting across regions
            let inadequateRegions = crops.filter { !$0.lightingIsAdequate }
            if !inadequateRegions.isEmpty {
                warnings.append("Lighting issues in \(inadequateRegions.count) region(s)")
                qualityScore *= 0.8
            }
            
            // Check coverage
            if crops.count < 3 {
                warnings.append("Incomplete face coverage")
                qualityScore *= 0.7
            }
        }
        
        return (crops, max(0, qualityScore), warnings)
    }
    
    // MARK: - Private Helpers
    
    private static func cvPixelBufferFromCGImage(_ cgImage: CGImage) -> CVPixelBuffer? {
        let attrs: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferCGImageCompatibilityKey as String: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey as String: true
        ]
        
        var pixelBuffer: CVPixelBuffer?
        let status = CVPixelBufferCreateWithIOSurface(
            kCFAllocatorDefault,
            cgImage,
            attrs as CFDictionary,
            &pixelBuffer
        )
        
        if status != kCVReturnSuccess {
            // Fallback: create buffer and render CGImage
            var buffer: CVPixelBuffer?
            let createStatus = CVPixelBufferCreate(
                kCFAllocatorDefault,
                cgImage.width,
                cgImage.height,
                kCVPixelFormatType_32BGRA,
                attrs as CFDictionary,
                &buffer
            )
            
            guard createStatus == kCVReturnSuccess, let buffer = buffer else {
                return nil
            }
            
            CVPixelBufferLockBaseAddress(buffer, .readAndWrite)
            defer { CVPixelBufferUnlockBaseAddress(buffer, .readAndWrite) }
            
            let context = CGContext(
                data: CVPixelBufferGetBaseAddress(buffer),
                width: cgImage.width,
                height: cgImage.height,
                bitsPerComponent: 8,
                bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGBitmapInfo.byteOrder32Little.rawValue | CGImageAlphaInfo.noneSkipFirst.rawValue
            )
            
            context?.draw(cgImage, in: CGRect(x: 0, y: 0, width: cgImage.width, height: cgImage.height))
            
            return buffer
        }
        
        return pixelBuffer
    }
}

// MARK: - Preview/Testing

#if DEBUG
import SwiftUI

struct SkinRegionExtractorPreview: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 16) {
            Text("Region Extraction Module")
                .font(.headline)
            
            Text("Ready to extract:")
            ForEach(FaceRegion.allCases, id: \.id) { region in
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text(region.displayName)
                    Spacer()
                }
                .padding(.horizontal)
            }
            
            Spacer()
        }
        .padding()
    }
}

#endif
