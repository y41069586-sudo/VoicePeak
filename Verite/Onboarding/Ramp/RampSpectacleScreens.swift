import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

// ============================================================
// MARK: — Screen 0: Opening
// ============================================================

/// The opening carousel. Four product-led pages: a real screenshot of what the
/// app produces, an acne-first headline, one line of substance. Horizontal
/// paging with dots, and — the part that matters for conversion — the SAME
/// primary CTA on every page, so nobody has to swipe four times to begin.
///
/// Two deliberate choices here:
///
/// 1. The art slot takes a real screenshot (`IntroScore`, `IntroScan`,
///    `IntroRoutine`, `IntroProgress` — drop any of them into
///    `Resources/Photos/`). Until a file exists the original line-art stands
///    in, so the flow never looks broken while the assets are being made.
///    Screenshots of the actual product outsell illustrations of it: the page
///    stops describing the app and starts showing what you get.
///
/// 2. "Already have an account?" sits on page one. Sign-in used to be step 18
///    of 21, and `onboardingComplete` lives only in the local store — so a
///    subscriber who reinstalled had to walk the entire funnel before they
///    could reach the button that restores what they already paid for.
struct RampBootScreen: View {
    let onAdvance: () -> Void
    /// Jump straight to sign-in. Returning users are not prospects; making
    /// them re-run the pitch is how you lose the ones you already won.
    var onSignIn: () -> Void = {}

    @State private var page = 0

    private struct IntroPage: Identifiable {
        let id: Int
        let photo: String
        let title: String
        let sub: String
    }

    /// Acne first, in the app's own voice. No percentage claims and no
    /// "clear in N days" promise — the product measures and plans, it does
    /// not guarantee an outcome, and the copy stays inside what it can do.
    private let pages: [IntroPage] = [
        IntroPage(id: 0, photo: "IntroScore",
                  title: "The honest way\nto clear your skin.",
                  sub: "One scan, one real score from 0 to 100 — no filter, no sugarcoating."),
        IntroPage(id: 1, photo: "IntroScan",
                  title: "See what's driving\nyour breakouts.",
                  sub: "Seven metrics read from a single photo of your face — blemishes first."),
        IntroPage(id: 2, photo: "IntroRoutine",
                  title: "A routine built\naround your skin.",
                  sub: "Morning and evening, matched to your concerns and the ingredients you react to."),
        IntroPage(id: 3, photo: "IntroProgress",
                  title: "Watch it change\nover 14 days.",
                  sub: "Every scan updates the plan and shows you what actually moved."),
    ]

    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $page) {
                ForEach(pages) { item in
                    introPage(item).tag(item.id)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .frame(maxHeight: .infinity)

            dots
                .padding(.top, VSpace.sm)

            RampPrimaryButton(title: "Get started") { onAdvance() }
                .padding(.horizontal, VSpace.lg)
                .padding(.top, VSpace.md)

            Button {
                Haptics.fire(.selection)
                onSignIn()
            } label: {
                Text("Already have an account?")
                    .font(VType.body)
                    .foregroundStyle(RampStage.textSecondary)
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
            }
            .padding(.top, VSpace.xs)
        }
        .padding(.bottom, VSpace.lg)
        .animation(VMotion.snappy, value: page)
    }

    private var dots: some View {
        HStack(spacing: 6) {
            ForEach(pages) { item in
                Capsule()
                    .fill(item.id == page ? RampStage.accentEdge : RampStage.hair)
                    .frame(width: item.id == page ? 18 : 6, height: 6)
            }
        }
        .accessibilityHidden(true)
    }

    private func introPage(_ item: IntroPage) -> some View {
        VStack(spacing: 0) {
            Spacer(minLength: VSpace.md)

            RampIntroArt(photo: item.photo, index: item.id)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, VSpace.lg)

            Spacer(minLength: VSpace.lg)

            VStack(spacing: VSpace.sm) {
                Text(LocalizedStringKey(item.title))
                    .font(RampStage.serif(30))
                    .foregroundStyle(RampStage.ink)
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
                Text(LocalizedStringKey(item.sub))
                    .font(VType.bodyLarge)
                    .foregroundStyle(RampStage.textSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, VSpace.lg)
            }
            .padding(.horizontal, VSpace.md)

            Spacer(minLength: VSpace.md)
        }
        .frame(maxWidth: .infinity)
    }
}

/// The intro's visual slot: a supplied screenshot if one has been dropped in,
/// otherwise the original line-art for that page. Composed mockups carry their
/// own framing, so nothing is added around the image — no card, no shadow.
private struct RampIntroArt: View {
    let photo: String
    let index: Int

    var body: some View {
        Group {
            #if canImport(UIKit)
            if let image = RampPhoto.load(photo) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
            } else {
                lineArt
            }
            #else
            lineArt
            #endif
        }
        .frame(maxHeight: 340)
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private var lineArt: some View {
        ZStack {
            Circle()
                .fill(RampStage.dawnLilac.opacity(0.75))
                .frame(width: 270, height: 270)
            switch index {
            case 0:  RampMirrorArt()
            case 1:  RampScanFaceArt()
            default: RampPlanArt()
            }
        }
        .frame(height: 300)
    }
}


// MARK: Intro line-art (pure SwiftUI, coral/blush)

/// Page 1 — the hand mirror with sparkles.
private struct RampMirrorArt: View {
    var body: some View {
        ZStack {
            // Handle.
            VStack(spacing: 0) {
                Spacer().frame(height: 150)
                Capsule()
                    .fill(RampStage.dawnPeach)
                    .overlay(Capsule().strokeBorder(RampStage.accentEdge, lineWidth: 4))
                    .frame(width: 34, height: 86)
            }
            // Frame + glass with a soft diagonal shine.
            Ellipse()
                .fill(Color.white)
                .overlay(Ellipse().strokeBorder(RampStage.accentEdge, lineWidth: 5))
                .frame(width: 140, height: 168)
                .offset(y: -32)
            Ellipse()
                .fill(RampStage.dawnPeach)
                .frame(width: 108, height: 136)
                .overlay(
                    Rectangle()
                        .fill(Color.white.opacity(0.75))
                        .frame(width: 34, height: 200)
                        .rotationEffect(.degrees(38))
                        .offset(x: -16)
                        .clipShape(Ellipse())
                )
                .clipShape(Ellipse())
                .offset(y: -32)

            Image(systemName: "sparkle")
                .font(.system(size: 26, weight: .bold))
                .foregroundStyle(RampStage.accentEdge)
                .offset(x: -98, y: -92)
            Image(systemName: "sparkle")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(RampStage.accentEdge)
                .offset(x: 96, y: -30)
            Image(systemName: "sparkle")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(RampStage.accentEdge)
                .offset(x: -86, y: 56)
        }
        .accessibilityHidden(true)
    }
}

/// Page 2 — the face inside a scan frame, check landed.
private struct RampScanFaceArt: View {
    var body: some View {
        ZStack {
            RampIntroBrackets()
                .stroke(RampStage.accentEdge, style: StrokeStyle(lineWidth: 7, lineCap: .round))
                .frame(width: 190, height: 190)

            // A friendly abstract face.
            ZStack {
                Circle()
                    .fill(Color.white)
                    .overlay(Circle().strokeBorder(RampStage.accentEdge, lineWidth: 4))
                    .frame(width: 96, height: 96)
                HStack(spacing: 26) {
                    Circle().fill(RampStage.accentDeep).frame(width: 7, height: 7)
                    Circle().fill(RampStage.accentDeep).frame(width: 7, height: 7)
                }
                .offset(y: -8)
                HStack(spacing: 52) {
                    Circle().fill(RampStage.dawnPeach).frame(width: 12, height: 12)
                    Circle().fill(RampStage.dawnPeach).frame(width: 12, height: 12)
                }
                .offset(y: 6)
                RampIntroSmile()
                    .stroke(RampStage.accentDeep, style: StrokeStyle(lineWidth: 3.5, lineCap: .round))
                    .frame(width: 30, height: 14)
                    .offset(y: 18)
            }

            // Check badge, bottom-right of the frame.
            ZStack {
                Circle()
                    .fill(Color.white)
                    .overlay(Circle().strokeBorder(RampStage.accentEdge, lineWidth: 4))
                Image(systemName: "checkmark")
                    .font(.system(size: 26, weight: .bold))
                    .foregroundStyle(RampStage.accentEdge)
            }
            .frame(width: 62, height: 62)
            .offset(x: 78, y: 66)
        }
        .accessibilityHidden(true)
    }
}

/// Page 3 — the 14-day plan calendar.
private struct RampPlanArt: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color.white)
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .strokeBorder(RampStage.accentEdge, lineWidth: 5)
                )
                .frame(width: 170, height: 160)
            UnevenRoundedRectangle(topLeadingRadius: 18, topTrailingRadius: 18)
                .fill(RampStage.accent)
                .frame(width: 170, height: 40)
                .offset(y: -60)
            Text("14 DAYS")
                .font(.system(size: 15, weight: .heavy, design: .rounded))
                // Ink: white on the beige tab is 1.7:1.
                .foregroundStyle(RampStage.ink)
                .tracking(1)
                .offset(y: -60)

            // Day dots: first row done, second underway.
            VStack(spacing: 14) {
                ForEach(0..<2, id: \.self) { row in
                    HStack(spacing: 14) {
                        ForEach(0..<5, id: \.self) { column in
                            let done = row == 0 || column < 2
                            Circle()
                                .fill(done ? RampStage.accentEdge : RampStage.dawnPeach)
                                .frame(width: 16, height: 16)
                        }
                    }
                }
            }
            .offset(y: 8)

            Image(systemName: "sparkle")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(RampStage.accentEdge)
                .offset(x: 96, y: -84)
        }
        .accessibilityHidden(true)
    }
}

/// Four rounded viewfinder corners as one shape.
private struct RampIntroBrackets: Shape {
    func path(in rect: CGRect) -> Path {
        let l = rect.width * 0.22
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.minY + l))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.minX + l, y: rect.minY))
        p.move(to: CGPoint(x: rect.maxX - l, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + l))
        p.move(to: CGPoint(x: rect.maxX, y: rect.maxY - l))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.maxX - l, y: rect.maxY))
        p.move(to: CGPoint(x: rect.minX + l, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY - l))
        return p
    }
}

/// A gentle smile arc.
private struct RampIntroSmile: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.minY))
        p.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.minY),
                       control: CGPoint(x: rect.midX, y: rect.maxY + rect.height))
        return p
    }
}

// ============================================================
// MARK: — Screen 1: A Reading (the real results chart, previewed)
// ============================================================

/// The strongest opener: the exact chart the app produces after a scan — a
/// circular photo above a two-column metric grid, the numbers counting up from
/// zero and resolving from a blur, just like the real reveal. Illustrative
/// data + a stock example face; the user's own is built from their scan.
struct RampSampleReadingScreen: View {
    let onAdvance: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var reveal: Double = 0        // 0 → 1 count-up driver

    // Illustrative reading — Overall leads, then five sub-scores. Kept in a
    // realistic 60–70 band: a first honest scan rarely reads higher, and an
    // over-bright sample sets a promise the real reveal can't match. Overall
    // ≈ the average of the five sub-scores.
    private let cells: [(String, Int, Bool)] = [
        ("Overall", 66, true),
        ("Glow", 69, false),
        ("Hydration", 63, false),
        ("Texture", 65, false),
        ("Redness", 61, false),
        ("Evenness", 68, false),
    ]

    private let columns = [GridItem(.flexible(), spacing: 20),
                           GridItem(.flexible(), spacing: 20)]

    var body: some View {
        VStack(spacing: 0) {
            Spacer().frame(height: VSpace.xxl * 1.1)

            Text("Your skin,\nfully read.")
                .font(RampStage.serif(26))
                .foregroundStyle(RampStage.ink)
                .multilineTextAlignment(.center)
                .lineSpacing(2)

            Text("The exact chart your first scan builds — photo and all.")
                .font(VType.caption)
                .foregroundStyle(RampStage.textSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, VSpace.xl)
                .padding(.top, VSpace.sm)

            Spacer()

            chartCard
                .padding(.horizontal, VSpace.xl)

            Spacer()

            Text("Illustrative reading. Yours is built from your scan.")
                .font(VType.micro)
                .foregroundStyle(RampStage.textTertiary)

            RampPrimaryButton(title: "I want mine") { onAdvance() }
                .padding(.horizontal, VSpace.lg)
                .padding(.top, VSpace.md)
            Spacer().frame(height: VSpace.xxl)
        }
        .task {
            if reduceMotion { reveal = 1; return }
            try? await Task.sleep(for: .milliseconds(420))
            // The SAME stepped count-up the real results run: discrete ticks
            // through withAnimation so the monospaced digits genuinely roll,
            // decelerating as they land — not one long linear morph.
            let steps = 26
            for i in 1...steps {
                let t = Double(i) / Double(steps)
                withAnimation(.linear(duration: 0.05)) {
                    reveal = 1 - pow(1 - t, 2.4)
                }
                if i % 2 == 0 { Haptics.fire(.tick) }
                try? await Task.sleep(for: .seconds(0.026 + 0.055 * t))
                if Task.isCancelled { return }
            }
            withAnimation(.easeOut(duration: 0.12)) { reveal = 1 }
        }
    }

    /// The card: circular photo straddling the top of a metric grid — the
    /// real results layout.
    private var chartCard: some View {
        ZStack(alignment: .top) {
            LazyVGrid(columns: columns, alignment: .leading, spacing: 18) {
                ForEach(cells.indices, id: \.self) { i in
                    metricCell(cells[i].0, cells[i].1, lead: cells[i].2)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 74)
            .padding(.bottom, 22)
            .frame(maxWidth: .infinity)
            .background(Color.white, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 26, style: .continuous)
                .strokeBorder(RampStage.hairline, lineWidth: 1))
            .shadow(color: RampStage.ink.opacity(0.16), radius: 26, y: 14)

            avatar
                .offset(y: -56)
        }
        .padding(.top, 56)
    }

    private func metricCell(_ label: String, _ value: Int, lead: Bool) -> some View {
        let shown = Int((Double(value) * reveal).rounded())
        return VStack(alignment: .leading, spacing: 6) {
            Text(LocalizedStringKey(label))
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(RampStage.textSecondary)
                .lineLimit(1)
            // The iOS-teaser look that RESOLVES: numbers start blurred and
            // sharpen as they count up (blur → 0 as reveal → 1), just like the
            // real reveal — not a permanent smudge covering the whole card.
            Text(verbatim: "\(shown)")
                .font(.system(size: 26, weight: .heavy, design: .rounded).monospacedDigit())
                .foregroundStyle(lead ? RampStage.accentDeep : RampStage.ink)
                .contentTransition(.numericText(value: Double(shown)))
                .blur(radius: 9 * (1 - reveal))
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(RampStage.hair.opacity(0.7))
                    Capsule()
                        .fill(lead ? RampStage.accentDeep : RampStage.accent)
                        // Only the pale fill needs bounding; accentDeep carries
                        // its own separation from the track.
                        .overlay(Capsule().strokeBorder(lead ? .clear : RampStage.accentEdge,
                                                        lineWidth: 1))
                        .frame(width: proxy.size.width * CGFloat(shown) / 100)
                }
            }
            .frame(height: 6)
            .blur(radius: 4 * (1 - reveal))
            .opacity(0.7 + 0.3 * reveal)
        }
    }

    /// The example face, in a ringed circle — exactly like the captured avatar
    /// on the real results screen.
    private var avatar: some View {
        Group {
            #if canImport(UIKit)
            if let ui = RampPhoto.load("SampleFace") {
                Image(uiImage: ui).resizable().scaledToFill()
            } else {
                Circle().fill(RampStage.accentSoft)
            }
            #else
            Circle().fill(RampStage.accentSoft)
            #endif
        }
        .frame(width: 108, height: 108)
        .clipShape(Circle())
        .overlay(Circle().strokeBorder(Color.white, lineWidth: 4))
        .overlay(Circle().strokeBorder(RampStage.accentSoft, lineWidth: 4).padding(-4))
        .shadow(color: RampStage.ink.opacity(0.20), radius: 14, y: 8)
    }
}

// ============================================================
// MARK: — Screen 2: The Split (what 14 days moves)
// ============================================================

/// Proof you make with your own thumb: dragging the slider climbs the metric
/// bars from "day 1" to "day 14" in lockstep. Interactive, quiet.
struct RampSplitScreen: View {
    let onAdvance: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var t: Double = 0
    @State private var showHint = true

    var body: some View {
        VStack(spacing: 0) {
            Spacer().frame(height: VSpace.xxl * 1.2)

            Text("What fourteen\ndays can move.")
                .font(RampStage.serif(26))
                .foregroundStyle(RampStage.ink)
                .multilineTextAlignment(.center)
                .lineSpacing(2)

            Text("Some things shift in two weeks. Some take longer. We'll be honest about which.")
                .font(VType.caption)
                .foregroundStyle(RampStage.textSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, VSpace.xl)
                .padding(.top, VSpace.sm)

            Spacer().frame(height: VSpace.xxl * 1.1)

            VStack(spacing: VSpace.md) {
                ForEach(RampSplitMetric.samples.indices, id: \.self) { i in
                    let metric = RampSplitMetric.samples[i]
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 7) {
                            Text(LocalizedStringKey(metric.label))
                                .font(VType.caption)
                                .foregroundStyle(RampStage.textSecondary)
                            Text(LocalizedStringKey(metric.tag))
                                .font(VType.micro)
                                .foregroundStyle(metric.tag == "Slower"
                                                 ? RampStage.textTertiary : RampStage.accentDeep)
                                .padding(.horizontal, 6).padding(.vertical, 1)
                                .background((metric.tag == "Slower"
                                             ? RampStage.hair : RampStage.accent.opacity(0.14)),
                                            in: Capsule())
                            Spacer()
                            Text(verbatim: "\(Int(metric.value(at: t) * 100))")
                                .font(VType.captionBold)
                                .foregroundStyle(RampStage.accentDeep)
                                .monospacedDigit()
                        }
                        GeometryReader { proxy in
                            ZStack(alignment: .leading) {
                                Capsule().fill(RampStage.hair.opacity(0.6))
                                // Edged: the beige fill is only 1.2:1 against
                                // the track, so the bar's length would be
                                // guesswork without the outline.
                                Capsule()
                                    .fill(RampStage.accent)
                                    .overlay(Capsule().strokeBorder(RampStage.accentEdge, lineWidth: 1))
                                    .frame(width: proxy.size.width * metric.value(at: t))
                            }
                        }
                        .frame(height: 6)
                    }
                }
            }
            .padding(.horizontal, VSpace.xl)

            RampMorphSlider(value: $t) {
                withAnimation(VMotion.gentle) { showHint = false }
            }
            .padding(.horizontal, VSpace.xl)
            .padding(.top, VSpace.lg)

            // "You can touch this" — visible until the first real drag.
            HStack(spacing: 6) {
                Image(systemName: "arrow.left.and.right")
                    .font(.system(size: 11, weight: .bold))
                Text("Try dragging the slider")
                    .font(VType.captionBold)
            }
            .foregroundStyle(RampStage.accentDeep)
            .padding(.horizontal, VSpace.md)
            .padding(.vertical, 6)
            .background(RampStage.accent.opacity(0.12), in: Capsule())
            .opacity(showHint ? 1 : 0)
            .padding(.top, VSpace.xs)

            HStack {
                Text("DAY 1")
                    .foregroundStyle(t < 0.5 ? RampStage.accentDeep : RampStage.textTertiary)
                Spacer()
                Text("DAY 14")
                    .foregroundStyle(t >= 0.5 ? RampStage.accentDeep : RampStage.textTertiary)
            }
            .font(VType.micro)
            .tracking(1.5)
            .padding(.horizontal, VSpace.xl)
            .padding(.top, VSpace.sm)

            Spacer()

            RampPrimaryButton(title: "Read mine") { onAdvance() }
                .padding(.horizontal, VSpace.lg)
            Spacer().frame(height: VSpace.xxl)
        }
        .onAppear {
            guard !reduceMotion else { t = 0.6; return }
            Task {
                try? await Task.sleep(for: .milliseconds(700))
                withAnimation(.easeInOut(duration: 1.2)) { t = 0.72 }
                try? await Task.sleep(for: .milliseconds(1400))
                withAnimation(.easeInOut(duration: 0.9)) { t = 0.2 }
            }
        }
    }
}

/// One metric bar on the Split screen — interpolates before→after by `t`.
/// The after-values are deliberately UNEVEN: fast movers (hydration, glow)
/// climb a lot in two weeks, slow ones (texture) barely — the honest message
/// is built into the bars, not just the caption.
private struct RampSplitMetric {
    let label: String
    let tag: String      // "Fast" / "Gradual" / "Slower"
    let before: Double
    let after: Double

    func value(at t: Double) -> CGFloat {
        CGFloat(before + (after - before) * max(0, min(1, t)))
    }

    static let samples: [RampSplitMetric] = [
        RampSplitMetric(label: "Hydration", tag: "Fast",    before: 0.40, after: 0.78),
        RampSplitMetric(label: "Glow",      tag: "Fast",    before: 0.38, after: 0.72),
        RampSplitMetric(label: "Redness",   tag: "Gradual", before: 0.50, after: 0.67),
        RampSplitMetric(label: "Texture",   tag: "Slower",  before: 0.44, after: 0.55),
    ]
}

/// Custom track slider with a soft knob — the one interaction on the Split
/// screen. Warm, quiet, no glow burst.
struct RampMorphSlider: View {
    @Binding var value: Double
    /// Fires on the first real finger drag (used to dismiss the "try it" hint).
    var onUserDrag: () -> Void = {}

    private let knob: CGFloat = 26

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let usable = max(width - knob, 1)
            let x = CGFloat(max(0, min(1, value))) * usable

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(RampStage.hair.opacity(0.6))
                    .frame(height: 5)
                Capsule()
                    .fill(RampStage.accentEdge)
                    .frame(width: x + knob / 2, height: 5)
                Circle()
                    .fill(Color.white)
                    .frame(width: knob, height: knob)
                    // Edge, not accent: a white knob ringed in pale beige has
                    // no visible boundary on this ground.
                    .overlay(Circle().strokeBorder(RampStage.accentEdge, lineWidth: 2))
                    .shadow(color: RampStage.ink.opacity(0.18), radius: 8, y: 3)
                    .offset(x: x)
            }
            .frame(maxHeight: .infinity, alignment: .center)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { g in
                        onUserDrag()
                        let newValue = Double(max(0, min(usable, g.location.x - knob / 2)) / usable)
                        if abs(newValue - value) > 0.02 { Haptics.fire(.tick) }
                        value = newValue
                    }
            )
        }
        .frame(height: knob)
        .accessibilityElement()
        .accessibilityLabel("onboarding.split")
        .accessibilityValue(Text(verbatim: "\(Int(value * 100))%"))
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: value = min(1, value + 0.1)
            case .decrement: value = max(0, value - 0.1)
            default: break
            }
        }
    }
}
