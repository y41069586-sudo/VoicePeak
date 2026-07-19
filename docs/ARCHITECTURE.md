# Glowé — Architecture

## One-line product

Scan your face → pick a product → get an honest, risk-first prediction for *your*
skin → prove it with a controlled half-face test → your routine contains only what
you've proven → share the verified result.

## Honesty invariants (enforced in code, not just copy)

These are load-bearing. Every feature is built to respect them:

1. **Face photos never leave the device.** Only local thumbnail *filenames* are
   persisted (`Scan.thumbnailFilename`). Nothing in the data model holds a remote
   URL for a face image. The backend module (off by default) syncs numeric
   metrics + routine only.
2. **No fake "after."** There is no "render predicted result" path anywhere. The
   Match screen overlays a risk/benefit *heatmap* on the user's real scan; proof
   comes only from the half-face test.
3. **Change vs baseline, never attractiveness.** `Scan.attributeScores` are
   tracked against the user's own Day-0 baseline. No absolute beauty score exists.
4. **Correlation, not causation.** Verdict copy says "what happened on your skin,"
   never "this product works."
5. **Confidence-gated verdicts.** `HalfFaceTest.confidence` + a scan-count/
   significance threshold gate every verdict; below threshold we show a
   "not enough data yet" state.
6. **Persistent disclaimer.** `DisclaimerBanner` (short) rides every analysis
   surface; the full text lives in Settings → Legal, localized ×5.

## Module map (`Verite/`)

| Folder | Responsibility | Milestone |
|---|---|---|
| `App/` | Entry point, `AppState`, feature flags, routing, tab shell | 1 |
| `DesignSystem/` | Theme tokens, typography, motion, haptics, gradient mesh, components | 1 |
| `Localization/` | `Localizable.xcstrings` + `InfoPlist.xcstrings` (EN/DE/ES/FR/IT) | 1 |
| `Models/` | SwiftData `@Model`s, schema, seed data | 1 |
| `Onboarding/` | Hero → quiz → baseline scan → paywall handoff | 1 (shell), 8 (full) |
| `Dashboard/` | "Today" home | 1 (shell), 9 (full) |
| `Scan/` | AVFoundation capture + AR alignment guide | 2 |
| `Analysis/` | `SkinAnalysisEngine`, CV pipeline, regions, attributes | 3 |
| `Catalog/` | Open Beauty Facts client, barcode, search, cache | 4 |
| `Ingredients/` | INCI parser + classification knowledge base | 4 |
| `Match/` | `MatchEngine`, zone heatmap, dupe finder, conflict check | 5 |
| `HalfFaceTest/` | Setup, queue, per-side-vs-own-baseline scoring, verdict | 6 |
| `Routine/` | Proven routine, timer, reminders, conflicts | 7 |
| `Progress/` | Timeline, side-by-side, Swift Charts | 7 |
| `Share/` | Verified Half-Face Reveal renderer | 9 |
| `Community/` | Opt-in aggregate efficacy (off by default) | 12 |
| `Purchases/` | StoreKit 2 (off by default) | 12 |
| `Backend/` | `BackendService` protocol, `LocalOnly` + Supabase (off by default) | 12 |
| `Settings/` | Language, data export/delete, purchases, legal | 1 (shell), 10 |
| `Legal/` | Impressum, Datenschutz, AGB, Disclaimer (localized) | 1 (shell), 10 |
| `Shared/` | Cross-cutting views (`ComingSoonView`, `DisclaimerBanner`) | 1 |

## App composition

```
VeriteApp (@main)
 └─ modelContainer(Persistence.makeContainer())
 └─ RootView
     ├─ GradientMeshBackground   (behind everything, Reduce-Motion aware)
     └─ @Query UserProfile → onboardingComplete ?
          ├─ false → OnboardingFlowView
          └─ true  → MainTabView (Today / Scan / Products / Routine / Progress / Settings)
```

State: persistent data is SwiftData; transient session/UI state is the observable
`AppState` (which also carries the `FeatureFlags`). No global singletons for data.

## Data model (SwiftData)

`UserProfile`, `Scan`, `Product`, `HalfFaceTest`, `RoutineItem`, `Streak`,
`SavingsLedger` — all registered in `Persistence.schema`. Enum-keyed maps are
stored as `[String: Double]` (the safest documented SwiftData shape) with typed
accessors on the model.

## Feature flags (all OFF by default — `FeatureFlags`)

`affiliateEnabled`, `backendEnabled`, `purchasesEnabled`, `communityEnabled`. The
app is fully functional with all four off (App-Review guideline 4.2 / brief §16).

## Analysis engine philosophy (Milestone 3, previewed)

A **documented classical-CV heuristic** pipeline for v1: Vision landmarks →
region segmentation → per-attribute metrics (redness, oiliness, texture, pores,
blemishes, hydration proxy, sensitivity) via Accelerate/CoreImage, normalized by
standardized-capture metadata. Every output is an **estimate**, tracked as change
vs baseline, with a confidence value. A learned Core ML model can slot in later
behind the same change-vs-baseline + confidence-gating interface.
