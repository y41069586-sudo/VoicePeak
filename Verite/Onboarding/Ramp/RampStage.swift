import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

// ============================================================
// MARK: — "Glow" — the warm, image-led onboarding stage
// ============================================================
//
// GlamUp-style: warm cream/blush ground, cocoa ink, one coral-peach accent,
// friendly rounded type, big soft cards — and PHOTOS carry the hero moments.
// Imagery loads from the asset catalog by name (see `RampPhoto`); until real
// photos are dropped in, an aesthetic warm-gradient placeholder stands in, so
// the flow always ships whole.

enum RampStage {
    // Ground & ink.
    static let porcelain = Color(hex: "FFF6F0") // warm cream-blush background
    static let recess     = Color(hex: "FBEAE1") // recessed panel
    static let ink        = Color(hex: "43322B") // warm cocoa, never black
    static let inkSoft    = Color(hex: "9A8378") // secondary text
    static let inkFaint   = Color(hex: "B8A79D") // tertiary text
    static let hair       = Color(hex: "EDDCD2") // warm hairline

    // The single accent (coral peach) + its warm glow.
    static let accent     = Color(hex: "E98A70")
    static let accentDeep = Color(hex: "D06B52")
    static let glow       = Color(hex: "F6C8AE")

    // Warm light pools layered behind the content (no cool tints — GlamUp
    // worlds are golden-hour warm throughout).
    static let dawnPeach  = Color(hex: "FFE3D2")
    static let dawnLilac  = Color(hex: "FFD9CF") // blush (name kept for call sites)
    static let dawnSky    = Color(hex: "FFF0DE") // vanilla (name kept for call sites)

    // Named text roles.
    static let textPrimary   = ink
    static let textSecondary = inkSoft
    static let textTertiary  = inkFaint

    // Surfaces.
    static let card = Color.white.opacity(0.85)
    static let hairline = hair

    /// Total conceptual screens (for the progress hairline).
    static let screenCount = 18

    /// Friendly rounded display face — the GlamUp voice. (Name kept from the
    /// serif era so every call site keeps working; the look is SF Rounded.)
    static func serif(_ size: CGFloat, italic: Bool = false, weight: Font.Weight = .bold) -> Font {
        Font.system(size: size, weight: weight, design: .rounded)
    }
}

// ============================================================
// MARK: — Photo slots (the images that carry the screens)
// ============================================================

/// A named photo from the asset catalog inside a soft rounded card. When the
/// image is missing (pre-art builds), a warm aesthetic gradient stands in — the
/// layout never breaks. The image can be added EITHER as an asset-catalog set
/// OR as a loose bundled file in `Verite/Resources/Photos/` (just drop
/// `GlowHero.jpg` etc. — no Contents.json needed). Both are picked up with no
/// code change. Expected names: "GlowHero", "GlowTexture", "GlowRitual".
struct RampPhoto: View {
    let name: String
    var cornerRadius: CGFloat = 28

    var body: some View {
        Group {
            #if canImport(UIKit)
            if let image = Self.load(name) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                placeholder
            }
            #else
            placeholder
            #endif
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .strokeBorder(Color.white.opacity(0.6), lineWidth: 1)
        )
        .shadow(color: RampStage.accent.opacity(0.22), radius: 24, y: 12)
        .accessibilityHidden(true)
    }

    #if canImport(UIKit)
    /// Maps the logical slot names used across the flow onto the ACTUAL
    /// filenames uploaded to `Resources/Photos/` (so call sites stay readable
    /// and the raw upload names never leak into the screens). Adjust the
    /// right-hand side to match whatever files were committed.
    private static let aliases: [String: String] = [
        "GlowHero":    "Image (53)",
        "GlowTexture": "Image (54)",
        "GlowRitual":  "Image (55)",
    ]

    /// Resolve an image from the asset catalog first, then a loose bundled file
    /// (by the slot name or its uploaded-filename alias, any common type) — so
    /// a GitHub-web upload into Resources/Photos works with no renaming and no
    /// asset-catalog editing. `.jfif` is just JPEG, decoded fine.
    static func load(_ name: String) -> UIImage? {
        if let asset = UIImage(named: name) { return asset }
        var candidates = [name]
        if let alias = aliases[name] { candidates.append(alias) }
        for base in candidates {
            for ext in ["jpg", "jpeg", "jfif", "png", "heic", "webp"] {
                if let url = Bundle.main.url(forResource: base, withExtension: ext),
                   let image = UIImage(contentsOfFile: url.path) {
                    return image
                }
            }
        }
        return nil
    }
    #endif

    /// Golden-hour gradient placeholder — deliberately pretty on its own.
    private var placeholder: some View {
        ZStack {
            LinearGradient(colors: [Color(hex: "FFE0C9"), Color(hex: "F8B99B"),
                                    Color(hex: "EE9377")],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
            RadialGradient(colors: [.white.opacity(0.55), .clear],
                           center: UnitPoint(x: 0.25, y: 0.2),
                           startRadius: 0, endRadius: 220)
            RadialGradient(colors: [Color(hex: "FFD9CF").opacity(0.8), .clear],
                           center: UnitPoint(x: 0.85, y: 0.85),
                           startRadius: 0, endRadius: 260)
        }
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
                .opacity(0.14)
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

/// Primary CTA: the GlamUp coral pill — warm, friendly, impossible to miss,
/// with a soft matching shadow instead of a hard glow.
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
            .font(.system(size: 17, weight: .semibold, design: .rounded))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, minHeight: 56)
            .background(
                LinearGradient(colors: [RampStage.accent, RampStage.accentDeep],
                               startPoint: .top, endPoint: .bottom),
                in: Capsule()
            )
            .shadow(color: RampStage.accent.opacity(isEnabled ? 0.45 : 0), radius: 16, y: 8)
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
                        .font(VType.bodyLarge.weight(.medium))
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
                    Text(verbatim: "?").font(RampStage.serif(13)).foregroundColor(RampStage.accentDeep),
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
