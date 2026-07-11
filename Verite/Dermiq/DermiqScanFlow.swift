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
        case guide, capture, theater, results, delta, potential, routineGen
    }

    // The flow opens on the capture guide (Do's & Don'ts) before the camera.
    var stage: Stage = .guide
    private(set) var capturedImage: UIImage?
    private(set) var analysis: DermiqAnalysis?
    private(set) var potentialImage: UIImage?
    private(set) var record: ScanRecord?

    /// The most recent prior scan; non-nil makes this a rescan (delta screen).
    let previousScan: ScanRecord?
    var isRescan: Bool { previousScan != nil }

    private var enhanceTask: Task<Void, Never>?

    init(previousScan: ScanRecord? = nil) {
        self.previousScan = previousScan
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
            guard let enhanced = try? await enhancer.enhance(image: image) else { return }
            self?.potentialImage = enhanced
            // The record may already exist by the time the render lands.
            if let record = self?.record, record.potentialFilename == nil {
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

        let targets = analysis.weakestThree
        let steps = RoutineBuilder.steps(targets: targets, weightedToward: weightedToward)

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
    @State private var model: ScanFlowModel

    init(previousScan: ScanRecord?, onFinished: @escaping (_ planCreated: Bool) -> Void) {
        self.previousScan = previousScan
        self.onFinished = onFinished
        _model = State(initialValue: ScanFlowModel(previousScan: previousScan))
    }

    var body: some View {
        ZStack {
            DQColor.background.ignoresSafeArea()

            switch model.stage {
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

    private func advanceToRoutineGen() {
        Haptics.fire(.transition)
        model.stage = .routineGen
    }
}
