# Vérité — Setup

## Requirements

- macOS with **Xcode 15+** (iOS 17 SDK).
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) — the project is defined by
  `project.yml` rather than a checked-in `.xcodeproj` (keeps the repo diffable and
  merge-friendly).

> **Note:** the Xcode project, iOS SDK, and Swift/SwiftUI toolchain only exist on
> macOS. This repo was authored in a Linux CI-style environment, so the code is
> written to Apple's documented APIs but has **not** been compiler-verified. First
> `xcodegen generate` + build on a Mac; fix any environment-specific issues there.

## Generate & open

```bash
brew install xcodegen        # once
cd <repo root>
xcodegen generate            # produces Verite.xcodeproj
open Verite.xcodeproj
```

Select an iPhone simulator (iOS 17+) and run. On first launch you'll see
onboarding → tap **Get started** → the dashboard.

## Building on Codemagic (CI)

This repo includes **`codemagic.yaml`** so the app builds on Codemagic's cloud
macOS machines — which is where the real compile happens (no Mac needed locally).

- **`ios-compile-check`** workflow: installs XcodeGen, runs `xcodegen generate`,
  and does an **unsigned iOS Simulator build** — the fast green/red "does it
  compile?" signal. It auto-triggers on pushes to `claude/*` branches.
- A commented **`ios-testflight`** workflow is included as a starting point for
  signed device builds → TestFlight. Enable it once you've connected an Apple
  Developer account + App Store Connect API key in the Codemagic UI, and set up
  `ios_signing` / `app_store_connect` there.

In Codemagic: add this repository, and it will pick up `codemagic.yaml`
automatically. The first run of `ios-compile-check` is the quickest way to
surface any environment-specific issues the Linux authoring environment couldn't
catch. Paste any build errors back and they'll get fixed.

## Signing

`project.yml` uses automatic signing with bundle id `com.verite.com`. In Xcode →
target **Verite** → Signing & Capabilities, pick your team. Change the bundle id
there (and in `project.yml`) if `com.verite.com` is taken.

## The display font (optional but recommended)

The "Aesthetic Blue" look uses an elegant editorial serif for headlines + big
numbers. It is **not bundled** — pick an SIL OFL face and confirm its license
permits app embedding, then:

1. Download e.g. **Playfair Display Italic** (SIL OFL) — or Cormorant / Marcellus.
2. Drop the `.ttf`/`.otf` into `Verite/Resources/Fonts/`.
3. Add a `UIAppFonts` array to `Verite/Resources/Info.plist` listing the file name.
4. Ensure the PostScript name matches `Typography.displayFontName` (default
   `"PlayfairDisplay-Italic"`); update that constant if you chose another face.

Until then everything renders in the **system serif** fallback — no tofu, fully
legible. See `docs/DESIGN_SPEC.md` for the font-usage rules.

## Localization

Five languages ship from day one via `Verite/Localization/Localizable.xcstrings`
(UI) and `InfoPlist.xcstrings` (permission strings): EN / DE / ES / FR / IT.
Device locale is auto-detected; override in Settings → Language. Strings marked
with a `comment` in the catalog want a human-translation review before release.

To regenerate the catalogs from source, run `scratchpad/gen_catalog.py`-style
tooling (the generator lives outside the app target; edit strings there or
directly in Xcode's String Catalog editor).

## Feature-flag modules (all OFF by default)

Toggle in `Verite/App/FeatureFlags.swift` (or a future debug settings screen):

| Flag | Turns on | Extra setup |
|---|---|---|
| `purchasesEnabled` | StoreKit 2 paywall + Restore | Add a StoreKit config file + product IDs (Milestone 12) |
| `affiliateEnabled` | Affiliate catalog enrichment | Add affiliate API keys (Amazon PA-API / Awin / Impact) |
| `backendEnabled` | Supabase account sync + opt-in aggregate efficacy | Add Supabase URL + anon key; run `Backend/` SQL + RLS |
| `communityEnabled` | Opt-in anonymized community efficacy | Requires `backendEnabled` |

The app is 100% functional with all four off — Open Beauty Facts + on-device
analysis only. **Face photos never leave the device regardless of any flag.**

Keys/secrets belong in a git-ignored `Secrets.xcconfig` (already in `.gitignore`),
never committed.

## Where things are

- Design tokens & motion specs → `docs/DESIGN_SPEC.md`
- Module map & data model → `docs/ARCHITECTURE.md`
- App-Review mapping → `docs/APP_REVIEW_CHECKLIST.md` (Milestone 11)
