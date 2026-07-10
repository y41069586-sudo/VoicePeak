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
    @State private var daysFilled = 0
    @State private var ready = false
    @State private var appeared = false

    private var targets: [DermiqSubScore] { model.analysis?.weakestThree ?? [] }

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
            Spacer(minLength: 20)

            // ---- Heading ----
            VStack(spacing: 8) {
                Text("BUILT FROM YOUR SCAN")
                    .font(DQFont.mono(11, weight: .semibold))
                    .foregroundStyle(DQColor.accentBright)
                    .tracking(3)
                Text(ready ? "Your plan is ready" : "Building your 14-day plan")
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .foregroundStyle(DQColor.textPrimary)
                    .multilineTextAlignment(.center)
                    .contentTransition(.opacity)
                Text("Not a template — every step answers one of your three weakest scores.")
                    .font(DQFont.body)
                    .foregroundStyle(DQColor.textSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 32)
            }
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 12)

            Spacer(minLength: 24)

            // ---- The plan taking shape, inside one real card ----
            VStack(alignment: .leading, spacing: 18) {
                // Targets as chips.
                VStack(alignment: .leading, spacing: 9) {
                    Text("TARGETING")
                        .font(DQFont.mono(10, weight: .semibold))
                        .foregroundStyle(DQColor.textSecondary)
                        .tracking(2)
                    HStack(spacing: 8) {
                        if targets.isEmpty {
                            targetChip(name: "Your weakest 3", value: nil)
                        } else {
                            ForEach(targets) { target in
                                targetChip(name: target.category.displayName, value: target.value)
                            }
                        }
                    }
                }

                Divider().overlay(DQColor.stroke)

                // 14-day grid, filling as the plan lays out.
                VStack(alignment: .leading, spacing: 9) {
                    Text("14 DAYS · MORNING & EVENING")
                        .font(DQFont.mono(10, weight: .semibold))
                        .foregroundStyle(DQColor.textSecondary)
                        .tracking(2)
                    dayGrid
                }

                Divider().overlay(DQColor.stroke)

                // Visible work: each build step ticks in with a check.
                VStack(alignment: .leading, spacing: 11) {
                    ForEach(0..<buildSteps.count, id: \.self) { index in
                        let done = index < stepCount
                        HStack(spacing: 10) {
                            Image(systemName: done ? "checkmark.circle.fill" : "circle")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundStyle(done ? DQColor.deltaUp : DQColor.stroke)
                            Text(buildSteps[index])
                                .font(DQFont.caption)
                                .foregroundStyle(done ? DQColor.textPrimary : DQColor.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                            Spacer(minLength: 0)
                        }
                        .opacity(done || index == stepCount ? 1 : 0.4)
                    }
                }
                .animation(VMotion.gentle, value: stepCount)
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(DQColor.surface, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .strokeBorder(DQColor.stroke, lineWidth: 1)
            )
            .shadow(color: DQColor.accent.opacity(0.10), radius: 22, y: 10)
            .padding(.horizontal, 24)
            .opacity(appeared ? 1 : 0)
            .scaleEffect(appeared ? 1 : 0.96)
            .offset(y: appeared ? 0 : 18)

            Spacer(minLength: 24)
        }
        .background(DQColor.background.ignoresSafeArea())
        .task { await runBuild() }
    }

    private func targetChip(name: String, value: Int?) -> some View {
        HStack(spacing: 5) {
            Image(systemName: "target")
                .font(.system(size: 11, weight: .semibold))
            Text(name)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .lineLimit(1)
            if let value {
                Text(verbatim: "\(value)")
                    .font(DQFont.mono(12, weight: .bold))
                    .foregroundStyle(DQColor.deltaDown)
            }
        }
        .foregroundStyle(DQColor.accentBright)
        .padding(.horizontal, 11)
        .padding(.vertical, 7)
        .background(DQColor.accentSoft, in: Capsule())
    }

    /// Two rows of seven day-pills that fill in as the plan is laid out.
    private var dayGrid: some View {
        VStack(spacing: 6) {
            ForEach(0..<2, id: \.self) { row in
                HStack(spacing: 6) {
                    ForEach(0..<7, id: \.self) { col in
                        let day = row * 7 + col
                        let filled = day < daysFilled
                        Text(verbatim: "\(day + 1)")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundStyle(filled ? Color.white : DQColor.textSecondary)
                            .frame(maxWidth: .infinity, minHeight: 30)
                            .background(filled ? AnyShapeStyle(DQColor.accent)
                                               : AnyShapeStyle(DQColor.surfaceElevated),
                                        in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                    }
                }
            }
        }
        .animation(VMotion.gentle, value: daysFilled)
    }

    private func runBuild() async {
        withAnimation(VMotion.gentle) { appeared = true }
        // Steps tick in, and the 14 days fill up alongside them.
        for index in 1...buildSteps.count {
            try? await Task.sleep(for: .milliseconds(520))
            guard !Task.isCancelled else { return }
            stepCount = index
            Haptics.fire(.tick)
            withAnimation(VMotion.gentle) { daysFilled = min(14, index * 4) }
        }
        try? await Task.sleep(for: .milliseconds(360))
        guard !Task.isCancelled else { return }
        withAnimation(VMotion.gentle) { daysFilled = 14 }
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
        return VStack(alignment: .leading, spacing: 22) {
            header(plan, today: today)
            dayGrid(plan, today: today)

            if plan.rescanUnlocked {
                rescanCard
            }

            blockCard(plan, day: today, block: .am, title: "Morning", icon: "sun.max.fill")
            blockCard(plan, day: today, block: .pm, title: "Evening", icon: "moon.stars.fill")

            Text("One reminder a day keeps the plan on track — set AM or PM in Settings.")
                .font(DQFont.micro)
                .foregroundStyle(DQColor.textSecondary)
                .padding(.horizontal, 4)
        }
        .padding(.horizontal, 20)
        .padding(.top, 18)
        .padding(.bottom, 110)
    }

    private func header(_ plan: RoutinePlan, today: Int) -> some View {
        let total = plan.steps(.am).count + plan.steps(.pm).count
        let done = plan.steps(.am).filter { plan.isDone(day: today, block: .am, step: $0) }.count
                 + plan.steps(.pm).filter { plan.isDone(day: today, block: .pm, step: $0) }.count
        return VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Text("Day \(today) of 14")
                    .font(.system(size: 28, weight: .heavy, design: .rounded))
                    .foregroundStyle(DQColor.textPrimary)
                Spacer()
                // Streak counter (Screen 8)
                HStack(spacing: 5) {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 13))
                        .foregroundStyle(plan.streak > 0 ? DQColor.deltaUp : DQColor.textSecondary)
                    Text(verbatim: "\(plan.streak)")
                        .font(DQFont.mono(15, weight: .semibold))
                        .foregroundStyle(DQColor.textPrimary)
                }
                .padding(.horizontal, 11)
                .padding(.vertical, 7)
                .background(DQColor.surface, in: Capsule())
                .overlay(Capsule().strokeBorder(DQColor.stroke, lineWidth: 1))
            }

            // The three targets as chips — scannable, not a sentence.
            HStack(spacing: 8) {
                ForEach(plan.targets) { target in
                    HStack(spacing: 5) {
                        Image(systemName: "target")
                            .font(.system(size: 10, weight: .semibold))
                        Text(target.category.displayName)
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .lineLimit(1)
                    }
                    .foregroundStyle(DQColor.accentBright)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(DQColor.accentSoft, in: Capsule())
                }
            }

            // Today at a glance: steps done + the honesty line.
            VStack(alignment: .leading, spacing: 6) {
                GeometryReader { proxy in
                    ZStack(alignment: .leading) {
                        Capsule().fill(DQColor.stroke.opacity(0.6))
                        Capsule()
                            .fill(DQColor.accent)
                            .frame(width: proxy.size.width * CGFloat(done) / CGFloat(max(total, 1)))
                    }
                }
                .frame(height: 6)
                .animation(VMotion.gentle, value: done)
                HStack {
                    Text(verbatim: "\(done) of \(total) steps today")
                        .font(DQFont.micro)
                        .foregroundStyle(DQColor.textSecondary)
                    Spacer()
                    Text("Built from your scan")
                        .font(DQFont.micro)
                        .foregroundStyle(DQColor.accentBright)
                }
            }
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
        return VStack(spacing: 3) {
            if day == 14 && state == .upcoming {
                Image(systemName: "lock.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(DQColor.textSecondary)
            } else if isDone {
                Image(systemName: "checkmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.white)
            } else {
                Text(verbatim: "\(day)")
                    .font(.system(size: 15, weight: .bold, design: .rounded).monospacedDigit())
                    .foregroundStyle(isToday ? DQColor.accentBright : DQColor.textSecondary)
            }
            Text(day == 14 ? "rescan" : "day")
                .font(.system(size: 8, weight: .semibold, design: .rounded))
                .foregroundStyle(isDone ? .white.opacity(0.85)
                                        : (isToday ? DQColor.accentBright : DQColor.textSecondary.opacity(0.7)))
        }
        .frame(width: 46, height: 54)
        .background(
            isDone ? AnyShapeStyle(DQColor.accent)
                   : (isToday ? AnyShapeStyle(DQColor.accentSoft) : AnyShapeStyle(DQColor.surface)),
            in: RoundedRectangle(cornerRadius: 14, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(isToday ? DQColor.accent : DQColor.stroke,
                              lineWidth: isToday ? 1.5 : 1)
        )
        .opacity(state == .missed ? 0.55 : 1)
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
        DQCard {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Image(systemName: icon)
                        .font(.system(size: 13))
                        .foregroundStyle(DQColor.accentBright)
                    Text(title)
                        .font(DQFont.headline)
                        .foregroundStyle(DQColor.textPrimary)
                    Spacer()
                    if plan.blockComplete(day: day, block) {
                        Text("DONE")
                            .font(DQFont.mono(10, weight: .bold))
                            .foregroundStyle(DQColor.deltaUp)
                            .tracking(1.5)
                    }
                }
                .padding(.bottom, 6)

                ForEach(plan.steps(block)) { step in
                    DermiqStepRow(
                        step: step,
                        done: plan.isDone(day: day, block: block, step: step)
                    ) {
                        toggle(plan, day: day, block: block, step: step)
                    }
                }
            }
        }
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
                            .font(.system(size: 22))
                            .foregroundStyle(done ? DQColor.deltaUp : DQColor.stroke)
                            .contentTransition(.symbolEffect(.replace))
                        VStack(alignment: .leading, spacing: 2) {
                            Text(step.productType)
                                .font(DQFont.headline)
                                .foregroundStyle(done ? DQColor.textSecondary : DQColor.textPrimary)
                                .strikethrough(done, color: DQColor.textSecondary)
                            Text(step.active)
                                .font(DQFont.mono(11))
                                .foregroundStyle(DQColor.accentBright)
                                .lineLimit(1)
                        }
                        Spacer(minLength: 0)
                    }
                }
                .buttonStyle(.plain)

                // The chevron opens the detail (why + examples).
                Button {
                    Haptics.fire(.tick)
                    withAnimation(VMotion.snappy) { expanded.toggle() }
                } label: {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(DQColor.textSecondary)
                        .rotationEffect(.degrees(expanded ? 180 : 0))
                        .frame(width: 32, height: 32)
                        .background(DQColor.surfaceElevated, in: Circle())
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
        .padding(.vertical, 9)
        .animation(VMotion.snappy, value: done)
    }
}
