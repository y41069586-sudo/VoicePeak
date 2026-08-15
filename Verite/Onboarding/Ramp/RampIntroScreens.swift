import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

// ============================================================
// MARK: — What the mockups show
// ============================================================
//
// Four screens, authored at the iPhone's real 402 × 874pt and rendered live
// inside `RampPhoneFrame`. They are miniatures of the app's own screens, built
// from the same tokens and carrying the same illustrative reading the rest of
// onboarding uses (Overall 66, and the five sub-scores behind it) — so the
// first thing a new user sees agrees with the reveal they get four screens
// later, instead of quietly promising a better one.

// ============================================================
// MARK: — Shared furniture
// ============================================================

/// The iOS status bar. Drawn, because these screens are never captured by the
/// system and would otherwise sit under an empty notch.
private struct IntroStatusBar: View {
    var tint: Color = RampStage.ink

    var body: some View {
        HStack {
            Text(verbatim: "9:41")
                .font(.system(size: 15, weight: .semibold))
            Spacer()
            HStack(spacing: 5) {
                Image(systemName: "cellularbars").font(.system(size: 12, weight: .semibold))
                Image(systemName: "wifi").font(.system(size: 12, weight: .semibold))
                Image(systemName: "battery.75").font(.system(size: 15, weight: .regular))
            }
        }
        .foregroundStyle(tint)
        .padding(.horizontal, 30)
        .padding(.top, 18)
        .frame(height: 62, alignment: .top)
    }
}

/// The app's real tab bar — Home, Routine, Progress.
private struct IntroTabBar: View {
    /// 0 Home · 1 Routine · 2 Progress.
    var active: Int

    private let items: [(String, String)] = [
        ("Home", "house.fill"),
        ("Routine", "checklist"),
        ("Progress", "chart.line.uptrend.xyaxis"),
    ]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(items.indices, id: \.self) { i in
                VStack(spacing: 5) {
                    Image(systemName: items[i].1).font(.system(size: 20, weight: .medium))
                    Text(verbatim: items[i].0).font(.system(size: 11, weight: .medium))
                }
                .foregroundStyle(i == active ? RampStage.accentDeep : RampStage.inkFaint)
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.top, 12)
        .padding(.bottom, 34)
        .background(alignment: .top) {
            Rectangle().fill(RampStage.hair).frame(height: 1)
        }
        .background(Color.white)
    }
}

/// Section eyebrow: uppercase, tracked, quiet.
private struct IntroEyebrow: View {
    let text: String

    var body: some View {
        Text(verbatim: text)
            .font(.system(size: 11, weight: .semibold))
            .tracking(1.4)
            .foregroundStyle(RampStage.inkFaint)
    }
}

// ============================================================
// MARK: — 1 · Home, with the score
// ============================================================

/// The results screen: the captured avatar, the honest 0–100 overall, and the
/// five sub-scores it is the average of.
struct RampIntroHomeScreen: View {
    /// Four in a 2 × 2, then the fifth across the full width. A five-item
    /// two-column grid leaves the last tile stranded beside a hole, and at
    /// mockup scale that hole is the first thing the eye finds.
    private let paired: [(String, Int)] = [
        ("Glow", 69), ("Hydration", 63), ("Texture", 65), ("Redness", 61),
    ]
    private let wide: (String, Int) = ("Evenness", 68)

    var body: some View {
        VStack(spacing: 0) {
            IntroStatusBar()

            HStack {
                Text(verbatim: "SkinFix")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(RampStage.ink)
                Spacer()
                Image(systemName: "gearshape")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(RampStage.inkSoft)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 18)

            scoreCard.padding(.horizontal, 20)

            VStack(spacing: 14) {
                HStack(spacing: 14) {
                    metricTile(paired[0].0, paired[0].1)
                    metricTile(paired[1].0, paired[1].1)
                }
                HStack(spacing: 14) {
                    metricTile(paired[2].0, paired[2].1)
                    metricTile(paired[3].0, paired[3].1)
                }
                metricTile(wide.0, wide.1)
            }
            .padding(.horizontal, 20)
            .padding(.top, 14)

            planCard
                .padding(.horizontal, 20)
                .padding(.top, 14)

            Spacer(minLength: 0)

            HStack(spacing: 10) {
                Image(systemName: "clock").font(.system(size: 14, weight: .semibold))
                Text(verbatim: "Next scan in 6d 4h")
                    .font(.system(size: 14, weight: .medium))
                Spacer()
                Image(systemName: "chevron.right").font(.system(size: 12, weight: .bold))
            }
            .foregroundStyle(RampStage.accentDeep)
            .padding(.horizontal, 18)
            .frame(height: 52)
            .background(RampStage.accentSoft, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .padding(.horizontal, 20)
            .padding(.bottom, 18)

            IntroTabBar(active: 0)
        }
        .background(RampStage.porcelain)
    }

    private var scoreCard: some View {
        VStack(spacing: 16) {
            HStack(spacing: 18) {
                avatar
                VStack(alignment: .leading, spacing: 2) {
                    IntroEyebrow(text: "OVERALL")
                    HStack(alignment: .firstTextBaseline, spacing: 2) {
                        Text(verbatim: "66")
                            .font(.system(size: 46, weight: .heavy, design: .rounded))
                            .foregroundStyle(RampStage.ink)
                        Text(verbatim: "/100")
                            .font(.system(size: 17, weight: .semibold, design: .rounded))
                            .foregroundStyle(RampStage.inkFaint)
                    }
                    Text(verbatim: "Up 4 since your last scan")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(RampStage.accentDeep)
                }
                Spacer(minLength: 0)
            }

            // The gauge: 100 slim ticks, filled to the score. Reads as a
            // measurement rather than a progress bar, which is the difference
            // between "here is your reading" and "here is your loading".
            HStack(spacing: 2) {
                ForEach(0..<40, id: \.self) { i in
                    Capsule()
                        .fill(i < 26 ? RampStage.accentEdge : RampStage.hair)
                        .frame(height: i < 26 ? 14 : 9)
                }
            }
            .frame(height: 14)
        }
        .padding(20)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .rampCardShadow()
    }

    private var avatar: some View {
        Group {
            #if canImport(UIKit)
            if let ui = RampPhoto.load("SampleFace") {
                Image(uiImage: ui).resizable().scaledToFill()
            } else {
                RampStage.accentSoft
            }
            #else
            RampStage.accentSoft
            #endif
        }
        .frame(width: 84, height: 84)
        .clipShape(Circle())
        .overlay(Circle().strokeBorder(Color.white, lineWidth: 3))
        .overlay(Circle().strokeBorder(RampStage.accentSoft, lineWidth: 3).padding(-3))
    }

    /// The 14-day plan, which the rest of onboarding keeps promising — so the
    /// home screen has to show it, and it fills the hole the metric grid used
    /// to leave above the tab bar.
    private var planCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                IntroEyebrow(text: "YOUR 14-DAY PLAN")
                Spacer()
                Text(verbatim: "Day 6")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(RampStage.accentDeep)
            }
            HStack(spacing: 4) {
                ForEach(0..<14, id: \.self) { i in
                    Capsule()
                        .fill(i < 6 ? RampStage.accentEdge : RampStage.hair)
                        .frame(height: 6)
                }
            }
            Text(verbatim: "Tonight: adapalene, then ceramides")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(RampStage.inkSoft)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .rampCardShadow()
    }

    private func metricTile(_ label: String, _ value: Int) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(verbatim: label)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(RampStage.inkSoft)
            Text(verbatim: "\(value)")
                .font(.system(size: 24, weight: .heavy, design: .rounded))
                .foregroundStyle(RampStage.ink)
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(RampStage.hair.opacity(0.8))
                    Capsule()
                        .fill(RampStage.accent)
                        .overlay(Capsule().strokeBorder(RampStage.accentEdge, lineWidth: 1))
                        .frame(width: proxy.size.width * CGFloat(value) / 100)
                }
            }
            .frame(height: 5)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .rampCardShadow()
    }
}

// ============================================================
// MARK: — 2 · The scan, mid-read
// ============================================================

/// The capture screen mid-read: the scan line crossing the face. This is the
/// screen the whole product rests on, so it is the one that gets the big phone
/// in the middle of the trio — and it is kept clear of overlays for the same
/// reason. Anything floating on top competes with the face it is reading.
struct RampIntroScanScreen: View {
    var body: some View {
        ZStack {
            portrait
            // The capture screen dims the frame so the mesh reads white on it —
            // on a bright portrait the wireframe otherwise disappears.
            LinearGradient(colors: [.black.opacity(0.42), .black.opacity(0.10),
                                    .black.opacity(0.16), .black.opacity(0.58)],
                           startPoint: .top, endPoint: .bottom)

            RampScanLine()

            VStack(spacing: 0) {
                IntroStatusBar(tint: .white)
                Spacer()
                viewfinderHint
            }
        }
        .frame(width: 402, height: 874)
        .background(Color(hex: "2A2622"))
    }

    private var portrait: some View {
        Group {
            #if canImport(UIKit)
            if let ui = RampPhoto.load("SampleFace") {
                Image(uiImage: ui).resizable().scaledToFill()
            } else {
                fallbackPortrait
            }
            #else
            fallbackPortrait
            #endif
        }
        .frame(width: 402, height: 874)
        .clipped()
    }

    /// Warm studio wash, so the screen still reads as a camera looking at a
    /// person before any photo has been dropped in.
    private var fallbackPortrait: some View {
        ZStack {
            LinearGradient(colors: [Color(hex: "5C5148"), Color(hex: "3A332C")],
                           startPoint: .top, endPoint: .bottom)
            Ellipse()
                .fill(RadialGradient(colors: [Color(hex: "C8A98C"), Color(hex: "8A7259")],
                                     center: .center, startRadius: 10, endRadius: 220))
                .frame(width: 300, height: 400)
                .offset(y: -40)
                .blur(radius: 22)
        }
    }

    private var viewfinderHint: some View {
        VStack(spacing: 12) {
            Text(verbatim: "Hold still — reading seven metrics")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.white.opacity(0.86))
            HStack(spacing: 8) {
                Image(systemName: "sparkles").font(.system(size: 12, weight: .bold))
                Text(verbatim: "SkinFix · Face scan")
                    .font(.system(size: 13, weight: .semibold))
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .frame(height: 38)
            .background(.white.opacity(0.16), in: Capsule())
            .overlay(Capsule().strokeBorder(.white.opacity(0.30), lineWidth: 1))
        }
        .padding(.bottom, 44)
    }
}

// ============================================================
// MARK: — 3 · The routine
// ============================================================

/// "Today", laid out exactly like `DermiqRoutineTab`'s real block cards: a
/// day/steps header, then Morning and Evening as their own cards — an icon
/// square, a done-count, and numbered rows that turn into a filled green
/// check as they're completed. Matches the real screen closely enough that
/// this mockup and the tab a new user lands on later read as the same app.
struct RampIntroRoutineScreen: View {
    private struct Step {
        let name: String
        let time: String
        let active: String
        var freq: String? = nil
        let done: Bool
    }

    private let morning: [Step] = [
        Step(name: "Gentle cleanser", time: "8:00", active: "Ceramides", done: true),
        Step(name: "Niacinamide 5%", time: "8:02", active: "Niacinamide", done: true),
        Step(name: "Moisturiser", time: "8:05", active: "Squalane", done: false),
        Step(name: "SPF 50", time: "8:08", active: "Mineral filter", done: false),
    ]
    private let evening: [Step] = [
        Step(name: "Gentle cleanser", time: "21:00", active: "Ceramides", done: false),
        Step(name: "Adapalene 0.1%", time: "21:05", active: "Retinoid", freq: "3× / week", done: false),
        Step(name: "Moisturiser", time: "21:15", active: "Squalane", done: false),
    ]

    private var doneCount: Int { morning.filter(\.done).count + evening.filter(\.done).count }
    private var totalCount: Int { morning.count + evening.count }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            IntroStatusBar()

            VStack(alignment: .leading, spacing: 4) {
                Text(verbatim: "Today")
                    .font(.system(size: 28, weight: .heavy, design: .rounded))
                    .foregroundStyle(RampStage.ink)
                Text(verbatim: "Day 6 of 14 · \(doneCount) of \(totalCount) steps done")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(RampStage.inkSoft)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 18)

            VStack(spacing: 16) {
                block("Morning", icon: "sun.max.fill",
                      when: "After you wake up", time: "8:00", steps: morning)
                block("Evening", icon: "moon.stars.fill",
                      when: "Before bed", time: "21:00", steps: evening)
            }
            .padding(.horizontal, 20)

            Spacer(minLength: 0)
            IntroTabBar(active: 1)
        }
        .background(RampStage.porcelain)
    }

    private func block(_ title: String, icon: String, when: String, time: String,
                       steps: [Step]) -> some View {
        let done = steps.filter(\.done).count
        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(RampStage.inkSoft)
                    .frame(width: 44, height: 44)
                    .background(RampStage.recess, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                VStack(alignment: .leading, spacing: 1) {
                    Text(verbatim: title)
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundStyle(RampStage.ink)
                    Text(verbatim: "\(when) · \(time)")
                        .font(.system(size: 12, weight: .regular))
                        .foregroundStyle(RampStage.inkSoft)
                }
                Spacer(minLength: 0)
                Text(verbatim: "\(done)/\(steps.count)")
                    .font(.system(size: 13, weight: .bold, design: .rounded).monospacedDigit())
                    .foregroundStyle(RampStage.inkSoft)
            }

            VStack(spacing: 14) {
                ForEach(steps.indices, id: \.self) { i in stepRow(steps[i], order: i + 1) }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .rampCardShadow()
    }

    /// Done is the ONE place this mockup steps outside the accent — a filled
    /// green check, exactly like `DermiqStepRow`. Reusing the brand accent
    /// for "done" would blur it with "selected"/"in progress" elsewhere in
    /// the flow; green is unambiguous.
    private func stepRow(_ step: Step, order: Int) -> some View {
        HStack(spacing: 12) {
            ZStack {
                if step.done {
                    Circle().fill(Self.positive)
                    Image(systemName: "checkmark")
                        .font(.system(size: 11, weight: .heavy))
                        .foregroundStyle(.white)
                } else {
                    Circle().fill(RampStage.accentSoft)
                    Text(verbatim: "\(order)")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(RampStage.accentDeep)
                }
            }
            .frame(width: 26, height: 26)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(verbatim: step.name)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(step.done ? RampStage.inkFaint : RampStage.ink)
                        .strikethrough(step.done, color: RampStage.inkFaint)
                    if let freq = step.freq {
                        Text(verbatim: freq)
                            .font(.system(size: 9.5, weight: .bold, design: .rounded))
                            .foregroundStyle(RampStage.accentDeep)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(RampStage.accentSoft, in: Capsule())
                    }
                }
                Text(verbatim: "\(step.time) · \(step.active)")
                    .font(.system(size: 12, weight: .regular))
                    .foregroundStyle(RampStage.inkFaint)
            }
            Spacer(minLength: 0)
        }
    }

    /// Success green — the same role `DQColor.deltaUp` plays in the real app:
    /// never the brand accent, always this one semantic colour.
    static let positive = Color(hex: "1F9D6B")
}

// ============================================================
// MARK: — 4 · Progress
// ============================================================

/// Laid out like the real `DermiqProgressTab`: a plain "Progress" title (no
/// decoration competing with it), the score-over-time chart with its green
/// delta line, the scan timeline, then per-metric detail bars. Same section
/// eyebrows, same green-for-"this improved" semantic the real tab uses.
struct RampIntroProgressScreen: View {
    /// The overall score, day 1 → day 14. Deliberately not a clean ramp: it
    /// dips on days 4 and 5, because purging is what actually happens and a
    /// chart that never dips is the one nobody believes afterwards.
    private let series: [CGFloat] = [52, 54, 53, 49, 47, 51, 55, 57, 56, 59, 62, 61, 64, 66]

    private let timeline: [(score: Int, label: String)] = [
        (72, "Today"), (67, "5 days ago"), (58, "13 days ago"),
    ]
    private let metrics: [(String, Int, Int)] = [
        ("Blemishes", 74, 9), ("Redness", 68, 6), ("Texture", 71, 3), ("Pores", 65, 2),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            IntroStatusBar()

            Text(verbatim: "Progress")
                .font(.system(size: 28, weight: .heavy, design: .rounded))
                .foregroundStyle(RampStage.ink)
                .padding(.horizontal, 24)
                .padding(.bottom, 18)

            VStack(spacing: 16) {
                chartCard
                timelineCard
                metricCard
            }
            .padding(.horizontal, 20)

            Spacer(minLength: 0)
            IntroTabBar(active: 2)
        }
        .background(RampStage.porcelain)
    }

    private var chartCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            IntroEyebrow(text: "SCORE OVER TIME")

            RampIntroSparkline(values: series)
                .frame(height: 108)

            HStack(spacing: 5) {
                Image(systemName: "arrow.up.right").font(.system(size: 11, weight: .bold))
                Text(verbatim: "+14 since your first scan")
                    .font(.system(size: 13, weight: .semibold))
            }
            .foregroundStyle(RampIntroRoutineScreen.positive)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .rampCardShadow()
    }

    /// The real tab's timeline is a bare photo strip; this mockup carries the
    /// score on the card, so the one photo bundled with onboarding still
    /// reads as three distinct readings rather than one picture repeated.
    private var timelineCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            IntroEyebrow(text: "SCAN TIMELINE")
            HStack(spacing: 10) {
                ForEach(timeline.indices, id: \.self) { i in timelineTile(timeline[i]) }
            }
            Text(verbatim: "Tap any two scans to compare them side by side.")
                .font(.system(size: 11.5, weight: .regular))
                .foregroundStyle(RampStage.inkSoft)
        }
    }

    private func timelineTile(_ entry: (score: Int, label: String)) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            avatarPhoto.frame(height: 78).clipped()
            VStack(alignment: .leading, spacing: 1) {
                Text(verbatim: "\(entry.score)")
                    .font(.system(size: 17, weight: .heavy, design: .rounded))
                    .foregroundStyle(RampStage.ink)
                Text(verbatim: entry.label)
                    .font(.system(size: 10.5, weight: .medium))
                    .foregroundStyle(RampStage.inkSoft)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .rampCardShadow()
    }

    private var avatarPhoto: some View {
        Group {
            #if canImport(UIKit)
            if let ui = RampPhoto.load("SampleFace") {
                Image(uiImage: ui).resizable().scaledToFill()
            } else {
                RampStage.accentSoft
            }
            #else
            RampStage.accentSoft
            #endif
        }
    }

    private var metricCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            IntroEyebrow(text: "METRIC DETAIL")
            ForEach(metrics.indices, id: \.self) { i in
                let (label, value, delta) = metrics[i]
                VStack(alignment: .leading, spacing: 7) {
                    HStack {
                        Text(verbatim: label)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(RampStage.ink)
                        Spacer()
                        Text(verbatim: "+\(delta)")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundStyle(RampIntroRoutineScreen.positive)
                    }
                    GeometryReader { proxy in
                        ZStack(alignment: .leading) {
                            Capsule().fill(RampStage.hair)
                            Capsule()
                                .fill(RampStage.accentEdge)
                                .frame(width: proxy.size.width * CGFloat(value) / 100)
                        }
                    }
                    .frame(height: 6)
                }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .rampCardShadow()
    }
}

/// The score line, with its area filled and every reading dotted.
private struct RampIntroSparkline: View {
    let values: [CGFloat]

    var body: some View {
        GeometryReader { proxy in
            let w = proxy.size.width, h = proxy.size.height
            let lo = (values.min() ?? 0) - 6, hi = (values.max() ?? 100) + 6
            let points = values.indices.map { i -> CGPoint in
                CGPoint(x: w * CGFloat(i) / CGFloat(max(values.count - 1, 1)),
                        y: h - (values[i] - lo) / max(hi - lo, 1) * h)
            }

            ZStack {
                Path { p in
                    guard let first = points.first else { return }
                    p.move(to: CGPoint(x: first.x, y: h))
                    points.forEach { p.addLine(to: $0) }
                    p.addLine(to: CGPoint(x: points[points.count - 1].x, y: h))
                    p.closeSubpath()
                }
                .fill(LinearGradient(colors: [RampStage.accent.opacity(0.55), .clear],
                                     startPoint: .top, endPoint: .bottom))

                Path { p in
                    guard let first = points.first else { return }
                    p.move(to: first)
                    points.dropFirst().forEach { p.addLine(to: $0) }
                }
                .stroke(RampStage.accentEdge,
                        style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))

                // Every reading gets the same open ring — white centre, coloured
                // edge — the last one just bigger, so the eye lands on "now"
                // without the line looking like it stops at a solid dot.
                ForEach(points.indices, id: \.self) { i in
                    let isLast = i == points.count - 1
                    Circle()
                        .fill(Color.white)
                        .overlay(Circle().strokeBorder(RampStage.accentEdge, lineWidth: isLast ? 2.5 : 1.5))
                        .frame(width: isLast ? 13 : 6, height: isLast ? 13 : 6)
                        .position(points[i])
                }
            }
        }
    }
}

#Preview("Home") { RampPhoneFrame(width: 260) { RampIntroHomeScreen() } }
#Preview("Scan") { RampPhoneFrame(width: 260) { RampIntroScanScreen() } }
#Preview("Routine") { RampPhoneFrame(width: 260) { RampIntroRoutineScreen() } }
#Preview("Progress") { RampPhoneFrame(width: 260) { RampIntroProgressScreen() } }
