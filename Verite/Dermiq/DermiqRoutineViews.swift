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

    @State private var shownCount = 0

    var body: some View {
        VStack(spacing: 28) {
            Spacer()
            Text("Building your plan from\nyour 3 weakest scores…")
                .font(DQFont.title)
                .foregroundStyle(DQColor.textPrimary)
                .multilineTextAlignment(.center)

            VStack(spacing: 10) {
                let targets = model.analysis?.weakestThree ?? []
                ForEach(Array(targets.enumerated()), id: \.element.id) { index, target in
                    if index < shownCount {
                        HStack {
                            Text(target.category.displayName)
                                .font(DQFont.headline)
                                .foregroundStyle(DQColor.textPrimary)
                            Spacer()
                            Text(verbatim: "\(target.value)")
                                .font(DQFont.mono(17, weight: .semibold))
                                .foregroundStyle(DQColor.deltaDown)
                        }
                        .padding(.horizontal, 18)
                        .padding(.vertical, 13)
                        .background(DQColor.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .strokeBorder(DQColor.stroke, lineWidth: 1)
                        )
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                    }
                }
            }
            .padding(.horizontal, 40)
            .animation(VMotion.standard, value: shownCount)
            Spacer()
            Spacer()
        }
        .background(DQColor.background.ignoresSafeArea())
        .task {
            let count = model.analysis?.weakestThree.count ?? 0
            for index in 1...max(count, 1) {
                try? await Task.sleep(for: .milliseconds(420))
                shownCount = index
                Haptics.fire(.tick)
            }
            try? await Task.sleep(for: .milliseconds(900))
            guard !Task.isCancelled else { return }
            onDone()
        }
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
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 3) {
                Text("Day \(today) of 14")
                    .font(DQFont.title)
                    .foregroundStyle(DQColor.textPrimary)
                Text("Targeting " + plan.targets.map(\.category.displayName).joined(separator: " · "))
                    .font(DQFont.caption)
                    .foregroundStyle(DQColor.textSecondary)
            }
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
    }

    private func dayGrid(_ plan: RoutinePlan, today: Int) -> some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 7), spacing: 8) {
            ForEach(1...14, id: \.self) { day in
                DQDayTile(
                    day: day,
                    state: tileState(plan, day: day, today: today),
                    isRescanTile: day == 14
                )
            }
        }
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

/// One checkable routine step with the optional "examples" disclosure.
private struct DermiqStepRow: View {
    let step: RoutineStep
    let done: Bool
    let onToggle: () -> Void

    @State private var showExamples = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Button(action: onToggle) {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: done ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 21))
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
                        Text(step.why)
                            .font(DQFont.caption)
                            .foregroundStyle(DQColor.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 0)
                }
            }
            .buttonStyle(.plain)

            if !step.examples.isEmpty {
                Button {
                    withAnimation(VMotion.snappy) { showExamples.toggle() }
                } label: {
                    HStack(spacing: 4) {
                        Text("Examples")
                        Image(systemName: "chevron.down")
                            .rotationEffect(.degrees(showExamples ? 180 : 0))
                    }
                    .font(DQFont.micro)
                    .foregroundStyle(DQColor.textSecondary)
                }
                .padding(.leading, 33)

                if showExamples {
                    VStack(alignment: .leading, spacing: 3) {
                        ForEach(step.examples, id: \.self) { example in
                            Text(example)
                                .font(DQFont.caption)
                                .foregroundStyle(DQColor.textSecondary)
                        }
                    }
                    .padding(.leading, 33)
                    .transition(.opacity)
                }
            }
        }
        .padding(.vertical, 8)
        .animation(VMotion.snappy, value: done)
    }
}
