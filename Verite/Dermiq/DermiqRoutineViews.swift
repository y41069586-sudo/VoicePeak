import SwiftUI
import SwiftData

// ============================================================
// MARK: — Screen 6: Routine Generation (2s transition)
// ============================================================

/// Makes the routine feel derived, not generic: the user's actual bottom-3
/// sub-scores are listed while the plan "builds".
struct DermiqRoutineGenView: View {
    let model: ScanFlowModel
    let onDone: () -> Void

    @State private var stepCount = 0
    @State private var ready = false

    private var buildSteps: [String] {
        [
            "Reading your three weakest metrics…",
            "Choosing your morning steps…",
            "Sequencing your evening actives…",
            "Laying out all 14 days…",
        ]
    }

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 8) {
                Text("BUILT FROM YOUR SCAN")
                    .font(DQFont.mono(11, weight: .semibold))
                    .foregroundStyle(DQColor.accentBright)
                    .tracking(3)
                Text(ready ? "Your plan is ready" : "Building your\n14-day plan")
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .foregroundStyle(DQColor.textPrimary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
                    .contentTransition(.opacity)
            }

            Spacer().frame(height: 40)

            // Just the work, ticking in — no card, no grid, no chips.
            VStack(alignment: .leading, spacing: 16) {
                ForEach(0..<buildSteps.count, id: \.self) { index in
                    let done = index < stepCount
                    HStack(spacing: 12) {
                        Image(systemName: done ? "checkmark.circle.fill" : "circle")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundStyle(done ? DQColor.deltaUp : DQColor.stroke)
                            .contentTransition(.symbolEffect(.replace))
                        Text(buildSteps[index])
                            .font(DQFont.body)
                            .foregroundStyle(done ? DQColor.textPrimary : DQColor.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: 0)
                    }
                    .opacity(done || index == stepCount ? 1 : 0.35)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 44)
            .animation(VMotion.gentle, value: stepCount)

            Spacer()
        }
        .background(DQColor.background.ignoresSafeArea())
        .task { await runBuild() }
    }

    private func runBuild() async {
        for index in 1...buildSteps.count {
            try? await Task.sleep(for: .milliseconds(520))
            guard !Task.isCancelled else { return }
            stepCount = index
            Haptics.fire(.tick)
        }
        try? await Task.sleep(for: .milliseconds(400))
        guard !Task.isCancelled else { return }
        withAnimation(VMotion.snappy) { ready = true }
        Haptics.fire(.milestone)
        try? await Task.sleep(for: .milliseconds(800))
        guard !Task.isCancelled else { return }
        onDone()
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
        return VStack(alignment: .leading, spacing: 18) {
            heroCard(plan, today: today)
                .vStaggeredAppear(index: 0)
            dayGrid(plan, today: today)
                .vStaggeredAppear(index: 1)

            if plan.rescanUnlocked {
                rescanCard
                    .vStaggeredAppear(index: 2)
            }

            // The day as a timeline: sun → moon, steps hanging off the rail.
            VStack(alignment: .leading, spacing: 0) {
                timelineBlock(plan, day: today, block: .am,
                              title: "Morning", icon: "sun.max.fill", isLast: false)
                timelineBlock(plan, day: today, block: .pm,
                              title: "Evening", icon: "moon.stars.fill", isLast: true)
            }
            .vStaggeredAppear(index: 2)
        }
        .padding(.horizontal, 20)
        .padding(.top, 18)
        .padding(.bottom, 110)
    }

    /// The hero: day, today's progress ring, targets and streak in one softly
    /// tinted card — the screen's single anchor.
    private func heroCard(_ plan: RoutinePlan, today: Int) -> some View {
        let total = plan.steps(.am).count + plan.steps(.pm).count
        let done = plan.steps(.am).filter { plan.isDone(day: today, block: .am, step: $0) }.count
                 + plan.steps(.pm).filter { plan.isDone(day: today, block: .pm, step: $0) }.count
        let allDone = total > 0 && done == total
        return VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center, spacing: 14) {
                VStack(alignment: .leading, spacing: 5) {
                    HStack(alignment: .firstTextBaseline, spacing: 7) {
                        Text("Day \(today)")
                            .font(.system(size: 32, weight: .heavy, design: .rounded))
                            .foregroundStyle(DQColor.textPrimary)
                        Text(verbatim: "of 14")
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                            .foregroundStyle(DQColor.textSecondary)
                    }
                    if allDone {
                        HStack(spacing: 5) {
                            Image(systemName: "checkmark.seal.fill")
                                .font(.system(size: 11, weight: .semibold))
                            Text("Today complete — see you tomorrow.")
                                .font(DQFont.micro)
                        }
                        .foregroundStyle(DQColor.deltaUp)
                        .transition(.opacity)
                    } else {
                        Text(verbatim: "\(done) of \(total) steps today")
                            .font(DQFont.caption)
                            .foregroundStyle(DQColor.textSecondary)
                            .contentTransition(.numericText(value: Double(done)))
                    }
                }
                Spacer(minLength: 0)
                progressRing(done: done, total: total, allDone: allDone)
            }

            HStack(spacing: 6) {
                ForEach(plan.targets) { target in
                    Text(target.category.displayName)
                        .font(.system(size: 11.5, weight: .semibold, design: .rounded))
                        .foregroundStyle(DQColor.accentBright)
                        .lineLimit(1)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 5)
                        .background(DQColor.surface.opacity(0.85), in: Capsule())
                }
                Spacer(minLength: 0)
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
                    .background(DQColor.surface.opacity(0.85), in: Capsule())
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(colors: [DQColor.accentSoft.opacity(0.65), DQColor.surface],
                           startPoint: .topLeading, endPoint: .bottomTrailing),
            in: RoundedRectangle(cornerRadius: 24, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(DQColor.stroke, lineWidth: 1)
        )
        .animation(VMotion.gentle, value: allDone)
    }

    /// Today's completion as a small ring — fills step by step, turns green
    /// and shows a check when the day is done.
    private func progressRing(done: Int, total: Int, allDone: Bool) -> some View {
        ZStack {
            Circle()
                .stroke(DQColor.stroke.opacity(0.6), lineWidth: 6)
            Circle()
                .trim(from: 0, to: total > 0 ? CGFloat(done) / CGFloat(total) : 0)
                .stroke(allDone ? DQColor.deltaUp : DQColor.accent,
                        style: StrokeStyle(lineWidth: 6, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(VMotion.gentle, value: done)
            if allDone {
                Image(systemName: "checkmark")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(DQColor.deltaUp)
                    .transition(.scale.combined(with: .opacity))
            } else {
                Text(verbatim: "\(done)/\(total)")
                    .font(.system(size: 13, weight: .bold, design: .rounded).monospacedDigit())
                    .foregroundStyle(DQColor.textPrimary)
                    .contentTransition(.numericText(value: Double(done)))
            }
        }
        .frame(width: 56, height: 56)
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

    /// One block of the day-timeline: a sun/moon node on a vertical rail, the
    /// block title beside it, and each step as its own small card.
    private func timelineBlock(_ plan: RoutinePlan, day: Int, block: RoutineBlock,
                               title: String, icon: String, isLast: Bool) -> some View {
        let steps = plan.steps(block)
        let doneCount = steps.filter { plan.isDone(day: day, block: block, step: $0) }.count
        let complete = !steps.isEmpty && doneCount == steps.count
        return HStack(alignment: .top, spacing: 14) {
            // The rail — the node fills green when the block is done, the line
            // runs on toward the next block.
            VStack(spacing: 6) {
                ZStack {
                    Circle()
                        .fill(complete ? AnyShapeStyle(DQColor.deltaUp)
                                       : AnyShapeStyle(DQColor.accentSoft))
                    Image(systemName: complete ? "checkmark" : icon)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(complete ? Color.white : DQColor.accentBright)
                        .contentTransition(.symbolEffect(.replace))
                }
                .frame(width: 36, height: 36)
                .animation(VMotion.gentle, value: complete)

                if !isLast {
                    Rectangle()
                        .fill(complete ? DQColor.deltaUp.opacity(0.45)
                                       : DQColor.stroke.opacity(0.7))
                        .frame(width: 2)
                        .frame(maxHeight: .infinity)
                        .animation(VMotion.gentle, value: complete)
                }
            }
            .frame(width: 36)

            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text(title)
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundStyle(DQColor.textPrimary)
                    Spacer()
                    if !complete {
                        Text(verbatim: "\(doneCount)/\(steps.count)")
                            .font(.system(size: 13, weight: .bold, design: .rounded).monospacedDigit())
                            .foregroundStyle(DQColor.textSecondary)
                            .contentTransition(.numericText(value: Double(doneCount)))
                    }
                }
                .frame(minHeight: 36)

                ForEach(steps) { step in
                    DermiqStepRow(
                        step: step,
                        done: plan.isDone(day: day, block: block, step: step)
                    ) {
                        toggle(plan, day: day, block: block, step: step)
                    }
                }
            }
            .padding(.bottom, isLast ? 0 : 22)
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
                            Text(step.productType)
                                .font(DQFont.headline)
                                .foregroundStyle(done ? DQColor.textSecondary : DQColor.textPrimary)
                                .strikethrough(done, color: DQColor.textSecondary.opacity(0.6))
                            Text(step.active)
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
                                Text(example)
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
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(DQColor.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(done ? DQColor.deltaUp.opacity(0.35) : DQColor.stroke, lineWidth: 1)
        )
        .animation(VMotion.snappy, value: done)
    }
}
