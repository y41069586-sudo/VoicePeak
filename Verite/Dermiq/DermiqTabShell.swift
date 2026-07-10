import SwiftUI
import SwiftData

// ============================================================
// MARK: — v2 shell: Scan / Routine / Progress
// ============================================================

struct DermiqTabShell: View {
    enum Tab: String, CaseIterable {
        case scan, routine, progress

        var title: String {
            switch self {
            case .scan: return "Scan"
            case .routine: return "Routine"
            case .progress: return "Progress"
            }
        }

        var icon: String {
            switch self {
            case .scan: return "faceid"
            case .routine: return "checklist"
            case .progress: return "chart.line.uptrend.xyaxis"
            }
        }
    }

    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ScanRecord.date, order: .reverse) private var scans: [ScanRecord]

    @State private var tab: Tab = .scan
    @State private var showFlow = false
    @State private var showSettings = false
    @State private var autoLaunched = false

    var body: some View {
        ZStack(alignment: .bottom) {
            Group {
                switch tab {
                case .scan:
                    DermiqScanHome(
                        scans: scans,
                        onScan: { startScan() },
                        onSettings: { showSettings = true },
                        onRoutine: { withAnimation(VMotion.snappy) { tab = .routine } },
                        onProgress: { withAnimation(VMotion.snappy) { tab = .progress } }
                    )
                case .routine:
                    DermiqRoutineTab { startScan() }
                case .progress:
                    DermiqProgressTab()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            tabBar
        }
        .background(DQColor.background.ignoresSafeArea())
        .dermiqBadgeAwards()
        .sheet(isPresented: $showSettings) {
            DermiqSettingsView()
        }
        .fullScreenCover(isPresented: $showFlow) {
            DermiqScanFlowView(previousScan: scans.first) { planCreated in
                showFlow = false
                if planCreated { tab = .routine }
                // Award scan badges once the cover is gone, so the popup
                // lands on the shell — never on top of the paywall.
                Task {
                    try? await Task.sleep(for: .milliseconds(700))
                    BadgeCenter.shared.evaluateScanMilestones(context: modelContext)
                }
            }
        }
        .task {
            // Onboarding hands off straight into Guided Capture: if the user
            // arrives with zero scans, open the flow at the moment of maximum
            // motivation instead of parking them on a home screen.
            guard !autoLaunched, scans.isEmpty else { return }
            autoLaunched = true
            try? await Task.sleep(for: .milliseconds(450))
            showFlow = true
        }
    }

    private func startScan() {
        Haptics.fire(.selection)
        showFlow = true
    }

    private var tabBar: some View {
        HStack {
            ForEach(Tab.allCases, id: \.rawValue) { item in
                Button {
                    Haptics.fire(.selection)
                    withAnimation(VMotion.snappy) { tab = item }
                } label: {
                    VStack(spacing: 3) {
                        Image(systemName: item.icon)
                            .font(.system(size: 19, weight: tab == item ? .semibold : .regular))
                        Text(item.title)
                            .font(DQFont.micro)
                    }
                    .foregroundStyle(tab == item ? DQColor.accentBright : DQColor.textSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            DQColor.surface.opacity(0.94),
            in: RoundedRectangle(cornerRadius: 22, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(DQColor.stroke, lineWidth: 1)
        )
        .padding(.horizontal, 24)
        .padding(.bottom, 10)
    }
}

// ============================================================
// MARK: — Screen 1: Home (the daily dashboard)
// ============================================================

/// The home tab is a real dashboard, not just a scan button: a personal
/// greeting, the latest score with its delta, today's ritual progress, a
/// daily tip and the score history — with the scan CTA always one thumb away.
/// Zero scans → a focused first-scan hero instead.
struct DermiqScanHome: View {
    let scans: [ScanRecord]
    let onScan: () -> Void
    let onSettings: () -> Void
    var onRoutine: () -> Void = {}
    var onProgress: () -> Void = {}

    @Query private var profiles: [UserProfile]
    @Query(filter: #Predicate<RoutinePlan> { $0.isActive },
           sort: \RoutinePlan.createdAt, order: .reverse)
    private var plans: [RoutinePlan]

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: .now)
        let base: String
        switch hour {
        case 5..<12:  base = "Good morning"
        case 12..<18: base = "Good afternoon"
        default:      base = "Good evening"
        }
        if let name = profiles.first?.displayName, !name.isEmpty {
            return "\(base), \(name)"
        }
        return base
    }

    /// One gentle, rotating tip a day — deterministic by day-of-year.
    private var dailyTip: String {
        let tips = [
            "SPF is the single biggest lever for your score — even on cloudy days.",
            "Glow follows sleep. Tonight's 8 hours show up in Thursday's scan.",
            "Consistency beats intensity: two gentle steps daily outwork a weekly overhaul.",
            "Hydration reads instantly on camera — water before coffee.",
            "Redness calms fastest when you skip hot water on your face.",
            "Texture changes are slow and real — trust the 14-day rhythm.",
            "Your evening cleanse matters more than any serum layered on top.",
        ]
        let day = Calendar.current.ordinality(of: .day, in: .year, for: .now) ?? 0
        return tips[day % tips.count]
    }

    var body: some View {
        VStack(spacing: 0) {
            header

            if scans.isEmpty {
                firstScanHero
            } else {
                dashboard
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(DQColor.background.ignoresSafeArea())
    }

    // MARK: Header

    private var header: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 1) {
                Text(greeting)
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(DQColor.textPrimary)
                Text(Date.now.formatted(date: .abbreviated, time: .omitted))
                    .font(DQFont.caption)
                    .foregroundStyle(DQColor.textSecondary)
            }
            Spacer()
            Button {
                Haptics.fire(.selection)
                onSettings()
            } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(DQColor.textSecondary)
                    .frame(width: 36, height: 36)
                    .background(DQColor.surface, in: Circle())
                    .overlay(Circle().strokeBorder(DQColor.stroke, lineWidth: 1))
            }
            .accessibilityLabel("Settings")
        }
        .padding(.horizontal, 24)
        .padding(.top, 14)
    }

    // MARK: First-scan hero (zero scans)

    private var firstScanHero: some View {
        VStack(spacing: 0) {
            Spacer()
            DQScanPortal()
                .frame(width: 260, height: 260)
                .onTapGesture { onScan() }
                .accessibilityAddTraits(.isButton)
                .accessibilityLabel("Scan your skin")
            Spacer()
            VStack(spacing: 8) {
                DQPrimaryButton(title: "Scan your skin", systemImage: "faceid") { onScan() }
                Text("Your first reading takes under a minute.")
                    .font(DQFont.micro)
                    .foregroundStyle(DQColor.textSecondary)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 96)
        }
    }

    // MARK: Dashboard (has scans)

    private var dashboard: some View {
        ScrollView {
            VStack(spacing: 14) {
                if let latest = scans.first {
                    scoreCard(latest)
                }
                HStack(spacing: 14) {
                    ritualCard
                    progressCard
                }
                tipCard
                DQPrimaryButton(title: "New scan", systemImage: "faceid") { onScan() }
                    .padding(.top, 4)

                if scans.count > 1 {
                    ScrollView(.horizontal) {
                        HStack(spacing: 8) {
                            ForEach(scans, id: \.id) { scan in
                                DQHistoryChip(date: scan.date, overall: scan.overall)
                            }
                        }
                    }
                    .scrollIndicators(.hidden)
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 18)
            .padding(.bottom, 110)
        }
        .scrollIndicators(.hidden)
    }

    private func scoreCard(_ latest: ScanRecord) -> some View {
        let previous = scans.dropFirst().first
        let delta = previous.map { latest.overall - $0.overall }
        return HStack(spacing: 18) {
            ZStack {
                DQScoreRing(progress: Double(latest.overall) / 100, lineWidth: 7)
                    .frame(width: 92, height: 92)
                Text(verbatim: "\(latest.overall)")
                    .font(.system(size: 30, weight: .heavy, design: .rounded).monospacedDigit())
                    .foregroundStyle(DQColor.textPrimary)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text("YOUR SCORE")
                    .font(DQFont.mono(10, weight: .semibold))
                    .foregroundStyle(DQColor.textSecondary)
                    .tracking(1.5)
                if let delta, delta != 0 {
                    HStack(spacing: 5) {
                        Image(systemName: delta > 0 ? "arrow.up.right" : "arrow.down.right")
                            .font(.system(size: 12, weight: .bold))
                        Text(verbatim: "\(delta > 0 ? "+" : "")\(delta) since last scan")
                            .font(DQFont.caption)
                    }
                    .foregroundStyle(delta > 0 ? DQColor.deltaUp : DQColor.deltaDown)
                } else {
                    Text("Scan again to see your trend.")
                        .font(DQFont.caption)
                        .foregroundStyle(DQColor.textSecondary)
                }
                Text(latest.date.formatted(date: .abbreviated, time: .omitted))
                    .font(DQFont.micro)
                    .foregroundStyle(DQColor.textSecondary)
            }
            Spacer(minLength: 0)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(DQColor.surface, in: RoundedRectangle(cornerRadius: DQRadius.card, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: DQRadius.card, style: .continuous)
                .strokeBorder(DQColor.stroke, lineWidth: 1)
        )
    }

    /// Today's ritual at a glance — taps through to the Routine tab.
    private var ritualCard: some View {
        Button {
            Haptics.fire(.selection)
            onRoutine()
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                Image(systemName: "sparkles")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(DQColor.accentBright)
                if let plan = plans.first {
                    let day = plan.dayIndex()
                    Text(verbatim: "Day \(day) of 14")
                        .font(DQFont.headline)
                        .foregroundStyle(DQColor.textPrimary)
                    Text(ritualStatus(plan, day: day))
                        .font(DQFont.micro)
                        .foregroundStyle(DQColor.textSecondary)
                } else {
                    Text("Your ritual")
                        .font(DQFont.headline)
                        .foregroundStyle(DQColor.textPrimary)
                    Text("Unlocks with your scan")
                        .font(DQFont.micro)
                        .foregroundStyle(DQColor.textSecondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(DQColor.surface, in: RoundedRectangle(cornerRadius: DQRadius.card, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: DQRadius.card, style: .continuous)
                    .strokeBorder(DQColor.stroke, lineWidth: 1)
            )
        }
        .buttonStyle(PressableStyle())
    }

    private func ritualStatus(_ plan: RoutinePlan, day: Int) -> String {
        let am = plan.blockComplete(day: day, .am)
        let pm = plan.blockComplete(day: day, .pm)
        switch (am, pm) {
        case (true, true):  return "Today complete ✓"
        case (true, false): return "Evening still open"
        case (false, _):    return "Morning still open"
        }
    }

    /// Trend teaser — taps through to the Progress tab.
    private var progressCard: some View {
        Button {
            Haptics.fire(.selection)
            onProgress()
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(DQColor.accentBright)
                Text(verbatim: "\(scans.count) \(scans.count == 1 ? "reading" : "readings")")
                    .font(DQFont.headline)
                    .foregroundStyle(DQColor.textPrimary)
                Text("See your curve")
                    .font(DQFont.micro)
                    .foregroundStyle(DQColor.textSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(DQColor.surface, in: RoundedRectangle(cornerRadius: DQRadius.card, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: DQRadius.card, style: .continuous)
                    .strokeBorder(DQColor.stroke, lineWidth: 1)
            )
        }
        .buttonStyle(PressableStyle())
    }

    private var tipCard: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "lightbulb.max")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(DQColor.accentBright)
                .padding(.top, 1)
            VStack(alignment: .leading, spacing: 3) {
                Text("TODAY'S TIP")
                    .font(DQFont.mono(9, weight: .semibold))
                    .foregroundStyle(DQColor.textSecondary)
                    .tracking(1.5)
                Text(dailyTip)
                    .font(DQFont.caption)
                    .foregroundStyle(DQColor.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(DQColor.surfaceElevated, in: RoundedRectangle(cornerRadius: DQRadius.card, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: DQRadius.card, style: .continuous)
                .strokeBorder(DQColor.stroke, lineWidth: 1)
        )
    }
}
