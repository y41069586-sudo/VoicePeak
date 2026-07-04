import SwiftUI
import SwiftData

/// "Today" — the aesthetic home. Shows a skin snapshot (change vs baseline), any
/// active half-face test, quick actions, and the money-saved counter. Renders
/// honest empty states until there's real data (no baseline yet, no active test).
struct DashboardView: View {
    @Environment(AppState.self) private var appState
    @Query private var scans: [Scan]
    @Query private var tests: [HalfFaceTest]
    @Query private var streaks: [Streak]
    @Query private var ledgers: [SavingsLedger]

    private var hasBaseline: Bool { scans.contains(where: { $0.isBaseline }) }
    private var fullScanCount: Int { scans.filter { $0.side == .full }.count }
    private var highlights: [AttributeChange] { BaselineTracker.highlights(scans) }
    private var changeConfidence: Double { BaselineTracker.confidence(scans) }
    private var reliableVerdict: Bool { BaselineTracker.hasReliableVerdict(scans) }
    private var activeTest: HalfFaceTest? {
        tests.first(where: { $0.status == .running || $0.status == .verdictReady })
    }
    private var latestPassedTest: HalfFaceTest? {
        tests.filter { $0.status == .passed }.sorted { $0.createdAt > $1.createdAt }.first
    }
    private var streak: Streak? { streaks.first }
    private var ledger: SavingsLedger? { ledgers.first }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    snapshotCard
                    if let activeTest { activeTestCard(activeTest) }
                    actionGrid
                    savingsCard
                    DisclaimerBanner(style: .short)
                }
                .padding(20)
            }
            .scrollIndicators(.hidden)
            .navigationTitle("tab.today")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    if let streak, streak.current > 0 {
                        Label {
                            Text(verbatim: "\(streak.current)")
                        } icon: {
                            Image(systemName: "flame.fill")
                        }
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.warning)
                        .accessibilityLabel(Text("dashboard.streak.accessibility"))
                        .accessibilityValue(Text(verbatim: "\(streak.current)"))
                    }
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
                        appState.selectedTab = .scan
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

    // MARK: Quick actions

    private var actionGrid: some View {
        VStack(spacing: 12) {
            GlassActionCard(action: { appState.selectedTab = .catalog }) {
                actionLabel("dashboard.action.analyzeProduct", "sparkles.rectangle.stack")
            }
            NavigationLink {
                TestsListView()
            } label: {
                HStack {
                    actionLabel("dashboard.action.tests", "flask")
                    Spacer(minLength: 8)
                    Image(systemName: "chevron.right")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(Theme.textSecondary)
                }
                .padding(18)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).strokeBorder(Theme.strokeSubtle, lineWidth: 1))
            }
            .buttonStyle(.plain)
            GlassActionCard(action: { appState.selectedTab = .routine }) {
                actionLabel("dashboard.action.provenRoutine", "checklist")
            }
            if let latestPassedTest {
                NavigationLink {
                    VerifiedShareView(test: latestPassedTest)
                } label: {
                    HStack {
                        actionLabel("dashboard.action.share", "square.and.arrow.up")
                        Spacer(minLength: 8)
                        Image(systemName: "chevron.right")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(Theme.textSecondary)
                    }
                    .padding(18)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).strokeBorder(Theme.strokeSubtle, lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func actionLabel(_ key: LocalizedStringKey, _ icon: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(Theme.accent)
                .frame(width: 26)
            Text(key)
                .font(.headline)
                .foregroundStyle(Theme.textPrimary)
        }
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
