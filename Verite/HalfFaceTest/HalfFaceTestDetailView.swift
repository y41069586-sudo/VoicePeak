import SwiftUI
import SwiftData

/// The running half-face test: cadence, per-side progress (each vs its own Day-0),
/// confidence, and — once earned — the verdict + finalize actions (promote to
/// routine on pass, bank the savings on fail).
struct HalfFaceTestDetailView: View {
    let test: HalfFaceTest

    @Environment(\.modelContext) private var modelContext
    @Query private var scans: [Scan]
    @Query private var profiles: [UserProfile]
    @Query private var products: [Product]
    @Query private var allTests: [HalfFaceTest]
    @Query private var routineItems: [RoutineItem]
    @Query private var ledgers: [SavingsLedger]

    @State private var showCapture = false

    private var product: Product? { products.first { $0.id == test.productID } }
    private var context: SkinContext? {
        SkinContext.build(scans: scans.filter { $0.side == .full }, profile: profiles.first)
    }
    private var progress: TestProgress {
        HalfFaceTestScoring.progress(for: test, scans: scans, product: product, context: context)
    }

    /// The earliest and most recent **real** scans of this test — for an honest
    /// before/after comparison (both are the user's own photos, never generated).
    /// nil until there are at least two scans to compare.
    private var comparisonImages: (before: UIImage, after: UIImage)? {
        let testScans = HalfFaceTestScoring.testScans(test, in: scans)
            .sorted { $0.date < $1.date }
        guard testScans.count >= 2,
              let beforeFile = testScans.first?.thumbnailFilename,
              let afterFile = testScans.last?.thumbnailFilename,
              let before = ThumbnailStore.load(beforeFile),
              let after = ThumbnailStore.load(afterFile) else { return nil }
        return (before, after)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                header
                if test.status == .passed || test.status == .failed {
                    finalOutcomeCard
                } else {
                    cadenceCard
                    progressCard
                    if progress.verdict == .pending {
                        pendingCard
                    } else {
                        verdictCard
                    }
                }
                comparisonCard
                hygieneCard
                DisclaimerBanner(style: .short)
            }
            .padding(20)
        }
        .scrollIndicators(.hidden)
        .navigationTitle("halfface.title")
        .navigationBarTitleDisplayMode(.inline)
        .background(GradientMeshBackground())
        .sheet(isPresented: $showCapture) {
            TestCaptureView(test: test) {}
        }
    }

    // MARK: Header

    private var header: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text(verbatim: product?.name ?? "—")
                        .font(.headline).foregroundStyle(Theme.textPrimary)
                    Spacer()
                    PillTag(titleKey: test.status.localizationKey, tone: statusTone)
                }
                HStack(spacing: 8) {
                    PillTag(titleKey: "halfface.treated", systemImage: "drop.fill", tone: .info)
                    Text(test.testSide.localizationKey).font(.caption).foregroundStyle(Theme.textSecondary)
                    Spacer()
                    PillTag(titleKey: "halfface.control", tone: .neutral)
                    Text(test.controlSide.localizationKey).font(.caption).foregroundStyle(Theme.textSecondary)
                }
            }
        }
    }

    private var statusTone: PillTag.Tone {
        switch test.status {
        case .passed: return .success
        case .failed: return .danger
        case .queued: return .neutral
        default: return .info
        }
    }

    // MARK: Cadence + scan

    private var cadenceCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                if test.status == .queued {
                    Label("halfface.queuedNote", systemImage: "clock")
                        .font(.subheadline).foregroundStyle(Theme.warning)
                    // Still allow capturing – the scan will count once the test starts.
                    PrimaryButton(titleKey: "halfface.scanNow", systemImage: "camera.viewfinder") {
                        showCapture = true
                    }
                } else {
                    HStack {
                        Image(systemName: "calendar")
                        Text(nextScanText).font(.subheadline)
                    }
                    .foregroundStyle(Theme.textSecondary)
                    PrimaryButton(titleKey: "halfface.scanNow", systemImage: "camera.viewfinder") {
                        showCapture = true
                    }
                }
            }
        }
    }

    private var nextScanText: LocalizedStringKey {
        guard let next = HalfFaceTestManager.nextScanDate(test: test, scans: scans) else {
            return "halfface.firstScan"
        }
        if next <= .now { return "halfface.scanReady" }
        let days = Calendar.current.dateComponents([.day], from: .now, to: next).day ?? 0
        return "halfface.nextIn \(max(days, 1))"
    }

    // MARK: Progress

    private var progressCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("halfface.progress").font(.subheadline.weight(.semibold)).foregroundStyle(Theme.textSecondary)
                    Spacer()
                    Text("halfface.round \(progress.rounds)").font(.caption).foregroundStyle(Theme.textSecondary)
                }
                Text(progress.focus.localizationKey)
                    .font(.footnote).foregroundStyle(Theme.textPrimary)
                improvementRow(titleKey: "halfface.treatedSide", change: progress.treatedFocus, tone: .info)
                improvementRow(titleKey: "halfface.controlSide", change: progress.controlFocus, tone: .neutral)
                ScoreBar(labelKey: "result.confidence", value: progress.confidence,
                         tone: progress.confidence >= AnalysisConfidence.significanceThreshold ? .success : .warning)
            }
        }
    }

    private func improvementRow(titleKey: LocalizedStringKey, change: SideChange?, tone: PillTag.Tone) -> some View {
        HStack {
            Text(titleKey).font(.subheadline).foregroundStyle(Theme.textPrimary)
            Spacer()
            if let change {
                let improved = change.improvement >= 0
                HStack(spacing: 4) {
                    Image(systemName: improved ? "arrow.down.right" : "arrow.up.right")
                        .font(.caption2.weight(.bold))
                    Text(abs(change.improvement).formatted(.percent.precision(.fractionLength(0))))
                        .font(Typography.number(14))
                }
                .foregroundStyle(improved ? Theme.success : Theme.danger)
            } else {
                Text(verbatim: "—").foregroundStyle(Theme.textSecondary)
            }
        }
    }

    // MARK: Verdict / pending

    private var pendingCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 8) {
                Label("result.notEnough.title", systemImage: "hourglass")
                    .font(.headline).foregroundStyle(Theme.textPrimary)
                Text("halfface.pending.body")
                    .font(.subheadline).foregroundStyle(Theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var verdictCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                if progress.passed {
                    Label("halfface.verdict.works", systemImage: "checkmark.seal.fill")
                        .font(.headline).foregroundStyle(Theme.success)
                    Text("halfface.verdict.works.body")
                        .font(.subheadline).foregroundStyle(Theme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                    PrimaryButton(titleKey: "halfface.addToRoutine", systemImage: "checklist") {
                        finalize(passed: true)
                    }
                } else {
                    Label("halfface.verdict.skip", systemImage: "xmark.seal.fill")
                        .font(.headline).foregroundStyle(Theme.warning)
                    Text("halfface.verdict.skip.body")
                        .font(.subheadline).foregroundStyle(Theme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                    PrimaryButton(titleKey: "halfface.skipAndSave", systemImage: "eurosign.circle") {
                        finalize(passed: false)
                    }
                }
            }
        }
    }

    private var finalOutcomeCard: some View {
        GlassCard {
            VStack(spacing: 12) {
                Image(systemName: test.status == .passed ? "checkmark.seal.fill" : "xmark.seal.fill")
                    .font(.largeTitle)
                    .foregroundStyle(test.status == .passed ? Theme.success : Theme.textSecondary)
                Text(test.status == .passed ? "halfface.done.passed" : "halfface.done.failed")
                    .font(Typography.display(22)).foregroundStyle(Theme.textPrimary)
                    .multilineTextAlignment(.center)
                if test.status == .passed {
                    NavigationLink {
                        VerifiedShareView(test: test)
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "square.and.arrow.up")
                            Text("halfface.share")
                        }
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Theme.signature, in: Capsule())
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 4)
                }
            }
            .frame(maxWidth: .infinity)
        }
    }

    private var hygieneCard: some View {
        GlassCard {
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "checkmark.shield").foregroundStyle(Theme.accent)
                Text("test.setup.hygiene.body")
                    .font(.caption).foregroundStyle(Theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func finalize(passed: Bool) {
        HalfFaceTestManager.finalize(
            test: test,
            passed: passed,
            confidence: progress.confidence,
            allTests: allTests,
            routineItems: routineItems,
            ledgers: ledgers,
            in: modelContext
        )
        Haptics.fire(passed ? .verdictReveal : .milestone)
    }

    /// Honest before/after: the user's real Day-0 scan vs. their most recent
    /// scan. No prediction, no generated imagery — only shown once two real
    /// scans exist to compare.
    @ViewBuilder
    private var comparisonCard: some View {
        if let images = comparisonImages {
            VStack(alignment: .leading, spacing: 12) {
                Text("halfface.compare.title")
                    .font(VType.sectionTitle)
                    .foregroundStyle(VColor.textPrimary)

                Text("halfface.compare.body")
                    .font(.footnote)
                    .foregroundStyle(Theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                HalfFaceSimulationView(original: images.before, after: images.after)
                    .aspectRatio(3/4, contentMode: .fit)
                    .frame(maxWidth: .infinity)
                    .blueGlow(Theme.accent, radius: 12, opacity: 0.15)
            }
        }
    }
}
