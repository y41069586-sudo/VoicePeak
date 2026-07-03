# Vérité — Design Spec ("Aesthetic Blue")

A refined, editorial, deep-blue aesthetic: premium beauty-tech meets honest lab
instrument. Dark-mode-first, ultra-smooth motion, 60fps everywhere.

## Color tokens (`DesignSystem/Theme.swift`)

| Token | Hex | Use |
|---|---|---|
| `bgBase` | `#070B18` | Near-black indigo — root background |
| `bgSurface` | `#0E1526` | Surfaces, subtle fills |
| `bgElevated` | `#16203A` | Elevated surfaces |
| `strokeSubtle` | `#243350` | Hairline strokes / track fills |
| `primary` | `#3E6BFF` | Vivid blue — primary brand |
| `primaryBright` | `#6E9BFF` | Tint / accent color asset |
| `accent` | `#5AD1FF` | Soft cyan glow |
| `success` | `#3FD8A4` | Positive / "it works for you" |
| `warning` | `#FFC24B` | Caution / streak flame |
| `danger` | `#FF6B6B` | Honest "this may irritate you" flags |
| `textPrimary` | `#F3F6FF` | Primary text |
| `textSecondary` | `#9AA9C8` | Secondary text |

**Signature gradient** `primary → accent`, used *sparingly*: scan ring, hero
elements, primary CTAs. A soft blue bloom (`.blueGlow()`) on those same key
elements. Frosted-glass cards (`.ultraThinMaterial`) sit over the animated
gradient mesh background.

## Typography (two-font system)

- **Display / headings** — an elegant editorial serif (Playfair Display Italic,
  SIL OFL, or Cormorant/Marcellus). Headlines, section titles, and big numbers
  **only** — never body text. Falls back to the system serif when not bundled.
  Accessed via `Typography.display(_:)`.
- **Body / UI** — SF Pro (system) for everything functional. Maximum legibility,
  full Dynamic Type.
- **Big numeric readouts** (scores, %, day counters) — SF Pro Rounded, **tabular
  figures** (`Typography.number(_:)`).

Rule: readability wins over aesthetics. The script/serif face must remain legible
at small sizes or fall back to the upright system serif.

## Motion (`DesignSystem/Motion.swift`) — 60fps target

| Token | Curve | Use |
|---|---|---|
| `Motion.spring` | `.spring(response: 0.4, dampingFraction: 0.82)` | House default |
| `Motion.springSoft` | `response 0.55, damping 0.9` | Large elements, sheets, bar fills |
| `Motion.springSnappy` | `response 0.28, damping 0.78` | Taps, toggles |
| `Motion.crossfade` | `.easeInOut(0.25)` | **Reduce Motion fallback** |

- Animated gradient mesh background drifts slowly (`GradientMeshBackground`,
  `Canvas` + `TimelineView`, `.drawingGroup()`), frozen under Reduce Motion.
- Score bars fill on reveal; the zone heatmap fades in over the real face; scan
  ring sweeps during capture; matched-geometry transitions between screens.
- **Every animation runs off precomputed values** — no heavy work per frame.
- Always respect Reduce Motion via `Motion.animation(reduceMotion:)` /
  `.veriteAnimation(value:)`. The app must feel calm, never janky.

## Haptics (`DesignSystem/Haptics.swift`)

`.capture` (shutter), `.verdictReveal` (success), `.riskFlagged` (warning),
`.milestone` (medium), `.selection` (light). Fire on capture, verdict reveal,
risky-product flag, and test milestones.

## Components (`DesignSystem/Components/`)

- `PrimaryButton` / `SecondaryButton` — gradient capsule CTA (+ glow + haptic) and
  a quiet skip/dismiss button. Press feedback collapses under Reduce Motion.
- `GlassCard` / `GlassActionCard` — the frosted-glass surface building block.
- `PillTag` — capsule label mapped to the semantic palette (a `.danger` pill reads
  as a real warning — honesty by color).
- `ScoreBar` — animated normalized fill with tabular % readout.
- `DisclaimerBanner` — persistent honesty disclaimer (short/full).

## Accessibility

VoiceOver labels/values on interactive + data elements; Dynamic Type via system
fonts; Reduce Motion crossfades; contrast tuned for the dark palette. All of the
above must hold in **all five languages**. Layout uses leading/trailing (never
hardcoded left/right) for RTL-readiness.
