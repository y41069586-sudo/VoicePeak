import SwiftUI
import SwiftData

/// "Today" — the aesthetic home. Shows a skin snapshot (change vs baseline), any
/// active half-face test, quick actions, and the money-saved counter. Renders
/// honest empty states until there's real data (no baseline yet, no active test).
struct DashboardView: View {
    @Environment(AppState.self) private var appState
    @State private var showSettings = false
    @Query private var scans: [Scan]
    @Query private var tests: [HalfFaceTest]
    @Query private var progresses: [UserProgress]
    @Query private var ledgers: [SavingsLedger]

    private var hasBaseline: Bool { scans.contains(where: { $0.isBaseline }) }
    private var fullScanCount: Int { scans.filter { $0.side == .full }.count }
    private var highlights: [AttributeChange] { BaselineTracker.highlights(scans) }
    private var changeConfidence: Double { BaselineTracker.confidence(scans) }
    private var reliableVerdict: Bool { BaselineTracker.hasReliableVerdict(scans) }
    private var activeTest: HalfFaceTest? {
        tests.first(where: { $0.status == .running || $0.status == .verdictReady })
    }

    /// Where the user stands in the one core flow: scan → match → prove.
    /// Drives the single guided call-to-action on the dashboard.
    private var stage: JourneyStage {
        if !hasBaseline { return .scan }
        if activeTest != nil { return .testing }
        return .match
    }
    private var hasAnyTest: Bool { !tests.isEmpty }
    private var hasVerdict: Bool {
        tests.contains { $0.status == .passed || $0.status == .failed }
    }
    private var latestPassedTest: HalfFaceTest? {
        tests.filter { $0.status == .passed }.sorted { $0.createdAt > $1.createdAt }.first
    }
    private var progress: UserProgress? { progresses.first }
    private var effectiveStreakCount: Int {
        guard let p = progress, let last = p.lastScanDate else { return 0 }
        let cal = Calendar.current
        if cal.isDateInToday(last) || cal.isDateInYesterday(last) {
            return p.currentStreak
        }
        return 0
    }
    private var totalFlames: Int { progress?.totalFlames ?? 0 }
    
    @State private var showTasksSheet = false
    private var ledger: SavingsLedger? { ledgers.first }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    snapshotCard
                        .vStaggeredAppear(index: 0)
                    journeyCard
                        .vStaggeredAppear(index: 1)
                    if let activeTest, activeTest.status == .verdictReady {
                        activeTestCard(activeTest)
                            .vStaggeredAppear(index: 2)
                    }
                    moreLinks
                        .vStaggeredAppear(index: 3)
                    savingsCard
                        .vStaggeredAppear(index: 4)
                    DisclaimerBanner(style: .short)
                        .vStaggeredAppear(index: 5)
                }
                .padding(20)
            }
            .scrollIndicators(.hidden)
            .background(GradientMeshBackground().ignoresSafeArea())
            .sheet(isPresented: $showSettings) {
                SettingsView()
            }
            .sheet(isPresented: $showTasksSheet) {
                TasksSheetView()
            }
            .navigationTitle("tab.today")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        Haptics.fire(.selection)
                        showSettings = true
                    } label: {
                        Image(systemName: "person.crop.circle")
                            .font(.title3)
                            .foregroundStyle(Theme.textPrimary)
                    }
                    .accessibilityLabel("tab.settings")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Haptics.fire(.selection)
                        showTasksSheet = true
                    } label: {
                        Label {
                            Text(verbatim: "\(totalFlames)")
                        } icon: {
                            Image(systemName: "flame.fill")
                        }
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.warning)
                    }
                    .accessibilityLabel("Aufgaben und Flammen")
                }
            }
            .toolbarBackground(.hidden, for: .navigationBar)
        }
    }

    // MARK: Skin snapshot

    private var snapshotCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("dashboard.snapshot.title")
                    .font(Typography.display(26))
                    .foregroundStyle(Theme.textPrimary)

                if !hasBaseline {
                    Text("dashboard.snapshot.noBaseline")
                        .font(.subheadline)
                        .foregroundStyle(Theme.textSecondary)
                    PrimaryButton(titleKey: "dashboard.action.scanNow", systemImage: "camera.viewfinder") {
                        appState.selectedTab = .analyze
                    }
                    .padding(.top, 4)
                } else if fullScanCount < AnalysisConfidence.minScansForChange {
                    Text("dashboard.snapshot.onlyBaseline")
                        .font(.subheadline)
                        .foregroundStyle(Theme.textSecondary)
                } else if reliableVerdict {
                    Text("dashboard.snapshot.summaryTitle")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(Theme.textSecondary)
                    if highlights.isEmpty {
                        Text("dashboard.snapshot.stable")
                            .font(.subheadline)
                            .foregroundStyle(Theme.textSecondary)
                    } else {
                        ForEach(highlights) { AttributeChangeRow(change: $0) }
                    }
                    ScoreBar(labelKey: "result.confidence", value: changeConfidence, tone: .success)
                        .padding(.top, 2)
                } else {
                    Text("dashboard.snapshot.notEnough")
                        .font(.subheadline)
                        .foregroundStyle(Theme.textSecondary)
                    ScoreBar(labelKey: "result.confidence", value: changeConfidence, tone: .warning)
                        .padding(.top, 2)
                }
            }
        }
    }

    // MARK: Active test

    private func activeTestCard(_ test: HalfFaceTest) -> some View {
        NavigationLink {
            HalfFaceTestDetailView(test: test)
        } label: {
            GlassCard {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        PillTag(titleKey: "dashboard.test.active", systemImage: "flask.fill", tone: .info)
                        Spacer()
                        Text(test.status.localizationKey)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Theme.textSecondary)
                        Image(systemName: "chevron.right")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(Theme.textSecondary)
                    }
                    ScoreBar(labelKey: "dashboard.test.confidence", value: test.confidence, tone: .info)
                }
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: The one guided flow — scan → match → prove

    /// A single card that shows the whole path and surfaces exactly one primary
    /// action: the user's *next* step. Replaces the old grid of equal buttons so
    /// the core flow reads as one journey, not three disconnected features.
    private var journeyCard: some View {
        GlassCard(featured: true) {
            VStack(alignment: .leading, spacing: 18) {
                StepPath(current: stage,
                         scanDone: hasBaseline,
                         matchDone: hasAnyTest,
                         proveDone: hasVerdict)
                VStack(alignment: .leading, spacing: 6) {
                    Text(stage.titleKey)
                        .font(Typography.display(22))
                        .foregroundStyle(Theme.textPrimary)
                    Text(stage.bodyKey)
                        .font(.subheadline)
                        .foregroundStyle(Theme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                journeyCTA
            }
        }
    }

    @ViewBuilder
    private var journeyCTA: some View {
        switch stage {
        case .scan:
            PrimaryButton(titleKey: "dashboard.action.scanNow", systemImage: "camera.viewfinder") {
                appState.selectedTab = .analyze
            }
        case .match:
            NavigationLink {
                CatalogView()
            } label: {
                ctaLabel("journey.cta.match", "sparkles.rectangle.stack")
            }
            .buttonStyle(.plain)
        case .testing:
            if let activeTest {
                NavigationLink {
                    HalfFaceTestDetailView(test: activeTest)
                } label: {
                    ctaLabel("journey.cta.viewTest", "flask.fill")
                }
                .buttonStyle(.plain)
            }
        }
    }

    /// A hero-gradient pill styled like `PrimaryButton`, but usable as the label
    /// of a `NavigationLink` (which needs a view, not an action closure).
    private func ctaLabel(_ key: LocalizedStringKey, _ icon: String) -> some View {
        HStack(spacing: VSpace.sm) {
            Image(systemName: icon)
            Text(key)
        }
        .font(VType.bodyLarge.weight(.semibold))
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity, minHeight: 54)
        .background(VColor.heroGradient, in: Capsule())
        .vGlow(VColor.primary, radius: 22, opacity: 0.25)
    }

    // MARK: Secondary links (never compete with the primary flow)

    @ViewBuilder
    private var moreLinks: some View {
        if hasAnyTest || latestPassedTest != nil {
            GlassCard {
                VStack(spacing: 0) {
                    if hasAnyTest {
                        NavigationLink { TestsListView() } label: {
                            moreRow("dashboard.action.tests", "flask")
                        }
                        .buttonStyle(.plain)
                    }
                    if let latestPassedTest {
                        if hasAnyTest { Divider().background(VColor.strokeSubtle) }
                        NavigationLink { VerifiedShareView(test: latestPassedTest) } label: {
                            moreRow("dashboard.action.share", "square.and.arrow.up")
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private func moreRow(_ key: LocalizedStringKey, _ icon: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(Theme.accent)
                .frame(width: 22)
            Text(key)
                .font(.subheadline)
                .foregroundStyle(Theme.textPrimary)
            Spacer(minLength: 8)
            Image(systemName: "chevron.right")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(Theme.textSecondary)
        }
        .contentShape(Rectangle())
        .padding(.vertical, 12)
    }

    // MARK: Money saved

    private var savingsCard: some View {
        GlassCard {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("dashboard.savings.title")
                        .font(.subheadline)
                        .foregroundStyle(Theme.textSecondary)
                    Text(savedString)
                        .font(Typography.number(30))
                        .foregroundStyle(Theme.success)
                }
                Spacer()
                Image(systemName: "eurosign.circle")
                    .font(.system(size: 34, weight: .light))
                    .foregroundStyle(Theme.success.opacity(0.7))
            }
        }
    }

    private var savedString: String {
        let amount = ledger?.totalSaved ?? 0
        let code = ledger?.currencyCode ?? (Locale.current.currency?.identifier ?? "EUR")
        return amount.formatted(.currency(code: code).precision(.fractionLength(0)))
    }
}

#Preview {
    DashboardView()
        .modelContainer(Persistence.previewContainer)
        .environment(AppState())
        .preferredColorScheme(.dark)
}

// MARK: - The one flow, as a shape

/// The three stages of the core promise: scan your face, match a product to it,
/// prove it with a half-face test. `stage` picks which one is the user's next
/// action; the dashboard shows a single CTA for it.
private enum JourneyStage {
    case scan, match, testing

    var titleKey: LocalizedStringKey {
        switch self {
        case .scan:    return "journey.scan.title"
        case .match:   return "journey.match.title"
        case .testing: return "journey.testing.title"
        }
    }
    var bodyKey: LocalizedStringKey {
        switch self {
        case .scan:    return "journey.scan.body"
        case .match:   return "journey.match.body"
        case .testing: return "journey.testing.body"
        }
    }
}

/// A three-node path indicator (Scan → Match → Prove) so the flow reads as one
/// connected journey. Completed steps get a checkmark, the current step is
/// filled, upcoming steps stay muted.
private struct StepPath: View {
    let current: JourneyStage
    let scanDone: Bool
    let matchDone: Bool
    let proveDone: Bool

    private enum NodeState { case done, current, upcoming }

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            node(number: 1, key: "journey.step.scan", state: scanState)
            connector(done: scanDone)
            node(number: 2, key: "journey.step.match", state: matchState)
            connector(done: matchDone)
            node(number: 3, key: "journey.step.prove", state: proveState)
        }
    }

    private var scanState: NodeState { current == .scan ? .current : (scanDone ? .done : .upcoming) }
    private var matchState: NodeState { current == .match ? .current : (matchDone ? .done : .upcoming) }
    private var proveState: NodeState { current == .testing ? .current : (proveDone ? .done : .upcoming) }

    private func node(number: Int, key: LocalizedStringKey, state: NodeState) -> some View {
        VStack(spacing: 7) {
            ZStack {
                Circle()
                    .fill(fill(state))
                    .frame(width: 34, height: 34)
                if state == .done {
                    Image(systemName: "checkmark")
                        .font(.footnote.weight(.bold))
                        .foregroundStyle(Theme.primary)
                } else {
                    Text(verbatim: "\(number)")
                        .font(.footnote.weight(.bold))
                        .foregroundStyle(state == .current ? .white : Theme.textSecondary)
                }
            }
            Text(key)
                .font(VType.micro)
                .foregroundStyle(state == .upcoming ? Theme.textSecondary : Theme.textPrimary)
        }
    }

    private func fill(_ state: NodeState) -> Color {
        switch state {
        case .current:  return Theme.primary
        case .done:     return Theme.primary.opacity(0.15)
        case .upcoming: return Theme.bgElevated
        }
    }

    private func connector(done: Bool) -> some View {
        Rectangle()
            .fill(done ? Theme.primary.opacity(0.5) : Theme.strokeSubtle)
            .frame(height: 2)
            .frame(maxWidth: .infinity)
            .padding(.top, 16)
    }
}
