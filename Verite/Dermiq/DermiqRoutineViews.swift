import SwiftUI
import SwiftData

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

            Text("Morning & evening — aimed at your three weakest scores.")
                .font(DQFont.caption)
                .foregroundStyle(DQColor.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
                .padding(.bottom, 46)
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
    @Query(sort: \RoutinePlan.createdAt, order: .reverse) private var plans: [RoutinePlan]

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
    }

    // MARK: Active plan

    private func activePlan(_ plan: RoutinePlan) -> some View {
        let today = plan.dayIndex()
        return VStack(alignment: .leading, spacing: 20) {
            header(plan, today: today)
                .vStaggeredAppear(index: 0)
            dayGrid(plan, today: today)
                .vStaggeredAppear(index: 1)

            if plan.rescanUnlocked {
                rescanCard
                    .vStaggeredAppear(index: 2)
            }

            blockCard(plan, day: today, block: .am, title: "Morning", icon: "sun.max.fill")
                .vStaggeredAppear(index: 2)
            blockCard(plan, day: today, block: .pm, title: "Evening", icon: "moon.stars.fill")
                .vStaggeredAppear(index: 3)
        }
        .padding(.horizontal, 20)
        .padding(.top, 18)
        .padding(.bottom, 110)
    }

    private func header(_ plan: RoutinePlan, today: Int) -> some View {
        let total = plan.steps(.am).count + plan.steps(.pm).count
        let done = plan.steps(.am).filter { plan.isDone(day: today, block: .am, step: $0) }.count
                 + plan.steps(.pm).filter { plan.isDone(day: today, block: .pm, step: $0) }.count
        let allDone = total > 0 && done == total
        return VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("Day \(today)")
                    .font(.system(size: 34, weight: .heavy, design: .rounded))
                    .foregroundStyle(DQColor.textPrimary)
                Text(verbatim: "of 14")
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

            // The three targets — quiet little chips, no borders shouting.
            HStack(spacing: 6) {
                ForEach(plan.targets) { target in
                    Text(LocalizedStringKey(target.category.displayName))
                        .font(.system(size: 11.5, weight: .semibold, design: .rounded))
                        .foregroundStyle(DQColor.accentBright)
                        .lineLimit(1)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 5)
                        .background(DQColor.accentSoft.opacity(0.7), in: Capsule())
                }
            }

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
                    Text(verbatim: "\(done) of \(total) steps today")
                        .font(DQFont.micro)
                        .foregroundStyle(DQColor.textSecondary)
                        .contentTransition(.numericText(value: Double(done)))
                }
            }
            .animation(VMotion.gentle, value: allDone)
        }
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
                    Text("Day 14 — rescan unlocked")
                        .font(DQFont.headline)
                        .foregroundStyle(DQColor.textPrimary)
                    Text("Time to measure the delta.")
                        .font(DQFont.caption)
                        .foregroundStyle(DQColor.textSecondary)
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
        let steps = plan.steps(block)
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
                    Text(LocalizedStringKey(title))
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundStyle(DQColor.textPrimary)
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

                ForEach(steps) { step in
                    DermiqStepRow(
                        step: step,
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
        Haptics.fire(.selection)
        if !wasComplete && plan.blockComplete(day: day, block) {
            // Block just finished → the day tile fills. Commit-grade haptic.
            Haptics.fire(.capture)
            RampAnalytics.track("routine_block_complete", ["day": String(day), "block": block.rawValue])
            BadgeCenter.shared.evaluateRoutineMilestones(plan: plan, day: day)
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
            Text("Scan your skin and Vérité builds a 14-day\nroutine from your weakest scores.")
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
                        VStack(alignment: .leading, spacing: 2) {
                            Text(LocalizedStringKey(step.productType))
                                .font(DQFont.headline)
                                .foregroundStyle(done ? DQColor.textSecondary : DQColor.textPrimary)
                                .strikethrough(done, color: DQColor.textSecondary.opacity(0.6))
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
                VStack(alignment: .leading, spacing: 8) {
                    Text(step.why)
                        .font(DQFont.caption)
                        .foregroundStyle(DQColor.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                    if !step.examples.isEmpty {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("EXAMPLES")
                                .font(DQFont.mono(9, weight: .bold))
                                .foregroundStyle(DQColor.accentBright)
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
                .padding(.top, 8)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(.vertical, 9)
        .animation(VMotion.snappy, value: done)
    }
}
