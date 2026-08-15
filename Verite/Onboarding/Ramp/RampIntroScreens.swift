import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

// ============================================================
// MARK: — What the mockups show
// ============================================================
//
// Four screens, authored at the iPhone's real 402 × 874pt and rendered live
// inside `RampPhoneFrame`. They are miniatures of the app's own screens, and
// the word that matters is MIRROR: each one is laid out against its real
// counterpart —
//
//   RampIntroReadingScreen  ← DermiqResultsView
//   RampIntroScanScreen     ← DermiqCaptureView
//   RampIntroRoutineScreen  ← DermiqRoutineTab
//   RampIntroProgressScreen ← DermiqProgressTab
//
// — same titles, same section eyebrows, same card shapes, same tokens. They
// drifted once already, into plausible-looking screens that existed nowhere
// in the product, which is the failure mode to watch for: a carousel whose
// entire argument is "this is what you get" cannot show something the user
// will never reach. When one of the real screens above is restructured, the
// mirror here is part of that change, not a follow-up.
//
// They also carry the same illustrative reading the rest of onboarding uses
// (Overall 66, and the sub-scores that average to it) — so the first thing a
// new user sees agrees with the reveal they get a few screens later, instead
// of quietly promising a better one.

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
// MARK: — 1 · Your reading
// ============================================================

/// The reading screen, rebuilt to mirror `DermiqResultsView` — the actual
/// screen this carousel is selling. Same title and standfirst, same Now ⇄
/// In 14 days segmented control, the same captured avatar straddling the
/// top of a two-column metric card, the same standing card and the same
/// "Glow me up" CTA underneath.
///
/// It used to be a different screen entirely: a "SkinFix" app-bar, a tick
/// gauge, a 2×2 of tiles and a plan strip — a plausible dashboard that
/// existed nowhere in the app. A carousel whose whole argument is "this is
/// what you get" cannot show a screen the user will never reach.
///
/// TWO NUMBERS ARE NOT FREE HERE, and both are derived rather than picked:
///
///  · The seven sub-scores average to exactly 66, because Overall IS their
///    average in the real engine and `RampSampleReadingScreen` shows 66 four
///    screens later. A mockup that quietly showed a prettier reading than
///    the one the flow goes on to promise is the one lie this file can tell
///    without anybody noticing.
///  · "Top 42%" is `DermiqPercentile.topPercent(overall: 66)` evaluated by
///    hand — the app's own documented distribution (mean 63, sd 14). Recompute
///    it if the reading above ever changes; do not round it for looks.
struct RampIntroReadingScreen: View {
    /// Overall leads, then every sub-score — the real grid order.
    private let overall = 66
    private let subScores: [(String, Int)] = [
        ("Blemishes", 66), ("Redness", 61), ("Texture", 65),
        ("Pores", 70), ("Evenness", 68), ("Hydration", 63), ("Glow", 69),
    ]

    private let columns = [GridItem(.flexible(), spacing: 18),
                           GridItem(.flexible(), spacing: 18)]

    var body: some View {
        VStack(spacing: 0) {
            IntroStatusBar()

            VStack(spacing: 5) {
                Text(verbatim: "Your reading")
                    .font(.system(size: 26, weight: .heavy, design: .rounded))
                    .foregroundStyle(RampStage.ink)
                Text(verbatim: "A reading of you — with your 14-day potential.")
                    .font(.system(size: 15, weight: .regular))
                    .foregroundStyle(RampStage.inkSoft)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 24)

            modeSwitch
                .padding(.top, 14)

            gridCard
                .padding(.horizontal, 20)

            standingCard
                .padding(.horizontal, 20)
                .padding(.top, 12)

            Spacer(minLength: 0)

            HStack(spacing: 8) {
                Image(systemName: "sparkles").font(.system(size: 15, weight: .bold))
                Text(verbatim: "Glow me up")
                    .font(.system(size: 17, weight: .bold, design: .rounded))
            }
            .foregroundStyle(Color.white)
            .frame(maxWidth: .infinity, minHeight: 56)
            .background(RampPrimaryButton.fill,
                        in: RoundedRectangle(cornerRadius: 26, style: .continuous))
            .shadow(color: RampStage.accentDeep.opacity(0.34), radius: 18, y: 8)
            .padding(.horizontal, 20)

            Text(verbatim: "Done")
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .foregroundStyle(RampStage.inkSoft)
                .padding(.top, 12)
                .padding(.bottom, 26)
        }
        .background(RampStage.porcelain)
    }

    /// The iOS-style segmented toggle, with the white pill parked on "Now".
    private var modeSwitch: some View {
        HStack(spacing: 4) {
            segment("Now", active: true)
            segment("In 14 days", active: false)
        }
        .padding(4)
        .background(RampStage.accentSoft, in: Capsule())
        .frame(maxWidth: 300)
    }

    private func segment(_ title: String, active: Bool) -> some View {
        Text(verbatim: title)
            .font(.system(size: 15, weight: .bold, design: .rounded))
            .foregroundStyle(active ? RampStage.accentDeep : RampStage.inkSoft)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 9)
            .background {
                if active {
                    Capsule()
                        .fill(Color.white)
                        .shadow(color: RampStage.accentEdge.opacity(0.18), radius: 6, y: 2)
                }
            }
    }

    private var gridCard: some View {
        ZStack(alignment: .top) {
            VStack(spacing: 12) {
                LazyVGrid(columns: columns, alignment: .leading, spacing: 14) {
                    metricCell("Overall", overall, lead: true)
                    ForEach(subScores.indices, id: \.self) { i in
                        metricCell(subScores[i].0, subScores[i].1, lead: false)
                    }
                }
                // The reading key. Without it "Blemishes 66" reads as a count
                // of blemishes rather than a score — the real card carries the
                // same line for the same reason.
                HStack(spacing: 5) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(RampStage.accentDeep)
                    Text(verbatim: "Every score runs 0–100 — higher is always better.")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(RampStage.inkSoft)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 18)
            .padding(.top, 70)
            .padding(.bottom, 18)
            .frame(maxWidth: .infinity)
            .background(Color.white, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 26, style: .continuous)
                .strokeBorder(RampStage.ink.opacity(0.08), lineWidth: 1))

            avatar.offset(y: -54)
        }
        .padding(.top, 54)
    }

    private func metricCell(_ label: String, _ value: Int, lead: Bool) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(verbatim: label)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(RampStage.inkSoft)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Text(verbatim: "\(value)")
                .font(.system(size: 24, weight: .heavy, design: .rounded).monospacedDigit())
                .foregroundStyle(lead ? RampStage.accentDeep : RampStage.ink)
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(RampStage.ink.opacity(0.08))
                    Capsule().fill(RampStage.accentEdge)
                        .frame(width: proxy.size.width * CGFloat(value) / 100)
                }
            }
            .frame(height: 6)
        }
    }

    /// The user's own capture, ringed — the proof the reading is about them.
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
        .frame(width: 108, height: 108)
        .clipShape(Circle())
        .overlay(Circle().strokeBorder(Color.white, lineWidth: 4))
        .overlay(Circle().strokeBorder(RampStage.accentSoft, lineWidth: 4).padding(-4))
        .shadow(color: RampStage.accentEdge.opacity(0.28), radius: 14, y: 8)
    }

    private var standingCard: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(verbatim: "YOUR STANDING")
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .tracking(2)
                    .foregroundStyle(RampStage.accentDeep)
                Spacer()
                // The estimate label is not decoration: this number is mapped
                // from a documented distribution, not a live ranking, and the
                // real card is required to say so wherever it appears.
                Text(verbatim: "est.")
                    .font(.system(size: 9, weight: .semibold, design: .monospaced))
                    .foregroundStyle(RampStage.inkSoft)
            }
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(verbatim: "Top 42%")
                    .font(.system(size: 34, weight: .heavy, design: .rounded).monospacedDigit())
                    .foregroundStyle(RampStage.accentDeep)
                Spacer()
                Image(systemName: "flame.fill")
                    .font(.system(size: 17))
                    .foregroundStyle(RampStage.accentDeep)
            }
            Text(verbatim: "Your strongest: Pores · Top 31%")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(RampStage.inkSoft)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .rampCardShadow()
    }
}

// ============================================================
// MARK: — 2 · The scan, mid-read
// ============================================================

/// The capture screen mid-read: the scan line crossing the face, with the
/// real shutter and gallery-import control from `DermiqCaptureView` under it.
/// This is the screen the whole product rests on, so it gets the big phone in
/// the middle of the trio.
///
/// The controls earn their place despite the "keep it clear of overlays"
/// instinct: without a shutter this reads as a photo with a line drawn over
/// it rather than as a camera about to fire. Everything else stays off — the
/// live quality checklist in particular, which is five rows tall and would
/// bury the face this screen exists to show.
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
                captureControls
            }
        }
        .frame(width: 402, height: 874)
        .background(Color(hex: "2A2622"))
    }

    /// Shutter centred, gallery import bottom-right — the real capture
    /// screen's layout, drawn in its all-conditions-pass state.
    private var captureControls: some View {
        ZStack {
            ZStack {
                Circle()
                    .stroke(RampStage.accentEdge, lineWidth: 3)
                    .frame(width: 76, height: 76)
                Circle()
                    .fill(RampPrimaryButton.fill)
                    .frame(width: 62, height: 62)
            }
            .shadow(color: RampStage.accentEdge.opacity(0.45), radius: 18)

            HStack {
                Spacer()
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.7))
                        .frame(width: 52, height: 52)
                    Image(systemName: "photo.on.rectangle")
                        .font(.system(size: 19, weight: .semibold))
                        .foregroundStyle(RampStage.ink)
                }
            }
            .padding(.trailing, 34)
        }
        .padding(.bottom, 34)
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
        .padding(.bottom, 26)
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

#Preview("Reading") { RampPhoneFrame(width: 260) { RampIntroReadingScreen() } }
#Preview("Scan") { RampPhoneFrame(width: 260) { RampIntroScanScreen() } }
#Preview("Routine") { RampPhoneFrame(width: 260) { RampIntroRoutineScreen() } }
#Preview("Progress") { RampPhoneFrame(width: 260) { RampIntroProgressScreen() } }
