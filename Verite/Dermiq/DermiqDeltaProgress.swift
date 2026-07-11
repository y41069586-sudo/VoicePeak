import SwiftUI
import SwiftData
import Charts

// ============================================================
// MARK: — Screen 9: Rescan & Delta
// ============================================================

/// Delta-focused results after day 14: old score morphs into the new one,
/// per-category deltas with arrows, updated Potential comparison.
struct DermiqDeltaView: View {
    let model: ScanFlowModel
    let onContinue: () -> Void

    @State private var shownScore: Int = 0
    @State private var morphDone = false

    private var oldAnalysis: DermiqAnalysis? { model.previousScan?.analysis }

    var body: some View {
        ScrollView {
            VStack(spacing: 26) {
                Text("14 days later.")
                    .font(DQFont.title)
                    .foregroundStyle(DQColor.textPrimary)
                    .padding(.top, 40)

                if let old = oldAnalysis, let new = model.analysis {
                    overallHero(old: old.overall, new: new.overall)
                    deltaList(old: old, new: new)

                    if let current = model.capturedImage {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("YOUR UPDATED CEILING")
                                .font(DQFont.mono(11, weight: .semibold))
                                .foregroundStyle(DQColor.accentBright)
                                .tracking(2)
                            DQBeforeAfterSlider(before: current, after: model.potentialImage)
                                .frame(height: 320)
                        }
                    }

                    DQPrimaryButton(title: "Start next 14 days") { onContinue() }
                        .padding(.top, 4)
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
        }
        .scrollIndicators(.hidden)
        .background(DQColor.background.ignoresSafeArea())
        .task { await playMorph() }
    }

    /// Flat "hero" number (no ring) — the score counts up, then a delta pill
    /// lands. Matches the UMax-style grid the rest of the results use.
    private func overallHero(old: Int, new: Int) -> some View {
        VStack(spacing: 10) {
            Text("OVERALL")
                .font(DQFont.mono(11, weight: .semibold))
                .foregroundStyle(DQColor.textSecondary)
                .tracking(3)
            Text(verbatim: "\(shownScore)")
                .font(.system(size: 80, weight: .heavy, design: .rounded).monospacedDigit())
                .foregroundStyle(DQColor.textPrimary)
                .contentTransition(.numericText(value: Double(shownScore)))
            HStack(spacing: 5) {
                Image(systemName: new >= old ? "arrow.up" : "arrow.down")
                    .font(.system(size: 12, weight: .bold))
                Text(verbatim: "\(abs(new - old)) from \(old)")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
            }
            .foregroundStyle(new >= old ? DQColor.deltaUp : DQColor.deltaDown)
            .padding(.horizontal, 13)
            .padding(.vertical, 7)
            .background((new >= old ? DQColor.deltaUp : DQColor.deltaDown).opacity(0.12), in: Capsule())
            .opacity(morphDone ? 1 : 0)
            .animation(VMotion.gentle, value: morphDone)
        }
        .padding(.vertical, 20)
        .frame(maxWidth: .infinity)
        .background(DQColor.surface, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous)
            .strokeBorder(DQColor.stroke, lineWidth: 1))
    }

    private func deltaList(old: DermiqAnalysis, new: DermiqAnalysis) -> some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)],
                  spacing: 12) {
            ForEach(new.subScores) { score in
                DQSubScoreCard(
                    score: score,
                    delta: old.subScore(for: score.category).map { score.value - $0.value }
                )
            }
        }
    }

    private func playMorph() async {
        guard let old = oldAnalysis?.overall, let new = model.analysis?.overall else { return }
        shownScore = old
        try? await Task.sleep(for: .milliseconds(900))

        let range = stride(from: old, through: new, by: new >= old ? 1 : -1)
        for value in range {
            withAnimation(.linear(duration: 0.04)) { shownScore = value }
            if value % 3 == 0 { Haptics.fire(.tick) }
            try? await Task.sleep(for: .milliseconds(70))
        }
        morphDone = true
        Haptics.fire(.verdictReveal)
    }
}

// ============================================================
// MARK: — Screen 10: Progress Tab
// ============================================================

struct DermiqProgressTab: View {
    @Query(sort: \ScanRecord.date, order: .forward) private var scans: [ScanRecord]

    @State private var compareSelection: [ScanRecord] = []
    @State private var showCompare = false
    @State private var metric: DermiqCategory = .hydration

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("Progress")
                    .font(DQFont.title)
                    .foregroundStyle(DQColor.textPrimary)
                    .padding(.top, 18)

                if scans.isEmpty {
                    emptyState
                    DermiqBadgesSection()
                } else {
                    chartCard
                    metricChartCard
                    timelineSection
                    DermiqBadgesSection()
                    subScoreHistory
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 110)
        }
        .scrollIndicators(.hidden)
        .background(DQColor.background.ignoresSafeArea())
        .sheet(isPresented: $showCompare) {
            DermiqCompareSheet(scans: compareSelection)
                .presentationDetents([.large])
                .presentationBackground(DQColor.surface)
        }
    }

    // MARK: Score-over-time chart

    private var chartCard: some View {
        DQCard {
            VStack(alignment: .leading, spacing: 14) {
                Text("SCORE OVER TIME")
                    .font(DQFont.mono(11, weight: .semibold))
                    .foregroundStyle(DQColor.textSecondary)
                    .tracking(2)
                Chart(scans, id: \.id) { scan in
                    LineMark(
                        x: .value("Date", scan.date),
                        y: .value("Score", scan.overall)
                    )
                    .foregroundStyle(DQColor.accent)
                    .interpolationMethod(.catmullRom)
                    .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round))
                    PointMark(
                        x: .value("Date", scan.date),
                        y: .value("Score", scan.overall)
                    )
                    .foregroundStyle(DQColor.accentBright)
                    .symbolSize(46)
                }
                .chartYScale(domain: 0...100)
                .chartXAxis {
                    AxisMarks { _ in
                        AxisValueLabel()
                            .font(DQFont.mono(9))
                            .foregroundStyle(DQColor.textSecondary)
                    }
                }
                .chartYAxis {
                    AxisMarks(values: [0, 25, 50, 75, 100]) { _ in
                        AxisGridLine().foregroundStyle(DQColor.stroke)
                        AxisValueLabel()
                            .font(DQFont.mono(9))
                            .foregroundStyle(DQColor.textSecondary)
                    }
                }
                .frame(height: 190)
            }
        }
    }

    // MARK: Per-metric detail chart

    /// One metric across every scan — picked via chips. Needs at least two
    /// readings to draw a line, so it appears from the second scan on.
    @ViewBuilder
    private var metricChartCard: some View {
        let points: [MetricPoint] = scans.compactMap { scan in
            scan.analysis?.subScore(for: metric).map {
                MetricPoint(date: scan.date, value: $0.value)
            }
        }
        if points.count >= 2 {
            DQCard {
                VStack(alignment: .leading, spacing: 14) {
                    Text("METRIC DETAIL")
                        .font(DQFont.mono(11, weight: .semibold))
                        .foregroundStyle(DQColor.textSecondary)
                        .tracking(2)

                    // Metric picker chips.
                    ScrollView(.horizontal) {
                        HStack(spacing: 6) {
                            ForEach(DermiqCategory.allCases) { category in
                                let on = category == metric
                                Button {
                                    Haptics.fire(.tick)
                                    withAnimation(VMotion.gentle) { metric = category }
                                } label: {
                                    Text(category.displayName)
                                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                                        .foregroundStyle(on ? Color.white : DQColor.accentBright)
                                        .padding(.horizontal, 11)
                                        .padding(.vertical, 6)
                                        .background(on ? AnyShapeStyle(DQColor.accent)
                                                       : AnyShapeStyle(DQColor.accentSoft),
                                                    in: Capsule())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .scrollIndicators(.hidden)

                    Chart(points) { point in
                        AreaMark(
                            x: .value("Date", point.date),
                            y: .value("Score", point.value)
                        )
                        .foregroundStyle(
                            LinearGradient(colors: [DQColor.accent.opacity(0.16), .clear],
                                           startPoint: .top, endPoint: .bottom)
                        )
                        .interpolationMethod(.catmullRom)
                        LineMark(
                            x: .value("Date", point.date),
                            y: .value("Score", point.value)
                        )
                        .foregroundStyle(DQColor.accent)
                        .interpolationMethod(.catmullRom)
                        .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round))
                        PointMark(
                            x: .value("Date", point.date),
                            y: .value("Score", point.value)
                        )
                        .foregroundStyle(DQColor.accentBright)
                        .symbolSize(40)
                    }
                    .chartYScale(domain: 0...100)
                    .chartXAxis {
                        AxisMarks { _ in
                            AxisValueLabel()
                                .font(DQFont.mono(9))
                                .foregroundStyle(DQColor.textSecondary)
                        }
                    }
                    .chartYAxis {
                        AxisMarks(values: [0, 25, 50, 75, 100]) { _ in
                            AxisGridLine().foregroundStyle(DQColor.stroke)
                            AxisValueLabel()
                                .font(DQFont.mono(9))
                                .foregroundStyle(DQColor.textSecondary)
                        }
                    }
                    .frame(height: 170)
                    .id(metric)

                    // The honest takeaway line under the curve.
                    if let first = points.first?.value, let last = points.last?.value {
                        let delta = last - first
                        HStack(spacing: 5) {
                            Image(systemName: delta >= 0 ? "arrow.up.right" : "arrow.down.right")
                                .font(.system(size: 11, weight: .bold))
                            Text(verbatim: delta == 0
                                 ? "Flat since your first scan"
                                 : "\(delta > 0 ? "+" : "")\(delta) since your first scan")
                                .font(DQFont.caption)
                        }
                        .foregroundStyle(delta >= 0 ? DQColor.deltaUp : DQColor.deltaDown)
                    }
                }
            }
        }
    }

    // MARK: Photo timeline (tap any two to compare)

    private var timelineSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("SCAN TIMELINE")
                    .font(DQFont.mono(11, weight: .semibold))
                    .foregroundStyle(DQColor.textSecondary)
                    .tracking(2)
                Spacer()
                if compareSelection.count == 2 {
                    Button("Compare") { showCompare = true }
                        .font(DQFont.caption.weight(.semibold))
                        .foregroundStyle(DQColor.accentBright)
                }
            }
            ScrollView(.horizontal) {
                HStack(spacing: 10) {
                    ForEach(scans.reversed(), id: \.id) { scan in
                        thumbnail(scan)
                    }
                }
            }
            .scrollIndicators(.hidden)
            Text("Tap any two scans to compare them side by side.")
                .font(DQFont.micro)
                .foregroundStyle(DQColor.textSecondary)
        }
    }

    private func thumbnail(_ scan: ScanRecord) -> some View {
        let selected = compareSelection.contains { $0.id == scan.id }
        return Button {
            Haptics.fire(.selection)
            if selected {
                compareSelection.removeAll { $0.id == scan.id }
            } else {
                compareSelection.append(scan)
                if compareSelection.count > 2 { compareSelection.removeFirst() }
            }
        } label: {
            VStack(spacing: 5) {
                Group {
                    if let image = DermiqImageStore.load(scan.photoFilename) {
                        Image(uiImage: image).resizable().scaledToFill()
                    } else {
                        DQColor.surfaceElevated
                    }
                }
                .frame(width: 72, height: 92)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(selected ? DQColor.accent : DQColor.stroke,
                                      lineWidth: selected ? 2 : 1)
                )
                Text(scan.date, format: .dateTime.day().month(.abbreviated))
                    .font(DQFont.micro)
                    .foregroundStyle(DQColor.textSecondary)
            }
        }
        .buttonStyle(PressableStyle())
    }

    // MARK: Sub-score history (latest vs previous)

    @ViewBuilder
    private var subScoreHistory: some View {
        if let latest = scans.last?.analysis {
            let previous = scans.count >= 2 ? scans[scans.count - 2].analysis : nil
            VStack(alignment: .leading, spacing: 10) {
                Text("SUB-SCORES — LATEST SCAN")
                    .font(DQFont.mono(11, weight: .semibold))
                    .foregroundStyle(DQColor.textSecondary)
                    .tracking(2)
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)],
                          spacing: 12) {
                    ForEach(latest.subScores) { score in
                        DQSubScoreCard(
                            score: score,
                            delta: previous?.subScore(for: score.category).map { score.value - $0.value }
                        )
                    }
                }
            }
        }
    }

    private var emptyState: some View {
        DQCard {
            VStack(spacing: 10) {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.system(size: 30, weight: .light))
                    .foregroundStyle(DQColor.textSecondary)
                Text("Your first scan starts the timeline.")
                    .font(DQFont.body)
                    .foregroundStyle(DQColor.textSecondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 24)
        }
    }
}

/// One (date, value) reading of a single metric — chart fodder.
private struct MetricPoint: Identifiable {
    let date: Date
    let value: Int
    var id: Date { date }
}

/// Side-by-side comparison of any two scans.
private struct DermiqCompareSheet: View {
    let scans: [ScanRecord]
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 18) {
            Capsule().fill(DQColor.stroke).frame(width: 40, height: 4).padding(.top, 12)
            Text("Compare")
                .font(DQFont.title)
                .foregroundStyle(DQColor.textPrimary)

            HStack(spacing: 12) {
                ForEach(scans.sorted { $0.date < $1.date }, id: \.id) { scan in
                    VStack(spacing: 8) {
                        Group {
                            if let image = DermiqImageStore.load(scan.photoFilename) {
                                Image(uiImage: image).resizable().scaledToFill()
                            } else {
                                DQColor.surfaceElevated
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 330)
                        .clipShape(RoundedRectangle(cornerRadius: DQRadius.card, style: .continuous))

                        Text(verbatim: "\(scan.overall)")
                            .font(DQFont.score(34))
                            .foregroundStyle(DQColor.textPrimary)
                        Text(scan.date, format: .dateTime.day().month().year())
                            .font(DQFont.micro)
                            .foregroundStyle(DQColor.textSecondary)
                    }
                }
            }
            .padding(.horizontal, 20)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(DQColor.surface)
    }
}
