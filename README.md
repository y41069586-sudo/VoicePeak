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

Built milestone-by-milestone (see the brief in `docs/`). **Milestones 1–11 + 13
implemented** — scaffold, camera + scan, classical-CV analysis engine, catalog +
INCI, honest match + heatmap, half-face test, proven routine + progress,
onboarding, verified share, settings + legal (×5) + export/delete, compliance
pass, and polish. **Milestone 12 (StoreKit / Supabase / Affiliate) is
feature-flagged OFF and awaits explicit opt-in.** 321 localized keys × 5 languages.

Design is a committed **light white-and-blue** theme (only the live camera
screens are dark, as they should be).

## Tech

SwiftUI (iOS 17+, light-first) · SwiftData · AVFoundation · Apple Vision +
classical-CV skin pipeline · Swift Charts · UserNotifications · String Catalog
(EN/DE/ES/FR/IT). StoreKit 2, Supabase, and Affiliate modules are
**feature-flagged OFF** — the app is fully functional offline without them.

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

## MCP

A project-scoped [MCP](https://modelcontextprotocol.io) config (`.mcp.json`)
connects MCP-aware clients (Claude Code, Cursor, VS Code) to the hosted
[Apify](https://apify.com) MCP server. Set `APIFY_TOKEN` in your environment;
setup and alternatives are in [`docs/MCP.md`](docs/MCP.md).
