import SwiftUI

// ============================================================
// MARK: — Existing Components (unchanged)
// ============================================================

/// Segmented progress indicator: completed = heroGradient, current = strokeBright, upcoming = strokeSubtle.
struct OnboardingProgressBar: View {
    let current: Int
    let total: Int

    var body: some View {
        HStack(spacing: VSpace.xs) {
            ForEach(0..<max(total, 1), id: \.self) { index in
                Capsule()
                    .fill(segmentStyle(for: index))
                    .frame(height: 3)
            }
        }
        .animation(VMotion.standard, value: current)
        .accessibilityElement()
        .accessibilityLabel("onboarding.progress")
        .accessibilityValue(Text(verbatim: "\(current)/\(total)"))
    }

    private func segmentStyle(for index: Int) -> AnyShapeStyle {
        if index < current - 1 { return AnyShapeStyle(VColor.heroGradient) }
        if index == current - 1 { return AnyShapeStyle(VColor.strokeBright) }
        return AnyShapeStyle(VColor.strokeSubtle)
    }
}

/// Tappable selection card (single- or multi-select) with a selected state.
struct OnboardingSelectCard: View {
    let titleKey: LocalizedStringKey
    var systemImage: String? = nil
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button {
            Haptics.fire(.selection)
            action()
        } label: {
            HStack(spacing: 12) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .foregroundStyle(selected ? VColor.primary : VColor.textSecondary)
                        .frame(width: 26)
                }
                Text(titleKey)
                    .font(.headline)
                    .foregroundStyle(VColor.textPrimary)
                Spacer(minLength: 8)
                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(selected ? VColor.primary : VColor.strokeSubtle)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(selected ? VColor.primary : VColor.strokeSubtle, lineWidth: selected ? 2 : 1)
            )
        }
        .buttonStyle(PressableStyle())
    }
}

/// Multi/single-select chip — fills with the signature gradient when selected.
struct ChoiceChip: View {
    let titleKey: LocalizedStringKey
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button {
            Haptics.fire(.selection)
            action()
        } label: {
            HStack(spacing: 6) {
                if selected { Image(systemName: "checkmark").font(.caption2.weight(.bold)) }
                Text(titleKey).font(VType.bodyMedium)
            }
            .foregroundStyle(selected ? .white : VColor.textPrimary)
            .padding(.horizontal, VSpace.md)
            .padding(.vertical, 10)
            .background(
                selected ? AnyShapeStyle(VColor.heroGradient) : AnyShapeStyle(VColor.bgSurface),
                in: Capsule()
            )
            .overlay(Capsule().strokeBorder(selected ? Color.clear : VColor.strokeSubtle, lineWidth: 1))
        }
        .buttonStyle(PressableStyle())
        .animation(VMotion.snappy, value: selected)
    }
}

/// Building-profile status line that ticks to checkmark on cue.
struct BuildingStatusRow: View {
    let titleKey: LocalizedStringKey
    let done: Bool

    var body: some View {
        HStack(spacing: VSpace.sm) {
            ZStack {
                Circle().stroke(VColor.strokeSubtle, lineWidth: 2).frame(width: 22, height: 22)
                if done {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(VColor.success)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            Text(titleKey)
                .font(VType.body)
                .foregroundStyle(done ? VColor.textPrimary : VColor.textSecondary)
            Spacer()
        }
        .animation(VMotion.snappy, value: done)
    }
}

/// Standard layout for a quiz step: title + subtitle + content + Continue/Skip.
struct OnboardingScaffold<Content: View>: View {
    let titleKey: LocalizedStringKey
    var subtitleKey: LocalizedStringKey? = nil
    var progress: (current: Int, total: Int)? = nil
    var continueEnabled: Bool = true
    var onContinue: () -> Void
    var onSkip: (() -> Void)? = nil
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(spacing: 0) {
            if let progress {
                OnboardingProgressBar(current: progress.current, total: progress.total)
                    .padding(.horizontal, 24).padding(.top, 12)
            }
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(titleKey)
                            .font(VType.heroTitle)
                            .foregroundStyle(VColor.textPrimary)
                        if let subtitleKey {
                            Text(subtitleKey)
                                .font(.subheadline)
                                .foregroundStyle(VColor.textSecondary)
                        }
                    }
                    .padding(.top, 20)
                    content()
                }
                .padding(24)
            }
            .scrollIndicators(.hidden)
            VStack(spacing: 6) {
                PrimaryButton(titleKey: "onboarding.continue", isEnabled: continueEnabled, action: onContinue)
                if let onSkip { SecondaryButton(titleKey: "onboarding.skip", action: onSkip) }
            }
            .padding(.horizontal, 24).padding(.bottom, 20)
        }
    }
}


// ============================================================
// MARK: — Screen 1: Cinematic Gradient (VBackground is used directly in OnboardingFlowView)
// ============================================================
// VBackground already provides the premium animated mesh background.
// No additional background needed — screens render on top of it.


// ============================================================
// MARK: — Screen 2: Mock Dashboard Components
// ============================================================

/// Full mock skin-health dashboard card shown in Screen 2.
struct MockDashboardCard: View {
    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: VSpace.md) {
                dashboardHeader
                dashboardBody
            }
        }
    }

    private var dashboardHeader: some View {
        HStack {
            Text("Skin Health Score")
                .font(VType.bodyMedium)
                .foregroundStyle(VColor.textPrimary)
            Spacer()
            Text("Today")
                .font(VType.caption)
                .foregroundStyle(VColor.textTertiary)
        }
    }

    private var dashboardBody: some View {
        HStack(spacing: VSpace.lg) {
            scoreRing
            metricsList
        }
    }

    private var scoreRing: some View {
        ZStack {
            Circle()
                .stroke(VColor.strokeSubtle, lineWidth: 6)
                .frame(width: 76, height: 76)
            Circle()
                .trim(from: 0, to: 0.78)
                .stroke(
                    LinearGradient(colors: [VColor.primary, VColor.accent], startPoint: .topLeading, endPoint: .bottomTrailing),
                    style: StrokeStyle(lineWidth: 6, lineCap: .round)
                )
                .frame(width: 76, height: 76)
                .rotationEffect(.degrees(-90))
            VStack(spacing: 0) {
                Text("78")
                    .font(VType.number(24))
                    .foregroundStyle(VColor.textPrimary)
                Text("score")
                    .font(VType.micro)
                    .foregroundStyle(VColor.textTertiary)
            }
        }
    }

    private var metricsList: some View {
        VStack(alignment: .leading, spacing: 8) {
            MockMetricPill(label: "Hydration", value: "Good", color: VColor.success)
            MockMetricPill(label: "Redness", value: "Mild", color: VColor.warning)
            MockMetricPill(label: "Barrier", value: "Strong", color: VColor.primary)
            MockMetricPill(label: "Texture", value: "Smooth", color: VColor.accent)
        }
    }
}

private struct MockMetricPill: View {
    let label: String
    let value: String
    let color: Color

    var body: some View {
        HStack(spacing: 6) {
            Circle().fill(color).frame(width: 6, height: 6)
            Text(label)
                .font(VType.caption)
                .foregroundStyle(VColor.textSecondary)
            Spacer()
            Text(value)
                .font(VType.captionBold)
                .foregroundStyle(color)
        }
    }
}

/// Mini trend chart preview for Screen 2.
struct MockTrendCard: View {
    private let bars: [CGFloat] = [0.38, 0.45, 0.42, 0.55, 0.60, 0.64, 0.68, 0.70, 0.72, 0.76, 0.80, 0.84]

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: VSpace.md) {
                trendHeader
                trendChart
                trendFooter
            }
        }
    }

    private var trendHeader: some View {
        HStack {
            Text("3-Week Progress")
                .font(VType.bodyMedium)
                .foregroundStyle(VColor.textPrimary)
            Spacer()
            HStack(spacing: 4) {
                Image(systemName: "arrow.up.right")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(VColor.success)
                Text("+24%")
                    .font(VType.captionBold)
                    .foregroundStyle(VColor.success)
            }
        }
    }

    private var trendChart: some View {
        HStack(alignment: .bottom, spacing: 4) {
            ForEach(bars.indices, id: \.self) { i in
                let h = bars[i] * 50
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [VColor.primary.opacity(0.35), VColor.primary],
                            startPoint: .bottom,
                            endPoint: .top
                        )
                    )
                    .frame(maxWidth: .infinity)
                    .frame(height: h)
            }
        }
        .frame(height: 50)
    }

    private var trendFooter: some View {
        HStack {
            Text("Week 1")
                .font(VType.micro)
                .foregroundStyle(VColor.textTertiary)
            Spacer()
            Text("Week 3")
                .font(VType.micro)
                .foregroundStyle(VColor.textTertiary)
        }
    }
}

/// Mock morning routine card for Screen 2.
struct MockRoutineCard: View {
    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: VSpace.md) {
                routineHeader
                routineItems
            }
        }
    }

    private var routineHeader: some View {
        HStack {
            Text("Morning Routine")
                .font(VType.bodyMedium)
                .foregroundStyle(VColor.textPrimary)
            Spacer()
            Image(systemName: "sun.max.fill")
                .foregroundStyle(VColor.warning)
                .font(.caption)
        }
    }

    private var routineItems: some View {
        VStack(spacing: VSpace.sm) {
            MockRoutineStep(n: 1, name: "Gentle Cleanser", status: "Proven", color: VColor.success)
            MockRoutineStep(n: 2, name: "Barrier Repair Serum", status: "Testing", color: VColor.warning)
            MockRoutineStep(n: 3, name: "SPF 50 Moisturizer", status: "Proven", color: VColor.success)
        }
    }
}

private struct MockRoutineStep: View {
    let n: Int
    let name: String
    let status: String
    let color: Color

    var body: some View {
        HStack(spacing: 10) {
            Text("\(n)")
                .font(VType.micro)
                .foregroundStyle(VColor.textTertiary)
                .frame(width: 14)
            Text(name)
                .font(VType.caption)
                .foregroundStyle(VColor.textPrimary)
            Spacer()
            Text(status)
                .font(VType.micro)
                .foregroundStyle(color)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(color.opacity(0.10), in: Capsule())
        }
    }
}


// ============================================================
// MARK: — Screen 3: Mock Face Scan
// ============================================================

/// Cinematic mock face scan animation. Completely simulated — no real camera.
struct MockFaceScanView: View {
    let reduceMotion: Bool

    @State private var phase: Int = 0
    @State private var ringTrim: CGFloat = 0
    @State private var isSpinning: Bool = false
    @State private var showMesh: Bool = false
    @State private var showRegions: Bool = false
    @State private var resultCount: Int = 0

    private struct ScanResult {
        let text: String
        let region: String
        let tone: String
    }

    private let scanResults: [ScanResult] = [
        ScanResult(text: "Mild dehydration detected",        region: "Cheek region",     tone: "warning"),
        ScanResult(text: "Redness within normal range",      region: "Overall skin tone", tone: "success"),
        ScanResult(text: "Smooth texture noted",             region: "Forehead",          tone: "success"),
        ScanResult(text: "Barrier function: moderate",       region: "Full face",         tone: "accent"),
    ]

    var body: some View {
        VStack(spacing: VSpace.lg) {
            faceVisual
            resultsList
        }
        .task { await runAnimation() }
    }

    // MARK: Face visual

    private var faceVisual: some View {
        ZStack {
            // Face silhouette fill
            Ellipse()
                .fill(VColor.bgElevated.opacity(0.7))
                .frame(width: 152, height: 192)

            // Face silhouette stroke
            Ellipse()
                .stroke(VColor.strokeSubtle, lineWidth: 1)
                .frame(width: 152, height: 192)

            // Region colour overlays
            if showRegions {
                faceRegions
                    .transition(.opacity)
            }

            // Mesh landmark dots
            if showMesh {
                faceMesh
                    .transition(.opacity)
            }

            // Scanning ring
            if phase >= 1 {
                scanningRing
                    .transition(.opacity)
            }

            // Status label
            statusLabel
        }
        .frame(width: 220, height: 240)
    }

    private var scanningRing: some View {
        Circle()
            .trim(from: 0, to: ringTrim)
            .stroke(
                LinearGradient(
                    colors: [VColor.primary, VColor.accent],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                style: StrokeStyle(lineWidth: 2.5, lineCap: .round)
            )
            .frame(width: 212, height: 212)
            .rotationEffect(.degrees(isSpinning ? 360 : -90))
            .animation(
                .linear(duration: 1.8).repeatForever(autoreverses: false),
                value: isSpinning
            )
    }

    private var faceRegions: some View {
        ZStack {
            // Forehead — hydration concern
            Ellipse()
                .fill(VColor.accent.opacity(0.18))
                .frame(width: 82, height: 52)
                .offset(y: -68)

            // Left cheek — mild dehydration
            Ellipse()
                .fill(VColor.warning.opacity(0.20))
                .frame(width: 54, height: 44)
                .offset(x: -46, y: 10)

            // Right cheek — mild dehydration
            Ellipse()
                .fill(VColor.warning.opacity(0.20))
                .frame(width: 54, height: 44)
                .offset(x: 46, y: 10)

            // Nose — healthy
            Ellipse()
                .fill(VColor.success.opacity(0.15))
                .frame(width: 36, height: 28)
                .offset(y: 18)
        }
    }

    private var faceMesh: some View {
        // Landmark dots relative to face centre (ellipse centre = 0,0)
        ZStack {
            ForEach(meshOffsets.indices, id: \.self) { i in
                let pt = meshOffsets[i]
                Circle()
                    .fill(VColor.primary.opacity(0.55))
                    .frame(width: 3, height: 3)
                    .offset(x: pt.0, y: pt.1)
            }
        }
    }

    private var meshOffsets: [(CGFloat, CGFloat)] {
        [
            (0, -82),   (-24, -68), (24, -68),
            (-38, -38), (38, -38),
            (-40, -24), (40, -24),
            (-30, -18), (30, -18),
            (0, -4),
            (-16, 18),  (16, 18),
            (0, 28),
            (-52, 12),  (52, 12),
            (-24, 54),  (0, 58), (24, 54),
            (0, 84),
        ]
    }

    @ViewBuilder
    private var statusLabel: some View {
        if phase == 0 {
            Text("Preparing analysis…")
                .font(VType.micro)
                .foregroundStyle(VColor.textTertiary)
                .offset(y: 112)
        } else if phase == 1 {
            Text("Analyzing skin regions…")
                .font(VType.micro)
                .foregroundStyle(VColor.primary)
                .offset(y: 112)
        }
    }

    // MARK: Results list

    private var resultsList: some View {
        VStack(spacing: VSpace.sm) {
            ForEach(0..<resultCount, id: \.self) { i in
                if i < scanResults.count {
                    ScanResultRow(
                        text: scanResults[i].text,
                        region: scanResults[i].region,
                        tone: scanResults[i].tone
                    )
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
        .animation(VMotion.snappy, value: resultCount)
    }

    // MARK: Animation sequence

    private func runAnimation() async {
        if reduceMotion {
            phase = 2
            ringTrim = 0.75
            showMesh = true
            showRegions = true
            resultCount = scanResults.count
            return
        }

        // 1. Ring appears and draws on
        try? await Task.sleep(for: .milliseconds(400))
        withAnimation(.easeIn(duration: 0.5)) { phase = 1 }
        withAnimation(.easeInOut(duration: 0.8)) { ringTrim = 0.75 }

        // 2. Ring starts spinning
        try? await Task.sleep(for: .milliseconds(500))
        isSpinning = true

        // 3. Mesh dots appear
        try? await Task.sleep(for: .milliseconds(900))
        withAnimation(.easeInOut(duration: 0.5)) { showMesh = true }

        // 4. Region overlays appear
        try? await Task.sleep(for: .milliseconds(700))
        withAnimation(.easeInOut(duration: 0.5)) { showRegions = true; phase = 2 }

        // 5. Results reveal one by one
        for _ in scanResults {
            try? await Task.sleep(for: .milliseconds(520))
            withAnimation(VMotion.snappy) { resultCount += 1 }
        }
    }
}

/// Single result row shown beneath the mock face scan.
private struct ScanResultRow: View {
    let text: String
    let region: String
    let tone: String

    private var toneColor: Color {
        switch tone {
        case "success": return VColor.success
        case "warning":  return VColor.warning
        case "accent":   return VColor.accent
        default:         return VColor.primary
        }
    }

    var body: some View {
        HStack(spacing: VSpace.md) {
            Circle()
                .fill(toneColor)
                .frame(width: 8, height: 8)
            VStack(alignment: .leading, spacing: 2) {
                Text(text)
                    .font(VType.bodyMedium)
                    .foregroundStyle(VColor.textPrimary)
                Text(region)
                    .font(VType.caption)
                    .foregroundStyle(VColor.textSecondary)
            }
            Spacer()
        }
        .padding(.horizontal, VSpace.md)
        .padding(.vertical, 10)
        .background(VColor.bgSurface, in: RoundedRectangle(cornerRadius: VRadius.sm, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: VRadius.sm, style: .continuous)
                .strokeBorder(toneColor.opacity(0.25), lineWidth: 1)
        )
    }
}


// ============================================================
// MARK: — Screen 4: Ingredient Intelligence Card
// ============================================================

struct IngredientMatchCard: View {
    let icon: String
    let iconColor: Color
    let name: String
    let brand: String
    let insight: String
    let badge: String
    let badgeColor: Color

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: VSpace.sm) {
                cardHeader
                Text(insight)
                    .font(VType.caption)
                    .foregroundStyle(VColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                badgePill
            }
        }
    }

    private var cardHeader: some View {
        HStack(spacing: VSpace.sm) {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(iconColor.opacity(0.12))
                .frame(width: 44, height: 44)
                .overlay(
                    Image(systemName: icon)
                        .foregroundStyle(iconColor)
                        .font(.headline)
                )
            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(VType.bodyMedium)
                    .foregroundStyle(VColor.textPrimary)
                Text(brand)
                    .font(VType.caption)
                    .foregroundStyle(VColor.textTertiary)
            }
            Spacer()
        }
    }

    private var badgePill: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption2.weight(.bold))
                .foregroundStyle(badgeColor)
            Text(badge)
                .font(VType.captionBold)
                .foregroundStyle(badgeColor)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(badgeColor.opacity(0.10), in: Capsule())
    }
}


// ============================================================
// MARK: — Screen 5: Privacy Pillar Row
// ============================================================

struct PrivacyPillarRow: View {
    let icon: String
    let text: String
    let index: Int

    var body: some View {
        HStack(spacing: VSpace.md) {
            Image(systemName: icon)
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(VColor.primary)
                .frame(width: 32)
            Text(text)
                .font(VType.body)
                .foregroundStyle(VColor.textPrimary)
            Spacer()
            Image(systemName: "checkmark")
                .font(.caption.weight(.semibold))
                .foregroundStyle(VColor.success)
        }
        .padding(.vertical, VSpace.md)
        .vStaggeredAppear(index: index)
    }
}


// ============================================================
// MARK: — Screen 6: Goal Large Card
// ============================================================

struct GoalLargeCard: View {
    let icon: String
    let label: String
    let subtitle: String?
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: VSpace.md) {
                iconCircle
                labelStack
                Spacer(minLength: 0)
                if selected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(VColor.primary)
                        .font(.title3)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .padding(.horizontal, VSpace.md)
            .padding(.vertical, VSpace.md)
            .background(VColor.bgSurface, in: RoundedRectangle(cornerRadius: VRadius.md, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: VRadius.md, style: .continuous)
                    .strokeBorder(selected ? VColor.primary : VColor.strokeSubtle, lineWidth: selected ? 2 : 1)
            )
        }
        .buttonStyle(PressableStyle())
        .animation(VMotion.snappy, value: selected)
    }

    private var iconCircle: some View {
        ZStack {
            Circle()
                .fill(selected ? AnyShapeStyle(VColor.heroGradient) : AnyShapeStyle(VColor.bgElevated2))
                .frame(width: 46, height: 46)
            Image(systemName: icon)
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(selected ? Color.white : VColor.primary)
        }
    }

    private var labelStack: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(VType.bodyLarge)
                .foregroundStyle(VColor.textPrimary)
            if let subtitle {
                Text(subtitle)
                    .font(VType.caption)
                    .foregroundStyle(VColor.textSecondary)
            }
        }
    }
}


// ============================================================
// MARK: — Screen 7: Account & Benefits
// ============================================================

struct AccountBenefitRow: View {
    let icon: String
    let text: String
    let index: Int

    var body: some View {
        HStack(spacing: VSpace.md) {
            Image(systemName: icon)
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(VColor.primary)
                .frame(width: 32)
            Text(text)
                .font(VType.body)
                .foregroundStyle(VColor.textPrimary)
            Spacer()
        }
        .padding(.vertical, VSpace.md)
        .vStaggeredAppear(index: index)
    }
}

/// Placeholder Sign in with Apple button — looks fully native, no auth logic yet.
struct AppleSignInPlaceholder: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: "apple.logo")
                    .font(.system(size: 18, weight: .semibold))
                Text("Sign in with Apple")
                    .font(.system(size: 17, weight: .semibold))
            }
            .foregroundStyle(Color.white)
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background(Color.black, in: RoundedRectangle(cornerRadius: VRadius.sm, style: .continuous))
        }
        .buttonStyle(PressableStyle())
    }
}


// ============================================================
// MARK: — Screen 8: Pulsing Scan Orb & Hint Row
// ============================================================

/// Pulsing camera orb with emanating rings — the emotional finale of onboarding.
struct PulsingScanOrb: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isAnimating: Bool = false

    var body: some View {
        ZStack {
            // Outer emanating ring 1
            Circle()
                .stroke(VColor.primary.opacity(isAnimating ? 0 : 0.18), lineWidth: 1.5)
                .scaleEffect(isAnimating ? 1.65 : 1.0)
                .frame(width: 104, height: 104)
                .animation(
                    .easeOut(duration: 1.8).repeatForever(autoreverses: false),
                    value: isAnimating
                )

            // Outer emanating ring 2 (offset phase)
            Circle()
                .stroke(VColor.primary.opacity(isAnimating ? 0 : 0.12), lineWidth: 1.5)
                .scaleEffect(isAnimating ? 1.65 : 1.0)
                .frame(width: 104, height: 104)
                .animation(
                    .easeOut(duration: 1.8).delay(0.6).repeatForever(autoreverses: false),
                    value: isAnimating
                )

            // Gradient fill
            Circle()
                .fill(
                    LinearGradient(
                        colors: [VColor.primary.opacity(0.14), VColor.accent.opacity(0.10)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 104, height: 104)

            // Trim arc
            Circle()
                .trim(from: 0, to: 0.82)
                .stroke(
                    LinearGradient(
                        colors: [VColor.primary, VColor.accent],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    style: StrokeStyle(lineWidth: 3, lineCap: .round)
                )
                .frame(width: 104, height: 104)
                .rotationEffect(.degrees(-90))

            // Camera icon
            Image(systemName: "camera.fill")
                .font(.system(size: 34, weight: .light))
                .foregroundStyle(VColor.primary)
        }
        .onAppear {
            guard !reduceMotion else { return }
            isAnimating = true
        }
    }
}

/// Small hint row beneath the scan CTA.
struct ScanHintRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: VSpace.sm) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(VColor.primary)
                .frame(width: 20)
            Text(text)
                .font(VType.body)
                .foregroundStyle(VColor.textSecondary)
            Spacer()
        }
    }
}
