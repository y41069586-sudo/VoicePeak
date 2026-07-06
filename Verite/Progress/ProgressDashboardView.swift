import SwiftUI
import SwiftData
import Charts

/// Whole-face progress: milestones, a per-attribute trend (Swift Charts), a
/// side-by-side compare of any two days, and the scan timeline. All change is
/// tracked as estimates vs the user's own history — never a beauty score.
struct ProgressDashboardView: View {
    @Query private var scans: [Scan]
    @Query private var progresses: [UserProgress]
    @Query private var tests: [HalfFaceTest]
    @Query private var ledgers: [SavingsLedger]

    @State private var attribute: SkinAttribute = .redness
    @State private var dayA: Scan?
    @State private var dayB: Scan?

    private var fullScans: [Scan] {
        scans.filter { $0.side == .full }.sorted { $0.date < $1.date }
    }

    private var effectiveStreakCount: Int {
        guard let p = progresses.first, let last = p.lastScanDate else { return 0 }
        let cal = Calendar.current
        if cal.isDateInToday(last) || cal.isDateInYesterday(last) {
            return p.currentStreak
        }
        return 0
    }

    var body: some View {
        NavigationStack {
            Group {
                if fullScans.isEmpty {
                    emptyState
                } else {
                    ScrollView {
                        VStack(spacing: 16) {
                            milestones
                            trendCard
                            if fullScans.count >= 2 { compareCard }
                            timelineCard
                            DisclaimerBanner(style: .short)
                        }
                        .padding(20)
                    }
                    .scrollIndicators(.hidden)
                }
            }
            .navigationTitle("tab.progress")
            .background(GradientMeshBackground())
        }
    }

    // MARK: Milestones

    private var milestones: some View {
        HStack(spacing: 10) {
            StatTile(value: "\(fullScans.count)", labelKey: "progress.stat.scans", tone: .info)
            StatTile(value: "\(effectiveStreakCount)", labelKey: "progress.stat.streak", tone: .warning)
            StatTile(value: "\(tests.filter { $0.status == .passed }.count)", labelKey: "progress.stat.tested", tone: .success)
        }
    }

    // MARK: Trend

    private struct TrendPoint: Identifiable {
        let id = UUID()
        let date: Date
        let value: Double
    }

    private var points: [TrendPoint] {
        fullScans.compactMap { scan in
            scan.score(for: attribute).map { TrendPoint(date: scan.date, value: $0) }
        }
    }

    private var trendCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("progress.trend").font(.subheadline.weight(.semibold)).foregroundStyle(Theme.textSecondary)
                    Spacer()
                    Picker("progress.trend", selection: $attribute) {
                        ForEach(SkinAttribute.allCases) { attr in
                            Text(attr.localizationKey).tag(attr)
                        }
                    }
                    .labelsHidden()
                    .tint(Theme.primary)
                }
                Chart(points) { point in
                    AreaMark(x: .value("Day", point.date), y: .value("Level", point.value))
                        .foregroundStyle(LinearGradient(colors: [Theme.primary.opacity(0.25), .clear],
                                                        startPoint: .top, endPoint: .bottom))
                    LineMark(x: .value("Day", point.date), y: .value("Level", point.value))
                        .foregroundStyle(Theme.primary)
                        .interpolationMethod(.catmullRom)
                    PointMark(x: .value("Day", point.date), y: .value("Level", point.value))
                        .foregroundStyle(Theme.primary)
                }
                .chartYScale(domain: 0...1)
                .frame(height: 170)
            }
        }
    }

    // MARK: Compare

    private var compareCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("progress.compare").font(.subheadline.weight(.semibold)).foregroundStyle(Theme.textSecondary)
                HStack(spacing: 12) {
                    dayPicker(titleKey: "progress.compare.a", selection: $dayA)
                    dayPicker(titleKey: "progress.compare.b", selection: $dayB)
                }
                ForEach(SkinAttribute.allCases) { attr in
                    HStack {
                        Text(attr.localizationKey).font(.footnote).foregroundStyle(Theme.textPrimary)
                        Spacer()
                        Text(percent(resolvedA?.score(for: attr)))
                            .font(Typography.number(13)).foregroundStyle(Theme.textSecondary)
                            .frame(width: 52, alignment: .trailing)
                        Image(systemName: "arrow.right").font(.caption2).foregroundStyle(Theme.textSecondary)
                        Text(percent(resolvedB?.score(for: attr)))
                            .font(Typography.number(13)).foregroundStyle(Theme.textPrimary)
                            .frame(width: 52, alignment: .trailing)
                    }
                }
            }
        }
    }

    private var resolvedA: Scan? { dayA ?? fullScans.first }
    private var resolvedB: Scan? { dayB ?? fullScans.last }

    private func dayPicker(titleKey: LocalizedStringKey, selection: Binding<Scan?>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(titleKey).font(.caption2).foregroundStyle(Theme.textSecondary)
            Menu {
                ForEach(fullScans) { scan in
                    Button(dateLabel(scan)) { selection.wrappedValue = scan }
                }
            } label: {
                HStack {
                    Text(dateLabel(selection.wrappedValue ?? (titleKey == "progress.compare.a" ? fullScans.first : fullScans.last)))
                        .font(.footnote)
                    Image(systemName: "chevron.up.chevron.down").font(.caption2)
                }
                .foregroundStyle(Theme.textPrimary)
                .padding(.horizontal, 12).padding(.vertical, 8)
                .frame(maxWidth: .infinity)
                .background(Theme.bgElevated, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(Theme.strokeSubtle, lineWidth: 1))
            }
        }
    }

    // MARK: Timeline

    private var timelineCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("progress.timeline").font(.subheadline.weight(.semibold)).foregroundStyle(Theme.textSecondary)
                ForEach(Array(fullScans.reversed())) { scan in
                    HStack(spacing: 12) {
                        thumbnail(for: scan)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(dateLabel(scan)).font(.subheadline).foregroundStyle(Theme.textPrimary)
                            if scan.isBaseline {
                                Text("scan.captured.baseline").font(.caption2).foregroundStyle(Theme.accent)
                            }
                        }
                        Spacer()
                        Text(scan.captureQuality.formatted(.percent.precision(.fractionLength(0))))
                            .font(Typography.number(12)).foregroundStyle(Theme.textSecondary)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func thumbnail(for scan: Scan) -> some View {
        if let name = scan.thumbnailFilename, let image = ThumbnailStore.load(name) {
            Image(uiImage: image).resizable().scaledToFill()
                .frame(width: 40, height: 50)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        } else {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Theme.bgElevated).frame(width: 40, height: 50)
                .overlay(Image(systemName: "face.smiling").foregroundStyle(Theme.textSecondary))
        }
    }

    // MARK: Empty

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.system(size: 46, weight: .light)).foregroundStyle(Theme.accent)
            Text("progress.empty.title").font(Typography.display(24)).foregroundStyle(Theme.textPrimary)
            Text("progress.empty.body").font(.subheadline).foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center).padding(.horizontal, 34)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: Helpers

    private func dateLabel(_ scan: Scan?) -> String {
        guard let scan else { return "—" }
        return scan.date.formatted(date: .abbreviated, time: .omitted)
    }

    private func percent(_ value: Double?) -> String {
        guard let value else { return "—" }
        return value.formatted(.percent.precision(.fractionLength(0)))
    }
}

/// A compact stat tile for the milestones row.
private struct StatTile: View {
    let value: String
    let labelKey: LocalizedStringKey
    let tone: PillTag.Tone

    var body: some View {
        VStack(spacing: 4) {
            Text(verbatim: value)
                .font(Typography.number(26, weight: .bold))
                .foregroundStyle(color)
            Text(labelKey)
                .font(.caption2)
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(Theme.strokeSubtle, lineWidth: 1))
    }

    private var color: Color {
        switch tone {
        case .success: return Theme.success
        case .warning: return Theme.warning
        case .danger: return Theme.danger
        default: return Theme.primary
        }
    }
}
