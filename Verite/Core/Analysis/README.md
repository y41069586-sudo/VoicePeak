# Skin Analysis Engine - Core Analysis Module

**Status:** Phase 3A Step 3 - ✅ COMPLETE

---

## Quick Start

### Basic Analysis

```swift
// 1. Prepare input from ARKit + Vision modules
let input = AnalysisInput(
    faceMeshPoints: arKitEngine.meshPoints,
    skinRegions: regionExtractor.regions,
    captureQuality: assessCaptureQuality()
)

// 2. Run analysis
let result = SkinAnalysisEngine.analyze(input: input)

// 3. Use result
print("Overall Skin Score: \(result.overallSkinScore)")
print("Redness: \(result.rednesScore.value)")
print("Acne: \(result.acneScore.value)")
```

### Baseline Comparison

```swift
let store = BaselineStore()

// First scan
try await store.setBaseline(firstScan)

// Later scan
if let comparison = await store.compareToBaseline(laterScan) {
    print("Redness change: \(comparison.deltas.rednes)%")
    print("Trend: \(comparison.trend)")
}
```

---

## Module Structure

```
Core/Analysis/
├── ScanAnalysisResult.swift       ← Output model (immutable, Codable)
├── AnalysisInput.swift            ← Input contract
├── RegionWeighting.swift          ← Regional aggregation
├── BaselineStore.swift            ← Baseline comparison & trends
├── PixelAnalysis.swift            ← Pixel-level metrics (10 functions)
├── SkinAnalysisEngine.swift       ← Main scoring logic (7 attributes)
├── SkinAnalysisEngineTests.swift  ← Comprehensive unit tests (41 tests)
├── INTEGRATION_EXAMPLES.swift     ← Usage examples (10 scenarios)
├── README.md                      ← This file
├── ARCHITECTURE_SUMMARY.md        ← Architecture overview
├── SKIN_ANALYSIS_ENGINE_README.md ← User guide & API reference
└── SCORING_HEURISTICS.md          ← Mathematical foundations
```

---

## Key Components

### 1. Input: AnalysisInput

```swift
struct AnalysisInput {
    let faceMeshPoints: [SIMD3<Float>]      // From ARKit
    let skinRegions: [SkinRegionData]        // From Vision
    let captureQuality: CaptureQuality       // Quality metrics
    let timestamp: Date
}
```

### 2. Output: ScanAnalysisResult

```swift
struct ScanAnalysisResult: Codable, Sendable {
    let overallSkinScore: Float              // 0–100
    let rednesScore: SkinAttribute           // 0–100
    let acneScore: SkinAttribute             // 0–100
    let oilinessScore: SkinAttribute         // 0–100
    let textureScore: SkinAttribute          // 0–100
    let poreScore: SkinAttribute             // 0–100
    let hydrationScore: SkinAttribute        // 0–100
    let sensitivityScore: SkinAttribute      // 0–100
    let baselineComparison: BaselineComparison?
}

struct SkinAttribute: Codable, Sendable {
    let value: Float                         // 0–100
    let confidence: Float                    // 0–1
    let regionContributions: RegionBreakdown // Per-region breakdown
}
```

### 3. Engine: SkinAnalysisEngine

```swift
enum SkinAnalysisEngine {
    static func analyze(
        input: AnalysisInput,
        regionWeighting: RegionWeighting = .default,
        qualityPenalty: Bool = true
    ) -> ScanAnalysisResult
}
```

### 4. Weighting: RegionWeighting

```swift
let weights = RegionWeighting(
    forehead: 0.2,
    leftCheek: 0.3,
    rightCheek: 0.3,
    chin: 0.2
)

// Presets: .default, .cheekFocused, .balanced, .tZoneFocused
```

### 5. Baseline: BaselineStore

```swift
let store = BaselineStore()
try await store.setBaseline(firstScan)
let comparison = await store.compareToBaseline(laterScan)
```

---

## Scoring Attributes

| Attribute | What It Measures | Score Range | Healthy |
|-----------|-----------------|-------------|---------|
| **Redness** | Inflammation, sensitivity | 0–100 | 0–25 |
| **Acne** | Breakouts, blemishes | 0–100 | 0–20 |
| **Oiliness** | Oil production, shine | 0–100 | 30–50 |
| **Texture** | Surface smoothness | 0–100 | 0–25 |
| **Pore** | Pore size visibility | 0–100 | 0–25 |
| **Hydration** | Moisture level | 0–100 | 50–100 |
| **Sensitivity** | Skin reactivity | 0–100 | 0–25 |
| **Overall** | Composite health | 0–100 | 70–100 |

---

## Confidence Values

Each score includes a confidence value (0–1):

- **0.9–1.0**: Very high confidence
- **0.7–0.9**: Good confidence
- **0.5–0.7**: Moderate confidence
- **<0.5**: Low confidence (use for reference only)

Confidence factors:
- **Base**: By metric type (redness: 0.75, acne: 0.70, etc.)
- **Coverage**: Reduced if not all 4 regions present
- **Quality**: Not a direct factor (handled via quality_factor)

---

## Region Analysis

Each attribute includes per-region breakdown:

```swift
let foreheadRedness = result.rednesScore.regionContributions.forehead
let leftCheekRedness = result.rednesScore.regionContributions.leftCheek
let rightCheekRedness = result.rednesScore.regionContributions.rightCheek
let chinRedness = result.rednesScore.regionContributions.chin
```

All regions scored 0–100 independently, then aggregated with weights.

---

## Baseline System

### First Scan (Baseline)

```swift
let baselineStore = BaselineStore()
let firstScan = SkinAnalysisEngine.analyze(input: input1)
try await baselineStore.setBaseline(firstScan)
```

Baseline stored persistently (JSON to Documents directory).

### Later Scans (Comparison)

```swift
let laterScan = SkinAnalysisEngine.analyze(input: input2)
if let comparison = await baselineStore.compareToBaseline(laterScan) {
    print("Redness delta: \(comparison.deltas.rednes)%")  // +8% = 8% worse
    print("Acne delta: \(comparison.deltas.acne)%")       // -5% = 5% better
    print("Trend: \(comparison.trend)")                    // .improving, .stable, .worsening
}
```

### Delta Interpretation

- **Negative delta** (e.g., -5%): Improvement in that attribute
- **Positive delta** (e.g., +8%): Worsening
- **|delta| < 2%**: Stable (within noise threshold)

### Trend Determination

```
avg_change = mean(all_deltas)

if |avg_change| <= 2.0 → .stable
else if avg_change > 0 → .worsening
else → .improving
```

---

## Performance

- **Speed**: <10ms per analysis on A15+ chips
- **Memory**: ~5–10MB (pixel buffers already normalized)
- **Threading**: Safe for concurrent analysis; no shared mutable state
- **CPU-only**: Pure math, no GPU required

---

## Testing

**41 comprehensive unit tests** covering:

- Determinism (identical input → identical output)
- Score ranges (0–100 for scores, 0–1 for confidence)
- Quality penalty effects
- Region weighting correctness
- Redness detection validation
- JSON serialization
- Baseline comparison logic
- Trend determination

**Run tests:**
```bash
xcodebuild test -scheme Verite -testPlan SkinAnalysisTests
```

---

## Documentation

### Architecture & Design
- **ARCHITECTURE_SUMMARY.md**: Complete architecture overview
- **SKIN_ANALYSIS_ENGINE_README.md**: Detailed user guide & API reference

### Technical Details
- **SCORING_HEURISTICS.md**: Mathematical foundations for each metric
- **Inline code comments**: Why decisions (not what)

### Examples
- **INTEGRATION_EXAMPLES.swift**: 10 usage scenarios and integration points

---

## Design Principles

### ✅ Enforced Invariants

1. **No randomness**: Deterministic, reproducible output
2. **Immutable outputs**: All results Codable & Sendable
3. **No UI coupling**: Zero SwiftUI/UIKit references
4. **No CoreML yet**: Pure heuristic logic
5. **No networking**: No external API calls
6. **All pure functions**: Except BaselineStore (file I/O)
7. **Region weights sum to 1.0**: Validated in init
8. **Scores in [0, 100]**: Automatically clamped

### ✅ Separation of Concerns

```
ARKitFaceEngine (face tracking only)
      ↓
SkinRegionExtractor (region extraction only)
      ↓
SkinAnalysisEngine (scoring only)
      ↓
      ← Never goes back up the chain
```

---

## Phase 3B: CoreML Integration

This architecture is designed for seamless ML enhancement:

```swift
// Phase 3B: Simply replace scoring functions
// Old:
private static func analyzeRedness(...) -> [FaceRegion: Float] {
    let metric = PixelAnalysis.rednessMetric(...)
    return normalize(metric)  // 8 lines of heuristics
}

// New:
private static func analyzeRedness(...) -> [FaceRegion: Float] {
    return coreMLModel.predictRedness(input.skinRegions)  // 1 line
}
```

**No changes needed to:**
- Input/output contracts
- Region weighting system
- Baseline comparison logic
- Confidence calculation
- Tests
- Documentation

---

## Usage Examples

### Example 1: Complete Pipeline

```swift
let regions = SkinRegionExtractor.extractRegions(from: cgImage)
let input = AnalysisInput(
    faceMeshPoints: arKitEngine.meshPoints,
    skinRegions: regions.map { /* convert */ },
    captureQuality: assessQuality()
)
let result = SkinAnalysisEngine.analyze(input: input)
print("Overall: \(result.overallSkinScore)")
```

### Example 2: Custom Weighting

```swift
let result = SkinAnalysisEngine.analyze(
    input: input,
    regionWeighting: .cheekFocused  // For acne analysis
)
```

### Example 3: Baseline Tracking

```swift
let store = BaselineStore()
try await store.setBaseline(firstScan)
let comparison = await store.compareToBaseline(laterScan)
print("Improvement: \(comparison.trend)")
```

### Example 4: JSON Persistence

```swift
let encoder = JSONEncoder()
encoder.dateEncodingStrategy = .iso8601
let data = try encoder.encode(result)
try data.write(to: fileURL, options: .atomic)
```

See **INTEGRATION_EXAMPLES.swift** for 10 detailed scenarios.

---

## Quality Adjustment

Quality affects overall score via penalty factor:

```
quality_factor = 0.7 + (overall_quality * 0.3)
```

Example:
- Perfect capture (quality 1.0): factor = 1.0 (no penalty)
- Poor lighting (quality 0.5): factor = 0.85 (15% penalty)

Disable with:
```swift
let result = SkinAnalysisEngine.analyze(input: input, qualityPenalty: false)
```

---

## What's Included

✅ 7 skin attribute scoring
✅ Overall composite score
✅ Per-region breakdown
✅ Confidence values
✅ Baseline comparison system
✅ Trend detection
✅ JSON serialization
✅ Comprehensive unit tests
✅ Detailed documentation
✅ Integration examples

---

## What's NOT Included

❌ CoreML models (Phase 3B)
❌ UI rendering (Phase 4)
❌ Camera control (Phase 3A Steps 1–2)
❌ Networking (N/A)
❌ Advanced ML (Phase 3B+)
❌ User preferences (Phase 4+)

---

## Troubleshooting

### "Score seems incorrect"
1. Check `CaptureQuality` – poor lighting/stability → quality penalty
2. Verify region coverage – missing regions reduce confidence
3. See **SCORING_HEURISTICS.md** for expected ranges per metric

### "Confidence too low"
1. Improve lighting (target: 0.8+)
2. Ensure face is stable and frontal
3. Retry capture
4. Check region extraction confidence

### "Baseline comparison not working"
1. Ensure first scan was set: `await store.setBaseline(scan)`
2. Check file permissions in Documents directory
3. Verify both scans have same region coverage

---

## API Reference

See **SKIN_ANALYSIS_ENGINE_README.md** for complete API documentation.

Quick reference:
- `SkinAnalysisEngine.analyze()` – Main entry point
- `RegionWeighting` – 4 presets + custom init
- `BaselineStore` – Persistence and comparison
- `PixelAnalysis` – 10 metric functions

---

## Contributing

When extending this module:

1. **Maintain immutability**: All outputs must be immutable
2. **Stay deterministic**: No randomness
3. **Preserve separation**: No UI/CoreML/networking
4. **Test everything**: Add unit tests for new functionality
5. **Document**: Add code comments (WHY only) and user documentation

---

## Support

- **Architecture questions**: See ARCHITECTURE_SUMMARY.md
- **Scoring logic**: See SCORING_HEURISTICS.md
- **API usage**: See SKIN_ANALYSIS_ENGINE_README.md
- **Examples**: See INTEGRATION_EXAMPLES.swift
- **Tests**: See SkinAnalysisEngineTests.swift

---

## Phase Timeline

- **Phase 3A Step 1**: ARKit face tracking ✅
- **Phase 3A Step 2**: Vision region extraction ✅
- **Phase 3A Step 3**: Analysis foundation (THIS PHASE) ✅
- **Phase 3B**: CoreML integration 🔄
- **Phase 3C**: Personalization & advanced ML
- **Phase 4**: UI & visualization
- **Phase 5**: Analytics & insights

---

## Summary

This module provides a **production-ready, deterministic, testable skin analysis engine** that:

- ✅ Scores 7 skin health attributes
- ✅ Computes confidence values
- ✅ Provides per-region breakdown
- ✅ Supports baseline comparison
- ✅ Detects trends
- ✅ Produces Codable output
- ✅ Runs in <10ms
- ✅ Is fully unit tested
- ✅ Is extensively documented
- ✅ Is ready for CoreML integration

**Ready for Phase 3B.**

---

## Questions?

Consult the documentation in order:
1. This file (quick start)
2. ARCHITECTURE_SUMMARY.md (overview)
3. SKIN_ANALYSIS_ENGINE_README.md (detailed guide)
4. SCORING_HEURISTICS.md (technical deep dive)
5. INTEGRATION_EXAMPLES.swift (code examples)
6. Source code (inline docs)
