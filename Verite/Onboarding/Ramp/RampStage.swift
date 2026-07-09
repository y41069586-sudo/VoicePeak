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

    /// Total number of conceptual screens (0–11) for the progress bar.
    static let screenCount = 12
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
// MARK: — Typewriter text (boot wordmark)
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

// ============================================================
// MARK: — Twin integrity HUD
// ============================================================

/// The permanent top-of-screen readout that turns the whole flow into "the
/// engine is building your twin". A mono label, a live percentage, a glowing
/// fill bar and a `SUBJECT · UNVERIFIED` status that only flips to VERIFIED
/// after the real scan. Shown from The Number through the Handoff.
struct RampIntegrityHUD: View {
    /// 0…1.
    let integrity: Double
    var verified: Bool = false

    private var pct: Int { Int((integrity * 100).rounded()) }

    var body: some View {
        VStack(spacing: 6) {
            HStack {
                Text(verbatim: "TWIN INTEGRITY")
                    .font(DQFont.mono(10, weight: .semibold))
                    .tracking(2)
                    .foregroundStyle(RampStage.textTertiary)
                Spacer()
                Text(verbatim: "\(pct)%")
                    .font(DQFont.mono(11, weight: .bold))
                    .foregroundStyle(RampStage.accent)
                    .contentTransition(.numericText(value: Double(pct)))
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.08))
                    Capsule()
                        .fill(DQColor.accentGradient)
                        .frame(width: geo.size.width * CGFloat(max(0, min(1, integrity))))
                        .vGlow(RampStage.accent, radius: 6, opacity: 0.7)
                }
            }
            .frame(height: 3)
            HStack(spacing: 5) {
                Circle()
                    .fill(verified ? DQColor.deltaUp : RampStage.accent)
                    .frame(width: 5, height: 5)
                Text(verbatim: verified ? "SUBJECT · VERIFIED" : "SUBJECT · UNVERIFIED")
                    .font(DQFont.mono(9, weight: .medium))
                    .tracking(1.5)
                    .foregroundStyle(RampStage.textTertiary)
                Spacer()
            }
        }
        .animation(VMotion.standard, value: integrity)
        .accessibilityElement()
        .accessibilityLabel("onboarding.twin.integrity")
        .accessibilityValue(Text(verbatim: "\(pct)%"))
    }
}

// ============================================================
// MARK: — Hold-to-begin button
// ============================================================

/// A commitment ritual instead of a tap: hold, a fill sweeps across, the
/// haptics ramp, and it fires only when the ring completes. Physical intent
/// converts far harder than a one-tap CTA. Reduce Motion degrades to a tap.
struct RampHoldToBeginButton: View {
    var title: String = "Hold to begin"
    var duration: Double = 1.1
    let action: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var progress: CGFloat = 0
    @State private var holding = false
    @State private var holdTask: Task<Void, Never>?

    var body: some View {
        ZStack {
            Capsule().fill(RampStage.card)
            GeometryReader { geo in
                Capsule()
                    .fill(DQColor.accentGradient)
                    .frame(width: geo.size.width * progress)
            }
            .clipShape(Capsule())
            HStack(spacing: 8) {
                Image(systemName: "hand.tap.fill")
                Text(holding ? "Keep holding…" : title)
            }
            .font(.system(size: 17, weight: .semibold))
            .foregroundStyle(DQColor.textPrimary)
        }
        .frame(maxWidth: .infinity, minHeight: 56)
        .overlay(Capsule().strokeBorder(RampStage.accent.opacity(0.6), lineWidth: 1))
        .vGlow(DQColor.accent, radius: 22, opacity: holding ? 0.45 : 0.2)
        .contentShape(Capsule())
        .scaleEffect(holding ? 0.98 : 1)
        .animation(VMotion.press, value: holding)
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in begin() }
                .onEnded { _ in release() }
        )
        .accessibilityAddTraits(.isButton)
        .accessibilityLabel(Text(title))
        .accessibilityAction { fire() }
    }

    private func begin() {
        guard !holding else { return }
        holding = true
        Haptics.fire(.selection)
        if reduceMotion { fire(); return }
        withAnimation(.linear(duration: duration)) { progress = 1 }
        holdTask = Task {
            let ticks = 5
            for _ in 1...ticks {
                try? await Task.sleep(for: .seconds(duration / Double(ticks)))
                if Task.isCancelled { return }
                Haptics.fire(.tick)
            }
            if !Task.isCancelled { fire() }
        }
    }

    private func release() {
        holdTask?.cancel()
        holdTask = nil
        guard holding, progress < 1 else { return }
        holding = false
        withAnimation(VMotion.snappy) { progress = 0 }
    }

    private func fire() {
        holdTask?.cancel()
        holdTask = nil
        holding = false
        progress = 1
        Haptics.fire(.capture)
        action()
    }
}

// ============================================================
// MARK: — Foreign score ticker
// ============================================================

/// A blurred marquee of *other people's* scores drifting past — the social
/// norm made visible ("everyone has a number; you've never seen yours").
struct RampForeignScoreTicker: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let scores = [73, 81, 58, 92, 64, 77, 49, 88, 61, 70, 84, 55, 79, 66, 90, 52]

    var body: some View {
        let row = scores.map(String.init).joined(separator: "   ·   ")
        let long = Array(repeating: row, count: 10).joined(separator: "   ·   ")
        Group {
            if reduceMotion {
                Text(verbatim: row).lineLimit(1)
            } else {
                TimelineView(.animation) { timeline in
                    let t = timeline.date.timeIntervalSinceReferenceDate
                    let shift = CGFloat((t * 28).truncatingRemainder(dividingBy: 6000))
                    Text(verbatim: long)
                        .lineLimit(1)
                        .fixedSize()
                        .offset(x: -shift)
                }
            }
        }
        .font(DQFont.mono(13, weight: .medium))
        .foregroundStyle(RampStage.textTertiary)
        .blur(radius: 1.2)
        .frame(height: 20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .clipped()
        .mask(
            LinearGradient(colors: [.clear, .black, .black, .clear],
                           startPoint: .leading, endPoint: .trailing)
        )
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

// ============================================================
// MARK: — Distribution curve ("where do you land?")
// ============================================================

/// An animated population bell-curve with scattered peers and a glowing "?"
/// marker that keeps sweeping without ever settling — your place is unknown
/// until the scan. No fabricated testimonials; a pure abstract visualization.
struct RampDistributionCurve: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30)) { timeline in
            let t = reduceMotion ? 0 : timeline.date.timeIntervalSinceReferenceDate
            Canvas { context, size in
                let w = size.width, h = size.height
                func bell(_ x: CGFloat) -> CGFloat {
                    let u = (x - 0.5) / 0.16
                    return exp(-0.5 * u * u)
                }
                func y(_ fx: CGFloat) -> CGFloat { h - bell(fx) * h * 0.80 - 8 }

                // Curve path.
                var curve = Path()
                let steps = 72
                for i in 0...steps {
                    let fx = CGFloat(i) / CGFloat(steps)
                    let point = CGPoint(x: fx * w, y: y(fx))
                    if i == 0 { curve.move(to: point) } else { curve.addLine(to: point) }
                }
                var fill = curve
                fill.addLine(to: CGPoint(x: w, y: h))
                fill.addLine(to: CGPoint(x: 0, y: h))
                fill.closeSubpath()
                context.fill(fill, with: .linearGradient(
                    Gradient(colors: [RampStage.accent.opacity(0.28), .clear]),
                    startPoint: CGPoint(x: 0, y: 0),
                    endPoint: CGPoint(x: 0, y: h)))
                context.stroke(curve, with: .color(RampStage.accent.opacity(0.75)), lineWidth: 1.5)

                // Scattered peers clustered near the mean.
                for i in 0..<44 {
                    let n = Self.hash(i, 12.9898)
                    let n2 = Self.hash(i, 78.233)
                    let fx = min(max(0.5 + (n - 0.5) * 0.62, 0.04), 0.96)
                    let py = y(fx) + (1 - n2) * (h - y(fx) - 6) * 0.9
                    let r = 1.3 + Self.hash(i, 39.42) * 1.4
                    context.fill(
                        Path(ellipseIn: CGRect(x: fx * w - r, y: py - r, width: r * 2, height: r * 2)),
                        with: .color(Color.white.opacity(0.16)))
                }

                // The searching "?" marker.
                let mx = CGFloat(0.5 + 0.34 * sin(t * 0.8))
                let my = y(mx)
                context.fill(
                    Path(ellipseIn: CGRect(x: mx * w - 16, y: my - 16, width: 32, height: 32)),
                    with: .color(RampStage.accent.opacity(0.18)))
                context.fill(
                    Path(ellipseIn: CGRect(x: mx * w - 6, y: my - 6, width: 12, height: 12)),
                    with: .color(RampStage.accent))
                context.draw(
                    Text(verbatim: "?")
                        .font(DQFont.mono(13, weight: .bold))
                        .foregroundColor(.white),
                    at: CGPoint(x: mx * w, y: my - 22))
            }
        }
        .frame(height: 176)
        .accessibilityHidden(true)
    }

    private static func hash(_ i: Int, _ salt: Double) -> Double {
        let v = sin(Double(i + 1) * salt) * 43758.5453
        return v - floor(v)
    }
}
