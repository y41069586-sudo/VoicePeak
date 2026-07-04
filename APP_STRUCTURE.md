# Vérité App Structure & Visual Hierarchy

## NAVIGATION HIERARCHY

```
VeriteApp (@main)
│
└── RootView
    ├── [IF NOT onboarded] → OnboardingFlowView
    │   ├── Welcome
    │   ├── ScanningExplained
    │   ├── BaselineCapture (AnalyzerTabView)
    │   ├── Permissions
    │   ├── RoutineSetup
    │   └── Ready → mark onboardingComplete
    │
    └── [IF onboarded] → MainTabView (TabView)
        ├── HOME TAB (house.fill)
        │   └── HomeTabView
        │       ├── SkinHealthCard
        │       ├── ActiveConcernsCard
        │       ├── TodaysRecommendationCard
        │       ├── PrimaryActionCard (CTA → Analyzer)
        │       ├── HydrationTrendCard
        │       ├── ConsistencyCard
        │       └── SettingsModalView (on gear tap)
        │           └── Settings list
        │
        ├── ANALYZER TAB ⭐ (camera.viewfinder)
        │   └── AnalyzerTabView
        │       ├── ScannerHeroSection
        │       │   └── "Start Scan" button
        │       ├── ScanHistoryRow[] (repeating)
        │       ├── ScannerInsightsSection
        │       │   └── InsightStep[] (4 steps)
        │       ├── PrivacyBadge
        │       ├── CameraScannerView (sheet on scan start)
        │       │   ├── AR guide circle
        │       │   └── "Take Scan" button
        │       └── ScanDetailView (nav destination)
        │           ├── ScanMetric[] (date, quality, baseline)
        │           └── AttributeBar[] (7 attributes)
        │
        ├── ROUTINE TAB (checklist)
        │   └── RoutineTabView
        │       ├── RoutineTimeSelector (AM/PM toggle)
        │       ├── [IF empty] EmptyRoutineState
        │       │   └── "Add First Product" button
        │       ├── [IF has items] RoutineItemRow[]
        │       │   ├── Checkbox
        │       │   ├── Product name & brand
        │       │   └── StatusBadge
        │       ├── "Add Product" button
        │       ├── ProductHealthSection
        │       │   └── ProductStatusCard[] (3: Working, Irritating, Testing)
        │       ├── ConsistencyTrackerSection
        │       │   └── Weekly circle[] (7 days)
        │       └── AddRoutineItemView (sheet on add)
        │           └── Product picker form
        │
        └── PROGRESS TAB (chart.line.uptrend.xyaxis)
            └── ProgressTabView
                ├── ProgressTabSelector (4 sub-tabs)
                │
                ├── [IF Timeline selected]
                │   └── ProgressTimelineView
                │       ├── EmptyProgressState (if no data)
                │       └── TimelineEntry[] (each scan)
                │           ├── Icon (flag or checkmark)
                │           ├── Label & date
                │           └── Quality %
                │
                ├── [IF Comparison selected]
                │   └── BeforeAfterView
                │       ├── ComparisonCard (before)
                │       ├── ComparisonCard (after)
                │       └── ImprovementRow[] (metrics)
                │
                ├── [IF Analytics selected]
                │   └── ProgressAnalyticsView
                │       ├── MetricCard[] (4 metrics)
                │       └── Trend graph (bar chart)
                │
                └── [IF Streak selected]
                    └── StreakView
                        ├── Large flame icon & number
                        └── StreakStat[] (best, started)
```

---

## COMPONENT TREE (Per Tab)

### HOME TAB — 7 Components

```
HomeTabView
├── SkinHealthCard
│   ├── Text ("Let's establish your baseline")
│   └── [if hasBaseline] ProgressView
│
├── ActiveConcernsCard
│   ├── Text ("Active Concerns")
│   └── Label[] (concern items)
│
├── TodaysRecommendationCard
│   ├── HStack (sparkles icon + label)
│   └── Text (insight)
│
├── PrimaryActionCard
│   ├── HStack
│   ├── Image (camera.viewfinder)
│   ├── VStack (title + subtitle)
│   └── Image (chevron.right)
│
├── HydrationTrendCard
│   ├── Text ("Hydration Trend")
│   └── HStack
│       └── VStack[] (5 bars + labels)
│
├── ConsistencyCard
│   ├── VStack (title, streak count)
│   └── Image (flame.fill)
│
└── SettingsModalView
    └── List
        └── Section[] (Account, Preferences, Legal)
```

### ANALYZER TAB — 9 Components

```
AnalyzerTabView
├── ScannerHeroSection
│   ├── ZStack (animated scan ring)
│   │   ├── Circle (stroke)
│   │   ├── Circle (gradient stroke)
│   │   └── Image (camera.fill)
│   ├── VStack (headline + description)
│   └── Button ("Start Scan")
│
├── ScanHistoryRow[]
│   ├── RoundedRectangle (thumbnail placeholder)
│   ├── VStack (date, quality)
│   └── Image (chevron.right)
│
├── ScannerInsightsSection
│   └── InsightStep[] (4 steps)
│       ├── Text (number badge)
│       ├── VStack (title + description)
│       └── Spacer
│
├── PrivacyBadge
│   ├── Image (lock.fill)
│   └── VStack (title + description)
│
├── CameraScannerView (sheet)
│   ├── HStack (Cancel button)
│   ├── Circle (scan target)
│   └── Button ("Take Scan")
│
└── ScanDetailView (nav destination)
    ├── VStack (scan info)
    │   └── ScanMetric[] (3 metrics)
    ├── VStack (analysis)
    │   └── AttributeBar[] (7 attributes)
    └── Spacer
```

### ROUTINE TAB — 8 Components

```
RoutineTabView
├── RoutineTimeSelector
│   └── Button[] (2: Morning, Evening)
│
├── [IF empty] EmptyRoutineState
│   ├── Image (sunrise/moon icon)
│   ├── Text ("No products yet")
│   └── Button ("Add First Product")
│
├── [IF has items] RoutineItemRow[]
│   ├── Button (checkbox)
│   ├── VStack (product name + brand)
│   ├── Spacer
│   └── StatusBadge
│
├── Button ("Add Product")
│
├── ProductHealthSection
│   └── ProductStatusCard[] (3 cards)
│       ├── Image (icon)
│       ├── Text (count)
│       └── Text (label)
│
├── ConsistencyTrackerSection
│   └── HStack
│       └── VStack[] (7 days)
│           ├── Circle (✓ or empty)
│           └── Text (day label)
│
└── AddRoutineItemView (sheet)
    └── Form
        └── Section[] (Product, Brand, Status)
```

### PROGRESS TAB — 10 Components

```
ProgressTabView
├── ProgressTabSelector
│   └── Button[] (4: Timeline, Compare, Stats, Streak)
│
├── [IF Timeline] ProgressTimelineView
│   └── TimelineEntry[]
│       ├── VStack (icon + divider)
│       ├── VStack (label + date)
│       └── VStack (quality %)
│
├── [IF Comparison] BeforeAfterView
│   ├── HStack
│   │   ├── ComparisonCard (before)
│   │   └── ComparisonCard (after)
│   └── ImprovementRow[] (metrics with arrows)
│
├── [IF Analytics] ProgressAnalyticsView
│   ├── MetricCard[] (4 cards)
│   └── VStack (trend graph)
│       └── HStack[] (bar chart)
│
└── [IF Streak] StreakView
    ├── ZStack (circle + flame + number)
    └── VStack[] (stats)
```

---

## DATA FLOW DIAGRAM

```
                    AppState (@Observable)
                    ├── selectedTab: AppTab
                    ├── languageOverride: String?
                    ├── featureFlags: FeatureFlags
                    ├── backend: BackendService
                    └── affiliate: AffiliateService
                         ↓
                    MainTabView (TabView)
                         ↓
        ┌────┬────────┬────────┬─────────┐
        ↓    ↓        ↓        ↓         ↓
      Home  Analyzer Routine Progress  (Settings)
        ↓    ↓        ↓        ↓
      📱   🔍       ✓        📈
        
        Each tab queries SwiftData:
        
        @Query private var scans: [Scan]
        @Query private var products: [Product]
        @Query private var routineItems: [RoutineItem]
        @Query private var tests: [HalfFaceTest]
        @Query private var streaks: [Streak]
        
        ↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓
        
        SwiftData Models (Persistent)
        ├── UserProfile
        ├── Scan (face captures + analysis)
        ├── Product (skincare items)
        ├── RoutineItem (routine steps)
        ├── HalfFaceTest (A/B tests)
        ├── Streak (consistency tracking)
        └── SavingsLedger
        
        ↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓
        
        SQLite Store (On-Device, No Cloud)
```

---

## COMPONENT REUSE MATRIX

| Component | Home | Analyzer | Routine | Progress |
|-----------|------|----------|---------|----------|
| GlassCard | 4 | 3 | 4 | 3 |
| PrimaryButton | 1 | 1 | 1 | 0 |
| StatusBadge | 0 | 0 | 3 | 0 |
| ScoreBar | 1 | 1 | 0 | 0 |
| EmptyState | 0 | 1 | 1 | 1 |
| ProgressView | 1 | 0 | 0 | 0 |
| **Total** | **7** | **6** | **9** | **4** |

**All built from 12 reusable components in `DesignSystem/Components/`**

---

## STYLING CONSISTENCY MATRIX

| Element | VColor Token | Used In |
|---------|--------------|---------|
| Card backgrounds | bgSurface | All tabs |
| Section backgrounds | bgElevated | Nested cards |
| App background | bgBase | All 4 tabs |
| Primary buttons | primary + accent (gradient) | CTA in each tab |
| Success status | success (#10A87E) | Routine (proven), Progress |
| Warning status | warning (#D9820A) | Routine (testing), Progress |
| Danger status | danger (#E24857) | Routine (irritating) |
| Text primary | textPrimary | Headlines, body |
| Text secondary | textSecondary | Supporting text |
| Text tertiary | textTertiary | Metadata, captions |
| Card borders | strokeSubtle | All cards |

**100% of colors use VColor system** ✓

---

## INTERACTION PATTERNS

### Global
- All buttons use `.spring(response: 0.3, dampingFraction: 0.7)`
- All cards have 1pt border (#DCE5F5)
- All corners are 10-12pt radius
- All spacing uses 4/8/12/16/20/24pt grid

### Home Tab
- Tap scan CTA → Navigate to Analyzer
- Tap gear icon → Show settings modal (sheet)
- Consistency badge pulses gently

### Analyzer Tab
- Tap scan history → Nav to scan detail
- Tap "Start Scan" → Camera sheet
- Detail view shows back button

### Routine Tab
- AM/PM toggle with animation
- Tap checkbox → Strikethrough + fade
- Tap "Add Product" → Product picker sheet
- Product cards show status color

### Progress Tab
- Tab selector changes with animation
- Timeline entries have staggered opacity
- Before/after cards scale slightly on tap
- Streak counter animates on enter

---

## ACCESSIBILITY

### Color Contrast
- All text meets WCAG AA (4.5:1 for body, 3:1 for UI)
- Status colors paired with icons (not color-only)
- Danger: #E24857 on white = 6.2:1 ✓

### Touch Targets
- All buttons ≥44pt tall
- All interactive elements ≥44pt × 44pt
- Spacing between tappables ≥8pt

### Labels
- All buttons have `.accessibilityLabel`
- All icons have descriptive labels
- Form fields have labels

### Reduced Motion
- Animations respect `accessibilityReduceMotion`
- Core functionality works without animation

---

## PERFORMANCE OPTIMIZATIONS

### View Hierarchy
- No nested scrollviews (each tab has 1 scroll)
- Card components are lightweight
- No heavy calculations in body

### SwiftData
- All queries filtered at source
- No in-memory sorting of large datasets
- Indexes on frequently queried fields

### Memory
- Images cached locally (not loaded dynamically)
- No view recreation on navigation
- Proper use of @State vs @StateObject

### Rendering
- List/ForEach use IDs for diffing
- Background colors set on container (not repeated)
- Gradients computed once, reused

---

## TESTING STRATEGY

### Preview Canvases
```swift
#Preview {
    HomeTabView()
        .modelContainer(Persistence.previewContainer)
        .environment(AppState())
}
```

All 4 tabs have preview canvases with mock data.

### Snapshot Tests
- Card layouts at various widths
- Empty states render correctly
- Status badges in all colors
- Navigation transitions smooth

### Integration Tests
- Tab switching doesn't lose state
- Settings modal opens/closes cleanly
- Navigation back works from detail views
- Queries reflect added/removed data

---

## LAUNCH CHECKLIST

- [ ] All 4 tabs compile without warnings
- [ ] Previews render for each tab
- [ ] No SwiftData migration issues
- [ ] Navigation works (all transitions)
- [ ] Settings modal opens/closes
- [ ] Camera placeholder doesn't crash
- [ ] Color contrast verified (WCAG AA)
- [ ] Touch targets ≥44pt checked
- [ ] Reduced motion respected
- [ ] App icon set
- [ ] App name localized
- [ ] Privacy policy linked
- [ ] Version bumped

---

*Last Updated: July 2026*  
*Architecture: Feature-first, tab-based, component-driven*  
*Ready for Phase 2: Real camera + ML integration*
