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

                }

                // Always reachable — even if the previous analysis failed to
                // decode, the user must be able to leave this screen.
                DQPrimaryButton(title: "Start next 14 days") { onContinue() }
                    .padding(.top, 4)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
        }
        .scrollIndicators(.hidden)
        .background(DQColor.background.ignoresSafeArea())
        .task { await playMorph() }
    }

    /// UMax-style hero: YOUR new scan photo straddles the top of the card, the
    /// score counts up beneath it, then a delta pill lands.
    private func overallHero(old: Int, new: Int) -> some View {
        ZStack(alignment: .top) {
            VStack(spacing: 10) {
                Text("OVERALL")
                    .font(DQFont.mono(11, weight: .semibold))
                    .foregroundStyle(DQColor.textSecondary)
                    .tracking(3)
                Text(verbatim: "\(shownScore)")
                    .font(.system(size: 76, weight: .heavy, design: .rounded).monospacedDigit())
                    .foregroundStyle(DQColor.textPrimary)
                    .contentTransition(.numericText(value: Double(shownScore)))
                HStack(spacing: 5) {
                    if new != old {
                        Image(systemName: new > old ? "arrow.up" : "arrow.down")
                            .font(.system(size: 12, weight: .bold))
                    }
                    (new == old ? Text("No change") : Text("\(abs(new - old)) from \(old)"))
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                }
                .foregroundStyle(new >= old ? DQColor.deltaUp : DQColor.deltaDown)
                .padding(.horizontal, 13)
                .padding(.vertical, 7)
                .background((new >= old ? DQColor.deltaUp : DQColor.deltaDown).opacity(0.12), in: Capsule())
                .opacity(morphDone ? 1 : 0)
                .animation(VMotion.gentle, value: morphDone)
            }
            .padding(.top, 60)
            .padding(.bottom, 22)
            .frame(maxWidth: .infinity)
            .background(DQColor.surface, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(DQColor.stroke, lineWidth: 1))

            heroAvatar
                .offset(y: -46)
        }
        .padding(.top, 46)
    }

    /// The new scan photo, framed with a soft ring — sits half over the card.
    private var heroAvatar: some View {
        Group {
            if let image = model.capturedImage {
                Image(uiImage: image).resizable().scaledToFill()
            } else {
                ZStack {
                    DQColor.accentSoft
                    Image(systemName: "face.smiling")
                        .font(.system(size: 30, weight: .light))
                        .foregroundStyle(DQColor.accentBright)
                }
            }
        }
        .frame(width: 92, height: 92)
        .clipShape(Circle())
        .overlay(Circle().strokeBorder(DQColor.surface, lineWidth: 4))
        .overlay(Circle().strokeBorder(DQColor.accentSoft, lineWidth: 4).padding(-4))
        .shadow(color: DQColor.accent.opacity(0.28), radius: 14, y: 8)
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
    @State private var showReel = false
    @State private var metric: DermiqCategory = .hydration

    /// Scans that can appear in the Glow-Up Reel (need a stored photo).
    private var reelScans: [ScanRecord] { scans.filter { $0.photoFilename != nil } }

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
                    if reelScans.count >= 2 {
                        reelCard
                    }
                    metricChartCard
                    timelineSection
                    DermiqBadgesSection()
                    subScoreHistory
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 28)   // breathing room above the system tab bar
        }
        .scrollIndicators(.hidden)
        .background(DQColor.background.ignoresSafeArea())
        .sheet(isPresented: $showCompare) {
            DermiqCompareSheet(scans: compareSelection)
                .presentationDetents([.large])
                .presentationBackground(DQColor.surface)
        }
        .sheet(isPresented: $showReel) {
            GlowUpReelSheet(scans: reelScans)
        }
    }

    // MARK: Glow-Up Reel entry

    private var reelCard: some View {
        Button {
            Haptics.fire(.selection)
            showReel = true
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    Circle().fill(.white.opacity(0.18))
                    Image(systemName: "film.fill")
                        .font(.system(size: 19, weight: .semibold))
                        .foregroundStyle(.white)
                }
                .frame(width: 46, height: 46)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Glow-Up Reel")
                        .font(.system(size: 17, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                    Text("Turn your \(reelScans.count) scans into a share-ready video")
                        .font(DQFont.micro)
                        .foregroundStyle(.white.opacity(0.85))
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.8))
            }
            .padding(16)
            .background(
                DQColor.accentGradient,
                in: RoundedRectangle(cornerRadius: DQRadius.card, style: .continuous)
            )
            .shadow(color: DQColor.accent.opacity(0.25), radius: 14, y: 6)
        }
        .buttonStyle(PressableStyle())
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
                .frame(height: 158)
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
                                    Text(LocalizedStringKey(category.displayName))
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
                    .frame(height: 150)
                    .id(metric)

                    // The honest takeaway line under the curve.
                    if let first = points.first?.value, let last = points.last?.value {
                        let delta = last - first
                        HStack(spacing: 5) {
                            Image(systemName: delta >= 0 ? "arrow.up.right" : "arrow.down.right")
                                .font(.system(size: 11, weight: .bold))
                            (delta == 0
                             ? Text("Flat since your first scan")
                             : (delta > 0 ? Text("+\(delta) since your first scan")
                                          : Text("\(delta) since your first scan")))
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
            if scans.count >= 2 {
                Text("Tap any two scans to compare them side by side.")
                    .font(DQFont.micro)
                    .foregroundStyle(DQColor.textSecondary)
            }
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
