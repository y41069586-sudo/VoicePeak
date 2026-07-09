import SwiftUI

// ============================================================
// MARK: — The dark onboarding stage
// ============================================================
//
// The ramp onboarding runs on the same dark, clinical-premium stage as the
// v2 app it hands off to. Nothing here redefines a design token — this enum
// only *maps* the DQ tokens (DQTheme.swift, the single source of truth) onto
// the onboarding's named roles.

enum RampStage {
    /// Bloom behind the head.
    static let backdropGlow = DQColor.accent
    /// Accent used for glows, progress fill and selected states on dark.
    static let accent = DQColor.accentBright

    // Text ladder on the dark stage.
    static let textPrimary   = Color.white
    static let textSecondary = Color.white.opacity(0.64)
    static let textTertiary  = Color.white.opacity(0.42)

    // Surfaces on the dark stage.
    static let card     = Color.white.opacity(0.06)
    static let hairline = Color.white.opacity(0.14)

    /// Total number of conceptual screens (0–9) for the progress bar.
    static let screenCount = 10
}

/// Full-bleed backdrop: the v2 background with a soft accent bloom behind
/// the head and a slow field of drifting light particles. No pure black
/// (design-system rule).
struct RampBackdrop: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            DQColor.background
            RadialGradient(
                colors: [RampStage.backdropGlow.opacity(0.22), .clear],
                center: UnitPoint(x: 0.5, y: 0.34),
                startRadius: 10,
                endRadius: 480
            )
            if !reduceMotion {
                RampParticleField()
            }
        }
        .ignoresSafeArea()
    }
}

/// Drifting glowing micro-particles — one cheap Canvas draw per frame, no
/// per-particle state. Positions are pure functions of (index, time), so the
/// field is deterministic and allocation-free.
struct RampParticleField: View {
    private static let count = 42

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30)) { timeline in
            Canvas { context, size in
                let t = timeline.date.timeIntervalSinceReferenceDate
                context.blendMode = .plusLighter
                for i in 0..<Self.count {
                    let seedX  = Self.hash(i, 12.9898)
                    let speed  = 0.008 + Self.hash(i, 78.233) * 0.020 // screen-heights/s
                    let phase  = Self.hash(i, 39.425)
                    let sway   = sin(t * (0.3 + phase * 0.5) + phase * 6.28) * 14
                    let cycle  = (Self.hash(i, 94.673) + t * speed)
                        .truncatingRemainder(dividingBy: 1)
                    let x = seedX * size.width + sway
                    let y = (1 - cycle) * (size.height + 40) - 20
                    let radius = 0.7 + Self.hash(i, 61.117) * 1.7
                    let twinkle = 0.35 + 0.65 * (0.5 + 0.5 * sin(t * (0.8 + phase * 2) + Double(i)))
                    let alpha = (0.05 + 0.16 * Self.hash(i, 27.541)) * twinkle
                    let rect = CGRect(x: x - radius, y: y - radius,
                                      width: radius * 2, height: radius * 2)
                    context.fill(Path(ellipseIn: rect),
                                 with: .color(RampStage.accent.opacity(alpha)))
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    /// Cheap deterministic pseudo-random in 0..<1 from an index + salt.
    private static func hash(_ i: Int, _ salt: Double) -> Double {
        let v = sin(Double(i + 1) * salt) * 43758.5453
        return v - floor(v)
    }
}

// ============================================================
// MARK: — Progress bar (thin, segmented, accent fill)
// ============================================================

struct RampProgressBar: View {
    /// Index of the current conceptual screen (0-based).
    let screenIndex: Int

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: VSpace.xs) {
            ForEach(0..<RampStage.screenCount, id: \.self) { index in
                segment(index)
            }
        }
        .animation(VMotion.standard, value: screenIndex)
        .accessibilityElement()
        .accessibilityLabel("onboarding.progress")
        .accessibilityValue(Text(verbatim: "\(screenIndex + 1)/\(RampStage.screenCount)"))
    }

    @ViewBuilder
    private func segment(_ index: Int) -> some View {
        let base = Capsule()
            .fill(index <= screenIndex
                  ? AnyShapeStyle(RampStage.accent)
                  : AnyShapeStyle(Color.white.opacity(0.12)))
            .frame(height: 3)
        if index == screenIndex && !reduceMotion {
            // The live segment breathes and glows — a quiet heartbeat.
            base
                .shadow(color: RampStage.accent.opacity(0.9), radius: 4)
                .phaseAnimator([0.55, 1.0]) { view, opacity in
                    view.opacity(opacity)
                } animation: { _ in
                    .easeInOut(duration: 0.9)
                }
        } else {
            base
        }
    }
}

// ============================================================
// MARK: — Typewriter text (cold-open wordmark)
// ============================================================

struct TypewriterText: View {
    let text: String
    var perCharacter: Duration = .milliseconds(80)
    var startDelay: Duration = .zero
    let font: Font
    var color: Color = RampStage.textPrimary
    var tracking: CGFloat = 0

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var visibleCount = 0

    var body: some View {
        // Full string reserves layout; visible prefix types over it.
        Text(text)
            .font(font)
            .tracking(tracking)
            .opacity(0)
            .overlay(alignment: .leading) {
                Text(String(text.prefix(visibleCount)))
                    .font(font)
                    .tracking(tracking)
                    .foregroundStyle(color)
                    .lineLimit(1)
                    .fixedSize()
            }
            .accessibilityLabel(Text(verbatim: text))
            .task {
                if reduceMotion {
                    visibleCount = text.count
                    return
                }
                try? await Task.sleep(for: startDelay)
                for index in 1...max(text.count, 1) {
                    try? await Task.sleep(for: perCharacter)
                    guard !Task.isCancelled else { return }
                    visibleCount = index
                }
            }
    }
}

// ============================================================
// MARK: — Buttons & option cards on the dark stage
// ============================================================

/// Small text-only secondary action ("Not now").
struct RampGhostButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(VType.body)
                .foregroundStyle(RampStage.textSecondary)
                .padding(.vertical, VSpace.sm)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(PressableStyle())
    }
}

/// Large tappable quiz option card. Fills with accent when selected —
/// selection *is* the advance, so there is no checkmark bookkeeping.
struct RampOptionCard: View {
    let label: String
    var icon: String? = nil
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: VSpace.md) {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 17, weight: .medium))
                        .foregroundStyle(selected ? Color.white : RampStage.accent)
                        .frame(width: 26)
                }
                Text(label)
                    .font(VType.bodyLarge.weight(.medium))
                    .foregroundStyle(selected ? Color.white : RampStage.textPrimary)
                    .multilineTextAlignment(.leading)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, VSpace.md)
            .frame(maxWidth: .infinity, minHeight: 58, alignment: .leading)
            .background(
                selected ? AnyShapeStyle(DQColor.accentGradient) : AnyShapeStyle(RampStage.card),
                in: RoundedRectangle(cornerRadius: VRadius.md, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: VRadius.md, style: .continuous)
                    .strokeBorder(selected ? RampStage.accent.opacity(0.9) : RampStage.hairline,
                                  lineWidth: 1)
            )
            .overlay {
                // Energy discharge on selection — the card "commits".
                if selected {
                    RampShockwave(cornerRadius: VRadius.md, maxScale: 1.22, duration: 0.55)
                }
            }
            .vGlow(DQColor.accent, radius: 18, opacity: selected ? 0.35 : 0)
            .scaleEffect(selected ? 1.02 : 1)
        }
        .buttonStyle(RampTiltPressStyle())
        .animation(VMotion.snappy, value: selected)
    }
}

/// Press style with a subtle 3D dip — option cards feel physical, like keys.
struct RampTiltPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.965 : 1)
            .rotation3DEffect(
                .degrees(configuration.isPressed ? 5 : 0),
                axis: (x: 1, y: 0, z: 0),
                perspective: 0.55
            )
            .animation(VMotion.press, value: configuration.isPressed)
    }
}

// ============================================================
// MARK: — Spectacle primitives
// ============================================================

/// One-shot expanding ring — the "energy discharge" used on quiz selections,
/// the cold-open ping and the calibration finale. Fires on appear.
struct RampShockwave: View {
    var color: Color = RampStage.accent
    var cornerRadius: CGFloat? = nil // nil = circle
    var maxScale: CGFloat = 1.6
    var lineWidth: CGFloat = 1.5
    var duration: Double = 0.6

    @State private var fired = false

    var body: some View {
        shape
            .scaleEffect(fired ? maxScale : 1)
            .opacity(fired ? 0 : 0.9)
            .onAppear { withAnimation(.easeOut(duration: duration)) { fired = true } }
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }

    @ViewBuilder
    private var shape: some View {
        if let cornerRadius {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .strokeBorder(color, lineWidth: lineWidth)
        } else {
            Circle().strokeBorder(color, lineWidth: lineWidth)
        }
    }
}

/// Slot-machine digits that never settle — the score you haven't learned yet.
/// Pure function of time; Reduce Motion pins it to a steady "??".
struct RampScrambleFigure: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Group {
            if reduceMotion {
                figure(text: "??")
            } else {
                TimelineView(.periodic(from: .now, by: 0.09)) { timeline in
                    let tick = Int(timeline.date.timeIntervalSinceReferenceDate / 0.09)
                    // Every ~12th frame flashes "??" — the number stays unknowable.
                    let text = tick % 12 == 0
                        ? "??"
                        : String(40 + Int(Self.hash(tick) * 59))
                    figure(text: text)
                }
            }
        }
        .accessibilityLabel("onboarding.score.unknown")
    }

    private func figure(text: String) -> some View {
        Text(verbatim: text)
            .font(DQFont.score(64))
            .foregroundStyle(DQColor.accentGradient)
            .monospacedDigit()
            .frame(minWidth: 110)
            .vGlow(RampStage.accent, radius: 30, opacity: 0.45)
            .contentTransition(.numericText())
    }

    private static func hash(_ i: Int) -> Double {
        let v = sin(Double(i) * 127.1) * 43758.5453
        return v - floor(v)
    }
}

/// "You can touch this" hint — a small pill that sways left/right until the
/// user grabs the head for the first time.
struct RampDragHint: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var sway = false

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "arrow.left.and.right")
                .font(.caption2.weight(.bold))
            Text("Drag to spin")
                .font(VType.captionBold)
        }
        .foregroundStyle(RampStage.textSecondary)
        .padding(.horizontal, VSpace.md)
        .padding(.vertical, 7)
        .background(RampStage.card, in: Capsule())
        .overlay(Capsule().strokeBorder(RampStage.hairline, lineWidth: 1))
        .offset(x: sway && !reduceMotion ? 10 : -10)
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                sway = true
            }
        }
        .accessibilityHidden(true)
    }
}
