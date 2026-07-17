import SwiftUI
import SwiftData
import UIKit

// ============================================================
// MARK: — Scan flow model
// ============================================================

/// Drives one pass through the scan spine:
/// capture → analysis theater → results (or delta on rescan) → potential →
/// routine generation. The Potential image is the slowest call, so it fires
/// in the background the moment the theater starts (spec, Screen 5).
@Observable
@MainActor
final class ScanFlowModel {

    enum Stage {
        case quiz, guide, capture, theater, results, delta, potential, routineGen
    }

    // The flow opens on the 2-question skin check, then the capture guide.
    var stage: Stage = .quiz
    private(set) var capturedImage: UIImage?
    private(set) var analysis: DermiqAnalysis?
    private(set) var potentialImage: UIImage?
    private(set) var record: ScanRecord?

    /// The most recent prior scan; non-nil makes this a rescan (delta screen).
    let previousScan: ScanRecord?
    var isRescan: Bool { previousScan != nil }

    /// True when this scan was paid for with a credit (€1.99 extra scan or a
    /// referral bonus) rather than a Pro weekly-included scan. Credit scans
    /// include the scan + rating ONLY — a NEW 14-day plan from one costs
    /// €3.99 even for Pro; the plan is only auto-included on the two weekly
    /// subscription scans.
    let usedCredit: Bool

    private var enhanceTask: Task<Void, Never>?

    init(previousScan: ScanRecord? = nil, usedCredit: Bool = false) {
        self.previousScan = previousScan
        self.usedCredit = usedCredit
    }

    // MARK: Pipeline

    func begin(with image: UIImage) {
        capturedImage = image
        stage = .theater
        RampAnalytics.track("scan_captured", ["rescan": String(isRescan)])

        let engine = EngineFactory.analysis(previousOverall: previousScan?.overall)
        Task { [weak self] in
            do {
                let result = try await engine.analyze(image: image)
                self?.analysis = result
            } catch {
                // Never dead-end the theater: fall back to fixture data.
                self?.analysis = try? await MockDermiqEngine(
                    previousOverall: self?.previousScan?.overall
                ).analyze(image: image)
            }
        }

        let enhancer = EngineFactory.enhancement()
        enhanceTask = Task { [weak self] in
            // Try the live enhancer (Gemini); if it fails for ANY reason, fall
            // back to the on-device retouch so the Potential reveal is never
            // stuck on "Rendering…" forever.
            var enhanced = try? await enhancer.enhance(image: image)
            if enhanced == nil {
                enhanced = try? await MockEnhancementEngine().enhance(image: image)
            }
            guard let enhanced, let self else { return }
            self.potentialImage = enhanced
            // The record may already exist by the time the render lands.
            if let record = self.record, record.potentialFilename == nil {
                record.potentialFilename = DermiqImageStore.save(enhanced)
            }
        }
    }

    /// Theater guarantees `analysis != nil` before calling this.
    ///
    /// Every scan — first or rescan — lands on the normal results grid. The
    /// "Now ⇄ In 14 days" toggle there is how you see the projection; we no
    /// longer shove the delta comparison screen in front of a dashboard rescan.
    func theaterFinished(context: ModelContext) {
        persist(context: context)
        // Burn the one free scan the moment a result is reached — durably, so
        // even if the ScanRecord write above raced or failed, a non-Pro user
        // can never land a second free reading.
        ReferralStore.shared.markFreeScanUsed()
        Haptics.fire(.transition)
        stage = .results
    }

    private func persist(context: ModelContext) {
        guard record == nil, let analysis else { return }
        let scan = ScanRecord(
            analysis: analysis,
            photoFilename: capturedImage.flatMap { DermiqImageStore.save($0) },
            potentialFilename: potentialImage.flatMap { DermiqImageStore.save($0) },
            isRescan: isRescan
        )
        context.insert(scan)
        try? context.save()
        record = scan
        // A one-time unlock bought BEFORE this scan (from the scan-blocked
        // paywall) attaches to it now.
        UnlockStore.shared.applyPending(to: scan.id)
        RampAnalytics.track("scan_completed", ["overall": String(analysis.overall)])
    }

    /// Creates the 14-day plan (Screen 6/7). Rescan plans are weighted toward
    /// whatever improved least.
    func createPlan(context: ModelContext) {
        guard let analysis else { return }

        var weightedToward: [DermiqCategory] = []
        if let previous = previousScan?.analysis {
            weightedToward = analysis.subScores
                .compactMap { new -> (DermiqCategory, Int)? in
                    guard let old = previous.subScore(for: new.category) else { return nil }
                    return (new.category, new.value - old.value)
                }
                .sorted { $0.1 < $1.1 }
                .prefix(2)
                .map(\.0)
        }

        // ALL seven readings feed the plan, worst first — the builder fills
        // its treatment slots from the full picture, not a 3-metric shortlist.
        let targets = analysis.subScores.sorted { $0.value < $1.value }
        let steps = RoutineBuilder.steps(
            targets: targets,
            weightedToward: weightedToward,
            prefs: SkinPrefs.load()   // the two pre-scan questions
        )

        // One active plan at a time.
        let plans = (try? context.fetch(FetchDescriptor<RoutinePlan>())) ?? []
        for plan in plans { plan.isActive = false }

        let plan = RoutinePlan(
            scanID: record?.id,
            targets: targets,
            am: steps.am,
            pm: steps.pm
        )
        context.insert(plan)
        try? context.save()
        WidgetBridge.publish(plan)
        // Fire-and-forget: Gemini reviews the plan and personalizes the
        // why-lines + summary. No key / offline → the plan stays rule-worded.
        RoutineAIReview.kickoff(plan: plan, analysis: analysis, context: context)
        RampAnalytics.track("plan_created", [
            "targets": targets.map(\.category.rawValue).joined(separator: ","),
        ])
    }

}

// ============================================================
// MARK: — Flow container (full-screen cover)
// ============================================================

struct DermiqScanFlowView: View {
    let previousScan: ScanRecord?
    /// Called when the flow completes (plan created) or is cancelled.
    let onFinished: (_ planCreated: Bool) -> Void

    @Environment(\.modelContext) private var modelContext
    @Environment(PurchaseManager.self) private var purchases
    @State private var model: ScanFlowModel

    init(previousScan: ScanRecord?, usedCredit: Bool = false,
         onFinished: @escaping (_ planCreated: Bool) -> Void) {
        self.previousScan = previousScan
        self.onFinished = onFinished
        _model = State(initialValue: ScanFlowModel(previousScan: previousScan,
                                                   usedCredit: usedCredit))
    }

    var body: some View {
        ZStack {
            DQColor.background.ignoresSafeArea()

            switch model.stage {
            case .quiz:
                DermiqPreScanQuiz(
                    onDone: { _ in model.stage = .guide },
                    onCancel: { onFinished(false) }
                )
            case .guide:
                DermiqCaptureGuideView(
                    onContinue: { model.stage = .capture },
                    onCancel: { onFinished(false) }
                )
            case .capture:
                DermiqCaptureView(
                    onCaptured: { image in model.begin(with: image) },
                    onCancel: { model.stage = .guide }
                )
            case .theater:
                DermiqTheaterView(model: model) {
                    model.theaterFinished(context: modelContext)
                }
            case .results:
                DermiqResultsView(
                    model: model,
                    onContinue: {
                        Haptics.fire(.transition)
                        model.stage = .potential
                    },
                    onClose: { onFinished(false) }
                )
            case .delta:
                DermiqDeltaView(model: model) {
                    advanceToRoutineGen()
                }
            case .potential:
                DermiqPotentialView(model: model) {
                    advanceToRoutineGen()
                }
            case .routineGen:
                DermiqRoutineGenView(model: model) {
                    model.createPlan(context: modelContext)
                    onFinished(true)
                }
            }
        }
        .animation(VMotion.crossfade, value: model.stage)
        .preferredColorScheme(.light)
    }

    /// The 14-day plan is included only on Pro's two WEEKLY scans; a credit
    /// scan (€1.99 extra / referral bonus) or a rating-only buy needs the
    /// €3.99 plan purchase. Without it the flow ends after the potential
    /// screen, plan-less.
    private var planAllowed: Bool {
        (purchases.isPro && !model.usedCredit)
            || (model.record.map { UnlockStore.shared.isRoutineUnlocked($0.id) } ?? false)
    }

    private func advanceToRoutineGen() {
        Haptics.fire(.transition)
        if planAllowed {
            model.stage = .routineGen
        } else {
            onFinished(false)
        }
    }
}
