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
            .background(RampStage.accent.opacity(0.16),
                        in: RoundedRectangle(cornerRadius: 16, style: .continuous))
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
        .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous)
            .strokeBorder(RampStage.hairline, lineWidth: 1))
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
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous)
            .strokeBorder(RampStage.hairline, lineWidth: 1))
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
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous)
            .strokeBorder(RampStage.hairline, lineWidth: 1))
    }
}

// ============================================================
// MARK: — 2 · The scan, mid-read
// ============================================================

/// The capture screen with the mesh live on the face and the three analysis
/// passes ticking over. This is the screen the whole product rests on, so it
/// is the one that gets the big phone in the middle of the trio.
struct RampIntroScanScreen: View {
    /// Where the face sits once the portrait has been cropped to fill 402 ×
    /// 874. Measured off `SampleFace` rather than guessed: the box runs
    /// hairline → chin and temple → temple, and it was solved from two
    /// landmarks that are easy to read off any portrait — the pupil line (the
    /// mesh puts it at v 0.39) and the bottom of the chin (v 1.0). Swap the
    /// photo and re-solving those two is the whole job.
    var faceRect: CGRect = CGRect(x: 0.115, y: 0.203, width: 0.716, height: 0.467)

    private let passes: [(String, Bool)] = [
        ("Reading your skin", true),
        ("Finding what drives it", true),
        ("Building your plan", false),
    ]

    var body: some View {
        ZStack {
            portrait
            // The capture screen dims the frame so the mesh reads white on it —
            // on a bright portrait the wireframe otherwise disappears.
            LinearGradient(colors: [.black.opacity(0.42), .black.opacity(0.10),
                                    .black.opacity(0.16), .black.opacity(0.58)],
                           startPoint: .top, endPoint: .bottom)

            RampFaceMesh(faceRect: faceRect)

            VStack(spacing: 0) {
                IntroStatusBar(tint: .white)
                passList
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

    /// The three passes, stacked top-left: two landed, one still spinning.
    private var passList: some View {
        VStack(spacing: 8) {
            ForEach(passes.indices, id: \.self) { i in
                HStack(spacing: 10) {
                    Text(verbatim: passes[i].0)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.white)
                    Spacer(minLength: 12)
                    if passes[i].1 {
                        Image(systemName: "checkmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(.white)
                    } else {
                        Circle()
                            .trim(from: 0, to: 0.7)
                            .stroke(.white, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                            .frame(width: 13, height: 13)
                    }
                }
                .padding(.horizontal, 16)
                .frame(height: 40)
                .background(.black.opacity(0.34), in: Capsule())
                .overlay(Capsule().strokeBorder(.white.opacity(0.22), lineWidth: 1))
            }
        }
        .frame(width: 250)
        .padding(.top, 6)
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

/// Morning and evening, as the app builds them: named steps, the ones already
/// done ticked off.
struct RampIntroRoutineScreen: View {
    private let morning: [(String, String, Bool)] = [
        ("Gentle gel cleanser", "Lukewarm water, 30 seconds", true),
        ("Niacinamide 10%", "Three drops, press in", true),
        ("SPF 50 fluid", "Two fingers, every morning", false),
    ]
    private let evening: [(String, String, Bool)] = [
        ("Double cleanse", "Oil first, then the gel", true),
        ("Adapalene 0.1%", "Pea-sized, alternate nights", false),
        ("Ceramide moisturiser", "Seal everything in", false),
    ]
    /// A third section, because a routine is not only twice a day — and
    /// because two sections left a third of this screen empty.
    private let weekly: [(String, String, Bool)] = [
        ("Gentle exfoliant", "Sundays, after cleansing", false),
    ]

    var body: some View {
        VStack(spacing: 0) {
            IntroStatusBar()

            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(verbatim: "Your routine")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundStyle(RampStage.ink)
                    Text(verbatim: "3 of 6 done today")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(RampStage.inkSoft)
                }
                Spacer()
                ZStack {
                    Circle().stroke(RampStage.hair, lineWidth: 5)
                    Circle().trim(from: 0, to: 0.5)
                        .stroke(RampStage.accentEdge,
                                style: StrokeStyle(lineWidth: 5, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    Text(verbatim: "50%")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(RampStage.accentDeep)
                }
                .frame(width: 52, height: 52)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 20)

            VStack(alignment: .leading, spacing: 18) {
                section("MORNING", icon: "sun.max.fill", steps: morning)
                section("EVENING", icon: "moon.stars.fill", steps: evening)
                section("WEEKLY", icon: "calendar", steps: weekly)
            }
            .padding(.horizontal, 20)

            Spacer(minLength: 0)
            IntroTabBar(active: 1)
        }
        .background(RampStage.porcelain)
    }

    private func section(_ title: String, icon: String,
                         steps: [(String, String, Bool)]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 7) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(RampStage.accentDeep)
                IntroEyebrow(text: title)
            }
            VStack(spacing: 0) {
                ForEach(steps.indices, id: \.self) { i in
                    if i > 0 {
                        Rectangle().fill(RampStage.hair).frame(height: 1).padding(.leading, 56)
                    }
                    stepRow(steps[i])
                }
            }
            .background(Color.white, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(RampStage.hairline, lineWidth: 1))
        }
    }

    private func stepRow(_ step: (String, String, Bool)) -> some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(step.2 ? RampStage.accentEdge : Color.clear)
                    .overlay(Circle().strokeBorder(step.2 ? RampStage.accentEdge : RampStage.hair,
                                                   lineWidth: 1.5))
                if step.2 {
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .heavy))
                        .foregroundStyle(.white)
                }
            }
            .frame(width: 26, height: 26)

            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: step.0)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(step.2 ? RampStage.inkFaint : RampStage.ink)
                    .strikethrough(step.2, color: RampStage.inkFaint)
                Text(verbatim: step.1)
                    .font(.system(size: 12, weight: .regular))
                    .foregroundStyle(RampStage.inkFaint)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .frame(height: 62)
    }
}

// ============================================================
// MARK: — 4 · The evolution
// ============================================================

/// Fourteen days of readings, and the photos behind them.
struct RampIntroProgressScreen: View {
    /// The overall score, day 1 → day 14. Deliberately not a clean ramp: it
    /// dips on days 4 and 5, because purging is what actually happens and a
    /// chart that never dips is the one nobody believes afterwards.
    private let series: [CGFloat] = [52, 54, 53, 49, 47, 51, 55, 57, 56, 59, 62, 61, 64, 66]

    var body: some View {
        VStack(spacing: 0) {
            IntroStatusBar()

            HStack {
                Text(verbatim: "Your evolution")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundStyle(RampStage.ink)
                Spacer()
                Text(verbatim: "14 days")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(RampStage.accentDeep)
                    .padding(.horizontal, 12)
                    .frame(height: 30)
                    .background(RampStage.accent.opacity(0.18), in: Capsule())
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 18)

            chartCard.padding(.horizontal, 20)
            movedCard.padding(.horizontal, 20).padding(.top, 14)
            calendarCard.padding(.horizontal, 20).padding(.top, 14)

            Spacer(minLength: 0)
            IntroTabBar(active: 2)
        }
        .background(RampStage.porcelain)
    }

    private var chartCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(verbatim: "66")
                    .font(.system(size: 32, weight: .heavy, design: .rounded))
                    .foregroundStyle(RampStage.ink)
                Text(verbatim: "overall")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(RampStage.inkSoft)
                Spacer()
                HStack(spacing: 3) {
                    Image(systemName: "arrow.up.right").font(.system(size: 11, weight: .bold))
                    Text(verbatim: "+14")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                }
                .foregroundStyle(RampStage.accentDeep)
            }

            RampIntroSparkline(values: series)
                .frame(height: 96)

            HStack {
                Text(verbatim: "DAY 1").font(.system(size: 10, weight: .semibold))
                Spacer()
                Text(verbatim: "DAY 14").font(.system(size: 10, weight: .semibold))
            }
            .tracking(1.2)
            .foregroundStyle(RampStage.inkFaint)
        }
        .padding(20)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous)
            .strokeBorder(RampStage.hairline, lineWidth: 1))
    }

    /// The page's headline promises this screen "shows you what actually
    /// moved", so it has to be on it. The deltas are uneven on purpose:
    /// hydration answers fast, texture barely budges in two weeks.
    private var movedCard: some View {
        let moved: [(String, Int)] = [("Hydration", 9), ("Glow", 7),
                                      ("Redness", 5), ("Texture", 3)]
        return VStack(alignment: .leading, spacing: 12) {
            IntroEyebrow(text: "WHAT MOVED")
            ForEach(moved.indices, id: \.self) { i in
                HStack(spacing: 12) {
                    Text(verbatim: moved[i].0)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(RampStage.inkSoft)
                        .frame(width: 78, alignment: .leading)
                    GeometryReader { proxy in
                        ZStack(alignment: .leading) {
                            Capsule().fill(RampStage.hair.opacity(0.8))
                            Capsule()
                                .fill(RampStage.accent)
                                .overlay(Capsule().strokeBorder(RampStage.accentEdge, lineWidth: 1))
                                .frame(width: proxy.size.width * CGFloat(moved[i].1) / 12)
                        }
                    }
                    .frame(height: 6)
                    Text(verbatim: "+\(moved[i].1)")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(RampStage.accentDeep)
                        .frame(width: 28, alignment: .trailing)
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous)
            .strokeBorder(RampStage.hairline, lineWidth: 1))
    }

    private var calendarCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                IntroEyebrow(text: "PHOTO CALENDAR")
                Spacer()
                Text(verbatim: "March")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(RampStage.inkSoft)
            }
            // Fourteen scanned days, then the rest of the month still open.
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 7), count: 7),
                      spacing: 7) {
                ForEach(0..<21, id: \.self) { i in
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(i < 14 ? RampStage.accent : RampStage.recess)
                        .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .strokeBorder(i < 14 ? RampStage.accentEdge : RampStage.hair,
                                          lineWidth: 1))
                        .overlay {
                            if i == 13 {
                                Image(systemName: "camera.fill")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundStyle(RampStage.accentDeep)
                            }
                        }
                        .aspectRatio(1, contentMode: .fit)
                }
            }
        }
        .padding(20)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous)
            .strokeBorder(RampStage.hairline, lineWidth: 1))
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

                ForEach(points.indices, id: \.self) { i in
                    Circle()
                        .fill(i == points.count - 1 ? RampStage.accentDeep : Color.white)
                        .overlay(Circle().strokeBorder(RampStage.accentEdge, lineWidth: 1.5))
                        .frame(width: i == points.count - 1 ? 11 : 6,
                               height: i == points.count - 1 ? 11 : 6)
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
