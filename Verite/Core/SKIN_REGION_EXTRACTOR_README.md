# Skin Region Extractor Module

## Overview

This module extracts and normalizes skin regions from face images for analysis. It is completely **standalone** and can be integrated without architectural changes.

**Module Location:** `Verite/Core/`

## Components

### `FaceGeometry.swift`

Face region definitions and geometric calculations.

**Key Classes/Enums:**

```swift
enum FaceRegion: String, CaseIterable {
    case forehead
    case leftCheek
    case rightCheek
    case chin
    case bridge
    
    var fractionalRect: (x0: Double, y0: Double, x1: Double, y1: Double)
    var displayName: String
}
```

**Key Functions:**

```swift
enum FaceGeometry {
    // Compute pixel rects for regions
    static func regionRect(in faceBounds: CGRect, for region: FaceRegion) -> CGRect
    static func regionRect(in faceBounds: CGRect, _ frac: (x0, y0, x1, y1)) -> CGRect
    
    // Utilities
    static func clampToImage(_ rect: CGRect, imageSize: CGSize) -> CGRect
    static func expand(_ rect: CGRect, by factor: CGFloat) -> CGRect
    static func centeredCrop(in bounds: CGRect, targetSize: CGSize) -> CGRect
    static func aspectRatioPreservingResize(from: CGSize, to: CGSize) -> CGSize
}
```

**Face Landmarks:**

```swift
struct FaceLandmarks {
    let boundingBox: CGRect
    let points: [String: CGPoint]  // "leftEye", "rightEye", "noseTip", etc.
    let confidence: Float
    var isValid: Bool
    
    var eyeDistance: CGFloat?
    var leftEyeCenter: CGPoint?
    var rightEyeCenter: CGPoint?
}

enum FaceLandmarkDetector {
    static func detectLandmarks(in cgImage: CGImage) -> FaceLandmarks?
}
```

### `ImageNormalization.swift`

Lighting analysis and image preprocessing.

**Key Functions:**

```swift
enum ImageNormalization {
    // Lighting analysis
    static func averageLuminance(pixelBuffer: CVPixelBuffer, rect: CGRect) -> Double?
    static func luminanceHistogram(pixelBuffer: CVPixelBuffer, rect: CGRect) -> [Int]
    static func assessLighting(_ buffer: CVPixelBuffer, _ rect: CGRect) 
        -> (adequate: Bool, score: Float, reason: String)
    
    // Correction
    static func adaptiveHistogramEqualization(_ buffer: CVPixelBuffer) -> CVPixelBuffer?
    static func normalizeBrightness(_ buffer: CVPixelBuffer, targetBrightness: Float) -> CVPixelBuffer?
    
    // Pixel buffer operations
    static func createPixelBuffer(width: Int, height: Int) -> CVPixelBuffer
    static func cropPixelBuffer(_ buffer: CVPixelBuffer, to rect: CGRect) -> CVPixelBuffer?
    static func resizePixelBuffer(_ buffer: CVPixelBuffer, to size: CGSize) -> CVPixelBuffer?
    
    // Quality
    static func assessQuality(pixelBuffer: CVPixelBuffer, faceRect: CGRect) 
        -> (acceptable: Bool, score: Float, issues: [String])
}
```

### `SkinRegionExtractor.swift`

Main service for extracting regions.

**Output Structure:**

```swift
struct SkinRegionCrop {
    let region: FaceRegion
    let pixelBuffer: CVPixelBuffer      // Normalized, ready for analysis
    let size: CGSize                     // Output dimensions (e.g., 224×224)
    let confidence: Float
    let avgLuminance: Double?
    let lightingIsAdequate: Bool
}
```

**Main API:**

```swift
enum SkinRegionExtractor {
    // Extract all or selected regions
    static func extractRegions(
        from cgImage: CGImage,
        regions: [FaceRegion] = FaceRegion.allCases,
        targetSize: CGSize = CGSize(width: 224, height: 224)
    ) -> [SkinRegionCrop]
    
    // Extract single region
    static func extractRegion(
        region: FaceRegion,
        faceBounds: CGRect,
        pixelBuffer: CVPixelBuffer,
        targetSize: CGSize
    ) -> SkinRegionCrop?
    
    // Batch with quality assessment
    static func extractRegionsWithQualityAssessment(
        from cgImage: CGImage,
        targetSize: CGSize
    ) -> (crops: [SkinRegionCrop], qualityScore: Float, warnings: [String])
}
```

## Usage

### Basic Region Extraction

```swift
import UIKit

let image = UIImage(named: "face.jpg")!
guard let cgImage = image.cgImage else { return }

// Extract all regions at 224×224
let crops = SkinRegionExtractor.extractRegions(from: cgImage)

for crop in crops {
    print("Region: \(crop.region.displayName)")
    print("  Size: \(crop.size)")
    print("  Lighting OK: \(crop.lightingIsAdequate)")
    
    // Use crop.pixelBuffer for analysis
}
```

### Selective Extraction

```swift
let crops = SkinRegionExtractor.extractRegions(
    from: cgImage,
    regions: [.forehead, .leftCheek, .rightCheek],
    targetSize: CGSize(width: 256, height: 256)
)
```

### Quality Assessment

```swift
let (crops, qualityScore, warnings) = SkinRegionExtractor.extractRegionsWithQualityAssessment(
    from: cgImage
)

print("Quality: \(qualityScore * 100)%")
if !warnings.isEmpty {
    print("Warnings: \(warnings.joined(separator: ", "))")
}
```

## Processing Pipeline

```
1. Detect face + landmarks (Vision)
   ↓
2. Convert CGImage → CVPixelBuffer
   ↓
3. For each region:
   a. Compute region rect from fractional coordinates
   b. Add margin for context
   c. Clamp to image bounds
   d. Crop pixel buffer
   e. Normalize brightness
   f. Resize to target size (224×224 or custom)
   g. Assess lighting quality
   ↓
4. Return array of SkinRegionCrop
```

## Key Features

✅ **Modular** — Each step is independent (detection, cropping, normalization)  
✅ **Testable** — Pure geometry functions, testable normalization  
✅ **Composable** — Works with ARKit face mesh or Vision landmarks  
✅ **Efficient** — Reuses CVPixelBuffer allocations, minimal memory overhead  
✅ **Quality-Aware** — Detects and reports lighting issues  
✅ **Flexible** — Custom sizes per region, selective extraction  

## Coordinate Systems

### Fractional Space (0...1)
- Used for region definitions (e.g., forehead is `y0: 0.05, y1: 0.25`)
- Face-local (relative to face bounding box)

### Pixel Space
- Actual image coordinates
- Used for rect calculations and pixel buffer indexing

### Normalized Image Space
- 0...1 image coordinates
- Used by ARKit module
- Convert using `MeshCoordinateTransform`

## Lighting Assessment

Each region provides:
- `avgLuminance: Double?` — Average brightness 0...255
- `lightingIsAdequate: Bool` — True if brightness is ~80–200 range
- Quality score penalties if lighting is poor

**Adequate Range:**
- 0.2–0.9 normalized brightness
- Optimal: 0.35–0.8

## Integration with Analysis Pipeline

After extraction, crops are ready for CoreML inference:

```swift
let crops = SkinRegionExtractor.extractRegions(from: cgImage)

for crop in crops {
    // Use crop.pixelBuffer as input to CoreML model
    let attributes = analyzeRegion(crop.pixelBuffer)
    
    // Aggregate across regions
}
```

## Performance Notes

- **Memory:** ~50 MB for 5 regions at 224×224 (temporary)
- **Time:** ~100–200 ms for full extraction (Vision + normalization)
- **Pixel Format:** BGRA (standard for AVCaptureSession)

## Testing

```bash
xcodebuild test -scheme Verite -testPlan SkinRegionExtractorTests
```

Tests cover:
- Region geometry (rects, bounds, clamping)
- Image normalization (brightness, histograms)
- Face landmark detection
- Quality assessment
- Coordinate transformations

## Design Principles

✅ **Standalone** — No Vérité dependencies (except models)  
✅ **Pure** — Geometry calculations are pure functions  
✅ **Graceful** — Returns empty crops if no face, not nil  
✅ **Composable** — Can use with ARKit mesh or Vision landmarks  
✅ **Testable** — Each component independently testable  

## Next Steps (Phase 3B)

After Step 2 confirmed:
- Step 3: CoreML analysis pipeline
  - Use `crop.pixelBuffer` as model input
  - Aggregate per-region attributes
  - Return `ScanAnalysis` structure

## Notes

- **CVPixelBuffer Format** — Always BGRA, matches camera output
- **Target Size** — 224×224 is standard for mobile ML models
- **Lighting Threshold** — Can be tuned based on model requirements
- **Region Margins** — Default 1.1× expansion for context

---

This module is **ready for Step 3 integration** (CoreML analysis pipeline).
