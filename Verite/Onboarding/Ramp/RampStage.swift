import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

// ============================================================
// MARK: — "Lumière" — the soft, editorial onboarding stage
// ============================================================
//
// The onboarding no longer runs on the dark, clinical v2 stage. It is its own
// committed light world: warm porcelain, dawn light, a single dusty-rose
// accent, Playfair serif, generous whitespace. A calm beauty ritual, not a
// scan terminal. (The rest of the v2 app keeps its dark system; the handoff
// dissolves from this light world into the camera.)

enum RampStage {
    // Ground & ink.
    static let porcelain = Color(hex: "F4ECE6") // warm background
    static let recess     = Color(hex: "EBE0D8") // recessed panel
    static let ink        = Color(hex: "372E2A") // warm espresso, never black
    static let inkSoft    = Color(hex: "8B7C73") // secondary text
    static let inkFaint   = Color(hex: "A99C92") // tertiary text
    static let hair       = Color(hex: "D8C9BE") // warm hairline

    // The single accent (dusty rose) + its champagne glow.
    static let accent     = Color(hex: "B4808A")
    static let accentDeep = Color(hex: "93606B")
    static let glow       = Color(hex: "EBC9AE")

    // Dawn-field tints layered behind the content.
    static let dawnPeach  = Color(hex: "F8DFC9")
    static let dawnLilac  = Color(hex: "ECD6E4")
    static let dawnSky    = Color(hex: "DDE6E8")

    // Named text roles.
    static let textPrimary   = ink
    static let textSecondary = inkSoft
    static let textTertiary  = inkFaint

    // Surfaces.
    static let card = Color.white.opacity(0.5)
    static let hairline = hair

    /// Total conceptual screens (for the progress hairline).
    static let screenCount = 17

    /// Playfair Display at an arbitrary size (falls back to the system serif).
    static func serif(_ size: CGFloat, italic: Bool = false, weight: Font.Weight = .regular) -> Font {
        #if canImport(UIKit)
        if UIFont(name: "Playfair Display", size: 12) != nil {
            let face = Font.custom("Playfair Display", size: size).weight(weight)
            return italic ? face.italic() : face
        }
        #endif
        let base = Font.system(size: size, weight: weight, design: .serif)
        return italic ? base.italic() : base
    }
}

// ============================================================
// MARK: — Backdrop (dawn light + film grain)
// ============================================================

/// Full-bleed warm porcelain with three soft dawn-light pools and a fine film
/// grain — the editorial texture that makes it read as photographed, not
/// rendered. The light pools drift almost imperceptibly.
struct RampBackdrop: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var drift = false

    var body: some View {
        ZStack {
            RampStage.porcelain

            dawnPool(RampStage.dawnPeach, at: UnitPoint(x: 0.20, y: 0.06), radius: 440)
            dawnPool(RampStage.dawnLilac, at: UnitPoint(x: 0.90, y: 0.20), radius: 460)
            dawnPool(RampStage.dawnSky,   at: UnitPoint(x: 0.50, y: 1.02), radius: 560)

            RampGrain()
                .opacity(0.30)
                .blendMode(.multiply)
        }
        .ignoresSafeArea()
        .scaleEffect(drift && !reduceMotion ? 1.05 : 1.0)
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 24).repeatForever(autoreverses: true)) {
                drift = true
            }
        }
    }

    private func dawnPool(_ color: Color, at point: UnitPoint, radius: CGFloat) -> some View {
        RadialGradient(colors: [color.opacity(0.9), .clear],
                       center: point, startRadius: 0, endRadius: radius)
    }
}

/// Static, deterministic film grain — stamped once (no per-frame work).
struct RampGrain: View {
    var body: some View {
        Canvas { context, size in
            let count = Int(size.width * size.height / 260)
            for i in 0..<count {
                let x = hash(i, 12.9898) * size.width
                let y = hash(i, 78.233) * size.height
                let a = 0.03 + hash(i, 41.17) * 0.06
                context.fill(
                    Path(ellipseIn: CGRect(x: x, y: y, width: 1.1, height: 1.1)),
                    with: .color(RampStage.ink.opacity(a)))
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func hash(_ i: Int, _ salt: Double) -> CGFloat {
        let v = sin(Double(i + 1) * salt) * 43758.5453
        return CGFloat(v - floor(v))
    }
}

// ============================================================
// MARK: — The Teint-Orb (the soft, luminous hero)
// ============================================================

/// The reimagined "head": a soft, luminous complexion-orb. Pearlescent radial
/// light, a champagne halo, a gentle breath. Beautiful on the light ground
/// where the old additive neon wireframe never could be.
struct TeintOrb: View {
    var haloed: Bool = true

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var breathe = false

    var body: some View {
        ZStack {
            if haloed {
                Circle()
                    .fill(RadialGradient(colors: [RampStage.glow.opacity(0.55), .clear],
                                         center: .center, startRadius: 0, endRadius: 150))
                    .frame(width: 300, height: 300)
                    .blur(radius: 10)
            }
            Circle()
                .fill(RadialGradient(
                    colors: [Color(hex: "FDF3E9"), Color(hex: "F1D6BF"),
                             Color(hex: "E4B7A9"), Color(hex: "C98F92")],
                    center: UnitPoint(x: 0.38, y: 0.32), startRadius: 2, endRadius: 150))
                .overlay(
                    Circle().fill(RadialGradient(
                        colors: [.white.opacity(0.85), .clear],
                        center: UnitPoint(x: 0.34, y: 0.28), startRadius: 0, endRadius: 46))
                )
                .frame(width: 176, height: 176)
                .shadow(color: RampStage.accent.opacity(0.4), radius: 30, y: 16)
                .scaleEffect(breathe && !reduceMotion ? 1.035 : 1.0)
        }
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 7).repeatForever(autoreverses: true)) {
                breathe = true
            }
        }
        .accessibilityHidden(true)
    }
}

// ============================================================
// MARK: — Progress (one thin filling hairline)
// ============================================================

struct RampProgressLine: View {
    /// 0…1.
    let fraction: Double

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(RampStage.hair)
                Capsule()
                    .fill(RampStage.accent)
                    .frame(width: geo.size.width * max(0, min(1, fraction)))
            }
        }
        .frame(height: 2)
        .animation(VMotion.gentle, value: fraction)
        .accessibilityElement()
        .accessibilityLabel("onboarding.progress")
        .accessibilityValue(Text(verbatim: "\(Int((fraction * 100).rounded()))%"))
    }
}

// ============================================================
// MARK: — Typewriter (kept for the opening wordmark)
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
// MARK: — Buttons
// ============================================================

/// Primary CTA: a calm solid espresso pill with porcelain text. No gradient,
/// no glow — the quiet confidence of the whole aesthetic.
struct RampPrimaryButton: View {
    let title: String
    var systemImage: String? = nil
    var isEnabled: Bool = true
    let action: () -> Void

    var body: some View {
        Button {
            Haptics.fire(.selection)
            action()
        } label: {
            HStack(spacing: 8) {
                if let systemImage { Image(systemName: systemImage) }
                Text(title)
            }
            .font(VType.bodyMedium)
            .foregroundStyle(RampStage.porcelain)
            .frame(maxWidth: .infinity, minHeight: 54)
            .background(RampStage.ink, in: Capsule())
            .opacity(isEnabled ? 1 : 0.4)
        }
        .buttonStyle(PressableStyle())
        .disabled(!isEnabled)
    }
}

/// Text-only secondary action ("Not now").
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

// ============================================================
// MARK: — Answer tile (the heart of the redesign)
// ============================================================

/// A calm, editorial answer tile. A serif title (optionally a soft descriptor),
/// a quiet selection dot, a whisper of rose when chosen. No fill-slam, no 3D
/// tilt, no shockwave — selection is a gentle settling, not an explosion.
struct RampOptionCard: View {
    let label: String
    var sub: String? = nil
    var icon: String? = nil
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .regular))
                        .foregroundStyle(RampStage.accentDeep)
                        .frame(width: 34, height: 34)
                        .background(RampStage.accent.opacity(selected ? 0.20 : 0.12),
                                    in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(label)
                        .font(RampStage.serif(18))
                        .foregroundStyle(selected ? RampStage.accentDeep : RampStage.ink)
                    if let sub {
                        Text(sub)
                            .font(VType.caption)
                            .foregroundStyle(RampStage.textSecondary)
                    }
                }
                Spacer(minLength: 0)
                selectionDot
            }
            .padding(.horizontal, 18)
            .frame(maxWidth: .infinity, minHeight: 62, alignment: .leading)
            .background(
                selected
                    ? AnyShapeStyle(RampStage.accent.opacity(0.12))
                    : AnyShapeStyle(RampStage.card),
                in: RoundedRectangle(cornerRadius: 18, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(selected ? RampStage.accent : RampStage.hairline, lineWidth: 1)
            )
        }
        .buttonStyle(PressableStyle())
        .animation(VMotion.gentle, value: selected)
    }

    private var selectionDot: some View {
        ZStack {
            Circle()
                .strokeBorder(selected ? RampStage.accent : RampStage.hair, lineWidth: 1.5)
                .frame(width: 20, height: 20)
            if selected {
                Circle().fill(RampStage.accent).frame(width: 20, height: 20)
                Circle().fill(Color.white).frame(width: 7, height: 7)
            }
        }
    }
}

// ============================================================
// MARK: — Distribution curve ("where do you land?")
// ============================================================

/// A soft population bell-curve with scattered peers and a gentle "?" marker
/// that drifts and never settles — your place is unknown until the scan. No
/// fabricated testimonials; a pure abstract visualization, now in warm ink.
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
                func y(_ fx: CGFloat) -> CGFloat { h - bell(fx) * h * 0.78 - 10 }

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
                    Gradient(colors: [RampStage.accent.opacity(0.22), .clear]),
                    startPoint: CGPoint(x: 0, y: 0),
                    endPoint: CGPoint(x: 0, y: h)))
                context.stroke(curve, with: .color(RampStage.accent.opacity(0.8)), lineWidth: 1.5)

                for i in 0..<40 {
                    let n = Self.hash(i, 12.9898)
                    let n2 = Self.hash(i, 78.233)
                    let fx = min(max(0.5 + (n - 0.5) * 0.6, 0.05), 0.95)
                    let py = y(fx) + (1 - n2) * (h - y(fx) - 6) * 0.9
                    let r = 1.3 + Self.hash(i, 39.42) * 1.3
                    context.fill(
                        Path(ellipseIn: CGRect(x: fx * w - r, y: py - r, width: r * 2, height: r * 2)),
                        with: .color(RampStage.ink.opacity(0.14)))
                }

                let mx = CGFloat(0.5 + 0.34 * sin(t * 0.7))
                let my = y(mx)
                context.fill(
                    Path(ellipseIn: CGRect(x: mx * w - 15, y: my - 15, width: 30, height: 30)),
                    with: .color(RampStage.accent.opacity(0.2)))
                context.fill(
                    Path(ellipseIn: CGRect(x: mx * w - 5, y: my - 5, width: 10, height: 10)),
                    with: .color(RampStage.accent))
                context.draw(
                    Text(verbatim: "?").font(RampStage.serif(13, italic: true)).foregroundColor(RampStage.accentDeep),
                    at: CGPoint(x: mx * w, y: my - 22))
            }
        }
        .frame(height: 172)
        .accessibilityHidden(true)
    }

    private static func hash(_ i: Int, _ salt: Double) -> CGFloat {
        let v = sin(Double(i + 1) * salt) * 43758.5453
        return CGFloat(v - floor(v))
    }
}
