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
// MARK: — Screen 1: The Scan (watch your skin get read)
// ============================================================

/// The genre's strongest opener, reimagined as a LIVE diagnostic: an abstract
/// face inside a scanner HUD, a beam sweeping it, detection chips popping in one
/// by one at each region, and a skin score materialising at the end. No real
/// people, no faces — pure, cinematic "the machine is reading you".
struct RampSampleReadingScreen: View {
    let onAdvance: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var beam = false
    @State private var chipsIn = 0
    @State private var scored = false
    @State private var shownScore = 0

    // Detection points around the face: label, value, x-offset, y-offset.
    private let nodes: [(String, Int, CGFloat, CGFloat)] = [
        ("Texture", 82, -66, -84),
        ("Pores",   78,  72, -40),
        ("Redness", 80, -74,  40),
        ("Glow",    88,  58,  92),
    ]

    var body: some View {
        VStack(spacing: 0) {
            Spacer().frame(height: VSpace.xxl * 1.1)

            Text("Watch your skin\nget read.")
                .font(RampStage.serif(26))
                .foregroundStyle(RampStage.ink)
                .multilineTextAlignment(.center)
                .lineSpacing(2)

            Spacer()

            ZStack {
                Circle()
                    .fill(RadialGradient(colors: [RampStage.accent.opacity(0.22), .clear],
                                         center: .center, startRadius: 0, endRadius: 200))
                    .frame(width: 320, height: 320)

                RampScanFaceArt()
                    .frame(width: 190, height: 190)

                // The beam sweeps the face, forever.
                ZStack {
                    Rectangle().fill(RampStage.accent.opacity(0.12))
                        .frame(width: 210, height: 42).blur(radius: 7)
                    Rectangle()
                        .fill(LinearGradient(colors: [.clear, RampStage.accent, .clear],
                                             startPoint: .leading, endPoint: .trailing))
                        .frame(width: 210, height: 2)
                }
                .offset(y: beam ? 104 : -104)
                .animation(reduceMotion ? nil :
                    Animation.easeInOut(duration: 2.0).repeatForever(autoreverses: true), value: beam)

                // Detection chips pop in, region by region.
                ForEach(nodes.indices, id: \.self) { i in
                    let node = nodes[i]
                    RampScanChip(label: node.0, value: node.1)
                        .offset(x: node.2, y: node.3)
                        .opacity(i < chipsIn ? 1 : 0)
                        .scaleEffect(i < chipsIn ? 1 : 0.6)
                        .animation(.spring(response: 0.4, dampingFraction: 0.7), value: chipsIn)
                }
            }
            .frame(width: 320, height: 320)

            Spacer().frame(height: VSpace.md)

            // The verdict badge — dashes until the scan lands a number.
            HStack(spacing: 8) {
                Image(systemName: "sparkles")
                    .font(.system(size: 13, weight: .bold))
                Text("Skin score")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                Text(verbatim: scored ? "\(shownScore)" : "· ·")
                    .font(.system(size: 16, weight: .heavy, design: .rounded))
                    .monospacedDigit()
                    .contentTransition(.numericText(value: Double(shownScore)))
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 16).padding(.vertical, 10)
            .background(RampStage.accent, in: Capsule())
            .shadow(color: RampStage.accent.opacity(0.4), radius: 12, y: 5)

            Spacer()

            Text("A live example. Yours is built from your own scan.")
                .font(VType.micro)
                .foregroundStyle(RampStage.textTertiary)

            RampPrimaryButton(title: "I want mine") { onAdvance() }
                .padding(.horizontal, VSpace.lg)
                .padding(.top, VSpace.md)
            Spacer().frame(height: VSpace.xxl)
        }
        .onAppear { beam = true }
        .task {
            if reduceMotion { chipsIn = nodes.count; scored = true; shownScore = 88; return }
            try? await Task.sleep(for: .milliseconds(700))
            for i in 1...nodes.count {
                withAnimation { chipsIn = i }
                Haptics.fire(.tick)
                try? await Task.sleep(for: .milliseconds(520))
                if Task.isCancelled { return }
            }
            withAnimation { scored = true }
            let target = 88
            let steps = 24
            for i in 0...steps {
                shownScore = Int((Double(target) * Double(i) / Double(steps)).rounded())
                try? await Task.sleep(for: .milliseconds(22))
                if Task.isCancelled { return }
            }
            shownScore = target
        }
    }
}

/// A small detection chip that pops onto a face region during the scan.
private struct RampScanChip: View {
    let label: String
    let value: Int

    var body: some View {
        HStack(spacing: 6) {
            Circle().fill(RampStage.accent).frame(width: 5, height: 5)
            Text(LocalizedStringKey(label))
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(RampStage.ink)
            Text(verbatim: "\(value)")
                .font(.system(size: 11, weight: .heavy, design: .rounded))
                .foregroundStyle(RampStage.accentDeep)
                .monospacedDigit()
        }
        .padding(.horizontal, 9).padding(.vertical, 5)
        .background(Color.white, in: Capsule())
        .overlay(Capsule().strokeBorder(RampStage.hair, lineWidth: 1))
        .shadow(color: RampStage.accent.opacity(0.18), radius: 8, y: 3)
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
// MARK: — Screen 2: The Number (spin it yourself)
// ============================================================

/// Interactive dopamine: the user TAPS the dial and it whirls through scores —
/// fast, then slowing, haptic on every tick — and lands on a number it was
/// never really entitled to. The caption then flips: that was a guess; yours is
/// measured. Tactile, playful, and it makes the point better than any sentence.
struct RampNumberScreen: View {
    let onAdvance: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var spinToken = 0
    @State private var spinning = false
    @State private var landed = false
    @State private var display = 0

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            Text("Find your\nnumber.")
                .font(RampStage.serif(30))
                .foregroundStyle(RampStage.ink)
                .multilineTextAlignment(.center)
                .lineSpacing(2)

            Spacer().frame(height: VSpace.xl)

            Button {
                guard !spinning else { return }
                spinToken += 1
            } label: {
                dial
            }
            .buttonStyle(PressableStyle())
            .disabled(spinning)

            Spacer().frame(height: VSpace.lg)

            Text(landed
                 ? "That was a guess. Yours is measured — one honest scan."
                 : "Tap the dial. Watch it hunt for a number it can't really know.")
                .font(VType.bodyLarge)
                .foregroundStyle(RampStage.textSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, VSpace.xl)
                .animation(.easeInOut, value: landed)

            Spacer()

            RampPrimaryButton(title: "Continue") { onAdvance() }
                .padding(.horizontal, VSpace.lg)
            Spacer().frame(height: VSpace.xxl)
        }
        .task(id: spinToken) {
            guard spinToken > 0 else { return }
            await runSpin()
        }
    }

    private var dial: some View {
        ZStack {
            Circle()
                .fill(RadialGradient(colors: [RampStage.accent.opacity(spinning ? 0.36 : 0.20), .clear],
                                     center: .center, startRadius: 0, endRadius: 150))

            ForEach(0..<48, id: \.self) { i in
                Capsule()
                    .fill(RampStage.hair)
                    .frame(width: 2, height: i % 4 == 0 ? 10 : 5)
                    .offset(y: -104)
                    .rotationEffect(.degrees(Double(i) / 48 * 360))
            }

            Circle()
                .stroke(RampStage.hair, lineWidth: 10)
                .frame(width: 196, height: 196)

            // The arc tracks whatever the dial currently reads.
            Circle()
                .trim(from: 0, to: CGFloat(display) / 100)
                .stroke(LinearGradient(colors: [RampStage.accent, RampStage.accentDeep],
                                       startPoint: .leading, endPoint: .trailing),
                        style: StrokeStyle(lineWidth: 10, lineCap: .round))
                .frame(width: 196, height: 196)
                .rotationEffect(.degrees(-90))
                .shadow(color: RampStage.accent.opacity(0.5), radius: 8)
                .animation(.easeOut(duration: 0.12), value: display)

            VStack(spacing: 2) {
                Text(verbatim: (landed || spinning) ? "\(display)" : "?")
                    .font(RampStage.serif(64))
                    .foregroundStyle(RampStage.ink)
                    .monospacedDigit()
                    .contentTransition(.numericText(value: Double(display)))
                Text(verbatim: "/ 100")
                    .font(VType.caption)
                    .foregroundStyle(RampStage.textTertiary)
            }

            if !landed && !spinning {
                Text("TAP")
                    .font(VType.micro).fontWeight(.bold).tracking(2)
                    .foregroundStyle(RampStage.accentDeep)
                    .offset(y: 66)
            }
        }
        .frame(width: 240, height: 240)
    }

    @MainActor
    private func runSpin() async {
        if reduceMotion {
            display = 84; landed = true; Haptics.fire(.milestone); return
        }
        spinning = true
        landed = false
        let target = 76 + (spinToken * 7) % 16   // 76…91, varies per spin
        var delay = 40
        for step in 0..<26 {
            display = 40 + (step * 7 + spinToken * 13) % 55   // churns 40…94
            Haptics.fire(.tick)
            try? await Task.sleep(for: .milliseconds(delay))
            delay += 8 + step                                  // decelerate
            if Task.isCancelled { spinning = false; return }
        }
        withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) { display = target }
        spinning = false
        landed = true
        Haptics.fire(.milestone)
    }
}

// ============================================================
// MARK: — Screen 3: The Reveal (before → after glow)
// ============================================================

/// The transformation, in your own hand: drag and a dull, flat skin orb blooms
/// into a radiant one, the projected gain climbing with it. Endpoints are
/// labelled DAY 1 / DAY 14, and the honest fast/slow tags stay in view so the
/// promise never overreaches.
struct RampSplitScreen: View {
    let onAdvance: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var t: Double = 0
    @State private var showHint = true

    var body: some View {
        VStack(spacing: 0) {
            Spacer().frame(height: VSpace.xxl * 1.0)

            Text("See your\n14-day glow.")
                .font(RampStage.serif(26))
                .foregroundStyle(RampStage.ink)
                .multilineTextAlignment(.center)
                .lineSpacing(2)

            Text("Some things shift in two weeks, some take longer. Drag to see it — honestly.")
                .font(VType.caption)
                .foregroundStyle(RampStage.textSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, VSpace.xl)
                .padding(.top, VSpace.sm)

            Spacer().frame(height: VSpace.xl)

            RampRevealOrb(t: t)
                .frame(width: 220, height: 220)
                .overlay(alignment: .top) {
                    Text(verbatim: "+\(Int((18 * t).rounded()))")
                        .font(.system(size: 15, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                        .monospacedDigit()
                        .padding(.horizontal, 12).padding(.vertical, 6)
                        .background(RampStage.accent, in: Capsule())
                        .shadow(color: RampStage.accent.opacity(0.4), radius: 8, y: 3)
                        .opacity(t > 0.12 ? 1 : 0)
                        .offset(y: -6)
                        .animation(.easeOut(duration: 0.2), value: t > 0.12)
                }

            Spacer().frame(height: VSpace.lg)

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

            RampMorphSlider(value: $t) {
                withAnimation(VMotion.gentle) { showHint = false }
            }
            .padding(.horizontal, VSpace.xl)
            .padding(.top, VSpace.sm)

            HStack(spacing: 6) {
                Image(systemName: "hand.draw")
                    .font(.system(size: 11, weight: .bold))
                Text("Drag to reveal your 14 days")
                    .font(VType.captionBold)
            }
            .foregroundStyle(RampStage.accentDeep)
            .padding(.horizontal, VSpace.md)
            .padding(.vertical, 6)
            .background(RampStage.accent.opacity(0.12), in: Capsule())
            .opacity(showHint ? 1 : 0)
            .padding(.top, VSpace.md)

            Spacer().frame(height: VSpace.lg)

            // Honest tags stay visible — fast vs. slow is never hidden.
            HStack(spacing: 8) {
                ForEach(RampSplitMetric.samples.indices, id: \.self) { i in
                    let metric = RampSplitMetric.samples[i]
                    HStack(spacing: 5) {
                        Circle()
                            .fill(metric.tag == "Slower" ? RampStage.textTertiary : RampStage.accent)
                            .frame(width: 5, height: 5)
                        Text(LocalizedStringKey(metric.label))
                            .font(.system(size: 10.5, weight: .semibold, design: .rounded))
                            .foregroundStyle(RampStage.textSecondary)
                    }
                }
            }
            .padding(.horizontal, VSpace.lg)

            Spacer()

            RampPrimaryButton(title: "Read mine") { onAdvance() }
                .padding(.horizontal, VSpace.lg)
            Spacer().frame(height: VSpace.xxl)
        }
        .onAppear {
            guard !reduceMotion else { t = 0.6; return }
            Task {
                try? await Task.sleep(for: .milliseconds(700))
                withAnimation(.easeInOut(duration: 1.3)) { t = 0.78 }
                try? await Task.sleep(for: .milliseconds(1500))
                withAnimation(.easeInOut(duration: 0.9)) { t = 0.22 }
            }
        }
    }
}

/// The skin orb that blooms from flat and dull (t=0) to radiant (t=1) — two
/// cross-fading spheres plus an aura and sparkles that rise with t.
private struct RampRevealOrb: View {
    let t: Double

    var body: some View {
        ZStack {
            // Aura — grows and brightens toward day 14.
            Circle()
                .fill(RadialGradient(colors: [RampStage.accent.opacity(0.45), .clear],
                                     center: .center, startRadius: 0, endRadius: 150))
                .scaleEffect(0.85 + 0.3 * t)
                .opacity(t)

            // Dull "now" sphere.
            Circle()
                .fill(RadialGradient(colors: [Color(hex: "DCE3EC"), Color(hex: "9AA7B5")],
                                     center: UnitPoint(x: 0.36, y: 0.30),
                                     startRadius: 4, endRadius: 150))
                .frame(width: 190, height: 190)
                .opacity(1 - t)

            // Radiant "day 14" sphere.
            Circle()
                .fill(RadialGradient(colors: [Color.white, RampStage.accent, RampStage.accentDeep],
                                     center: UnitPoint(x: 0.33, y: 0.28),
                                     startRadius: 2, endRadius: 170))
                .frame(width: 190, height: 190)
                .opacity(t)

            // Rim light + sparkles bloom in.
            Circle()
                .strokeBorder(Color.white.opacity(0.55 * t), lineWidth: 2)
                .frame(width: 190, height: 190)

            Image(systemName: "sparkle")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(.white)
                .offset(x: -46, y: -52).opacity(t)
            Image(systemName: "sparkle")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(.white)
                .offset(x: 54, y: 30).opacity(t)
        }
        .frame(width: 220, height: 220)
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
