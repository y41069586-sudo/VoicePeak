# Codemagic CI/CD Deployment Guide

**Status**: Production-Ready  
**Last Updated**: Phase 3B  
**CoreML**: Optional (heuristic fallback in CI)

---

## Overview

This guide covers the complete Codemagic CI/CD setup for Vérité, ensuring:

1. **Deterministic builds** via XcodeGen (no committed `.xcodeproj`)
2. **All tests pass** in CI (Phase 3A + 3B) without CoreML model
3. **CoreML optional** (fallback to heuristic mode if missing)
4. **No build-time CoreML dependency** (`.mlmodelc` is optional)
5. **Production-grade signing & archiving** for TestFlight

---

## Architecture

### XcodeGen Workflow

The project uses **XcodeGen** to generate `Verite.xcodeproj` from `project.yml`:

```bash
brew install xcodegen
xcodegen generate --spec project.yml
```

**Benefits**:
- No `.xcodeproj` checked into git (avoids merge conflicts)
- Single source of truth (`project.yml`)
- Deterministic, reproducible builds
- CI can regenerate project on every run

### Test Structure

Tests are now organized in a separate XcodeGen target `VeriteTests`:

```
Verite/
├── Core/
│   ├── Analysis/
│   │   ├── SkinAnalysisEngineTests.swift       (Phase 3A)
│   │   ├── CoreML/
│   │   │   └── SkinAnalysisEngineCoreMLTests.swift  (Phase 3B)
│   │   └── ...
│   ├── ARKitFaceEngineTests.swift              (Camera/face detection)
│   └── SkinRegionExtractorTests.swift          (Region extraction)
└── ... (main sources excluded via **/*Tests.swift excludes)
```

**Configuration in `project.yml`**:
- App target (`Verite`): excludes `**/*Tests.swift`
- Test target (`VeriteTests`): includes only `**/*Tests.swift`
- Test target depends on app target

### CoreML Deployment Strategy

#### Why CoreML is Optional

1. **Not in repo**: `.mlmodel` / `.mlmodelc` files are not committed
2. **Fallback system**: `SkinAnalysisEngineCoreML` gracefully degrades
3. **Default mode**: `.hybrid` mode with heuristic baseline
4. **CI behavior**: Tests pass without model (heuristic path works)

#### Runtime Behavior

```swift
enum AnalysisMode {
    case heuristic      // Pure fallback (always works)
    case coreML         // ML-only (needs model)
    case hybrid         // ML + heuristic (recommended, works without model)
}

// Default config (CI-safe)
CoreMLAnalysisConfig(
    mode: .hybrid,              // ← Fallback to heuristic if model missing
    mlWeight: 0.7,              // 70% ML, 30% heuristic
    enableFallback: true        // ← Required for CI
)
```

**What happens without model**:
- `ModelLoader.loadModel()` returns `nil`
- `InferencePipeline.infer()` detects missing model
- `HybridFusionEngine` returns heuristic baseline
- **App continues to work** (with heuristic predictions)

---

## Workflows

### 1. Compile Check (Every Push to `claude/*`)

**Purpose**: Fast feedback on syntax/build errors

```yaml
ios-compile-check:
  - Generates project via XcodeGen
  - Builds unsigned app for iOS Simulator
  - Takes ~15-20 minutes
  - No tests (quick check)
```

**When to use**: Every commit, every PR (fast compilation check)

### 2. Phase 3 Tests (Every Push to `claude/*`)

**Purpose**: Run all Phase 3A + 3B tests in CI

```yaml
ios-test-phase3:
  - Generates project via XcodeGen
  - Runs all **/*Tests.swift tests
  - Collects code coverage
  - Takes ~20-30 minutes
  - Runs on iOS Simulator (no CoreML model)
```

**Test coverage**:
- Phase 3A: Heuristic engine, ARKit integration, region extraction
- Phase 3B: CoreML integration (fallback mode), hybrid fusion, model loading

**What tests verify**:
- ✓ Heuristic analysis works (baseline)
- ✓ CoreML gracefully fails when model missing
- ✓ Fallback to heuristic is automatic
- ✓ App output is deterministic
- ✓ No crashes in CI environment

### 3. Archive Build (Every Push to `main` / `develop`)

**Purpose**: Create an unsigned IPA for manual testing

```yaml
ios-archive:
  - Generates project via XcodeGen
  - Builds Release configuration
  - Creates app bundle
  - Takes ~20 minutes
  - No signing (manual distribution only)
```

**When to use**: Before final release (verify Release config builds)

### 4. Release to TestFlight (Every Tag `v*`)

**Purpose**: Signed build → TestFlight for beta testing

```yaml
ios-release:
  - Generates project via XcodeGen
  - Runs final test verification
  - Builds & signs IPA
  - Uploads to TestFlight
  - Takes ~30-40 minutes
  - Requires App Store Connect integration
```

**Prerequisites**:
- Tag matches pattern `v*` (e.g., `v1.0.0`, `v1.0.1-beta`)
- App Store Connect integration configured in Codemagic
- Signing certificate + provisioning profile auto-managed

---

## Setup Instructions

### Prerequisites

- [ ] Codemagic account (free tier is sufficient)
- [ ] GitHub repo connected to Codemagic
- [ ] (Optional) App Store Connect account for TestFlight

### Step 1: Configure Codemagic

1. **Create project**: Codemagic → `+ New app` → Select GitHub repo → Select iOS
2. **Auto-detect settings**: Codemagic detects `codemagic.yaml`
3. **Configure signing** (for release only):
   - Codemagic → Team settings → Integrations
   - Add "App Store Connect" integration
   - Name it exactly: `Verite 1` (or update `codemagic.yaml` with your name)
4. **Enable workflows**:
   - Codemagic → `codemagic.yaml` → Enable each workflow

### Step 2: Verify XcodeGen Setup

```bash
# Local verification (before pushing)
brew install xcodegen
xcodegen generate --spec project.yml
xcodebuild test -project Verite.xcodeproj -scheme Verite
```

### Step 3: Push & Test

```bash
# Test compile check
git push origin feature-branch -u

# Watch in Codemagic → ios-compile-check (should pass in ~15 min)
# Watch in Codemagic → ios-test-phase3 (should pass in ~25 min)
```

### Step 4: Tag & Release

```bash
# When ready for TestFlight
git tag v0.1.0
git push origin v0.1.0

# Watch in Codemagic → ios-release (should complete in ~40 min)
# IPA automatically uploaded to TestFlight
```

---

## CI Behavior: CoreML Handling

### What Happens During `ios-test-phase3`

1. **No `.mlmodelc` file** in bundle (not committed)
2. **ModelLoader.loadModel()** is called
   - Looks for `SkinAnalysisModel.mlmodelc` in bundle
   - File not found → returns `nil`
   - **No error, no crash**
3. **InferencePipeline.infer()** detects missing model
   - Returns empty/null predictions
4. **HybridFusionEngine** detects failed inference
   - Checks config: `enableFallback: true` (default)
   - Falls back to heuristic baseline
   - **Returns heuristic predictions as result**
5. **Tests pass** (test data mocks both paths)

### Example Test Output

```
[SkinAnalysisEngineCoreMLTests testModelMissingFallback]
  ModelLoader: Model not found (expected in CI)
  InferencePipeline: Inference skipped, model unavailable
  HybridFusionEngine: Falling back to heuristic baseline
  Result: ✓ Correct fallback behavior verified
```

---

## Production Deployment: Adding the CoreML Model

When you have a trained `.mlmodelc` file, deploy it to production:

### Step 1: Add Model to Bundle

```bash
# Copy compiled model
cp /path/to/SkinAnalysisModel.mlmodelc Verite/Resources/Models/

# Add to Xcode (via XcodeGen in project.yml or manual Xcode UI)
# Ensure: Build Phases → Copy Bundle Resources → includes .mlmodelc
```

### Step 2: Update Config (Optional)

Change default mode if desired:

```swift
// In app initialization
let config = CoreMLAnalysisConfig(
    mode: .coreML,              // Use ML exclusively (model is now present)
    mlWeight: 1.0,              // 100% ML
    enableFallback: true        // Still fallback if model corrupted
)
```

Or keep `.hybrid` (recommended for production resilience):

```swift
let config = CoreMLAnalysisConfig(
    mode: .hybrid,              // Always use heuristic baseline
    mlWeight: 0.8,              // 80% ML, 20% heuristic
    enableFallback: true
)
```

### Step 3: Commit & Deploy

```bash
git add Verite/Resources/Models/SkinAnalysisModel.mlmodelc
git commit -m "Add production SkinAnalysisModel"
git tag v1.1.0-ml
git push origin v1.1.0-ml
```

**CI will now**:
- Include `.mlmodelc` in bundle
- Tests run with CoreML inference
- Production app uses ML predictions

---

## Troubleshooting

### Build Fails: "XcodeGen not found"

```bash
# Install XcodeGen locally
brew install xcodegen

# Check codemagic.yaml has XcodeGen install step
# scripts:
#   - name: Install XcodeGen
#     script: brew install xcodegen
```

### Tests Fail: "VeriteTests target not found"

1. Verify `project.yml` includes both targets:
   ```yaml
   targets:
     Verite:
       type: application
     VeriteTests:
       type: bundle
   ```
2. Regenerate project: `xcodegen generate --spec project.yml`
3. Verify tests are in `Verite/**/*Tests.swift`

### App Crashes: "CoreML model not found"

**Expected in CI** (not a bug). Verify fallback:

1. Check `CoreMLAnalysisConfig.enableFallback: true` (default)
2. Check mode is `.hybrid` or `.heuristic` (not `.coreML` alone)
3. Run tests: `xcodebuild test -project Verite.xcodeproj -scheme Verite`
4. Tests should pass (heuristic fallback verified)

### TestFlight Upload Fails

1. Check App Store Connect integration name matches `codemagic.yaml`:
   ```yaml
   integrations:
     app_store_connect: "Verite 1"  # ← Must match Codemagic integration name
   ```
2. Check bundle ID: `com.verite.com`
3. Check signing certificate + provisioning profile are valid in App Store Connect

---

## Performance Targets

| Workflow | Time | Notes |
|----------|------|-------|
| `ios-compile-check` | 15-20 min | Build only, no tests |
| `ios-test-phase3` | 20-30 min | Full test suite, coverage |
| `ios-archive` | 20-25 min | Release build, archive |
| `ios-release` | 30-40 min | Build + sign + TestFlight |

---

## Environment Variables

### Required (Codemagic UI)

- `XCODE_PROJECT`: `Verite.xcodeproj` (auto-generated)
- `XCODE_SCHEME`: `Verite`

### Optional

```yaml
environment:
  vars:
    CI_ENVIRONMENT: "codemagic"      # For analytics
    LOG_LEVEL: "debug"               # Increase verbosity
```

### App Store Connect (for release workflow)

- Configured via Codemagic UI (Integrations → App Store Connect)
- No secrets in `codemagic.yaml`
- Auto-managed by Codemagic

---

## Next Steps

1. ✅ **Push to `claude/*` branch** → Verify compile check passes
2. ✅ **Review test output** → Confirm Phase 3A + 3B tests run
3. ✅ **Test fallback** → Verify app works without CoreML model
4. ✅ **Tag release** → Push `v*` tag → Verify TestFlight upload
5. 🔄 **Deploy CoreML model** (when ready) → Update bundle, re-tag

---

## References

- **XcodeGen Docs**: https://github.com/yonaskolb/XcodeGen
- **Codemagic Docs**: https://docs.codemagic.io
- **CoreML Integration Guide**: `Verite/Core/Analysis/CoreML/INTEGRATION_GUIDE.md`
- **Phase 3B Architecture**: `Verite/Core/Analysis/CoreML/PHASE_3B_ARCHITECTURE.md`

---

## Support

For issues or questions:

1. Check test output: Codemagic → Workflow → Logs
2. Review `codemagic.yaml` syntax
3. Verify `project.yml` is valid YAML
4. Test locally: `xcodegen generate && xcodebuild test -project Verite.xcodeproj -scheme Verite`
