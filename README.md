# Vérité

**The honest skincare app.** Scan your face → pick a product → get an honest,
risk-first prediction for *your* skin → prove it with a controlled half-face
test → your routine contains only what you've proven → share the verified result.

Vérité leads with *"why not"* as often as *"why"*, never fakes a glow-up, and
only puts a product in your routine after you've proven it works on your own
face. All face photos and analysis happen **on-device and are never uploaded.**

> Vérité is a tracking and education tool, not medical advice, and not a
> substitute for a dermatologist.

---

## Status

Built milestone-by-milestone (see the brief in `docs/`). **Current: Milestone 1 —
Scaffold.** The project structure, design system, feature flags, routing,
SwiftData models, and a 5-language String Catalog are in place.

## Tech

SwiftUI (iOS 17+, dark-first) · SwiftData · AVFoundation · Apple Vision +
classical-CV skin pipeline · Swift Charts · String Catalog (EN/DE/ES/FR/IT).
StoreKit 2, Supabase, and Affiliate modules are **feature-flagged OFF** — the app
is fully functional offline without them.

## Getting started

This repo ships source + an [XcodeGen](https://github.com/yonaskolb/XcodeGen)
spec (`project.yml`) instead of a checked-in `.xcodeproj`. On a Mac with Xcode 15+:

```bash
brew install xcodegen
xcodegen generate
open Verite.xcodeproj
```

Full instructions, feature-flag toggles, and where to drop the display font are
in [`docs/SETUP.md`](docs/SETUP.md). Design tokens and motion specs are in
[`docs/DESIGN_SPEC.md`](docs/DESIGN_SPEC.md); architecture in
[`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md).
