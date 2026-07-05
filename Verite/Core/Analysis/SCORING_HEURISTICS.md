# Skin Analysis Scoring Heuristics

This document explains the mathematical foundations and design rationale for each scoring heuristic in the Skin Analysis Engine.

---

## Overview

The scoring system uses **deterministic heuristics** based on pixel-level analysis to approximate clinical skin health metrics. These heuristics will later be enhanced with CoreML models in Phase 3B, but are designed to work independently and provide reasonable results.

### Core Principle

Each score (0–100) represents a spectrum:

- **0–25**: Excellent/Healthy
- **25–50**: Good/Acceptable
- **50–75**: Fair/Concerning
- **75–100**: Poor/Severe

(Score direction varies by attribute; see each section)

---

## Redness Score

### What We're Measuring

Redness indicates inflammation, sensitivity, acne, rosacea, or irritation. Clinically assessed via:
- Red channel prominence in RGB color space
- Luminance variance (indicates capillary activity)

### Mathematical Foundation

#### Component 1: Red Channel Excess

In BGRA pixel format, we compute:

```
red_excess = R - (B + G) / 2
```

This isolates the red component independent of overall brightness.

**Why this works:**
- Healthy skin: R ≈ (B + G) / 2 (balanced color)
- Red skin: R >> (B + G) / 2 (red dominates)

**Normalization:**
Typical range: -30 to +30 (empirically observed)

```
normalized = ((red_excess + 30) / 60) * 100
```

Clamps to [0, 100].

#### Component 2: Luminance Variance

Redness often correlates with capillary activity, which causes luminance fluctuation:

```
luminance_factor = (std_dev / 50) * 10
```

Where `std_dev` is the standard deviation of luminance in the region.

Assumption: healthy skin has std_dev ~30–50; inflamed skin ~40–70.

### Final Formula

```
redness_score = normalized_red_excess + luminance_factor * 0.2
```

Weight `luminance_factor` at 0.2 (20%) because red channel is the primary indicator.

### Validation

- **Clear skin**: Red-excess near 0, low variance → score ~20
- **Mild redness**: Red-excess +10, variance 40 → score ~35
- **Inflamed**: Red-excess +25, variance 60 → score ~65
- **Severe redness**: Red-excess +30, variance 70 → score ~85

---

## Acne Score

### What We're Measuring

Acne severity assessed via:
- Texture irregularities (pores, comedones, pustules)
- Surface roughness (bumpy/uneven)

### Mathematical Foundation

#### Component 1: Pore Frequency

High-frequency patterns (small pores and bumps) detected via multi-scale variance:

```
pore_frequency = fine_scale_variance - coarse_scale_variance
```

Where:
- `fine_scale_variance`: Variance at 3px kernel (detects individual pores)
- `coarse_scale_variance`: Variance at 7px kernel (detects broad features)

**Why this works:**
- Healthy skin: Small difference (smooth)
- Porous/bumpy skin: Large difference (many high-frequency features)

**Normalization:**
Typical range: 0–30

```
pore_component = clamp((pore_freq / 20) * 40, 0, 50)
```

#### Component 2: Texture Variance

Overall surface roughness measured at medium scale (5px kernel):

```
texture_variance = local_variance at 5px kernel
```

**Why this works:**
- Smooth skin: Low variance (~5–15)
- Textured skin: High variance (~20–80)

**Normalization:**
```
texture_component = clamp((texture_var / 50) * 60, 0, 50)
```

### Final Formula

```
acne_score = pore_component + texture_component
acne_score = clamp(score, 0, 100)
```

Both components equally weighted (acne manifests as bumpy + porous).

### Validation

- **Clear**: Pore freq 0–5, texture var 5–15 → score ~10
- **Mild**: Pore freq 5–10, texture var 15–30 → score ~35
- **Moderate**: Pore freq 10–15, texture var 30–45 → score ~60
- **Severe**: Pore freq 20+, texture var 60+ → score ~85+

---

## Oiliness Score

### What We're Measuring

Oil production assessed via:
- Specular highlights (bright, reflective regions = oil shine)
- Overall luminance (bright = more reflective = oilier)

### Mathematical Foundation

#### Component 1: Specularity

Bright spots indicate oil/sebum (high light reflection):

```
specularity_percentage = percentage of pixels with luminance > threshold
```

Typical threshold: 200/255 (very bright).

**Why this works:**
- Dry skin: Few pixels > 200 luma (~0–5%)
- Oily skin: Many pixels > 200 luma (~10–30%)

**Normalization:**
```
specularity_score = specularity_percentage * 70
```

Capped at 70 to leave room for other factors.

#### Component 2: Luminance Level

Higher overall brightness suggests more oil:

```
avg_luminance: 0–255
```

Typical ranges:
- Normal: 100–150
- Oily: 150–200

**Normalization:**
```
luma_factor = clamp((avg_luminance - 100) / 50 * 30, 0, 30)
```

### Final Formula

```
oiliness_score = specularity_score + luma_factor
oiliness_score = clamp(score, 0, 100)
```

### Validation

- **Dry**: Specularity 1%, luma 90 → score ~3
- **Balanced**: Specularity 8%, luma 130 → score ~30
- **Oily**: Specularity 20%, luma 170 → score ~65
- **Very oily**: Specularity 30%, luma 200 → score ~90

---

## Texture Score

### What We're Measuring

Surface smoothness/roughness assessed via:
- Local luminance variance (edge density)
- Overall surface uniformity

### Mathematical Foundation

#### Single Component: Texture Variance

Computed at 5px kernel (medium scale):

```
variance = sqrt(mean_of_squared_deviations)
```

Applied at every non-border pixel with subsampling (step = kernel_size/2 for efficiency).

**Why this works:**
- Smooth skin: Variance ~5–10
- Rough skin: Variance ~30–80

**Normalization:**
```
texture_score = clamp((variance / 100) * 100, 0, 100)
```

Simple linear mapping; variance inherently captures roughness.

### Notes

- Computed at single scale (5px) for speed and simplicity
- Pore frequency (multi-scale) is handled separately in acne scoring
- Includes both macro roughness and pore texture

### Validation

- **Smooth**: Variance 5–10 → score ~5–10
- **Even**: Variance 15–25 → score ~15–25
- **Rough**: Variance 40–60 → score ~40–60
- **Very rough**: Variance 70+ → score ~70+

---

## Pore Score

### What We're Measuring

Pore size/visibility assessed via:
- High-frequency pattern detection
- Multi-scale variance difference

### Mathematical Foundation

Pore frequency is the difference between fine and coarse variance:

```
pore_frequency = fine_variance - coarse_variance
```

Where:
- `fine_variance`: Variance at 3px kernel (pore-scale)
- `coarse_variance`: Variance at 7px kernel (broader features)

**Why this works:**
- Pores are localized small features
- Difference between fine and coarse detects these localized patterns
- Healthy skin: Small pores (small difference)
- Enlarged pores: Large difference

**Normalization:**
Typical range: 0–30

```
pore_score = clamp((pore_freq / 30) * 100, 0, 100)
```

### Relationship to Acne

Similar to acne's pore frequency component, but:
- Acne emphasizes texture + pore frequency (bumpy + porous)
- Pore score emphasizes pore frequency alone (pure size)

### Validation

- **Minimal**: Pore freq 0–3 → score ~0–10
- **Normal**: Pore freq 8–12 → score ~27–40
- **Enlarged**: Pore freq 15–20 → score ~50–67
- **Very enlarged**: Pore freq 25+ → score ~83+

---

## Hydration Score

### What We're Measuring

Skin moisture level assessed via:
- Luminance uniformity (hydrated = uniform = plump)
- Brightness level (dull appearance = dehydrated)
- Texture smoothness (inverse: rough = dehydrated)

### Mathematical Foundation

#### Component 1: Luminance Uniformity

Well-hydrated skin has even, consistent color (low variance):

```
uniformity_score = clamp((1 - std_dev / 100) * 100, 0, 100)
```

Inverted because low variance = good.

**Why this works:**
- Healthy hydrated: std_dev 20–40 → uniformity ~60–80
- Dehydrated: std_dev 50–80 → uniformity ~20–50

#### Component 2: Brightness Level

Hydrated skin appears brighter (plump, reflective):

```
brightness_score = clamp((avg_luminance / 200) * 100, 0, 100)
```

**Why this works:**
- Dull dehydrated: luma ~80–120 → score ~40–60
- Bright hydrated: luma ~140–180 → score ~70–90

#### Component 3: Texture (Inverse)

Rough texture correlates with dehydration:

```
texture_inverse = clamp((1 - texture_var / 100) * 50, 0, 50)
```

Lower weight (0.5x vs 1x for others).

### Final Formula

```
hydration_score = (uniformity * 0.5) + (brightness * 0.3) + (texture_inverse * 0.2)
hydration_score = clamp(score, 0, 100)
```

Weights reflect relative importance:
- 50%: Uniformity (most indicative of hydration)
- 30%: Brightness (secondary)
- 20%: Smoothness (tertiary)

### Validation

- **Severely dehydrated**: Std 60, luma 90, texture 50 → score ~20
- **Dehydrated**: Std 50, luma 120, texture 40 → score ~40
- **Adequate**: Std 35, luma 150, texture 25 → score ~65
- **Well-hydrated**: Std 25, luma 170, texture 10 → score ~85

---

## Sensitivity Score

### What We're Measuring

Skin reactivity/fragility assessed via:
- Redness (inflamed = sensitive)
- Luminance instability (reactive to stimuli)
- Capture quality (poor lighting = sensitivity to light)

### Mathematical Foundation

#### Component 1: Redness Base

Inflamed skin is typically sensitive:

```
redness_component = redness_score * 0.5
```

Direct correlation; weight at 50%.

#### Component 2: Luminance Instability

Reactive skin shows high luminance variance (capillary fluctuation):

```
instability = clamp((std_dev / 80) * 50, 0, 50)
```

Typical ranges:
- Resilient: std_dev 20–30 → instability ~13–19
- Sensitive: std_dev 50–70 → instability ~31–44

Weight at 50%.

### Final Formula

```
sensitivity_score = (redness * 0.5) + (instability * 0.5)
sensitivity_score = clamp(score, 0, 100)
```

Equal weighting between inflammation and reactivity markers.

### Validation

- **Resilient**: Redness 15, instability 10 → score ~12
- **Slightly sensitive**: Redness 35, instability 20 → score ~27
- **Sensitive**: Redness 55, instability 40 → score ~47
- **Highly sensitive**: Redness 75, instability 50 → score ~62

---

## Overall Skin Score

### Design Principle

Overall score represents **composite skin health** by inverting problem attributes and weighting by clinical importance:

```
healthy_skin = low redness + low acne + balanced oiliness + smooth texture + small pores + high hydration + low sensitivity
```

### Mathematical Foundation

#### Individual Inversions

For most attributes, high score = problem:

```
inverted_redness = 100 - redness
inverted_acne = 100 - acne
inverted_oiliness = 100 - oiliness
inverted_texture = 100 - texture
inverted_pore = 100 - pore
inverted_sensitivity = 100 - sensitivity
```

Hydration already scores high = good, so **no inversion**.

#### Weighting by Clinical Importance

```
overall = (
    inverted_redness * 0.15 +      // Inflammation: 15%
    inverted_acne * 0.20 +         // Most visible concern: 20%
    inverted_oiliness * 0.12 +     // Common but less critical: 12%
    inverted_texture * 0.15 +      // Major concern: 15%
    inverted_pore * 0.10 +         // Secondary: 10%
    hydration * 0.15 +             // Foundational: 15%
    inverted_sensitivity * 0.13    // Indicator: 13%
) * quality_factor
```

**Weight Rationale:**
1. **Acne (20%)**: Most visible, socially impactful
2. **Redness + Texture (15% each)**: Major skin quality concerns
3. **Hydration (15%)**: Foundational skin health
4. **Sensitivity (13%)**: User comfort and barrier health
5. **Oiliness (12%)**: Common but manageable
6. **Pore size (10%)**: Aesthetic but less clinically critical

#### Quality Factor

Adjusts for capture conditions:

```
quality_factor = 0.7 + (overall_capture_quality * 0.3)
```

Range: [0.7, 1.0]

**Examples:**
- Perfect capture (quality 1.0): factor = 1.0 (no penalty)
- Poor capture (quality 0.0): factor = 0.7 (30% penalty)

This reflects confidence: poor capture → results less reliable → lower confidence in score.

### Final Clamping

```
overall_score = clamp(overall, 0, 100)
```

### Validation

Example 1: Healthy skin profile
```
redness: 20, acne: 10, oiliness: 35, texture: 15, pore: 12, hydration: 75, sensitivity: 18
overall = (80*0.15 + 90*0.20 + 65*0.12 + 85*0.15 + 88*0.10 + 75*0.15 + 82*0.13) * 1.0
        = (12 + 18 + 7.8 + 12.75 + 8.8 + 11.25 + 10.66) * 1.0
        = 81.26 → Good skin health
```

Example 2: Problem skin profile
```
redness: 70, acne: 65, oiliness: 75, texture: 55, pore: 60, hydration: 40, sensitivity: 65
overall = (30*0.15 + 35*0.20 + 25*0.12 + 45*0.15 + 40*0.10 + 40*0.15 + 35*0.13) * 0.85
        = (4.5 + 7 + 3 + 6.75 + 4 + 6 + 4.55) * 0.85
        = 35.8 * 0.85 → 30.43 → Poor skin health
```

---

## Confidence Calculation

### Base Confidence per Attribute

Each attribute has a base confidence depending on measurement reliability:

| Attribute | Base Confidence | Reason |
|-----------|-----------------|--------|
| Redness | 0.75 | Red channel is direct |
| Acne | 0.70 | Multi-factor, texture-dependent |
| Oiliness | 0.72 | Specularity detectable but variable |
| Texture | 0.68 | Depends on lighting, surface angle |
| Pore | 0.60 | Smallest features, hardest to detect |
| Hydration | 0.65 | Indirect measurement via multiple factors |
| Sensitivity | 0.70 | Inferred from redness + variance |

### Region Coverage Adjustment

Confidence reduced if not all regions present:

```
coverage = number_of_regions / 4.0
adjusted_confidence = base_confidence * coverage
```

Example:
- All 4 regions: coverage = 1.0 → confidence unchanged
- 3 regions: coverage = 0.75 → confidence * 0.75
- 2 regions: coverage = 0.5 → confidence * 0.5

### Interpretation

- **0.9–1.0**: Very high confidence, reliable measurement
- **0.7–0.9**: Good confidence, trustworthy
- **0.5–0.7**: Moderate confidence, informative but not definitive
- **<0.5**: Low confidence, use for reference only

---

## Pixel Analysis Assumptions

### Lighting Model

Assumes:
- Neutral daylight or soft white light (5000–6500K)
- No extreme shadows or glare
- Reasonably frontal face angle (<30° deviation)

### Color Space

All analysis in BGRA (iPhone camera native):
- B: Blue channel
- G: Green channel
- R: Red channel
- A: Alpha (unused)

### Image Quality

Assumes:
- Normalized pixel buffers (from Vision module)
- Brightness normalized to target (50% avg luma)
- 224×224 or larger resolution

---

## Future Enhancements

### Phase 3B: CoreML Models

Replace heuristics with trained models:
- Redness classification (inflammation types)
- Acne detection and grading
- Oiliness levels
- Texture classification
- Pore size estimation
- Hydration assessment
- Sensitivity markers

All replace corresponding `analyzeX()` functions.

### Phase 3C: Personalization

Per-user calibration:
- Age-appropriate baseline norms
- Skin type adjustments (dry, combination, oily)
- Genetic factors
- Environmental factors

Modify:
- Normalization thresholds
- Weighting factors
- Confidence base values

---

## References

### Clinical Grading Scales

- **Acne**: GRAPPA (Global Resource for Advancement of Psoriasis and Psoriatic Arthritis), ECAP (Efficacy of Acne Control and Prevention)
- **Redness**: VASI (Vitiligo Area Scoring Index) - inverse for redness
- **Texture**: TEWL (Transepidermal Water Loss) proxy
- **Hydration**: Skin capacitance correlation

### Pixel Analysis Methods

- Specularity: Highlight detection (graphics rendering)
- Texture variance: Laplacian of Gaussian, edge detection
- Color analysis: RGB/HSV color science

---

## Testing & Validation

See `SkinAnalysisEngineTests.swift` for:
- Determinism verification
- Score range validation
- Quality penalty testing
- Region weighting correctness
- Per-attribute behavior validation
- Codability testing

All heuristics verified to produce:
1. Deterministic output
2. Scores within [0, 100]
3. Confidence within [0, 1]
4. Reasonable clinical correlation

---

## Questions?

Consult SKIN_ANALYSIS_ENGINE_README.md for architectural overview and usage examples.
