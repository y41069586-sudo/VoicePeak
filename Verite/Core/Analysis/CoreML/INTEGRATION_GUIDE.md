# Phase 3B Integration Guide
## How to Use CoreML Layer in Your App

---

## Quick Start

### 1. Initialize Engine
```swift
import Verite

// In your AppState or SceneDelegate
@MainActor
class AppState: ObservableObject {
    let skinAnalysisEngine = SkinAnalysisEngineCoreML()
    
    func setupAnalysisEngine() async {
        // Preload model to avoid first-frame latency
        await skinAnalysisEngine.preloadModel()
    }
}
```

### 2. Run Analysis
```swift
// In your scanning/analysis code
let input = AnalysisInput(
    faceMeshPoints: faceGeometry.meshPoints,
    skinRegions: extractedRegions,
    captureQuality: quality
)

// Async analysis (doesn't block UI)
let result = await appState.skinAnalysisEngine.analyze(input: input)

// Update UI with result
DispatchQueue.main.async {
    self.scanResult = result
}
```

### 3. Display Results
```swift
// ScanAnalysisResult is compatible with existing UI
ScanResultView(result: result)  // No UI changes needed!
```

---

## Mode Selection

### Development: Heuristic Only
```swift
Task {
    await appState.skinAnalysisEngine.setMode(.heuristic)
}
```
- Debug Phase 3A behavior
- No model dependency
- Fast iteration

### Testing: Pure CoreML
```swift
Task {
    await appState.skinAnalysisEngine.setMode(.coreML)
}
```
- Test new model accuracy
- Model-only performance
- Falls back to heuristic if model missing

### Production: Hybrid (Default)
```swift
Task {
    // Default mode is already .hybrid
    // Only set if customizing
    await appState.skinAnalysisEngine.setMode(.hybrid)
}
```
- Best accuracy + safety
- ML predictions enhance heuristic
- Never crashes

---

## Configuration

### Standard Setup
```swift
let engine = SkinAnalysisEngineCoreML()
// Uses defaults:
// - mode: .hybrid
// - mlWeight: 0.7 (70% ML, 30% heuristic)
// - confidenceThreshold: 0.5
// - enableFallback: true
```

### Custom Configuration
```swift
var config = CoreMLAnalysisConfig()
config.mode = .hybrid
config.mlWeight = 0.8              // Trust ML more
config.confidenceThreshold = 0.6   // Higher bar for ML
config.enableFallback = true       // Always safe
config.logMetrics = true           // Debug output

await engine.updateConfig(config)
```

### Tuning ML Weight
```
mlWeight = 1.0   → Pure ML (risky, use coreML mode)
mlWeight = 0.7   → ML-heavy hybrid (balanced, default)
mlWeight = 0.5   → Equal blend (conservative)
mlWeight = 0.3   → Heuristic-heavy (safe, less accurate)
mlWeight = 0.0   → Pure heuristic (same as heuristic mode)
```

---

## Model Management

### Check Model Availability
```swift
let available = await engine.isModelAvailable()

if available {
    print("✅ CoreML model loaded")
    await engine.setMode(.hybrid)
} else {
    print("⚠️  Model missing, using heuristic")
    await engine.setMode(.heuristic)
}
```

### Preload on App Start
```swift
@main
struct VeriteApp: App {
    @StateObject var appState = AppState()
    
    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(appState)
                .task {
                    // Preload to avoid latency on first scan
                    await appState.skinAnalysisEngine.preloadModel()
                }
        }
    }
}
```

### Manual Model Cache Clear
```swift
// Force reload from disk
await engine.clearModelCache()

// Then repreload
await engine.preloadModel()
```

---

## Async Patterns

### SwiftUI Integration
```swift
struct ScanView: View {
    @EnvironmentObject var appState: AppState
    @State private var analysisResult: ScanAnalysisResult?
    @State private var isAnalyzing = false
    
    var body: some View {
        ZStack {
            CameraPreviewView { capturedFrame in
                isAnalyzing = true
                
                Task {
                    // Async analysis off main thread
                    let input = processFrame(capturedFrame)
                    let result = await appState.skinAnalysisEngine.analyze(input: input)
                    
                    await MainActor.run {
                        analysisResult = result
                        isAnalyzing = false
                    }
                }
            }
            
            if let result = analysisResult {
                ScanResultView(result: result)
            }
        }
    }
}
```

### Manual Task Management
```swift
// Explicit task binding
var analysisTask: Task<ScanAnalysisResult, Never>?

func startAnalysis(input: AnalysisInput) {
    analysisTask = Task {
        return await engine.analyze(input: input)
    }
}

func stopAnalysis() {
    analysisTask?.cancel()
}
```

---

## Performance Monitoring

### Enable Debug Metrics
```swift
var config = CoreMLAnalysisConfig()
config.logMetrics = true
await engine.updateConfig(config)

// Output:
// [CoreML] ℹ️  CoreML model loaded successfully
// [CoreML] ℹ️  Analysis (hybrid): 24.5ms
// [CoreML] ℹ️  Analysis (hybrid): 23.2ms
```

### Programmatic Metrics
```swift
let metrics = await engine.getMetrics()

print("Total analyses: \(metrics.analysisCount)")
print("Average hybrid: \(metrics.averageHybridTime * 1000)ms")
print("Min ML time: \(metrics.minCoreMLTime * 1000)ms")
print("Max ML time: \(metrics.maxCoreMLTime * 1000)ms")

// Reset for next session
await engine.resetMetrics()
```

### Monitoring Performance
```swift
struct PerformanceMonitor {
    let engine: SkinAnalysisEngineCoreML
    
    func reportMetrics() async {
        let metrics = await engine.getMetrics()
        
        let avgTime = metrics.averageHybridTime * 1000
        let status = avgTime < 25 ? "✅ Good" : "⚠️  Slow"
        
        print("\(status): \(avgTime)ms average")
    }
}
```

---

## Error Handling

### Graceful Fallback (Automatic)
```swift
// No error handling needed!
// Engine automatically falls back to heuristic

let result = await engine.analyze(input: input)
// Result is always valid ScanAnalysisResult
```

### Explicit Fallback Detection
```swift
// Check if CoreML was used
let mode = await engine.getMode()
let result = await engine.analyze(input: input)

if mode == .coreML && result.rednesScore.confidence < 0.5 {
    // CoreML fell back to heuristic
    print("Model confidence low, consider manual override")
}
```

### Debugging Failures
```swift
// Enable metrics to see what happened
var config = CoreMLAnalysisConfig()
config.logMetrics = true
await engine.updateConfig(config)

// Check model availability
let available = await engine.isModelAvailable()
print("Model available: \(available)")

// Try preloading
await engine.preloadModel()
```

---

## Integration with Existing Code

### Compatibility: Phase 3A → Phase 3B
```swift
// OLD CODE (Phase 3A)
let result = SkinAnalysisEngine.analyze(
    input: input,
    regionWeighting: .default
)

// NEW CODE (Phase 3B - Drop-In Replacement)
let result = await engine.analyze(
    input: input,
    regionWeighting: .default
)

// result is identical ScanAnalysisResult
// Just add 'await' and use new engine
```

### With BaselineStore
```swift
let baselineStore = BaselineStore()

// Analysis (unchanged)
let scanResult = await engine.analyze(input: input)

// Comparison (unchanged)
let comparison = await baselineStore.compareToBaseline(scanResult)

// Everything works as before!
```

### With Baseline Setting
```swift
// Set baseline (unchanged API)
try await baselineStore.setBaseline(scanResult)

// Later comparisons work identically
let comparison = await baselineStore.compareToBaseline(newScanResult)
```

---

## A/B Testing

### Compare Heuristic vs. CoreML
```swift
func compareAlgorithms(input: AnalysisInput) async {
    let heuristicResult = await analyzeHeuristic(input)
    let coreMLResult = await analyzeCoreML(input)
    
    print("Heuristic: \(heuristicResult.overallSkinScore)")
    print("CoreML: \(coreMLResult.overallSkinScore)")
}

func analyzeHeuristic(_ input: AnalysisInput) async -> ScanAnalysisResult {
    await engine.setMode(.heuristic)
    return await engine.analyze(input: input)
}

func analyzeCoreML(_ input: AnalysisInput) async -> ScanAnalysisResult {
    await engine.setMode(.coreML)
    return await engine.analyze(input: input)
}
```

### Feature Flag Integration
```swift
if FeatureFlags.enableCoreML {
    await engine.setMode(.hybrid)
} else {
    await engine.setMode(.heuristic)
}
```

---

## Model Deployment

### Including Model in Bundle
1. Add `.mlmodelc` to Xcode project
2. Ensure it's in Build Phases → Copy Bundle Resources
3. Verify file name matches model name

### Model Updates
```swift
// Swap model by file name
let engineV1 = SkinAnalysisEngineCoreML(modelName: "SkinAnalysisModel_v1")
let engineV2 = SkinAnalysisEngineCoreML(modelName: "SkinAnalysisModel_v2")

// A/B test both
let resultV1 = await engineV1.analyze(input: input)
let resultV2 = await engineV2.analyze(input: input)
```

---

## Testing

### Unit Tests
```swift
// Run existing tests (Phase 3A still works)
XCTest: SkinAnalysisEngineTests

// Run new Phase 3B tests
XCTest: SkinAnalysisEngineCoreMLTests
```

### Integration Testing
```swift
func testEndToEndAnalysis() async {
    let engine = SkinAnalysisEngineCoreML()
    let input = createMockAnalysisInput()
    
    let result = await engine.analyze(input: input)
    
    XCTAssertGreater(result.overallSkinScore, 0)
    XCTAssertLess(result.overallSkinScore, 100)
}
```

---

## Troubleshooting

### Model Not Found
```
Problem: ⚠️  Failed to load CoreML model
Solution: 
  1. Verify .mlmodelc in project
  2. Check file name matches modelName parameter
  3. Confirm in Build Phases → Copy Bundle Resources
```

### Slow Performance
```
Problem: Analysis taking >30ms
Solution:
  1. Check CPU load (other tasks running?)
  2. Try .heuristic mode to compare
  3. Monitor with logMetrics: true
  4. Consider throttling to 15 FPS
```

### Inconsistent Results
```
Problem: Different scores between runs
Solution:
  1. Normal: ML has slight variance
  2. Enable hybrid mode for stability
  3. Use higher mlWeight for consistency
  4. Check lighting conditions (affects both)
```

---

## Best Practices

### ✅ DO
- Use hybrid mode in production
- Preload model on app startup
- Enable fallback (always true)
- Monitor performance with metrics
- Test with poor lighting conditions
- Keep Phase 3A tests passing

### ❌ DON'T
- Modify Phase 3A code
- Run analysis on main thread (use await)
- Assume model is available (check first)
- Ignore fallback mechanism
- Change RegionWeighting
- Modify ScanAnalysisResult structure

---

## Summary

Phase 3B integration is **minimal**:

1. Create engine: `SkinAnalysisEngineCoreML()`
2. Run analysis: `await engine.analyze(input:)`
3. Use result: Identical to Phase 3A

Everything else **just works** because Phase 3B is a drop-in replacement layer.
