# Phase 3: Complete AI Skin Analysis System
## Transform Vérité from Mock → Real On-Device AI

---

## Current State Summary

✅ **Already Real:**
- AVCaptureSession with front camera pipeline
- Vision framework face detection + landmarks on live frames
- Classical CV heuristic analysis engine (SkinAnalysisCore)
- SwiftData persistence for scans + user state
- Baseline capture flow in onboarding

❌ **Needs Implementation (Phase 3):**
- ARKit real-time face mesh tracking & alignment (not just Vision)
- CoreML inference engine (currently Vision + heuristics only)
- Real trend analytics with temporal smoothing & baseline tracking
- Centralized preference/user state persistence system
- Reusable modal system for product picker, conflicts, analysis details
- Onboarding baseline scan UX enhancements
- Analyzer tab real-time display (currently placeholder)
- Performance optimization & frame throttling

---

## Phase 3 Modules (In Implementation Order)

### 1. ARKIT + FACE MESH (Real-Time Face Tracking)
**Why First:** Enables better face stabilization and mesh-based region extraction.

**Files to Create:**
```
Verite/Core/
  ├─ ARKitFaceEngine.swift          (ARKit session management + face mesh tracking)
  ├─ FaceTrackingState.swift        (face position, rotation, mesh data)
  └─ MeshCoordinateTransform.swift  (mesh point → image coordinates)
```

**Implementation Details:**
- Create `ARKitFaceEngine`: Manages `ARFaceTrackingConfiguration`
- Subscribe to frame updates, extract face mesh + facial expression blendshapes
- Track face position (center, scale, yaw/pitch/roll)
- Output normalized face mesh in image coordinates
- Graceful fallback to Vision-only if ARKit unavailable

**API:**
```swift
@Observable
class ARKitFaceEngine {
    @Published private(set) var faceTracking: FaceTrackingState?
    @Published private(set) var isAvailable: Bool
    
    func start() async
    func stop()
    // Mesh points transformed to UIImage coordinates
    var meshPointsInImageSpace: [SIMD3<Float>]? { get }
}
```

**Performance:** 60 FPS, 15ms latency max

---

### 2. SKIN REGION EXTRACTION (Vision + Landmark-Based)
**Purpose:** Segment face into consistent regions for analysis.

**Files to Create:**
```
Verite/Core/
  ├─ SkinRegionExtractor.swift      (face → region crops + normalized buffers)
  ├─ FaceGeometry.swift              (region rect calculations)
  └─ ImageNormalization.swift        (lighting correction, resizing)
```

**Regions to Extract:**
- Forehead (T-zone upper)
- Left cheek
- Right cheek
- Chin
- Bridge (optional)
- Left/right temple (optional)

**Implementation:**
- Use Vision landmarks to compute region rects (as already done in `SkinAnalysisCore`)
- Crop image buffers at each region
- Apply light normalization (histogram equalization or adaptive scaling)
- Return normalized CVPixelBuffer for each region

**API:**
```swift
struct SkinRegionCrop {
    let region: FaceRegion
    let pixelBuffer: CVPixelBuffer
    let confidence: Double
}

struct SkinRegionExtractor {
    static func extractRegions(from cgImage: CGImage) -> [SkinRegionCrop]?
}
```

---

### 3. COREML ANALYSIS ENGINE (Replace Heuristics)
**Critical:** This is the heart of Phase 3.

**Files to Create:**
```
Verite/Core/
  ├─ CoreMLModel.swift              (wrapper for .mlmodel assets)
  ├─ SkinAnalysisMLPipeline.swift    (Vision + CoreML orchestration)
  └─ HeuristicFallback.swift         (if no model: structured heuristics)

Verite/Resources/
  └─ SkinAnalysis.mlmodel           (trained model or placeholder)
```

**Implementation Strategy:**

If a trained CoreML model exists:
- Wrap it in a lightweight `CoreMLModel` class
- Use `VNCoreMLRequest` for inference
- Input: normalized face crop (224×224 or model-specific size)
- Output: 7 attributes (redness, acne, oiliness, texture, pores, blemishes, hydration)

If no trained model yet:
- Create `HeuristicFallback` that restructures existing `SkinMetrics` logic
- Clearly separate "model layer" so it can be swapped later
- Keep inference async and non-blocking

**API:**
```swift
struct SkinAnalysisOutput {
    let redness: Double          // 0...1
    let oiliness: Double
    let texture: Double
    let pores: Double
    let blemishes: Double        // acne detection
    let hydration: Double
    let sensitivity: Double
    let confidence: Double       // 0...1, model confidence
    let processingTimeMs: Double
}

protocol SkinAnalysisModel {
    func analyze(imageCrop: CVPixelBuffer) async -> SkinAnalysisOutput?
}

@Observable
class SkinAnalysisMLPipeline {
    private let model: SkinAnalysisModel
    
    func analyzeFullFace(cgImage: CGImage) async -> ScanAnalysis {
        // 1. Extract regions
        // 2. Run model on each region
        // 3. Aggregate results
        // 4. Return ScanAnalysis
    }
}
```

**Key Constraint:** 
- Zero network calls
- Inference must complete in <2 seconds
- Frame throttling to prevent overload

---

### 4. TREND ANALYTICS ENGINE (Real Baseline Tracking)
**Purpose:** Replace mock trend charts with real temporal analysis.

**Files to Create:**
```
Verite/Services/
  ├─ TrendEngine.swift              (compute changes vs baseline)
  ├─ TrendCalculator.swift           (statistical aggregation)
  └─ TemporalSmoother.swift          (reduce noise in short series)
```

**Implementation Details:**

**Baseline Definition:**
- First full-face scan after onboarding = baseline
- Stored as reference `ScanAnalysis` in `UserProfile`
- All future scans compute delta vs this baseline

**Trend Computation:**
```swift
struct TrendData {
    let attribute: SkinAttribute
    let baseline: Double
    let current: Double
    let delta: Double           // current - baseline
    let percentChange: Double   // delta / baseline * 100 (if baseline != 0)
    let trend: TrendDirection   // improved, stable, worsened
    let confidence: Double      // 0...1, based on sample size
}

class TrendEngine {
    func computeTrend(
        attribute: SkinAttribute,
        scans: [Scan],
        baseline: ScanAnalysis?
    ) -> TrendData?
    
    // Weekly aggregation
    func weeklyTrends(limit: Int = 12) -> [Date: [TrendData]]
    
    // Improvement detection
    func improvementScore(attribute: SkinAttribute) -> Double?
}
```

**Logic:**
1. Load baseline scan (isBaseline = true)
2. For each attribute, compare recent scans to baseline
3. Apply temporal smoothing (moving average over last 3–5 scans)
4. Compute percentage change
5. Classify as improvement/stable/worsened (threshold: ±6%)

**Edge Cases:**
- No baseline yet → show "baseline capture pending"
- Only 1–2 scans → raw delta, low confidence
- High variance → flag as noisy, suggest retest

---

### 5. USER PREFERENCES PERSISTENCE (Centralized Store)
**Purpose:** Replace scattered AppStorage with clean repository pattern.

**Files to Create:**
```
Verite/Services/
  ├─ PreferencesStore.swift          (centralized user state)
  ├─ SkinProfileStore.swift           (skin type, concerns, goals)
  └─ RoutinePreferencesStore.swift    (routine settings)
```

**PreferencesStore API:**
```swift
@Observable
class PreferencesStore {
    // Skin profile
    var skinType: SkinType { get set }
    var skinConcerns: [SkinConcern] { get set }
    var skinGoals: [String] { get set }
    
    // Analysis calibration
    var lightingAdjustment: Double { get set }  // -1...+1
    var cameraDistance: Double { get set }      // cm, ~15-30
    
    // Routine preferences
    var routineReminders: Bool { get set }
    var amRoutine: [Product] { get set }
    var pmRoutine: [Product] { get set }
    
    // Advanced
    var languageOverride: String? { get set }
    
    // Persistence
    func save() throws
    func reset() throws
}
```

**Implementation:**
- Use SwiftData for structured data (linked to UserProfile)
- Use AppStorage only for simple flags + language
- No scattered UserDefaults throughout the code
- Single source of truth via `@Observable`

**Integration:**
- Replace `@AppStorage` usage in Settings/Home with `PreferencesStore`
- Update Routine tab to read/write via store
- Update Onboarding to initialize store

---

### 6. MODAL SYSTEM (Reusable Components)
**Purpose:** Professional UX layer for common flows.

**Files to Create:**
```
Verite/UI/Modals/
  ├─ ProductPickerModal.swift        (select products for routine)
  ├─ IngredientConflictModal.swift    (warn on incompatibilities)
  ├─ AnalysisDetailModal.swift        (breakdown + confidence)
  ├─ LightingCalibrationModal.swift   (on-device hint system)
  └─ ModalAnimationSystem.swift       (shared transitions)
```

**ProductPickerModal:**
- Searchable list of products
- Select → assign to AM/PM routine
- Show ingredients warnings
- Smooth sheet transition

**IngredientConflictModal:**
- Simple, non-alarming warnings
- "High alcohol + sensitive skin" → gentle suggestion
- Link to ingredient explanations
- "Use at own discretion" tone

**AnalysisDetailModal:**
- Breakdown of scan result
- Per-attribute confidence scores
- Lighting quality indicator
- "Why this matters" explanation

**LightingCalibrationModal:**
- On-device histogram feedback
- Face alignment hints
- "Hold still for 3 seconds" countdown

**API:**
```swift
// Product picker
@State private var showProductPicker = false
.sheet(isPresented: $showProductPicker) {
    ProductPickerModal(
        onSelect: { product in
            preferences.amRoutine.append(product)
        }
    )
}

// Conflict warning
if ingredientEngine.hasConflict(products) {
    IngredientConflictModal(conflict: ...) { dismiss in
        // proceed or cancel
    }
}

// Analysis detail
ScanResultView {
    AnalysisDetailModal(analysis: scan.analysis)
}
```

---

### 7. ONBOARDING BASELINE SCAN FLOW
**Purpose:** Guided first scan with baseline confirmation.

**Enhancement Areas:**

**File Updates:**
- `Verite/Onboarding/OnboardingFlowView.swift` (add baseline step)
- `Verite/Onboarding/OnboardingBaselineView.swift` (refine UX)

**Flow:**
1. **Explain Scan** → "This will establish your skin baseline"
2. **Lighting Check** → histogram + position guide (via LightingCalibrationModal)
3. **Face Alignment** → ARKit/Vision mesh overlay + alignment cues
4. **Hold Still** → 3-second countdown
5. **Capture Baseline** → run analysis
6. **Confirmation** → "Baseline saved. We'll compare future scans to this."
7. **Next Steps** → proceed to home or routine setup

**Key UX Elements:**
- Real-time face mesh overlay (from ARKit)
- Lighting quality bar (0–100%)
- "Perfect alignment" state (face fully in guide)
- Confident/low-confidence feedback

---

### 8. ANALYZER TAB REAL-TIME UPGRADE
**Purpose:** Replace static UI with live scan results and trends.

**File Updates:**
- `Verite/Analyzer/AnalyzerTabView.swift` (currently all placeholder)

**New Structure:**
```swift
struct AnalyzerTabView: View {
    @Query private var scans: [Scan]
    @State private var engine = SkinAnalysisMLPipeline()
    @State private var trends: [SkinAttribute: TrendData] = [:]
    
    var body: some View {
        if let latestScan = scans.first {
            AnalyzerContentView(scan: latestScan, trends: trends)
        } else {
            AnalyzerEmptyState()  // Prompt baseline capture
        }
    }
}
```

**Components:**
- **Latest Result Card** → today's scan (if available)
- **Attribute Breakdown** → 7 cards with confidence bars
- **Trend Chart** → weekly improvement % per attribute
- **Comparison View** → vs baseline + vs 1 week ago
- **Quick Scan Button** → jump to camera

---

### 9. PERFORMANCE & MEMORY OPTIMIZATION
**Files to Create:**
```
Verite/Core/
  ├─ FrameThrottler.swift            (60 FPS → 15 FPS for analysis)
  └─ ImageBufferPool.swift            (reuse CVPixelBuffer allocations)
```

**Key Optimizations:**
- Process every 4th video frame (15 FPS) for analysis, display at 60 FPS
- Reuse `CVPixelBuffer` allocations via object pool
- Async CoreML inference on background thread
- Deallocate large intermediate buffers immediately after use
- Monitor memory growth (unit test)

---

## Implementation Order (Priority)

### Phase 3A (Weeks 1–2): Core Analysis Engine
1. ✅ ARKit face mesh tracking
2. ✅ Vision region extraction
3. ✅ CoreML pipeline + heuristic fallback
4. ✅ Frame throttling + performance

### Phase 3B (Week 3): Persistence & Analytics
5. ✅ Preferences store (centralized)
6. ✅ Baseline tracker
7. ✅ Trend analytics engine
8. ✅ Temporal smoothing

### Phase 3C (Week 4): UI & Modals
9. ✅ Modal system (product picker, conflicts, details)
10. ✅ Onboarding baseline flow UX
11. ✅ Analyzer tab real-time display
12. ✅ Integration tests

---

## Testing Strategy

**Unit Tests (no UI):**
- `SkinAnalysisMLPipeline` heuristics
- `TrendEngine` calculations
- `PreferencesStore` persistence
- `TemporalSmoother` edge cases

**Integration Tests:**
- Baseline capture → analysis → persistence
- Scan 2 weeks later → trend computation
- Onboarding flow end-to-end

**Manual Testing:**
- Live camera feed + alignment guide (must feel smooth, 60 FPS)
- First baseline scan (verify saved, correct analysis)
- Weekly trends (realistic deltas)
- Modal transitions (smooth, no jank)
- Settings → preferences reflected immediately

---

## Architecture Principles

**Strict Separation:**
```
/Core           – Pure logic: analysis, trends, extraction
/Services       – Singletons: preferences, analytics engines
/Features       – Views: Analyzer, Home, Routine, Progress, Onboarding
/UI             – Reusable: modals, components, design system
```

**No Rules Broken:**
- ❌ No giant SwiftUI files
- ❌ No mixed logic in views
- ❌ No duplicated pipelines
- ✅ MVVM or feature-based where UI state is needed
- ✅ Testable, pure functions in Core
- ✅ Clean observable facades for UI

---

## Success Criteria (End of Phase 3)

- [ ] Real-time face mesh tracking (ARKit)
- [ ] CoreML inference pipeline (or heuristic placeholder)
- [ ] Baseline capture → analysis → save
- [ ] Trend calculations (improvement detection)
- [ ] Centralized preference storage
- [ ] Analyzer tab displays real trends + latest scan
- [ ] All modals functional (product picker, conflicts, details)
- [ ] Onboarding baseline flow guides user smoothly
- [ ] 60 FPS camera, <2s analysis latency
- [ ] Zero privacy leaks (on-device only)
- [ ] App feels "real" not simulated

---

## File Structure Summary (Post-Phase 3)

```
Verite/
├─ Core/
│  ├─ ARKitFaceEngine.swift
│  ├─ SkinRegionExtractor.swift
│  ├─ SkinAnalysisMLPipeline.swift
│  ├─ FaceGeometry.swift
│  ├─ ImageNormalization.swift
│  └─ FrameThrottler.swift
│
├─ Services/
│  ├─ PreferencesStore.swift
│  ├─ TrendEngine.swift
│  ├─ TrendCalculator.swift
│  └─ TemporalSmoother.swift
│
├─ UI/Modals/
│  ├─ ProductPickerModal.swift
│  ├─ IngredientConflictModal.swift
│  ├─ AnalysisDetailModal.swift
│  ├─ LightingCalibrationModal.swift
│  └─ ModalAnimationSystem.swift
│
├─ Features/
│  ├─ Analyzer/
│  ├─ Home/
│  ├─ Routine/
│  ├─ Progress/
│  └─ Onboarding/ (enhanced)
│
└─ [existing structure preserved]
    ├─ Scan/
    ├─ Analysis/
    ├─ Models/
    ├─ DesignSystem/
    └─ etc.
```

---

## Notes

- **ARKit Fallback:** If device lacks A12+ (rare), Vision-only pipeline continues to work
- **CoreML Model:** Assume placeholder for now; trained model can be dropped in later
- **Privacy:** All computation runs on-device; no image transmission
- **Compatibility:** iOS 16+ for ARKit + SwiftData
- **Onboarding Refresh:** Not a redesign—just add real baseline capture step
- **No Big Rewrites:** Existing ScanView, Analysis logic, SwiftData schema stay largely intact

---

## Next Steps

1. Review this plan
2. Confirm module priority order
3. Begin Phase 3A (Core Analysis Engine)
4. Create ticket per module
5. Code review after each module is complete
