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
        .onAppear {
            // Onboarding hands off straight into the camera: with zero scans,
            // open the capture flow IMMEDIATELY and without the cover's slide
            // animation, so the home dashboard never flashes behind it.
            guard !autoLaunched, scans.isEmpty else { return }
            autoLaunched = true
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) { showFlow = true }
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
                    heroCard(latest)
                }
                todaysPlanCard
                curveCard
                tipCard
                DQPrimaryButton(title: "New scan", systemImage: "faceid") { onScan() }
                    .padding(.top, 4)
            }
            .padding(.horizontal, 24)
            .padding(.top, 16)
            .padding(.bottom, 110)
        }
        .scrollIndicators(.hidden)
    }

    /// The hero: your photo + the score + the honest path to your potential —
    /// the GlamUp/UMax pattern (one big personal card carries the screen).
    private func heroCard(_ latest: ScanRecord) -> some View {
        let previous = scans.dropFirst().first
        let delta = previous.map { latest.overall - $0.overall }
        let potential = latest.analysis.map { DermiqProjection.project($0).overall }
        let streak = plans.first?.streak ?? 0

        return VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 14) {
                heroAvatar(latest)
                VStack(alignment: .leading, spacing: 3) {
                    Text("YOUR SKIN SCORE")
                        .font(DQFont.mono(10, weight: .semibold))
                        .foregroundStyle(DQColor.textSecondary)
                        .tracking(1.5)
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(verbatim: "\(latest.overall)")
                            .font(.system(size: 44, weight: .heavy, design: .rounded).monospacedDigit())
                            .foregroundStyle(DQColor.textPrimary)
                        if let delta, delta != 0 {
                            HStack(spacing: 3) {
                                Image(systemName: delta > 0 ? "arrow.up" : "arrow.down")
                                    .font(.system(size: 10, weight: .bold))
                                Text(verbatim: "\(abs(delta))")
                                    .font(.system(size: 13, weight: .bold, design: .rounded))
                            }
                            .foregroundStyle(delta > 0 ? DQColor.deltaUp : DQColor.deltaDown)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background((delta > 0 ? DQColor.deltaUp : DQColor.deltaDown).opacity(0.12),
                                        in: Capsule())
                        }
                    }
                }
                Spacer(minLength: 0)
                if streak > 0 {
                    VStack(spacing: 1) {
                        Image(systemName: "flame.fill")
                            .font(.system(size: 15))
                            .foregroundStyle(DQColor.deltaUp)
                        Text(verbatim: "\(streak)")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundStyle(DQColor.textPrimary)
                    }
                    .padding(10)
                    .background(DQColor.surfaceElevated, in: Circle())
                }
            }

            // The path to the projected potential — one honest bar.
            if let potential, potential > latest.overall {
                VStack(alignment: .leading, spacing: 6) {
                    GeometryReader { proxy in
                        ZStack(alignment: .leading) {
                            Capsule().fill(DQColor.stroke.opacity(0.6))
                            // Potential marker zone (soft) …
                            Capsule().fill(DQColor.accentSoft)
                                .frame(width: proxy.size.width * CGFloat(potential) / 100)
                            // …and where you are today (solid).
                            Capsule().fill(DQColor.accent)
                                .frame(width: proxy.size.width * CGFloat(latest.overall) / 100)
                        }
                    }
                    .frame(height: 8)
                    HStack {
                        Text(verbatim: "Now \(latest.overall)")
                            .font(DQFont.micro)
                            .foregroundStyle(DQColor.textSecondary)
                        Spacer()
                        Text(verbatim: "Potential \(potential) · 14d est.")
                            .font(DQFont.micro.weight(.semibold))
                            .foregroundStyle(DQColor.accentBright)
                    }
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(DQColor.surface, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(DQColor.stroke, lineWidth: 1)
        )
        .shadow(color: DQColor.accent.opacity(0.08), radius: 18, y: 8)
    }

    @ViewBuilder
    private func heroAvatar(_ latest: ScanRecord) -> some View {
        Group {
            if let image = DermiqImageStore.load(latest.photoFilename) {
                Image(uiImage: image).resizable().scaledToFill()
            } else {
                ZStack {
                    DQColor.accentSoft
                    Image(systemName: "faceid")
                        .font(.system(size: 22, weight: .light))
                        .foregroundStyle(DQColor.accentBright)
                }
            }
        }
        .frame(width: 64, height: 64)
        .clipShape(Circle())
        .overlay(Circle().strokeBorder(DQColor.accentSoft, lineWidth: 3))
    }

    /// Today's plan, previewed right on Home: the next steps with live checks
    /// and one tap into the Routine tab — GlamUp's "today card" pattern.
    @ViewBuilder
    private var todaysPlanCard: some View {
        if let plan = plans.first {
            let day = plan.dayIndex()
            let block: RoutineBlock = plan.blockComplete(day: day, .am) ? .pm : .am
            let steps = Array(plan.steps(block).prefix(3))
            Button {
                Haptics.fire(.selection)
                onRoutine()
            } label: {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        HStack(spacing: 6) {
                            Image(systemName: block == .am ? "sun.max.fill" : "moon.stars.fill")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(DQColor.accentBright)
                            Text(verbatim: "TODAY · DAY \(day) OF 14")
                                .font(DQFont.mono(10, weight: .semibold))
                                .foregroundStyle(DQColor.textSecondary)
                                .tracking(1.5)
                        }
                        Spacer()
                        HStack(spacing: 3) {
                            Text(block == .am ? "Morning" : "Evening")
                            Image(systemName: "chevron.right")
                        }
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(DQColor.accentBright)
                    }

                    ForEach(steps) { step in
                        HStack(spacing: 10) {
                            let done = plan.isDone(day: day, block: block, step: step)
                            Image(systemName: done ? "checkmark.circle.fill" : "circle")
                                .font(.system(size: 18))
                                .foregroundStyle(done ? DQColor.deltaUp : DQColor.stroke)
                            Text(step.productType)
                                .font(DQFont.headline)
                                .foregroundStyle(done ? DQColor.textSecondary : DQColor.textPrimary)
                                .strikethrough(done, color: DQColor.textSecondary)
                                .lineLimit(1)
                            Spacer(minLength: 0)
                        }
                    }
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(DQColor.surface, in: RoundedRectangle(cornerRadius: DQRadius.card, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: DQRadius.card, style: .continuous)
                        .strokeBorder(DQColor.stroke, lineWidth: 1)
                )
            }
            .buttonStyle(PressableStyle())
        }
    }

    /// Trend teaser — one slim row into the Progress tab.
    private var curveCard: some View {
        Button {
            Haptics.fire(.selection)
            onProgress()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(DQColor.accentBright)
                    .frame(width: 34, height: 34)
                    .background(DQColor.accentSoft, in: RoundedRectangle(cornerRadius: 11, style: .continuous))
                VStack(alignment: .leading, spacing: 1) {
                    Text(verbatim: "\(scans.count) \(scans.count == 1 ? "reading" : "readings")")
                        .font(DQFont.headline)
                        .foregroundStyle(DQColor.textPrimary)
                    Text("See your curve")
                        .font(DQFont.micro)
                        .foregroundStyle(DQColor.textSecondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(DQColor.textSecondary)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
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
