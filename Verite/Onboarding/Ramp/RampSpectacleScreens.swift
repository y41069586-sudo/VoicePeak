import SwiftUI

// ============================================================
// MARK: — Screen 0: Opening
// ============================================================

/// The GlamUp-style intro: three illustrated pages — mirror, scan, plan —
/// with a big rounded title, a short line and one coral button. Paged
/// VERTICALLY: swiping down (or tapping Continue) moves to the next page;
/// the last page hands off into the flow. Pure-SwiftUI line-art in the
/// brand's coral/blush palette — no assets needed.
struct RampBootScreen: View {
    let onAdvance: () -> Void

    @State private var page: Int? = 0

    private let titles = ["Your glow,\nmeasured.", "Discover\nyour skin.", "Glow in\n14 days."]
    private let subs = [
        "One scan. One honest score from 0 to 100 — no filter, no sugarcoating.",
        "Seven metrics, clear insights and a plan made for your face.",
        "A simple morning & evening ritual, rebuilt from every scan.",
    ]

    var body: some View {
        ScrollView(.vertical) {
            // Eager VStack (not Lazy) so every page is laid out up front — the
            // programmatic scroll to ANY page then animates identically, with
            // no snap when a not-yet-rendered page would otherwise pop in.
            VStack(spacing: 0) {
                ForEach(0..<3, id: \.self) { index in
                    introPage(index)
                        .containerRelativeFrame(.vertical)
                        .id(index)
                }
            }
            .scrollTargetLayout()
        }
        .scrollTargetBehavior(.paging)
        .scrollIndicators(.hidden)
        .scrollPosition(id: $page)
        .ignoresSafeArea()
        .overlay(alignment: .bottom) {
            VStack(spacing: VSpace.md) {
                // Page dots — reflect the vertical position.
                HStack(spacing: 6) {
                    ForEach(0..<3, id: \.self) { index in
                        Capsule()
                            .fill(index == (page ?? 0) ? RampStage.accent : RampStage.hair)
                            .frame(width: index == (page ?? 0) ? 18 : 6, height: 6)
                    }
                }
                .animation(VMotion.snappy, value: page)

                RampPrimaryButton(title: (page ?? 0) >= 2 ? "Get started" : "Continue") {
                    let current = page ?? 0
                    if current >= 2 {
                        onAdvance()
                    } else {
                        // One consistent scroll for every Continue press.
                        withAnimation(.easeInOut(duration: 0.5)) { page = current + 1 }
                    }
                }
                .padding(.horizontal, VSpace.lg)
            }
            .padding(.bottom, 44) // clear of the home indicator (full-bleed pager)
        }
    }

    private func introPage(_ index: Int) -> some View {
        VStack(spacing: 0) {
            Spacer()

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

            Spacer()

            VStack(spacing: VSpace.md) {
                Text(titles[index])
                    .font(RampStage.serif(34))
                    .foregroundStyle(RampStage.ink)
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
                Text(subs[index])
                    .font(VType.bodyLarge)
                    .foregroundStyle(RampStage.textSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, VSpace.xl)
            }

            Spacer()
            // Room for the fixed dots + button overlay.
            Spacer().frame(height: 150)
        }
        .frame(maxWidth: .infinity)
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
                    .overlay(Capsule().strokeBorder(RampStage.accent, lineWidth: 4))
                    .frame(width: 34, height: 86)
            }
            // Frame + glass with a soft diagonal shine.
            Ellipse()
                .fill(Color.white)
                .overlay(Ellipse().strokeBorder(RampStage.accent, lineWidth: 5))
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
                .foregroundStyle(RampStage.accent)
                .offset(x: -98, y: -92)
            Image(systemName: "sparkle")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(RampStage.accent)
                .offset(x: 96, y: -30)
            Image(systemName: "sparkle")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(RampStage.accent)
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
                .stroke(RampStage.accent, style: StrokeStyle(lineWidth: 7, lineCap: .round))
                .frame(width: 190, height: 190)

            // A friendly abstract face.
            ZStack {
                Circle()
                    .fill(Color.white)
                    .overlay(Circle().strokeBorder(RampStage.accent, lineWidth: 4))
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
                    .overlay(Circle().strokeBorder(RampStage.accent, lineWidth: 4))
                Image(systemName: "checkmark")
                    .font(.system(size: 26, weight: .bold))
                    .foregroundStyle(RampStage.accent)
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
                        .strokeBorder(RampStage.accent, lineWidth: 5)
                )
                .frame(width: 170, height: 160)
            UnevenRoundedRectangle(topLeadingRadius: 18, topTrailingRadius: 18)
                .fill(RampStage.accent)
                .frame(width: 170, height: 40)
                .offset(y: -60)
            Text("14 DAYS")
                .font(.system(size: 15, weight: .heavy, design: .rounded))
                .foregroundStyle(Color.white)
                .tracking(1)
                .offset(y: -60)

            // Day dots: first row done, second underway.
            VStack(spacing: 14) {
                ForEach(0..<2, id: \.self) { row in
                    HStack(spacing: 14) {
                        ForEach(0..<5, id: \.self) { column in
                            let done = row == 0 || column < 2
                            Circle()
                                .fill(done ? RampStage.accent : RampStage.dawnPeach)
                                .frame(width: 16, height: 16)
                        }
                    }
                }
            }
            .offset(y: 8)

            Image(systemName: "sparkle")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(RampStage.accent)
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
// MARK: — Screen 1: A Reading (the outcome, shown first)
// ============================================================

/// The genre's strongest opener: show the artifact the user will own BEFORE
/// asking for anything. An illustrative reading card — clearly labeled, no
/// invented people, no faces — cycles through a few example scores.
struct RampSampleReadingScreen: View {
    let onAdvance: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var index = 0
    @State private var float = false

    private let samples = RampSampleReading.samples

    var body: some View {
        VStack(spacing: 0) {
            Spacer().frame(height: VSpace.xxl * 1.5)

            Text("Your skin, as a\nsingle honest page.")
                .font(RampStage.serif(25))
                .foregroundStyle(RampStage.ink)
                .multilineTextAlignment(.center)
                .lineSpacing(2)

            Spacer()

            // The card floats on a soft accent pool and sways almost
            // imperceptibly — it reads as a live artifact, not a static mock.
            ZStack {
                Ellipse()
                    .fill(RadialGradient(colors: [RampStage.accent.opacity(0.28), .clear],
                                         center: .center, startRadius: 0, endRadius: 220))
                    .frame(width: 340, height: 300)
                    .blur(radius: 8)

                RampSampleReadingCard(sample: samples[index])
                    .id(index)
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity)
                            .combined(with: .scale(scale: 0.94)),
                        removal: .move(edge: .leading).combined(with: .opacity)
                            .combined(with: .scale(scale: 0.94))))
            }
            .rotation3DEffect(.degrees(float ? 2.2 : -2.2),
                              axis: (x: 1, y: 0.35, z: 0), perspective: 0.6)
            .offset(y: float ? -6 : 6)
            .animation(.easeInOut(duration: 3.4).repeatForever(autoreverses: true), value: float)

            // Cycle dots
            HStack(spacing: 6) {
                ForEach(samples.indices, id: \.self) { i in
                    Capsule()
                        .fill(i == index ? RampStage.accent : RampStage.hair)
                        .frame(width: i == index ? 18 : 6, height: 4)
                }
            }
            .animation(VMotion.snappy, value: index)
            .padding(.top, VSpace.lg)

            Text("Illustrative reading. Yours is built from your scan.")
                .font(VType.micro)
                .foregroundStyle(RampStage.textTertiary)
                .padding(.top, VSpace.xs)

            Spacer()

            RampPrimaryButton(title: "I want mine") { onAdvance() }
                .padding(.horizontal, VSpace.lg)
            Spacer().frame(height: VSpace.xxl)
        }
        .onAppear { float = true }
        .task {
            guard !reduceMotion else { return }
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(2600))
                guard !Task.isCancelled else { return }
                withAnimation(.spring(response: 0.6, dampingFraction: 0.82)) {
                    index = (index + 1) % samples.count
                }
            }
        }
    }
}

/// One illustrative reading: an overall score + per-metric levels.
struct RampSampleReading {
    let overall: Int
    let metrics: [(String, Double)] // label, 0…1

    static let samples: [RampSampleReading] = [
        RampSampleReading(overall: 74, metrics: [
            ("Texture", 0.71), ("Redness", 0.66), ("Pores", 0.78),
            ("Evenness", 0.73), ("Glow", 0.81), ("Hydration", 0.69), ("Blemishes", 0.84),
        ]),
        RampSampleReading(overall: 62, metrics: [
            ("Texture", 0.55), ("Redness", 0.48), ("Pores", 0.66),
            ("Evenness", 0.61), ("Glow", 0.58), ("Hydration", 0.72), ("Blemishes", 0.70),
        ]),
        RampSampleReading(overall: 86, metrics: [
            ("Texture", 0.84), ("Redness", 0.88), ("Pores", 0.82),
            ("Evenness", 0.87), ("Glow", 0.90), ("Hydration", 0.83), ("Blemishes", 0.89),
        ]),
    ]
}

/// The card itself — white paper on the porcelain stage, serif score,
/// seven quiet metric rows. This exact layout returns as the user's own
/// shareable Reading Card after the first scan.
struct RampSampleReadingCard: View {
    let sample: RampSampleReading

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var reveal = false
    @State private var shownScore = 0

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(verbatim: Brand.name.uppercased())
                    .font(VType.micro).tracking(4)
                    .foregroundStyle(RampStage.accentDeep)
                Spacer()
                Text("READING")
                    .font(VType.micro).tracking(4)
                    .foregroundStyle(RampStage.textTertiary)
            }

            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(verbatim: "\(shownScore)")
                    .font(RampStage.serif(56))
                    .foregroundStyle(RampStage.ink)
                    .monospacedDigit()
                    .contentTransition(.numericText(value: Double(shownScore)))
                Text(verbatim: "/ 100")
                    .font(VType.caption)
                    .foregroundStyle(RampStage.textTertiary)
            }
            .padding(.vertical, VSpace.sm)

            VStack(spacing: 9) {
                ForEach(sample.metrics.indices, id: \.self) { i in
                    let metric = sample.metrics[i]
                    HStack(spacing: 10) {
                        Text(LocalizedStringKey(metric.0))
                            .font(VType.caption)
                            .foregroundStyle(RampStage.textSecondary)
                            .frame(width: 74, alignment: .leading)
                        GeometryReader { proxy in
                            ZStack(alignment: .leading) {
                                Capsule().fill(RampStage.hair.opacity(0.55))
                                Capsule()
                                    .fill(LinearGradient(
                                        colors: [RampStage.accent, RampStage.accentDeep],
                                        startPoint: .leading, endPoint: .trailing))
                                    .frame(width: proxy.size.width * metric.1 * (reveal ? 1 : 0))
                            }
                        }
                        .frame(height: 4)
                        .animation(.easeOut(duration: 0.6).delay(Double(i) * 0.07), value: reveal)
                        Text(verbatim: "\(Int(metric.1 * 100))")
                            .font(VType.captionBold)
                            .foregroundStyle(RampStage.accentDeep)
                            .monospacedDigit()
                            .frame(width: 24, alignment: .trailing)
                            .opacity(reveal ? 1 : 0)
                            .animation(.easeOut(duration: 0.4).delay(0.2 + Double(i) * 0.07), value: reveal)
                    }
                }
            }
        }
        .padding(VSpace.lg)
        .frame(width: 290)
        .background(Color.white.opacity(0.88), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(RampShine().clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous)))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(RampStage.hairline, lineWidth: 1)
        )
        .shadow(color: RampStage.accent.opacity(0.22), radius: 28, y: 16)
        .task(id: sample.overall) {
            if reduceMotion { reveal = true; shownScore = sample.overall; return }
            reveal = false
            shownScore = 0
            reveal = true   // drives the per-row staggered fill animations
            let target = sample.overall
            let steps = 26
            for i in 0...steps {
                shownScore = Int((Double(target) * Double(i) / Double(steps)).rounded())
                try? await Task.sleep(for: .milliseconds(20))
                if Task.isCancelled { return }
            }
            shownScore = target
        }
    }
}

/// A soft diagonal light that sweeps across a surface, forever. Clipped by the
/// caller to whatever shape it sits on. The signature "live glass" touch.
struct RampShine: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var travel = false

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            Rectangle()
                .fill(LinearGradient(
                    colors: [.clear, Color.white.opacity(0.55), .clear],
                    startPoint: .top, endPoint: .bottom))
                .frame(width: 60)
                .rotationEffect(.degrees(20))
                .offset(x: travel ? w + 90 : -90)
                .animation(reduceMotion ? nil :
                    Animation.easeInOut(duration: 2.4).repeatForever(autoreverses: false).delay(0.8),
                    value: travel)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .onAppear { travel = true }
    }
}

// ============================================================
// MARK: — Screen 1: The Number (curiosity, calmly)
// ============================================================

struct RampNumberScreen: View {
    let onAdvance: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            RampScoreGauge()
                .frame(width: 240, height: 240)
                .vStaggeredAppear(index: 0)

            Spacer().frame(height: VSpace.xl)

            VStack(spacing: VSpace.md) {
                Text("Every complexion\nhas a number.")
                    .font(RampStage.serif(29))
                    .foregroundStyle(RampStage.ink)
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
                    .vStaggeredAppear(index: 1)
                Text("Most people never learn theirs.\nYours takes one honest scan.")
                    .font(VType.bodyLarge)
                    .foregroundStyle(RampStage.textSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .vStaggeredAppear(index: 2)
            }
            .padding(.horizontal, VSpace.xl)

            Spacer()

            RampPrimaryButton(title: "Continue") { onAdvance() }
                .padding(.horizontal, VSpace.lg)
            Spacer().frame(height: VSpace.xxl)
        }
    }
}

/// A living score gauge: a breathing halo, a fine tick ring, a glowing arc
/// that circles forever like a scanner searching, and a big number that drifts
/// through plausible scores and never settles — the number exists, it just
/// isn't yours yet. Reduce Motion pins a calm "· ·".
private struct RampScoreGauge: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var spin = false
    @State private var breathe = false

    var body: some View {
        ZStack {
            // Breathing halo.
            Circle()
                .fill(RadialGradient(colors: [RampStage.accent.opacity(0.30), .clear],
                                     center: .center, startRadius: 0, endRadius: 150))
                .scaleEffect(breathe ? 1.12 : 0.92)
                .animation(reduceMotion ? nil :
                    Animation.easeInOut(duration: 2.6).repeatForever(autoreverses: true), value: breathe)

            // Fine tick ring.
            ForEach(0..<48, id: \.self) { i in
                Capsule()
                    .fill(RampStage.hair)
                    .frame(width: 2, height: i % 4 == 0 ? 10 : 5)
                    .offset(y: -104)
                    .rotationEffect(.degrees(Double(i) / 48 * 360))
            }

            // Static track.
            Circle()
                .stroke(RampStage.hair, lineWidth: 8)
                .frame(width: 196, height: 196)

            // Glowing arc that circles forever.
            Circle()
                .trim(from: 0, to: 0.16)
                .stroke(LinearGradient(colors: [RampStage.accent.opacity(0), RampStage.accent],
                                       startPoint: .leading, endPoint: .trailing),
                        style: StrokeStyle(lineWidth: 8, lineCap: .round))
                .frame(width: 196, height: 196)
                .rotationEffect(.degrees(spin ? 360 : 0))
                .shadow(color: RampStage.accent.opacity(0.5), radius: 8)
                .animation(reduceMotion ? nil :
                    Animation.linear(duration: 3.2).repeatForever(autoreverses: false), value: spin)

            // Center: the drifting number.
            VStack(spacing: 2) {
                driftNumber
                Text(verbatim: "/ 100")
                    .font(VType.caption)
                    .foregroundStyle(RampStage.textTertiary)
            }
        }
        .onAppear { spin = true; breathe = true }
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private var driftNumber: some View {
        if reduceMotion {
            figure("· ·")
        } else {
            TimelineView(.periodic(from: .now, by: 0.75)) { timeline in
                let tick = Int(timeline.date.timeIntervalSinceReferenceDate / 0.75)
                figure(String(42 + Int(Self.hash(tick) * 53)))
                    .contentTransition(.numericText())
                    .animation(.easeInOut(duration: 0.45), value: tick)
            }
        }
    }

    private func figure(_ text: String) -> some View {
        Text(verbatim: text)
            .font(RampStage.serif(62))
            .foregroundStyle(RampStage.ink)
            .monospacedDigit()
            .frame(minWidth: 96)
    }

    private static func hash(_ i: Int) -> Double {
        let v = sin(Double(i) * 127.1) * 43758.5453
        return v - floor(v)
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
                                .contentTransition(.numericText(value: metric.value(at: t)))
                        }
                        GeometryReader { proxy in
                            let w = proxy.size.width * metric.value(at: t)
                            ZStack(alignment: .leading) {
                                Capsule().fill(RampStage.hair.opacity(0.6))
                                Capsule()
                                    .fill(LinearGradient(
                                        colors: [RampStage.accent, RampStage.accentDeep],
                                        startPoint: .leading, endPoint: .trailing))
                                    .frame(width: w)
                                    .shadow(color: RampStage.accent.opacity(0.45), radius: 5, y: 1)
                                    .overlay(alignment: .trailing) {
                                        // A bright head-dot rides the tip of each bar.
                                        Circle()
                                            .fill(Color.white)
                                            .frame(width: 7, height: 7)
                                            .shadow(color: RampStage.accent.opacity(0.7), radius: 4)
                                            .offset(x: 3)
                                            .opacity(metric.value(at: t) > 0.06 ? 1 : 0)
                                    }
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
                    .fill(LinearGradient(colors: [RampStage.accent, RampStage.accentDeep],
                                         startPoint: .leading, endPoint: .trailing))
                    .frame(width: x + knob / 2, height: 5)
                Circle()
                    .fill(Color.white)
                    .frame(width: knob, height: knob)
                    .overlay(Circle().strokeBorder(RampStage.accent, lineWidth: 2))
                    .overlay(Circle().fill(RampStage.accent).frame(width: 7, height: 7))
                    .shadow(color: RampStage.accent.opacity(0.55), radius: 12, y: 3)
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
