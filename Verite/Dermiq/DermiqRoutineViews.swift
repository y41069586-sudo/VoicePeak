import SwiftUI
import SwiftData
import StoreKit

// ============================================================
// MARK: — Screen 6: Routine Generation (2s transition)
// ============================================================

/// The plan builds as a JOURNEY: a smooth route draws itself down the screen,
/// day stations check in as the line passes them — slow over the first days,
/// then accelerating — and day 14 lands with a checkered flag. Same honest
/// content (a 14-day plan being laid out), staged as the road ahead.
struct DermiqRoutineGenView: View {
    let model: ScanFlowModel
    let onDone: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var progress: CGFloat = 0
    @State private var reachedCount = 0
    @State private var ready = false

    /// The day stations along the route (last = finish).
    private static let days = [1, 3, 7, 10, 14]
    /// Per-leg travel time — the route ACCELERATES toward day 14.
    private static let legDurations: [Double] = [0.85, 0.70, 0.45, 0.32]

    var body: some View {
        VStack(spacing: 0) {
            Spacer().frame(height: 40)

            VStack(spacing: 8) {
                Text("BUILT FROM YOUR SCAN")
                    .font(DQFont.mono(11, weight: .semibold))
                    .foregroundStyle(DQColor.accentBright)
                    .tracking(3)
                Text(ready ? "Your plan is ready" : "Building your\n14-day plan")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(DQColor.textPrimary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)
                    .padding(.horizontal, 24)
                    .contentTransition(.opacity)
                    .animation(VMotion.gentle, value: ready)
            }

            PlanRouteView(progress: progress,
                          reachedCount: reachedCount,
                          days: Self.days,
                          finished: ready)
                .padding(.horizontal, 36)
                .padding(.vertical, 10)

            // One quiet line instead of the old "BUILT FROM" receipt card —
            // the plan reads ALL seven metrics now, not a shortlist.
            Text("Built from all seven of your readings.")
                .font(DQFont.micro)
                .foregroundStyle(DQColor.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
                .padding(.bottom, 40)
        }
        .background(DQColor.background.ignoresSafeArea())
        .task { await travel() }
    }

    /// Drives the trip: hold for the screen entrance, pop day 1, then run the
    /// legs with rising speed; day 14 lands with the milestone pulse.
    private func travel() async {
        if reduceMotion {
            progress = 1
            reachedCount = Self.days.count
            ready = true
            try? await Task.sleep(for: .milliseconds(900))
            if !Task.isCancelled { onDone() }
            return
        }

        // Let the screen's own crossfade land before the route moves.
        try? await Task.sleep(for: .milliseconds(450))
        guard !Task.isCancelled else { return }
        reachedCount = 1                                  // Day 1 — checked.
        Haptics.fire(.tick)

        let fractions = PlanRoute.nodeFractions
        for leg in 0..<Self.legDurations.count {
            let duration = Self.legDurations[leg]
            withAnimation(.easeInOut(duration: duration)) {
                progress = fractions[leg + 1]
            }
            try? await Task.sleep(for: .milliseconds(Int(duration * 1000)))
            guard !Task.isCancelled else { return }
            reachedCount = leg + 2
            Haptics.fire(leg == Self.legDurations.count - 1 ? .milestone : .tick)
        }

        withAnimation(VMotion.snappy) { ready = true }
        try? await Task.sleep(for: .milliseconds(950))
        guard !Task.isCancelled else { return }
        onDone()
    }
}

// ============================================================
// MARK: — The route (path + day stations)
// ============================================================

/// Geometry of the journey: waypoints snake down the canvas (right → left →
/// right → left → finish), smoothed with Catmull-Rom and sampled into a
/// polyline so trim-by-length and node fractions line up exactly.
private enum PlanRoute {

    /// Relative waypoints, top to bottom. One per day station. The x extremes
    /// stay off the edges so each day label has room on the OUTER side of its
    /// node (away from the snaking line, which never reaches past a turn).
    static let waypoints: [CGPoint] = [
        CGPoint(x: 0.68, y: 0.06),   // Day 1
        CGPoint(x: 0.30, y: 0.30),   // Day 3
        CGPoint(x: 0.70, y: 0.54),   // Day 7
        CGPoint(x: 0.30, y: 0.78),   // Day 10
        CGPoint(x: 0.58, y: 0.94),   // Day 14 — finish
    ]

    /// Catmull-Rom through the waypoints, sampled densely (normalized space).
    static let samples: [CGPoint] = {
        var result: [CGPoint] = []
        let pts = waypoints
        let n = pts.count
        for i in 0..<(n - 1) {
            let p0 = pts[max(i - 1, 0)]
            let p1 = pts[i]
            let p2 = pts[i + 1]
            let p3 = pts[min(i + 2, n - 1)]
            let steps = 28
            for s in 0..<steps {
                let t = CGFloat(s) / CGFloat(steps)
                result.append(catmullRom(p0, p1, p2, p3, t))
            }
        }
        result.append(pts[n - 1])
        return result
    }()

    /// Cumulative normalized arc length at every sample.
    static let cumulative: [CGFloat] = {
        var out: [CGFloat] = [0]
        for i in 1..<samples.count {
            let dx = samples[i].x - samples[i - 1].x
            let dy = samples[i].y - samples[i - 1].y
            out.append(out[i - 1] + (dx * dx + dy * dy).squareRoot())
        }
        return out
    }()

    /// Arc-length fraction (0…1) at each waypoint — the animation targets.
    static let nodeFractions: [CGFloat] = {
        let total = cumulative.last ?? 1
        let perSegment = 28
        return (0..<waypoints.count).map { i in
            let index = min(i * perSegment, cumulative.count - 1)
            return cumulative[index] / total
        }
    }()

    /// Point on the route at arc-length fraction `f`, scaled to `size`.
    static func point(at f: CGFloat, in size: CGSize) -> CGPoint {
        let total = cumulative.last ?? 1
        let target = max(0, min(1, f)) * total
        var i = 1
        while i < cumulative.count - 1, cumulative[i] < target { i += 1 }
        let segment = cumulative[i] - cumulative[i - 1]
        let t = segment > 0 ? (target - cumulative[i - 1]) / segment : 0
        let a = samples[i - 1], b = samples[i]
        return CGPoint(x: (a.x + (b.x - a.x) * t) * size.width,
                       y: (a.y + (b.y - a.y) * t) * size.height)
    }

    private static func catmullRom(_ p0: CGPoint, _ p1: CGPoint,
                                   _ p2: CGPoint, _ p3: CGPoint,
                                   _ t: CGFloat) -> CGPoint {
        let t2 = t * t, t3 = t2 * t
        func axis(_ a: CGFloat, _ b: CGFloat, _ c: CGFloat, _ d: CGFloat) -> CGFloat {
            0.5 * ((2 * b)
                   + (-a + c) * t
                   + (2 * a - 5 * b + 4 * c - d) * t2
                   + (-a + 3 * b - 3 * c + d) * t3)
        }
        return CGPoint(x: axis(p0.x, p1.x, p2.x, p3.x),
                       y: axis(p0.y, p1.y, p2.y, p3.y))
    }
}

/// The route, trimmed by `progress`; upcoming road is a faint dashed hint.
private struct PlanRouteShape: Shape {
    var progress: CGFloat

    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let samples = PlanRoute.samples
        guard let total = PlanRoute.cumulative.last, total > 0,
              let first = samples.first else { return path }
        let target = total * max(0, min(1, progress))

        path.move(to: scaled(first, rect))
        for i in 1..<samples.count {
            let length = PlanRoute.cumulative[i]
            if length <= target {
                path.addLine(to: scaled(samples[i], rect))
            } else {
                let previous = PlanRoute.cumulative[i - 1]
                let segment = length - previous
                let t = segment > 0 ? (target - previous) / segment : 0
                if t > 0 {
                    let a = samples[i - 1], b = samples[i]
                    path.addLine(to: scaled(
                        CGPoint(x: a.x + (b.x - a.x) * t, y: a.y + (b.y - a.y) * t), rect))
                }
                break
            }
        }
        return path
    }

    private func scaled(_ p: CGPoint, _ rect: CGRect) -> CGPoint {
        CGPoint(x: rect.minX + p.x * rect.width, y: rect.minY + p.y * rect.height)
    }
}

/// Route + stations + moving tip. Pure presentation — the parent drives
/// `progress`/`reachedCount`.
private struct PlanRouteView: View {
    let progress: CGFloat
    let reachedCount: Int
    let days: [Int]
    let finished: Bool

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            ZStack {
                // The road ahead — faint, dashed.
                PlanRouteShape(progress: 1)
                    .stroke(DQColor.stroke,
                            style: StrokeStyle(lineWidth: 3, lineCap: .round, dash: [1, 10]))

                // The traveled road — solid, glowing.
                PlanRouteShape(progress: progress)
                    .stroke(DQColor.accentGradient,
                            style: StrokeStyle(lineWidth: 4.5, lineCap: .round))
                    .shadow(color: DQColor.accent.opacity(0.45), radius: 6)

                // The moving tip.
                if progress > 0.001, !finished {
                    Circle()
                        .fill(Color.white)
                        .frame(width: 13, height: 13)
                        .overlay(Circle().strokeBorder(DQColor.accent, lineWidth: 3.5))
                        .shadow(color: DQColor.accent.opacity(0.6), radius: 7)
                        .position(PlanRoute.point(at: progress, in: size))
                }

                // Day stations.
                ForEach(Array(days.enumerated()), id: \.offset) { index, day in
                    let waypoint = PlanRoute.waypoints[index]
                    let center = CGPoint(x: waypoint.x * size.width,
                                         y: waypoint.y * size.height)
                    let isFinish = index == days.count - 1
                    let reached = index < reachedCount

                    stationNode(reached: reached, finish: isFinish)
                        .position(center)

                    Text("Day \(day)")
                        .font(.system(size: 13,
                                      weight: reached ? .bold : .semibold,
                                      design: .rounded))
                        .foregroundStyle(reached ? DQColor.accentBright : DQColor.textSecondary)
                        .fixedSize()
                        .position(x: labelX(node: center.x, onLeft: waypoint.x < 0.5, in: size),
                                  y: center.y)
                        .animation(VMotion.gentle, value: reached)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement()
        .accessibilityLabel("Your 14-day plan is being laid out")
    }

    /// Label sits on the OUTER side of its node (the line turns back inward at
    /// each station, so the outer side is always clear), clamped so it never
    /// runs off the canvas edge.
    private func labelX(node: CGFloat, onLeft: Bool, in size: CGSize) -> CGFloat {
        let outer: CGFloat = 46
        let x = onLeft ? node - outer : node + outer
        return min(max(x, 36), size.width - 36)
    }

    @ViewBuilder
    private func stationNode(reached: Bool, finish: Bool) -> some View {
        let side: CGFloat = finish ? 40 : 28
        ZStack {
            Circle()
                .fill(reached ? AnyShapeStyle(DQColor.accentGradient)
                              : AnyShapeStyle(DQColor.surface))
            Circle()
                .strokeBorder(reached ? DQColor.accentBright : DQColor.stroke,
                              lineWidth: reached ? 0 : 1.5)
            if reached {
                Image(systemName: finish ? "flag.checkered" : "checkmark")
                    .font(.system(size: finish ? 16 : 12, weight: .heavy))
                    .foregroundStyle(.white)
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .frame(width: side, height: side)
        .shadow(color: DQColor.accent.opacity(reached ? 0.35 : 0), radius: 9, y: 4)
        .scaleEffect(reached ? 1 : 0.86)
        .animation(VMotion.snappy, value: reached)
    }
}

// ============================================================
// MARK: — Screen 7: 14-Day Routine (+ Screen 8 check-in mechanics)
// ============================================================

/// Day grid (today highlighted, completed filled, day 14 = rescan lock),
/// today's AM/PM card with checkable steps, streak counter. Missing a day is
/// never punished — the tile just stays unfilled.
struct DermiqRoutineTab: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.requestReview) private var requestReview
    @Query(sort: \RoutinePlan.createdAt, order: .reverse) private var plans: [RoutinePlan]

    /// The native rating ask fires at most once from here, ever — right after
    /// the user completes their FIRST full routine day (AM + PM checked). A
    /// genuine "it's working" moment, and the system throttles on top anyway.
    @AppStorage("dermiq.reviewAskedRoutine") private var routineReviewAsked = false

    /// Kit card starts on the lean "Essentials" view so the first thing the
    /// user sees is the four products they actually need to start.
    @State private var kitEssentialsOnly = true

    /// Recovery state lives in UserDefaults; bumping this forces the tab to
    /// re-read it after the user starts or ends a back-off.
    @State private var recoveryRefresh = 0

    /// Asks the shell to start the day-14 rescan flow.
    let onRescan: () -> Void

    private var plan: RoutinePlan? { plans.first { $0.isActive } }

    var body: some View {
        ScrollView {
            if let plan {
                activePlan(plan)
            } else {
                emptyState
            }
        }
        .scrollIndicators(.hidden)
        .background(DQColor.background.ignoresSafeArea())
        // Keep the Home Screen widget in sync with what's on screen — covers
        // the midnight day rollover and any edit made elsewhere.
        .onAppear { WidgetBridge.publish(plan) }
    }

    // MARK: Active plan

    private func activePlan(_ plan: RoutinePlan) -> some View {
        let today = plan.dayIndex()
        return VStack(alignment: .leading, spacing: 20) {
            // Structure: what do I do TODAY first (header → days → AM/PM),
            // then the meta layer (kit, irritation, AI verdict) below it.
            header(plan, today: today)
                .vStaggeredAppear(index: 0)
            dayGrid(plan, today: today)
                .vStaggeredAppear(index: 1)

            if plan.rescanUnlocked {
                rescanCard
                    .vStaggeredAppear(index: 1)
            }

            blockCard(plan, day: today, block: .am, title: "Morning", icon: "sun.max.fill")
                .vStaggeredAppear(index: 1)
            blockCard(plan, day: today, block: .pm, title: "Evening", icon: "moon.stars.fill")
                .vStaggeredAppear(index: 2)

            kitCard(plan)
                .vStaggeredAppear(index: 3)
            recoveryCard(plan, today: today)
                .vStaggeredAppear(index: 3)
            if let summary = RoutineAIReview.summary(for: plan) {
                aiCheckCard(summary)
                    .vStaggeredAppear(index: 3)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 18)
        .padding(.bottom, 28)
    }

    private func rampIcon(for day: Int) -> String {
        switch RoutineSchedule.phase(for: day) {
        case .reset:  return "leaf.fill"
        case .easing: return "arrow.up.forward"
        case .full:   return "bolt.fill"
        }
    }

    private func header(_ plan: RoutinePlan, today: Int) -> some View {
        let amSteps = plan.scheduledSteps(.am, day: today)
        let pmSteps = plan.scheduledSteps(.pm, day: today)
        let total = amSteps.count + pmSteps.count
        let done = amSteps.filter { plan.isDone(day: today, block: .am, step: $0) }.count
                 + pmSteps.filter { plan.isDone(day: today, block: .pm, step: $0) }.count
        let allDone = total > 0 && done == total
        return VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("Day \(today)")
                    .font(.system(size: 34, weight: .heavy, design: .rounded))
                    .foregroundStyle(DQColor.textPrimary)
                Text("of 14")
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                    .foregroundStyle(DQColor.textSecondary)
                Spacer()
                // Streak — quiet, only once it exists.
                if plan.streak > 0 {
                    HStack(spacing: 4) {
                        Image(systemName: "flame.fill")
                            .font(.system(size: 12))
                        Text(verbatim: "\(plan.streak)")
                            .font(.system(size: 14, weight: .bold, design: .rounded).monospacedDigit())
                    }
                    .foregroundStyle(DQColor.deltaUp)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(DQColor.deltaUp.opacity(0.10), in: Capsule())
                }
            }

            // Ramp phase — makes "why so few steps on day 2" read as a
            // deliberate barrier-reset, not a broken plan.
            HStack(spacing: 9) {
                Image(systemName: rampIcon(for: today))
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(DQColor.accentBright)
                    .frame(width: 20)
                VStack(alignment: .leading, spacing: 1) {
                    Text(LocalizedStringKey(RoutineSchedule.phaseTitle(for: today)))
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(DQColor.textPrimary)
                    Text(LocalizedStringKey(RoutineSchedule.phaseDetail(for: today)))
                        .font(DQFont.micro)
                        .foregroundStyle(DQColor.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 11)
            .padding(.vertical, 9)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(DQColor.accentSoft.opacity(0.45),
                        in: RoundedRectangle(cornerRadius: 12, style: .continuous))

            // Today at a glance: one thin line, one quiet caption — and a small
            // moment when the day is done.
            VStack(alignment: .leading, spacing: 7) {
                GeometryReader { proxy in
                    ZStack(alignment: .leading) {
                        Capsule().fill(DQColor.stroke.opacity(0.5))
                        Capsule()
                            .fill(allDone ? DQColor.deltaUp : DQColor.accent)
                            .frame(width: proxy.size.width * CGFloat(done) / CGFloat(max(total, 1)))
                    }
                }
                .frame(height: 5)
                .animation(VMotion.gentle, value: done)

                if allDone {
                    HStack(spacing: 5) {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 11, weight: .semibold))
                        Text("Today complete — see you tomorrow.")
                            .font(DQFont.micro)
                    }
                    .foregroundStyle(DQColor.deltaUp)
                    .transition(.opacity.combined(with: .move(edge: .top)))
                } else {
                    Text("\(done) of \(total) steps today")
                        .font(DQFont.micro)
                        .foregroundStyle(DQColor.textSecondary)
                        .contentTransition(.numericText(value: Double(done)))
                }
            }
            .animation(VMotion.gentle, value: allDone)
        }
    }

    /// Adaptive back-off. When calm: a quiet "skin feels irritated?" link that
    /// pauses the strong actives for a few days. When recovering: a banner with
    /// the days left and an "all better" escape hatch.
    @ViewBuilder
    private func recoveryCard(_ plan: RoutinePlan, today: Int) -> some View {
        let _ = recoveryRefresh   // re-read UserDefaults after begin/end
        if RoutineRecovery.isActive(plan, on: today) {
            let left = RoutineRecovery.daysLeft(plan, on: today)
            HStack(spacing: 11) {
                Image(systemName: "cross.case.fill")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(DQColor.deltaDown)
                    .frame(width: 34, height: 34)
                    .background(DQColor.deltaDown.opacity(0.12),
                                in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text("Recovery mode")
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .foregroundStyle(DQColor.textPrimary)
                        Text(verbatim: "\(left)d")
                            .font(DQFont.mono(9, weight: .bold))
                            .foregroundStyle(DQColor.deltaDown)
                            .padding(.horizontal, 5).padding(.vertical, 1)
                            .background(DQColor.deltaDown.opacity(0.12), in: Capsule())
                    }
                    Text("Strong actives paused — your barrier gets gentle days.")
                        .font(DQFont.micro)
                        .foregroundStyle(DQColor.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 4)
                Button {
                    Haptics.fire(.selection)
                    RoutineRecovery.end(plan)
                    WidgetBridge.publish(plan)
                    withAnimation(VMotion.snappy) { recoveryRefresh += 1 }
                } label: {
                    Text("All better")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(DQColor.accentBright)
                        .padding(.horizontal, 11).padding(.vertical, 7)
                        .background(DQColor.accentBright.opacity(0.10), in: Capsule())
                }
                .buttonStyle(.plain)
            }
            .padding(14)
            .background(DQColor.surface, in: RoundedRectangle(cornerRadius: DQRadius.card, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: DQRadius.card, style: .continuous)
                .strokeBorder(DQColor.deltaDown.opacity(0.35), lineWidth: 1))
        } else {
            Button {
                Haptics.fire(.selection)
                RoutineRecovery.begin(plan)
                WidgetBridge.publish(plan)
                withAnimation(VMotion.snappy) { recoveryRefresh += 1 }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "hand.raised.fill")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(DQColor.textSecondary)
                    Text("Skin feels irritated?")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(DQColor.textPrimary)
                    Spacer(minLength: 4)
                    Text("Pause actives")
                        .font(DQFont.micro)
                        .foregroundStyle(DQColor.accentBright)
                }
                .padding(.horizontal, 14).padding(.vertical, 11)
                .frame(maxWidth: .infinity)
                .background(DQColor.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(DQColor.stroke, lineWidth: 1))
            }
            .buttonStyle(.plain)
        }
    }

    /// "Your kit" — the honest shopping answer. The 8 daily steps are really
    /// only a handful of products (one cleanser covers AM + PM, etc.), and the
    /// Essentials view trims that to the four you need to start. Tap to expand.
    @ViewBuilder
    private func kitCard(_ plan: RoutinePlan) -> some View {
        let kit = plan.shoppingKit
        let essentials = kit.filter(\.isEssential)
        let extras = kit.filter { !$0.isEssential }
        let visible = kitEssentialsOnly ? essentials : kit
        DisclosureGroup {
            // Airy layout: every product is its own breathing mini-card —
            // name row, usage chips, a HOW-TO line, and the budget pick —
            // instead of dense divider-rows.
            VStack(spacing: 10) {
                if !extras.isEmpty {
                    kitSegment(essentialCount: essentials.count, totalCount: kit.count)
                        .padding(.top, 8)
                }
                ForEach(visible) { product in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(alignment: .firstTextBaseline, spacing: 10) {
                            Image(systemName: "bag")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(DQColor.accentBright)
                                .frame(width: 24, height: 24)
                                .background(DQColor.accentSoft.opacity(0.7), in: Circle())
                            Text(LocalizedStringKey(product.productType))
                                .font(.system(size: 15, weight: .bold, design: .rounded))
                                .foregroundStyle(DQColor.textPrimary)
                                .fixedSize(horizontal: false, vertical: true)
                            Spacer(minLength: 6)
                            Text(verbatim: product.tiers)
                                .font(DQFont.mono(10, weight: .semibold))
                                .foregroundStyle(DQColor.textSecondary)
                        }

                        HStack(spacing: 6) {
                            Text(verbatim: product.usage)
                                .font(.system(size: 11, weight: .semibold, design: .rounded))
                                .foregroundStyle(DQColor.accentBright)
                                .padding(.horizontal, 8).padding(.vertical, 3)
                                .background(DQColor.accentSoft.opacity(0.7), in: Capsule())
                            if !product.isEssential {
                                Text("Add later")
                                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                                    .foregroundStyle(DQColor.textSecondary)
                                    .padding(.horizontal, 8).padding(.vertical, 3)
                                    .overlay(Capsule().strokeBorder(DQColor.stroke, lineWidth: 1))
                            }
                        }

                        Text(LocalizedStringKey(product.howTo))
                            .font(DQFont.caption)
                            .foregroundStyle(DQColor.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)

                        if let cheapest = product.cheapest {
                            HStack(spacing: 5) {
                                Image(systemName: "tag")
                                    .font(.system(size: 10, weight: .semibold))
                                Text(LocalizedStringKey(cheapest))
                            }
                            .font(DQFont.micro)
                            .foregroundStyle(DQColor.textSecondary)
                        }
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(DQColor.background,
                                in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                Group {
                    if kitEssentialsOnly && !extras.isEmpty {
                        Text("Start with these four. The other \(extras.count) you add once the habit sticks.")
                    } else {
                        Text("One cleanser covers morning and evening — you buy fewer products than there are steps.")
                    }
                }
                .font(DQFont.micro)
                .foregroundStyle(DQColor.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 2)
            }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "basket.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(DQColor.accentBright)
                    .frame(width: 32, height: 32)
                    .background(DQColor.accentBright.opacity(0.10), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                VStack(alignment: .leading, spacing: 1) {
                    Text("Your kit")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(DQColor.textPrimary)
                    Text("\(essentials.count) to start · \(kit.count) in full")
                        .font(DQFont.micro)
                        .foregroundStyle(DQColor.textSecondary)
                }
            }
        }
        .tint(DQColor.accentBright)
        .padding(16)
        .background(DQColor.surface, in: RoundedRectangle(cornerRadius: DQRadius.card, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: DQRadius.card, style: .continuous)
                .strokeBorder(DQColor.stroke, lineWidth: 1)
        )
    }

    /// Two-segment pill: Essentials (the starter four) vs Full (everything).
    private func kitSegment(essentialCount: Int, totalCount: Int) -> some View {
        HStack(spacing: 4) {
            kitSegmentButton(title: "Essentials", count: essentialCount, on: kitEssentialsOnly) {
                kitEssentialsOnly = true
            }
            kitSegmentButton(title: "Full plan", count: totalCount, on: !kitEssentialsOnly) {
                kitEssentialsOnly = false
            }
        }
        .padding(3)
        .background(DQColor.background, in: Capsule())
    }

    private func kitSegmentButton(title: LocalizedStringKey, count: Int,
                                  on: Bool, action: @escaping () -> Void) -> some View {
        Button {
            Haptics.fire(.selection)
            withAnimation(VMotion.snappy) { action() }
        } label: {
            HStack(spacing: 5) {
                Text(title)
                Text(verbatim: "\(count)")
                    .font(DQFont.mono(10, weight: .bold))
                    .opacity(0.8)
            }
            .font(.system(size: 12, weight: .semibold, design: .rounded))
            .foregroundStyle(on ? .white : DQColor.textSecondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 7)
            .background(on ? DQColor.accentBright : .clear, in: Capsule())
        }
        .buttonStyle(.plain)
    }

    /// The Gemini verdict on this plan: badge + personal 2–3 sentence summary.
    /// Only shows once the background review has landed.
    private func aiCheckCard(_ summary: String) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 6) {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(DQColor.accentBright)
                Text("AI-checked plan")
                    .font(DQFont.mono(10, weight: .semibold)).tracking(1.5)
                    .foregroundStyle(DQColor.accentBright)
            }
            Text(verbatim: summary)
                .font(DQFont.caption)
                .foregroundStyle(DQColor.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(DQColor.accentSoft.opacity(0.45), in: RoundedRectangle(cornerRadius: DQRadius.card, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: DQRadius.card, style: .continuous)
                .strokeBorder(DQColor.accentSoft, lineWidth: 1)
        )
    }

    /// One horizontal, scrollable strip of day pills — roomier than the old
    /// squeezed 7-column grid, and it starts scrolled to today.
    private func dayGrid(_ plan: RoutinePlan, today: Int) -> some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal) {
                HStack(spacing: 8) {
                    ForEach(1...14, id: \.self) { day in
                        dayPill(day: day, state: tileState(plan, day: day, today: today))
                            .id(day)
                    }
                }
                .padding(.horizontal, 2)
                .padding(.vertical, 2)
            }
            .scrollIndicators(.hidden)
            .onAppear { proxy.scrollTo(max(today - 1, 1), anchor: .leading) }
        }
    }

    private func dayPill(day: Int, state: DQDayTile.TileState) -> some View {
        let isToday = state == .today
        let isDone = state == .completed
        return Group {
            if day == 14 && state == .upcoming {
                Image(systemName: "lock.fill")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(DQColor.textSecondary.opacity(0.7))
            } else if isDone {
                Image(systemName: "checkmark")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.white)
            } else {
                Text(verbatim: "\(day)")
                    .font(.system(size: 15, weight: .bold, design: .rounded).monospacedDigit())
                    .foregroundStyle(isToday ? DQColor.accentBright : DQColor.textSecondary)
            }
        }
        .frame(width: 44, height: 48)
        .background(
            isDone ? AnyShapeStyle(DQColor.accent)
                   : (isToday ? AnyShapeStyle(DQColor.accentSoft) : AnyShapeStyle(DQColor.surface)),
            in: RoundedRectangle(cornerRadius: 15, style: .continuous)
        )
        .overlay {
            if isToday {
                RoundedRectangle(cornerRadius: 15, style: .continuous)
                    .strokeBorder(DQColor.accent, lineWidth: 1.5)
            }
        }
        .opacity(state == .missed ? 0.45 : 1)
    }

    private func tileState(_ plan: RoutinePlan, day: Int, today: Int) -> DQDayTile.TileState {
        if plan.dayComplete(day) { return .completed }
        if day == today { return .today }
        return day < today ? .missed : .upcoming
    }

    private var rescanCard: some View {
        DQCard(elevated: true) {
            HStack(spacing: 14) {
                Image(systemName: "faceid")
                    .font(.system(size: 24, weight: .light))
                    .foregroundStyle(DQColor.accentBright)
                VStack(alignment: .leading, spacing: 2) {
                    Text("You finished 14 days")
                        .font(DQFont.headline)
                        .foregroundStyle(DQColor.textPrimary)
                    Text("Rescan to see your delta — then your next 14 days begin.")
                        .font(DQFont.caption)
                        .foregroundStyle(DQColor.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
                Button {
                    Haptics.fire(.selection)
                    onRescan()
                } label: {
                    Text("Rescan")
                        .font(DQFont.headline)
                        .foregroundStyle(DQColor.textPrimary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 9)
                        .background(DQColor.accentGradient, in: Capsule())
                }
                .buttonStyle(PressableStyle())
            }
        }
    }

    // MARK: Step blocks

    private func blockCard(_ plan: RoutinePlan, day: Int, block: RoutineBlock,
                           title: String, icon: String) -> some View {
        let steps = plan.scheduledSteps(block, day: day)
        let doneCount = steps.filter { plan.isDone(day: day, block: block, step: $0) }.count
        let complete = !steps.isEmpty && doneCount == steps.count
        return DQCard {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 10) {
                    Image(systemName: icon)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(complete ? DQColor.deltaUp : DQColor.accentBright)
                        .frame(width: 32, height: 32)
                        .background((complete ? DQColor.deltaUp : DQColor.accentBright).opacity(0.10),
                                    in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    VStack(alignment: .leading, spacing: 1) {
                        Text(LocalizedStringKey(title))
                            .font(.system(size: 17, weight: .bold, design: .rounded))
                            .foregroundStyle(DQColor.textPrimary)
                        Text(LocalizedStringKey(block == .am ? "After you wake up" : "Before bed"))
                            .font(DQFont.micro)
                            .foregroundStyle(DQColor.textSecondary)
                    }
                    Spacer()
                    if complete {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(DQColor.deltaUp)
                            .transition(.scale.combined(with: .opacity))
                    } else {
                        Text(verbatim: "\(doneCount)/\(steps.count)")
                            .font(.system(size: 13, weight: .bold, design: .rounded).monospacedDigit())
                            .foregroundStyle(DQColor.textSecondary)
                            .contentTransition(.numericText(value: Double(doneCount)))
                    }
                }
                .padding(.bottom, 8)
                .animation(VMotion.gentle, value: complete)

                ForEach(Array(steps.enumerated()), id: \.element.id) { index, step in
                    DermiqStepRow(
                        step: step,
                        order: index + 1,
                        done: plan.isDone(day: day, block: block, step: step)
                    ) {
                        toggle(plan, day: day, block: block, step: step)
                    }
                }
            }
        }
        .animation(VMotion.gentle, value: doneCount)
    }

    private func toggle(_ plan: RoutinePlan, day: Int, block: RoutineBlock, step: RoutineStep) {
        let wasComplete = plan.blockComplete(day: day, block)
        plan.toggle(day: day, block: block, step: step)
        try? modelContext.save()
        WidgetBridge.publish(plan)
        Haptics.fire(.selection)
        if !wasComplete && plan.blockComplete(day: day, block) {
            // Block just finished → the day tile fills. Commit-grade haptic.
            Haptics.fire(.capture)
            RampAnalytics.track("routine_block_complete", ["day": String(day), "block": block.rawValue])
            BadgeCenter.shared.evaluateRoutineMilestones(plan: plan, day: day)

            // First FULL day done (AM + PM) → the native Apple rating card,
            // slightly delayed so the completion animation lands first.
            if !routineReviewAsked && plan.dayComplete(day) {
                routineReviewAsked = true
                Task {
                    try? await Task.sleep(for: .milliseconds(1800))
                    requestReview()
                }
            }
        }
    }

    // MARK: Empty state

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer().frame(height: 130)
            Image(systemName: "checklist")
                .font(.system(size: 38, weight: .light))
                .foregroundStyle(DQColor.textSecondary)
            Text("No active plan")
                .font(DQFont.title)
                .foregroundStyle(DQColor.textPrimary)
            Text("Scan your skin and Glowé builds a 14-day\nroutine from your weakest scores.")
                .font(DQFont.body)
                .foregroundStyle(DQColor.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }
}

/// One checkable routine step. Collapsed by default — just the check, the
/// product name and its active — so the list scans in a second. The why-line
/// and product examples live behind a chevron.
private struct DermiqStepRow: View {
    let step: RoutineStep
    /// 1-based position inside the block — the visible "do this Nth" order.
    var order: Int = 0
    let done: Bool
    let onToggle: () -> Void

    @State private var expanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 12) {
                // Tapping the row is the main action: check it off.
                Button(action: onToggle) {
                    HStack(spacing: 12) {
                        Image(systemName: done ? "checkmark.circle.fill" : "circle")
                            .font(.system(size: 23))
                            .foregroundStyle(done ? DQColor.deltaUp : DQColor.stroke)
                            .contentTransition(.symbolEffect(.replace))
                            .scaleEffect(done ? 1.0 : 0.96)
                        // The ORDER — answers "when?" at a glance: steps run
                        // top to bottom, 1 → n.
                        if order > 0 {
                            Text(verbatim: "\(order)")
                                .font(.system(size: 12, weight: .bold, design: .rounded).monospacedDigit())
                                .foregroundStyle(done ? DQColor.textSecondary : DQColor.accentBright)
                                .frame(width: 22, height: 22)
                                .background(DQColor.accentSoft.opacity(done ? 0.4 : 0.8), in: Circle())
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 6) {
                                Text(LocalizedStringKey(step.productType))
                                    .font(DQFont.headline)
                                    .foregroundStyle(done ? DQColor.textSecondary : DQColor.textPrimary)
                                    .strikethrough(done, color: DQColor.textSecondary.opacity(0.6))
                                // Cadence pill for non-daily actives, so it's
                                // clear why this step isn't there every day.
                                if let freq = RoutineSchedule.frequencyLabel(for: step) {
                                    Text(LocalizedStringKey(freq))
                                        .font(.system(size: 9.5, weight: .bold, design: .rounded))
                                        .foregroundStyle(DQColor.accentBright)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(DQColor.accentSoft.opacity(0.8), in: Capsule())
                                }
                            }
                            Text(LocalizedStringKey(step.active))
                                .font(DQFont.mono(11))
                                .foregroundStyle(DQColor.accentBright)
                                .lineLimit(1)
                        }
                        .opacity(done ? 0.65 : 1)
                        Spacer(minLength: 0)
                    }
                }
                .buttonStyle(.plain)

                // The chevron opens the detail (why + examples) — quiet, no chrome.
                Button {
                    Haptics.fire(.tick)
                    withAnimation(VMotion.snappy) { expanded.toggle() }
                } label: {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(DQColor.textSecondary.opacity(0.7))
                        .rotationEffect(.degrees(expanded ? 180 : 0))
                        .frame(width: 34, height: 34)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(expanded ? "Hide details" : "Show details")
            }

            if expanded {
                VStack(alignment: .leading, spacing: 12) {
                    // HOW TO USE — the practical instruction, front and centre.
                    VStack(alignment: .leading, spacing: 4) {
                        Label("HOW TO USE", systemImage: "hand.draw")
                            .font(DQFont.mono(9, weight: .bold))
                            .foregroundStyle(DQColor.accentBright)
                            .tracking(1.5)
                        Text(LocalizedStringKey(RoutineHowTo.instruction(for: step)))
                            .font(DQFont.caption)
                            .foregroundStyle(DQColor.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    // WHY — the personal, score-tied reason.
                    VStack(alignment: .leading, spacing: 4) {
                        Text("WHY THIS")
                            .font(DQFont.mono(9, weight: .bold))
                            .foregroundStyle(DQColor.textSecondary)
                            .tracking(1.5)
                        Text(step.why)
                            .font(DQFont.caption)
                            .foregroundStyle(DQColor.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    if !step.examples.isEmpty {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("PRODUCTS ($ → $$$)")
                                .font(DQFont.mono(9, weight: .bold))
                                .foregroundStyle(DQColor.textSecondary)
                                .tracking(1.5)
                            ForEach(step.examples, id: \.self) { example in
                                Text(LocalizedStringKey(example))
                                    .font(DQFont.caption)
                                    .foregroundStyle(DQColor.textSecondary)
                            }
                        }
                    }
                }
                .padding(.leading, 34)
                .padding(.top, 10)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(.vertical, 9)
        .animation(VMotion.snappy, value: done)
    }
}
