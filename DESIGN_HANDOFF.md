# Vérité — Design System & Product Handoff

## DESIGN PHILOSOPHY

Vérité is built on three pillars:

### 1. TRUST
Users should never feel manipulated. The app is honest, evidence-based, and admits limitations.

### 2. SIMPLICITY
No cognitive overload. Every screen has one primary purpose. Visual hierarchy is crystal clear.

### 3. INTELLIGENCE
The app respects the user's intelligence. No fake confidence, no false positivity. Real insights, real data.

---

## VISUAL STYLE

### Aesthetic References
- **Apple Health** — clean, minimal, focused on one metric
- **Linear** — premium product design, breathing room
- **Headspace** — calm, reassuring, supportive tone
- **Arc Browser** — modern, thoughtful, departs from convention

### DO
✓ Use soft blue + white palette  
✓ Create breathing room with 20pt+ padding  
✓ Use large, bold typography for headlines  
✓ Employ subtle shadows (not harsh)  
✓ Round corners (10-12pt standard)  
✓ Use semantic colors for status (green/yellow/red for meaning)  
✓ Employ whitespace as a design element  
✓ Keep animations under 300ms  

### DON'T
❌ Use dark mode (committed light aesthetic)  
❌ Over-decorate cards (keep 1 focus element)  
❌ Mix typefaces (use system fonts only)  
❌ Clash colors (maintain hierarchy)  
❌ Add unnecessary icons (keep 1 icon per card max)  
❌ Create motion for motion's sake  
❌ Use terminology users don't understand  
❌ Promise unrealistic results  

---

## COLOR TOKENS (Production)

### Backgrounds (Elevation Ladder)
```
bgBase:       #EEF3FD  (app background, constant)
bgSurface:    #FFFFFF  (cards, first elevation)
bgElevated:   #F4F8FF  (cards on cards)
bgElevated2:  #EAF1FE  (deeply stacked cards)
```

**Usage:**
- `bgBase` — Always behind all content
- `bgSurface` — Standard card background
- `bgElevated` — Nested cards, second layer
- `bgElevated2` — Rarely used; reserved for complex nested layouts

### Strokes (Borders)
```
strokeSubtle:  #DCE5F5  (1pt hairline on every card)
strokeBright:  #B9CBEC  (focused/active states)
```

**Usage:**
- `strokeSubtle` — Default border for all cards
- `strokeBright` — Highlight active/focused cards, hover states

### Brand Colors
```
primary:       #3E6BFF  (primary action, links)
primaryBright: #6E9BFF  (hover, secondary emphasis)
accent:        #1CA3E6  (secondary, gradients)
```

**Usage:**
- `primary` — Primary CTA buttons, active links
- `primaryBright` — Hover states, secondary emphasis
- `accent` — Gradient fills (with primary), secondary accent

### Semantic Colors
```
success:  #10A87E  (positive, improvement, ready)
warning:  #D9820A  (caution, testing, attention needed)
danger:   #E24857  (risk, irritation, concern)
```

**Usage:**
- `success` — Improvement indicators, proven products, checkmarks
- `warning` — Testing status, cautions, needs attention
- `danger` — Irritation alerts, risk flags, concerns

### Text Colors
```
textPrimary:   #0E1B34  (headlines, body text)
textSecondary: #5D6E90  (supporting text, labels)
textTertiary:  #8595B5  (captions, metadata, timestamps)
```

**Usage:**
- `textPrimary` — All headlines and body copy
- `textSecondary` — Labels, section headers, supporting text
- `textTertiary` — Timestamps, metadata, helper text

### Hero Gradient
```
LinearGradient(
  colors: [primary, accent],
  startPoint: .topLeading,
  endPoint: .bottomTrailing
)
```

**Usage:**
- **Only** reserved for: Primary action button, scan ring, score reveal, logo mark
- Never decorative
- Maximum 1 per screen

---

## TYPOGRAPHY SYSTEM

### Type Scale

| Role | Size | Weight | Usage |
|------|------|--------|-------|
| Display | 26pt | semibold | App title, major sections |
| Title 1 | 22pt | bold | Screen titles (nav bar) |
| Title 2 | 20pt | bold | Section headers |
| Headline | 17pt | semibold | Card titles, strong emphasis |
| Body | 16pt | regular | Primary text, instructions |
| Callout | 14pt | regular | Supporting text, descriptions |
| Subheadline | 13pt | semibold | Secondary emphasis, labels |
| Caption | 12pt | regular | Metadata, timestamps, hints |
| Caption 2 | 11pt | semibold | Small badges, fine text |

### Font Family
- **Primary:** System (SF Pro Display for headlines, SF Pro Text for body)
- **No custom fonts** — System fonts only
- **No italic** — Use weight/size instead

### Line Heights
- Headline: 1.2
- Body: 1.4
- Caption: 1.3

### Hierarchy Rules

**A screen should have:**
1. **One primary headline** (largest, boldest)
2. **Supporting subheadings** (medium size)
3. **Body copy** (regular, readable)
4. **Metadata** (smallest, tertiary color)

**Never:**
- Put two equally-large headlines on one screen
- Use small text for important information
- Mix 5+ different text sizes

---

## SPACING SYSTEM

### Grid: 4pt Base
```
4pt   = 1 unit (micro)
8pt   = 2 units (small)
12pt  = 3 units (medium)
16pt  = 4 units (standard)
20pt  = 5 units (large)
24pt  = 6 units (XL)
```

### Component Spacing

**Cards:**
- Padding inside: 16pt
- Gap between: 12pt
- Corner radius: 10-12pt

**Buttons:**
- Min height: 44pt (tap target)
- Padding horizontal: 16pt
- Padding vertical: 12pt
- Corner radius: 10pt

**Lists:**
- Item padding: 12pt
- Gap between items: 8pt
- Side margins: 20pt

**Sections:**
- Top margin: 20pt
- Bottom margin: 20pt
- Between sections: 24pt

---

## COMPONENT SPECIFICATIONS

### GlassCard
- Background: `bgSurface`
- Border: 1pt `strokeSubtle`
- Corner radius: 12pt
- Padding: 16pt
- Shadow: `.shadow(radius: 1, y: 1)` (subtle)
- Hover: Border becomes `strokeBright`

### PrimaryButton
- Background: `primary` to `accent` gradient (top-left to bottom-right)
- Text: white, headline weight
- Min size: 44pt height × 100pt width (preferably full-width)
- Corner radius: 10pt
- Padding: 12pt vertical, 16pt horizontal
- State: Active (full gradient), Disabled (gray), Pressed (slight scale)

### SecondaryButton
- Background: `primary` @ 10% opacity
- Text: `primary` color, callout weight
- Same size as primary
- Hover: Background becomes `primary` @ 15%

### StatusBadge
- Format: Colored pill with icon or text
- Text: caption2 weight, semantic color
- Background: Semantic color @ 10% opacity
- Padding: 4pt vertical, 8pt horizontal
- Border radius: 6pt
- Colors:
  - Success: Green pill
  - Warning: Orange pill
  - Danger: Red pill

### EmptyState
- Icon: 40pt, primary color @ 50% opacity
- Headline: title3 weight
- Description: callout, secondary color
- Button: Optional CTA
- Frame: Full card, 120pt height minimum
- Spacing: 16pt between elements

### ScoreRing
- Outer circle: 120pt diameter
- Stroke width: 3pt
- Gradient: primary to accent
- Inner label: large bold number
- Opacity animation: 0.6 to 1.0

### ScoreBar
- Height: 4pt
- Corner radius: 2pt
- Background: `bgElevated`
- Fill: Semantic color or gradient
- Label: callout above/below

---

## ANIMATION SYSTEM

### Timing
- **Short interactions:** 200ms (button taps)
- **Navigation:** 300ms (tab switches)
- **Complex:** 400ms (sheet opens)
- **Entrance:** 500ms (staggered list appearance)

### Curves
- **Discrete changes:** `.easeInOut`
- **Bouncy interactions:** `.spring(response: 0.3, dampingFraction: 0.7)`
- **Smooth transitions:** `.linear`

### What Animates
✓ Button state changes  
✓ Card entrance (opacity + scale)  
✓ Tab switching  
✓ Modals (slide up)  
✓ Checkboxes (scale)  
✓ List items (staggered opacity)  

### What Doesn't Animate
❌ Page scrolling  
❌ Text input  
❌ Icon changes  
❌ List reordering  
❌ Toggling visibility  

### Gesture Feedback
- Tap: 100% opacity → 90% opacity (on press)
- Swipe: Follows finger smoothly
- Long press: Haptic feedback (if applicable)

---

## RESPONSIVE DESIGN

### Breakpoints
- **iPhone SE (375pt):** Minimum width
- **iPhone 14 (390pt):** Standard width
- **iPad (768pt+):** Large width (future)

### Adaptive Layouts
- Single column (all phones)
- Double column (iPad, future)
- Full bleed (tab padding = 20pt)

### Safe Areas
- Top: Respect nav bar inset
- Bottom: Respect tab bar inset
- Sides: Always 20pt padding minimum

---

## ACCESSIBILITY GUIDELINES

### Color Contrast
- **Text on white:** Minimum 4.5:1 (WCAG AA)
- **UI elements:** Minimum 3:1
- **Status only:** Always pair color with icon/text

### Touch Targets
- Minimum 44pt × 44pt
- 8pt minimum spacing between targets
- Centered labels for buttons

### Labels & Hints
- All interactive elements have accessibility labels
- Form fields have labels
- Images have descriptions
- Icons have semantic meaning

### Reduced Motion
- Respect `accessibilityReduceMotion` environment
- Core functionality doesn't require animation
- Provide instant feedback to actions

### Text
- Minimum 12pt font size (readable)
- Good contrast (4.5:1 or higher)
- No text-only icons
- Clear language (no jargon)

---

## DARK MODE

**NOTE:** Vérité is light-mode only. No dark mode planned.

```swift
.preferredColorScheme(.light)  // Enforced in VeriteApp
```

**Rationale:** The white-blue palette is the committed, premium aesthetic. Dark mode would dilute the brand.

---

## LOCALIZATION

### String Keys
All user-facing text uses `LocalizedStringKey`:

```swift
Text("dashboard.snapshot.title")  // Key in String Catalog
Text("analyzer.hero.cta")         // Localized automatically
```

### Right-to-Left (RTL)
- Images flip for RTL languages
- Leading/trailing used instead of left/right
- Padding respects layout direction

### Supported Languages (Phase 2+)
- English (primary)
- Spanish
- French
- German
- Japanese
- Chinese (Simplified)

---

## BRAND VOICE

### Tone
"Scientifically intelligent but human."

### In Copy
- **Not:** "Dermatologically proven" ❌
- **Yes:** "Our analysis suggests..." ✓
- **Not:** "Your skin will glow in 7 days!" ❌
- **Yes:** "Track improvements over weeks" ✓
- **Not:** "AI magic" ❌
- **Yes:** "Computer vision analysis" ✓

### In Interaction
- Buttons are action-oriented: "Scan Now", "Continue"
- Errors are helpful: "We need better lighting"
- Success is understated: "Analysis saved"
- Guidance is warm: "This helps us improve"

---

## SCREEN SPECIFICATIONS

### Safe Area Insets (iPhone)
- Top: 0-47pt (status bar + notch)
- Bottom: 0-34pt (home indicator)
- Sides: 0pt (full bleed)

### Content Margins
- Standard: 20pt horizontal
- Tight: 16pt horizontal (rare)
- No margins on edge-to-edge backgrounds

### Card Grid
- Single column (all screens)
- Full width minus 40pt (20pt margins)
- 12pt gap between cards

---

## ONBOARDING DESIGN

### Screens
1. Welcome (headline + description + CTA)
2. How scanning works (4-step visual guide)
3. Baseline capture (camera integration)
4. Permissions request (standard iOS)
5. Routine setup (quick product add)
6. Success (celebration + enter app)

### Tone
- Reassuring (not pushy)
- Educational (explains *why*)
- Honest (realistic expectations)
- Friendly (warm language)

---

## DESIGN ASSETS

### Figma
- [Figma link]
- Components library (auto-synced)
- Color tokens documented
- All screens as prototypes

### Color Definitions
- Hex codes in `VColor.swift`
- Semantic tokens in `Theme.swift`
- SwiftUI Color extensions

### Icon Library
- SF Symbols only (no custom icons)
- System icons for all UI
- 16pt, 17pt, 18pt sizes

---

## HANDOFF CHECKLIST

For developers implementing screens:

- [ ] Use VColor tokens (never hardcoded hex)
- [ ] Respect spacing grid (4pt multiples)
- [ ] Use provided components (GlassCard, PrimaryButton, etc.)
- [ ] Implement accessibility labels
- [ ] Test on iPhone SE (375pt) and 14 Pro (390pt)
- [ ] Verify color contrast (WCAG AA minimum)
- [ ] Respect safe areas
- [ ] Add preview with mock data
- [ ] No custom fonts (system only)
- [ ] Animations under 300ms (except transitions)

---

## DESIGN TOKENS (Copy-Paste Reference)

```swift
// Colors
let brandPrimary = Color(hex: "3E6BFF")
let brandAccent = Color(hex: "1CA3E6")
let successGreen = Color(hex: "10A87E")
let warningOrange = Color(hex: "D9820A")
let dangerRed = Color(hex: "E24857")

// Spacing
let spacing4 = 4.0
let spacing8 = 8.0
let spacing12 = 12.0
let spacing16 = 16.0
let spacing20 = 20.0
let spacing24 = 24.0

// Corner Radius
let cardRadius = 12.0
let buttonRadius = 10.0
let badgeRadius = 6.0

// Font Sizes
let display = 26.0
let title1 = 22.0
let title2 = 20.0
let headline = 17.0
let body = 16.0
let callout = 14.0
let subheadline = 13.0
let caption = 12.0
let caption2 = 11.0
```

---

## DESIGN CRITIQUES

### Common Issues & Fixes

**Issue:** Too many colors on one screen  
**Fix:** Use max 3 semantic colors + neutrals

**Issue:** Buttons too small  
**Fix:** Minimum 44pt height, full-width if possible

**Issue:** Text hard to read  
**Fix:** Increase size to body (16pt) or use semibold

**Issue:** Cards feel cramped  
**Fix:** Add 16pt padding minimum, increase spacing between

**Issue:** Animation feels janky  
**Fix:** Use .spring or .easeInOut, keep < 300ms

**Issue:** App looks generic  
**Fix:** Ensure gradient on primary CTA, breathing room, clear hierarchy

---

*Last Updated: July 2026*  
*Design Philosophy: Trust, Simplicity, Intelligence*  
*Visual Language: Premium, Calm, Apple-Quality*
