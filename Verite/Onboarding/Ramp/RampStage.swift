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
    // Ground & ink — a NEUTRAL ground (near-white, not tinted) with warm-black
    // ink. This replaced an all-over warm-beige wash. The reason: no matter
    // how modern the components are, a screen where the ENTIRE surface —
    // background, cards, fills — sits in one warm gold/cream hue reads as a
    // sepia photograph before the eye even parses the layout. Warmth is real
    // and belongs in the brand, but it has to live in the ACCENT and in
    // photography, not in the canvas everything else sits on.
    static let porcelain = Color.white // flat white background (name kept for call sites)
    static let recess     = Color(hex: "F3E9DE") // recessed panel — warm, not tinted gold
    static let ink        = Color(hex: "1E1610") // near-black, maximum contrast
    static let inkSoft    = Color(hex: "6D5F52") // secondary text — warm taupe, matches the peach ink
    static let inkFaint   = Color(hex: "BDA894") // tertiary text
    static let hair       = Color(hex: "F3E5D6") // warm hairline (barely-there, peach-tinted)

    // The accent is pulled straight from the app icon — the light peach of
    // the bandage and skin, deepening into the coral of the acne blemish —
    // instead of a generic beige/sand that read as "the same colour on every
    // screen" and didn't tie back to the mark. Kept ONLY for small,
    // deliberate uses: selection rings, progress fill, chip backgrounds, the
    // odd icon. It is never a canvas colour. `accentEdge` is the icon's skin
    // tone; `accentDeep` is the icon's blemish coral, for on-light TEXT.
    static let accent     = Color(hex: "F5DCC0")
    static let accentEdge = Color(hex: "E0995F")
    static let accentDeep = Color(hex: "C15A3E")
    static let glow       = Color(hex: "F5DCC0")

    /// A warm peach glow. Named for the three-pool "dawn light" backdrop it
    /// was built for; that backdrop is gone (see `RampBackdrop`) and this is
    /// what outlived it — the photo-placeholder wash and the sign-in screen's
    /// halo. `dawnLilac` and `dawnSky` went with the pools.
    static let dawnPeach  = Color(hex: "F8DFC9")

    /// Soft accent tint for icon chips, segmented backgrounds, soft buttons.
    static let accentSoft = Color(hex: "F5DCC0")

    // Named text roles.
    static let textPrimary   = ink
    static let textSecondary = inkSoft
    static let textTertiary  = inkFaint

    // Surfaces — crisp solid white cards, separated from the ground by
    // elevation (shadow) rather than by an outline. See `RampCardShadow`.
    static let card = Color.white
    static let hairline = hair

    /// Total conceptual screens (for the progress hairline). Derived from the
    /// step enum so removing/adding a step keeps the progress bar exact.
    static var screenCount: Int { RampStep.allCases.count }

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
/// code change.
///
/// Slots in use:
///   GlowHero, GlowTexture, GlowRitual   — quiz + insight screens
///   IntroScore, IntroScan,              — the four opening carousel pages
///   IntroRoutine, IntroProgress           (see RampBootScreen)
///
/// The Intro slots want composed product mockups — a screenshot of the real
/// dashboard, scan, routine and progress view, framed however you like. They
/// are drawn without a card or shadow, so whatever framing the file carries is
/// what shows. Until each file lands, that page falls back to its line-art.
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
        .shadow(color: RampStage.ink.opacity(0.14), radius: 24, y: 12)
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

    /// Soft neutral-peach gradient placeholder — a quiet stand-in, not a
    /// colourful moment in its own right (the photo it precedes should be).
    private var placeholder: some View {
        ZStack {
            LinearGradient(colors: [Color(hex: "F8F1E9"), Color(hex: "F3DCC4"),
                                    Color(hex: "E0995F")],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
            RadialGradient(colors: [.white.opacity(0.55), .clear],
                           center: UnitPoint(x: 0.25, y: 0.2),
                           startRadius: 0, endRadius: 220)
            RadialGradient(colors: [Color(hex: "F5DCC0").opacity(0.8), .clear],
                           center: UnitPoint(x: 0.85, y: 0.85),
                           startRadius: 0, endRadius: 260)
        }
    }
}

// ============================================================
// MARK: — Backdrop
// ============================================================

/// Flat white, full bleed, with a whisper of film grain over it.
///
/// This replaced three drifting "dawn light" pools — peach, lilac and sky
/// radial gradients over warm porcelain, breathing on a 24-second loop. The
/// problem was not that they were ugly: it was that onboarding is a stack of
/// WHITE CARDS, and a tinted, unevenly-lit ground gave every one of them a
/// different amount of contrast depending on where it happened to sit. The
/// peach pool at the top meant the first tile on a screen always had more
/// separation than the last. White is the same everywhere, so the cards are
/// the only thing that varies.
///
/// The grain stays, at a fraction of its old strength. It is luminance noise
/// rather than a tint — the ground still reads as white — and it is what
/// keeps the surface from looking like an untextured fill. Take it to zero
/// if even that is too much; nothing else depends on it.
///
/// Removing the pools also ends a `repeatForever` animation that ran for the
/// entire length of onboarding to move something almost nobody could see.
struct RampBackdrop: View {
    var body: some View {
        ZStack {
            Color.white

            RampGrain()
                .opacity(0.05)
                .blendMode(.multiply)
        }
        .ignoresSafeArea()
    }
}

// ============================================================
// MARK: — Screen-to-screen motion (a drift, not a shove)
// ============================================================

/// Timing for the between-screens transition. A spring, however heavily
/// damped, still resolves a POSITION by simulating a force — it starts at
/// full velocity and decelerates by fighting itself to a stop, which is
/// exactly the "pushed" feeling this replaced. A long, front-loaded ease-out
/// has no such force in it: the screen is already moving as fast as it will
/// ever move on the very first frame and spends the rest of the curve
/// settling, the way something let go drifts rather than something thrown.
///
/// That is also why the duration is longer than the spring it replaced
/// (0.56s vs. ~0.48s) — a drift this gentle needs the extra beat to read as
/// deliberate rather than as slow.
enum RampMotion {
    static let drift = Animation.timingCurve(0.16, 1, 0.3, 1, duration: 0.56)
}

/// The advance/back transition: a screen drifting sideways off its own
/// weight, not being slid on rails. Three things do the work together —
///
///  · ROTATION, a couple of degrees, so the motion has a single consistent
///    axis of "lean" instead of gliding perfectly flat. A leaf caught by
///    wind tilts as it moves; a card pushed on rails does not.
///  · A slight DOWNWARD settle on exit and rise on entry, so the path isn't
///    a dead-straight horizontal line — real drift is never perfectly axial.
///  · SCALE, just enough (3.5%) to read as depth rather than as shrinking.
///
/// Insertion and removal lean opposite ways so the two screens never rotate
/// in parallel — that would read as one card sliding behind another rather
/// than as two independent, opposite drifts.
private struct RampLeafDrift: ViewModifier {
    var offsetX: CGFloat
    var offsetY: CGFloat
    var rotation: Double
    var scale: CGFloat
    var opacity: Double

    func body(content: Content) -> some View {
        content
            .scaleEffect(scale)
            .rotationEffect(.degrees(rotation))
            .offset(x: offsetX, y: offsetY)
            .opacity(opacity)
    }
}

extension AnyTransition {
    /// The new screen — drifts in from the right, tilted a touch clockwise,
    /// settling flat as it arrives.
    static var rampLeafIn: AnyTransition {
        .modifier(
            active: RampLeafDrift(offsetX: 64, offsetY: -10, rotation: 2.6, scale: 0.965, opacity: 0),
            identity: RampLeafDrift(offsetX: 0, offsetY: 0, rotation: 0, scale: 1, opacity: 1)
        )
    }

    /// The old screen — drifts out to the left, tilted the other way, sinking
    /// a little as it goes.
    static var rampLeafOut: AnyTransition {
        .modifier(
            active: RampLeafDrift(offsetX: -64, offsetY: 12, rotation: -2.6, scale: 0.965, opacity: 0),
            identity: RampLeafDrift(offsetX: 0, offsetY: 0, rotation: 0, scale: 1, opacity: 1)
        )
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
                // Edge, not accent: this hairline is 2pt tall, too thin to
                // carry an outline, so it takes the darker tone outright.
                Capsule()
                    .fill(RampStage.accentEdge)
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

/// A soft, neutral drop shadow used in place of a hairline border. This is
/// the one change that made the whole flow stop reading as a stack of
/// outlined form fields: separation now comes from light and elevation, not
/// from a stroke around every rectangle.
///
/// Nudged up when `RampBackdrop` went white. The cards are white too, so the
/// ground used to be doing part of the work — porcelain against white is a
/// small difference, but it was a real one, and on a white ground it is
/// gone. The shadow is now the ONLY thing holding a tile off the page, so it
/// carries a little more weight. Still nowhere near a visible drop shadow:
/// the target is a tile that has an edge, not one that hovers.
struct RampCardShadow: ViewModifier {
    func body(content: Content) -> some View {
        content.shadow(color: RampStage.ink.opacity(0.045), radius: 2, y: 1)
            .shadow(color: RampStage.ink.opacity(0.08), radius: 18, y: 8)
    }
}

extension View {
    func rampCardShadow() -> some View { modifier(RampCardShadow()) }
}

/// Primary CTA: full-width, bold, on the brand's own skin→blemish gradient —
/// the exact fill `DQPrimaryButton` uses in the app proper, so the button the
/// user taps twenty times during onboarding is the same button that greets
/// them afterwards.
///
/// This replaced a solid near-black fill. On a warm peach ground, a black
/// slab is the one shape on screen that belongs to no palette; repeated on
/// 26 screens it made the whole flow read as monochrome-with-an-accent
/// rather than as one warm thing. The coral end of the gradient is dark
/// enough to carry white text, so nothing is lost on contrast.
struct RampPrimaryButton: View {
    let title: String
    var systemImage: String? = nil
    var isEnabled: Bool = true
    let action: () -> Void

    /// Skin → blemish, matching `DQColor.accentGradient` exactly.
    static let fill = LinearGradient(colors: [RampStage.accentEdge, RampStage.accentDeep],
                                     startPoint: .topLeading, endPoint: .bottomTrailing)

    var body: some View {
        Button {
            Haptics.fire(.selection)
            action()
        } label: {
            HStack(spacing: 8) {
                if let systemImage { Image(systemName: systemImage) }
                Text(LocalizedStringKey(title))
            }
            .font(.system(size: 17, weight: .bold, design: .rounded))
            .foregroundStyle(Color.white)
            .frame(maxWidth: .infinity, minHeight: 58)
            .background(Self.fill,
                        in: RoundedRectangle(cornerRadius: 26, style: .continuous))
            // Tightened from 0.34/r20 — a coloured shadow that wide reads as
            // a glow around the button rather than as the button sitting on
            // the page, and on a white ground it haloed visibly into the
            // margins. Same colour, less of it, dropped closer.
            .shadow(color: RampStage.accentDeep.opacity(isEnabled ? 0.22 : 0), radius: 14, y: 7)
            .opacity(isEnabled ? 1 : 0.35)
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
            Text(LocalizedStringKey(title))
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

/// A calm, editorial answer tile. White always, separated by shadow rather
/// than a border; selection is a sand-coloured ring plus a filled checkmark,
/// not a tinted fill — the tint-on-select pattern is what made the earlier
/// version look washed rather than chosen.
///
/// There is no descriptor slot. It existed for one screen — the self-rating
/// question, where every tile carried a gloss ("Rough patch · Tight, uneven,
/// needs care") — and it set the label and the gloss side by side, so the
/// longest ones wrapped to two lines and the row of tiles stopped scanning
/// as a row. The labels answer the question on their own; anything that
/// genuinely needs explaining belongs in the question's `subtitle`, once,
/// rather than repeated on every option.
struct RampOptionCard: View {
    let label: String
    var icon: String? = nil
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 19, weight: .regular))
                        .foregroundStyle(selected ? RampStage.accentDeep : RampStage.inkFaint)
                        .frame(width: 22, height: 22)
                }
                Text(LocalizedStringKey(label))
                    .font(VType.bodyLarge.weight(.semibold))
                    .foregroundStyle(RampStage.ink)
                Spacer(minLength: 0)
                selectionMark
            }
            .padding(.horizontal, 18)
            .frame(maxWidth: .infinity, minHeight: 62, alignment: .leading)
            .background(RampStage.card, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .rampCardShadow()
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(selected ? RampStage.accentEdge : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(PressableStyle())
        .animation(VMotion.gentle, value: selected)
        .accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
    }

    private var selectionMark: some View {
        Group {
            if selected {
                ZStack {
                    Circle().fill(RampStage.accentEdge).frame(width: 22, height: 22)
                    Image(systemName: "checkmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Color.white)
                }
            }
        }
    }
}

// ============================================================
// MARK: — Distribution curve ("where do you land?")
// ============================================================

/// A soft population bell-curve that DRAWS ITSELF on appear (left → right,
/// ~1.6 s), then lights up the user's estimated range as a soft band with a
/// gentle "?" marker drifting inside it, never settling — your exact place is
/// unknown until the scan. No fabricated testimonials; a pure abstract
/// visualization in warm ink.
struct RampDistributionCurve: View {
    /// The quiz-predicted score band (0–100). Nil = generic center band.
    var range: (low: Int, high: Int)? = nil
    /// Seconds to wait after appearing before the draw starts, so the line
    /// grows AFTER the screen's own entrance instead of finishing invisibly.
    var startDelay: Double = 0

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    // Draw driven by an animatable Shape (reliable, unlike Canvas+TimelineView
    // which rendered the whole curve at once on device).
    @State private var drawProgress: CGFloat = 0
    @State private var bandOpacity: CGFloat = 0

    static let drawDuration: Double = 1.6
    static let bandDelay: Double = 0.25

    var body: some View {
        ZStack {
            RampBellShape(progress: drawProgress, filled: true)
                .fill(LinearGradient(colors: [RampStage.accent.opacity(0.22), .clear],
                                     startPoint: .top, endPoint: .bottom))
            RampBellShape(progress: drawProgress, filled: false)
                .stroke(RampStage.accentEdge.opacity(0.85),
                        style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
            peerDots.opacity(Double(drawProgress))
            bandOverlay.opacity(Double(bandOpacity))
        }
        .frame(height: 172)
        .accessibilityHidden(true)
        .onAppear { animate() }
    }

    private func animate() {
        if reduceMotion { drawProgress = 1; bandOpacity = 1; return }
        withAnimation(.easeInOut(duration: Self.drawDuration).delay(startDelay)) {
            drawProgress = 1
        }
        withAnimation(.easeOut(duration: 0.5)
            .delay(startDelay + Self.drawDuration + Self.bandDelay)) {
            bandOpacity = 1
        }
    }

    /// Faint peer dots scattered under the curve — fade in as the line draws.
    private var peerDots: some View {
        Canvas { context, size in
            let w = size.width, h = size.height
            func bell(_ x: CGFloat) -> CGFloat { let u = (x - 0.5) / 0.16; return exp(-0.5 * u * u) }
            func y(_ fx: CGFloat) -> CGFloat { h - bell(fx) * h * 0.78 - 10 }
            for i in 0..<40 {
                let n = Self.hash(i, 12.9898), n2 = Self.hash(i, 78.233)
                let fx = min(max(0.5 + (n - 0.5) * 0.6, 0.05), 0.95)
                let py = y(fx) + (1 - n2) * (h - y(fx) - 6) * 0.9
                let r = 1.3 + Self.hash(i, 39.42) * 1.3
                context.fill(Path(ellipseIn: CGRect(x: fx * w - r, y: py - r, width: r * 2, height: r * 2)),
                             with: .color(RampStage.ink.opacity(0.14)))
            }
        }
    }

    /// The user's estimated band + a "?" marker — fades in after the draw.
    private var bandOverlay: some View {
        Canvas { context, size in
            let w = size.width, h = size.height
            func bell(_ x: CGFloat) -> CGFloat { let u = (x - 0.5) / 0.16; return exp(-0.5 * u * u) }
            func y(_ fx: CGFloat) -> CGFloat { h - bell(fx) * h * 0.78 - 10 }
            let x1 = CGFloat(range?.low ?? 33) / 100
            let x2 = CGFloat(range?.high ?? 67) / 100

            var band = Path()
            let bandSteps = 24
            band.move(to: CGPoint(x: x1 * w, y: h))
            for i in 0...bandSteps {
                let fx = x1 + (x2 - x1) * CGFloat(i) / CGFloat(bandSteps)
                band.addLine(to: CGPoint(x: fx * w, y: y(fx)))
            }
            band.addLine(to: CGPoint(x: x2 * w, y: h))
            band.closeSubpath()
            context.fill(band, with: .color(RampStage.accent.opacity(0.24)))
            for edge in [x1, x2] {
                var line = Path()
                line.move(to: CGPoint(x: edge * w, y: y(edge)))
                line.addLine(to: CGPoint(x: edge * w, y: h))
                context.stroke(line, with: .color(RampStage.accentEdge.opacity(0.5)),
                               style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
            }
            let mid = (x1 + x2) / 2, my = y(mid)
            context.fill(Path(ellipseIn: CGRect(x: mid * w - 15, y: my - 15, width: 30, height: 30)),
                         with: .color(RampStage.accent.opacity(0.2)))
            context.fill(Path(ellipseIn: CGRect(x: mid * w - 5, y: my - 5, width: 10, height: 10)),
                         with: .color(RampStage.accentEdge))
            context.draw(Text(verbatim: "?").font(RampStage.serif(13))
                            .foregroundColor(RampStage.accentDeep),
                         at: CGPoint(x: mid * w, y: my - 22))
        }
    }

    private static func hash(_ i: Int, _ salt: Double) -> CGFloat {
        let v = sin(Double(i + 1) * salt) * 43758.5453
        return CGFloat(v - floor(v))
    }
}

/// The bell curve as an animatable Shape, revealed left → right by `progress`.
private struct RampBellShape: Shape {
    var progress: CGFloat
    var filled: Bool

    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }

    func path(in rect: CGRect) -> Path {
        let w = rect.width, h = rect.height
        func bell(_ x: CGFloat) -> CGFloat { let u = (x - 0.5) / 0.16; return exp(-0.5 * u * u) }
        func y(_ fx: CGFloat) -> CGFloat { rect.minY + h - bell(fx) * h * 0.78 - 10 }

        let steps = 72
        let visible = max(1, Int(CGFloat(steps) * min(max(progress, 0), 1)))
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: y(0)))
        for i in 1...visible {
            let fx = CGFloat(i) / CGFloat(steps)
            p.addLine(to: CGPoint(x: rect.minX + fx * w, y: y(fx)))
        }
        if filled {
            let edgeX = rect.minX + CGFloat(visible) / CGFloat(steps) * w
            p.addLine(to: CGPoint(x: edgeX, y: rect.maxY))
            p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
            p.closeSubpath()
        }
        return p
    }
}
