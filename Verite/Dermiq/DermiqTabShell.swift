import SwiftUI
import SwiftData
import UIKit

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

    /// Which carousel card is in view (drives the page dots).
    @State private var homeCard: Int? = 0

    var body: some View {
        VStack(spacing: 0) {
            header
            home
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(DQColor.background.ignoresSafeArea())
    }

    // MARK: Header

    private var header: some View {
        HStack(spacing: 14) {
            Text(greeting)
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(DQColor.textSecondary)
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

    // MARK: Home (the GlamUp pattern: big headline + scan-card carousel)

    private var home: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Ready to\nglow?")
                        .font(.system(size: 36, weight: .heavy, design: .rounded))
                        .foregroundStyle(DQColor.textPrimary)
                        .lineSpacing(1)
                    Text(scans.isEmpty ? "Choose a scan to start" : "Choose where to continue")
                        .font(DQFont.body)
                        .foregroundStyle(DQColor.textSecondary)
                }
                .padding(.horizontal, 24)
                .padding(.top, 12)

                carousel
                pageDots

                if let latest = scans.first {
                    lastReadingRow(latest)
                        .padding(.horizontal, 24)
                }

                tipCard
                    .padding(.horizontal, 24)
            }
            .padding(.bottom, 110)
        }
        .scrollIndicators(.hidden)
    }

    /// The swipeable card deck — one big card per destination, each carrying a
    /// REAL visual (viewfinder with your photo, the live 14-day grid, your
    /// actual curve) instead of an icon in a disc, plus its own CTA.
    private var carousel: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 14) {
                deckCard(index: 0,
                         title: scans.isEmpty ? "First Skin Scan" : "Skin Scan",
                         sub: "One photo. An honest 0–100 score across 7 metrics.",
                         button: scans.isEmpty ? "Start scan" : "New scan",
                         action: onScan) {
                    DeckScanVisual(photo: scans.first.flatMap { DermiqImageStore.load($0.photoFilename) })
                }
                planDeckCard(index: 1)
                deckCard(index: 2,
                         title: "Progress",
                         sub: scans.isEmpty
                            ? "Every reading lands on your curve — watch it climb."
                            : "\(scans.count) \(scans.count == 1 ? "reading" : "readings") on your curve so far.",
                         button: "See your curve",
                         action: onProgress) {
                    DeckCurveVisual(values: Array(scans.map(\.overall).reversed()))
                }
            }
            .scrollTargetLayout()
        }
        .contentMargins(.horizontal, 24, for: .scrollContent)
        .scrollTargetBehavior(.viewAligned)
        .scrollIndicators(.hidden)
        .scrollPosition(id: $homeCard)
    }

    /// The plan card adapts: live day + step status with a plan, teaser without.
    private func planDeckCard(index: Int) -> some View {
        let plan = plans.first
        let day = plan?.dayIndex() ?? 0
        let sub: String
        if let plan {
            let total = plan.steps(.am).count + plan.steps(.pm).count
            let done = plan.steps(.am).filter { plan.isDone(day: day, block: .am, step: $0) }.count
                     + plan.steps(.pm).filter { plan.isDone(day: day, block: .pm, step: $0) }.count
            sub = "Day \(day) of 14 — \(done) of \(total) steps done today."
        } else {
            sub = "Builds itself from your first scan — 14 days, morning & evening."
        }
        return deckCard(index: index,
                        title: "14-Day Plan",
                        sub: sub,
                        button: plan != nil ? "Open routine" : "Start with a scan",
                        action: plan != nil ? onRoutine : onScan) {
            DeckPlanVisual(plan: plan, today: day)
        }
    }

    private func deckCard<Visual: View>(index: Int, title: String, sub: String,
                                        button: String, action: @escaping () -> Void,
                                        @ViewBuilder visual: () -> Visual) -> some View {
        VStack(spacing: 0) {
            Spacer().frame(height: 24)
            visual()
                .frame(height: 158)
            Spacer().frame(height: 18)
            Text(title)
                .font(.system(size: 22, weight: .heavy, design: .rounded))
                .foregroundStyle(DQColor.textPrimary)
                .multilineTextAlignment(.center)
            Text(sub)
                .font(DQFont.caption)
                .foregroundStyle(DQColor.textSecondary)
                .multilineTextAlignment(.center)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 20)
                .padding(.top, 6)
            Spacer(minLength: 14)
            DQPrimaryButton(title: button) { action() }
                .padding(.horizontal, 18)
            Spacer().frame(height: 20)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 384)
        .background(DQColor.surface, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .strokeBorder(DQColor.stroke, lineWidth: 1)
        )
        .shadow(color: DQColor.accent.opacity(0.08), radius: 18, y: 8)
        .containerRelativeFrame(.horizontal) { length, _ in length * 0.8 }
        .id(index)
    }

    /// Slim segmented pager — quieter and more designed than dots.
    private var pageDots: some View {
        HStack(spacing: 5) {
            ForEach(0..<3, id: \.self) { index in
                Capsule()
                    .fill(index == (homeCard ?? 0) ? DQColor.accent : DQColor.stroke.opacity(0.8))
                    .frame(width: 26, height: 4)
            }
        }
        .frame(maxWidth: .infinity)
        .animation(VMotion.snappy, value: homeCard)
    }

    /// One slim personal row under the deck: your photo, last score, delta,
    /// projected potential — a tap opens Progress.
    private func lastReadingRow(_ latest: ScanRecord) -> some View {
        let previous = scans.dropFirst().first
        let delta = previous.map { latest.overall - $0.overall }
        let potential = latest.analysis.map { DermiqProjection.project($0).overall }
        return Button {
            Haptics.fire(.selection)
            onProgress()
        } label: {
            HStack(spacing: 12) {
                Group {
                    if let image = DermiqImageStore.load(latest.photoFilename) {
                        Image(uiImage: image).resizable().scaledToFill()
                    } else {
                        ZStack {
                            DQColor.accentSoft
                            Image(systemName: "faceid")
                                .font(.system(size: 15, weight: .light))
                                .foregroundStyle(DQColor.accentBright)
                        }
                    }
                }
                .frame(width: 42, height: 42)
                .clipShape(Circle())
                .overlay(Circle().strokeBorder(DQColor.accentSoft, lineWidth: 2))

                VStack(alignment: .leading, spacing: 1) {
                    Text("LAST READING")
                        .font(DQFont.mono(9, weight: .semibold))
                        .foregroundStyle(DQColor.textSecondary)
                        .tracking(1.5)
                    HStack(spacing: 6) {
                        Text(verbatim: "\(latest.overall)")
                            .font(.system(size: 20, weight: .heavy, design: .rounded).monospacedDigit())
                            .foregroundStyle(DQColor.textPrimary)
                        if let delta, delta != 0 {
                            HStack(spacing: 2) {
                                Image(systemName: delta > 0 ? "arrow.up" : "arrow.down")
                                    .font(.system(size: 9, weight: .bold))
                                Text(verbatim: "\(abs(delta))")
                                    .font(.system(size: 12, weight: .bold, design: .rounded))
                            }
                            .foregroundStyle(delta > 0 ? DQColor.deltaUp : DQColor.deltaDown)
                        }
                    }
                }
                Spacer()
                if let potential, potential > latest.overall {
                    VStack(alignment: .trailing, spacing: 1) {
                        Text("POTENTIAL · EST.")
                            .font(DQFont.mono(9, weight: .semibold))
                            .foregroundStyle(DQColor.textSecondary)
                            .tracking(1.5)
                        Text(verbatim: "\(potential)")
                            .font(.system(size: 17, weight: .bold, design: .rounded).monospacedDigit())
                            .foregroundStyle(DQColor.accentBright)
                    }
                }
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(DQColor.textSecondary)
            }
            .padding(13)
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

// ============================================================
// MARK: — Deck visuals (designed, data-driven — no icon-in-a-disc)
// ============================================================

/// Scan card visual: a soft viewfinder with corner brackets and a scan line.
/// Shows YOUR latest capture when one exists; a friendly face sketch before.
private struct DeckScanVisual: View {
    let photo: UIImage?

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(DQColor.accentSoft.opacity(0.5))
            Group {
                if let photo {
                    Image(uiImage: photo)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 96, height: 118)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                } else {
                    DeckFaceSketch()
                        .frame(width: 86, height: 108)
                }
            }
            DeckBrackets()
                .stroke(DQColor.accent, style: StrokeStyle(lineWidth: 3.5, lineCap: .round))
                .frame(width: 130, height: 146)
            LinearGradient(colors: [.clear, DQColor.accent.opacity(0.7), .clear],
                           startPoint: .leading, endPoint: .trailing)
                .frame(width: 118, height: 2.5)
                .offset(y: 12)
        }
        .frame(width: 190, height: 158)
    }
}

/// A friendly line-drawn face (head, eyes, smile) for the pre-photo state.
private struct DeckFaceSketch: View {
    var body: some View {
        ZStack {
            Ellipse()
                .strokeBorder(DQColor.accentBright, lineWidth: 3)
            HStack(spacing: 17) {
                Circle().fill(DQColor.accentBright).frame(width: 5.5, height: 5.5)
                Circle().fill(DQColor.accentBright).frame(width: 5.5, height: 5.5)
            }
            .offset(y: -7)
            DeckSmile()
                .stroke(DQColor.accentBright, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .frame(width: 26, height: 9)
                .offset(y: 20)
        }
    }
}

/// Four rounded viewfinder corner brackets.
private struct DeckBrackets: Shape {
    func path(in rect: CGRect) -> Path {
        let len = min(rect.width, rect.height) * 0.18
        let r: CGFloat = 10
        var p = Path()
        // Top-left
        p.move(to: CGPoint(x: rect.minX, y: rect.minY + len))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.minY + r))
        p.addQuadCurve(to: CGPoint(x: rect.minX + r, y: rect.minY),
                       control: CGPoint(x: rect.minX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.minX + len, y: rect.minY))
        // Top-right
        p.move(to: CGPoint(x: rect.maxX - len, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX - r, y: rect.minY))
        p.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.minY + r),
                       control: CGPoint(x: rect.maxX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + len))
        // Bottom-right
        p.move(to: CGPoint(x: rect.maxX, y: rect.maxY - len))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - r))
        p.addQuadCurve(to: CGPoint(x: rect.maxX - r, y: rect.maxY),
                       control: CGPoint(x: rect.maxX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.maxX - len, y: rect.maxY))
        // Bottom-left
        p.move(to: CGPoint(x: rect.minX + len, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX + r, y: rect.maxY))
        p.addQuadCurve(to: CGPoint(x: rect.minX, y: rect.maxY - r),
                       control: CGPoint(x: rect.minX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY - len))
        return p
    }
}

private struct DeckSmile: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.minY))
        p.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.minY),
                       control: CGPoint(x: rect.midX, y: rect.maxY + rect.height))
        return p
    }
}

/// Plan card visual: the real 14-day grid in miniature — done days filled,
/// today outlined, the rest ghosted (all ghosted before a plan exists).
private struct DeckPlanVisual: View {
    let plan: RoutinePlan?
    let today: Int

    var body: some View {
        VStack(spacing: 7) {
            ForEach(0..<2, id: \.self) { row in
                HStack(spacing: 7) {
                    ForEach(0..<7, id: \.self) { col in
                        tile(day: row * 7 + col + 1)
                    }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 24)
        .frame(width: 240, height: 158)
        .background(DQColor.accentSoft.opacity(0.5),
                    in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    @ViewBuilder
    private func tile(day: Int) -> some View {
        let done = plan?.dayComplete(day) ?? false
        let isToday = plan != nil && day == today
        ZStack {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(done ? DQColor.accent : DQColor.surface.opacity(isToday ? 1 : 0.7))
            if isToday && !done {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(DQColor.accent, lineWidth: 1.5)
            }
            if done {
                Image(systemName: "checkmark")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.white)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 34)
    }
}

/// Progress card visual: your actual score curve (last readings), or a dashed
/// "still unwritten" curve with a ? before there is enough data.
private struct DeckCurveVisual: View {
    let values: [Int]

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(DQColor.accentSoft.opacity(0.5))
            if values.count >= 2 {
                GeometryReader { proxy in
                    let pts = points(in: proxy.size)
                    ZStack {
                        Path { p in
                            guard let first = pts.first, let last = pts.last else { return }
                            p.move(to: CGPoint(x: first.x, y: proxy.size.height))
                            p.addLine(to: first)
                            for pt in pts.dropFirst() { p.addLine(to: pt) }
                            p.addLine(to: CGPoint(x: last.x, y: proxy.size.height))
                            p.closeSubpath()
                        }
                        .fill(LinearGradient(colors: [DQColor.accent.opacity(0.22), .clear],
                                             startPoint: .top, endPoint: .bottom))
                        Path { p in
                            guard let first = pts.first else { return }
                            p.move(to: first)
                            for pt in pts.dropFirst() { p.addLine(to: pt) }
                        }
                        .stroke(DQColor.accent,
                                style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
                        if let last = pts.last {
                            Circle()
                                .fill(DQColor.accent)
                                .frame(width: 10, height: 10)
                                .overlay(Circle().strokeBorder(Color.white, lineWidth: 2))
                                .position(last)
                        }
                    }
                }
                .padding(22)
            } else {
                GeometryReader { proxy in
                    let size = proxy.size
                    ZStack {
                        Path { p in
                            p.move(to: CGPoint(x: 0, y: size.height * 0.85))
                            p.addQuadCurve(to: CGPoint(x: size.width - 6, y: size.height * 0.18),
                                           control: CGPoint(x: size.width * 0.55, y: size.height * 0.95))
                        }
                        .stroke(DQColor.accent.opacity(0.55),
                                style: StrokeStyle(lineWidth: 3, lineCap: .round, dash: [1, 7]))
                        Text(verbatim: "?")
                            .font(.system(size: 14, weight: .heavy, design: .rounded))
                            .foregroundStyle(DQColor.accentBright)
                            .frame(width: 28, height: 28)
                            .background(DQColor.surface, in: Circle())
                            .position(x: size.width - 6, y: size.height * 0.18)
                    }
                }
                .padding(22)
            }
        }
        .frame(width: 220, height: 158)
    }

    private func points(in size: CGSize) -> [CGPoint] {
        let vals = values.suffix(8).map(Double.init)
        guard vals.count >= 2 else { return [] }
        let lo = (vals.min() ?? 0) - 3
        let hi = (vals.max() ?? 100) + 3
        let span = max(hi - lo, 1)
        return vals.enumerated().map { index, value in
            CGPoint(x: size.width * CGFloat(index) / CGFloat(vals.count - 1),
                    y: size.height * CGFloat(1 - (value - lo) / span))
        }
    }
}
