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
        case quiz, guide, capture, theater, results, potential, routineGen
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
    /// subscription scans. `private(set) var` (not `let`) so `begin()` can
    /// re-affirm it from the durable UserDefaults marker — a rebuilt cover
    /// can never downgrade a credit scan to a free-plan one.
    private(set) var usedCredit: Bool

    private var enhanceTask: Task<Void, Never>?

    init(previousScan: ScanRecord? = nil, usedCredit: Bool = false) {
        self.previousScan = previousScan
        self.usedCredit = usedCredit
    }

    // MARK: Pipeline

    func begin(with image: UIImage) {
        capturedImage = image
        stage = .theater
        // Re-affirm the credit flag from the durable marker (belt-and-braces
        // against a lost init value). Once true it stays true; consuming the
        // marker here keeps it from bleeding into a later scan.
        usedCredit = usedCredit || ReferralStore.shared.consumeNextScanUsesCredit()
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
            // back to the on-device retouch. If BOTH fail (some photos make the
            // image model refuse and CoreImage bail), show the ORIGINAL so the
            // reveal is NEVER stuck on "Rendering…" — before == after, honest,
            // and the slider still works.
            var enhanced = try? await enhancer.enhance(image: image)
            if enhanced == nil {
                enhanced = try? await MockEnhancementEngine().enhance(image: image)
            }
            guard let self else { return }
            let final = enhanced ?? image
            self.potentialImage = final
            // The record may already exist by the time the render lands.
            if let record = self.record, record.potentialFilename == nil {
                record.potentialFilename = DermiqImageStore.save(final)
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
        // paywall) attaches to it now. In the current flow only a RATING
        // pending is legitimate — a routine pending was already dropped as
        // stale in UnlockStore's init, so this can't hand a free plan.
        UnlockStore.shared.applyPending(to: scan.id)
        // Diagnostic: the exact inputs to the plan-price decision, so a
        // "why is the plan free?" report is answerable from the logs.
        DermiqDiagnostics.record(
            "Scan saved — usedCredit=\(usedCredit) routineUnlocked=\(UnlockStore.shared.isRoutineUnlocked(scan.id))")
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
        let profile = (try? context.fetch(FetchDescriptor<UserProfile>()))?.first
        let steps = RoutineBuilder.steps(
            targets: targets,
            weightedToward: weightedToward,
            prefs: SkinPrefs.load(),        // the two pre-scan questions
            avoid: SkinSensitivities.load(), // allergies from onboarding
            context: PlanContext(profile: profile) // the onboarding quiz answers
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
        // The routine promises a day-14 rescan — actually schedule that nudge.
        NotificationManager.scheduleTestReminder(afterDays: 14)
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
    @Query private var allPlans: [RoutinePlan]
    @Query(sort: \ScanRecord.date, order: .reverse) private var scans: [ScanRecord]
    @State private var model: ScanFlowModel
    @State private var planPurchasing = false
    @State private var planPurchaseFailed = false
    /// "Build my 14-day plan" while a plan already exists → warn first.
    @State private var showPlanReplaceWarning = false

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
            case .potential:
                DermiqPotentialView(
                    model: model,
                    ctaTitle: planCTATitle,
                    ctaCaption: planCTACaption,
                    ctaEnabled: !planPurchasing,
                    onBack: {
                        Haptics.fire(.transition)
                        model.stage = .results
                    }
                ) {
                    planCTATapped()
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
        .alert("You already have a 14-day plan", isPresented: $showPlanReplaceWarning) {
            Button("Yes, create new") { proceedToPlan() }
            Button("Back to dashboard", role: .cancel) { onFinished(false) }
        } message: {
            Text("A new plan replaces your current one and its progress. Create a new plan anyway?")
        }
        .alert("Couldn't load plans", isPresented: $planPurchaseFailed) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Check your connection and try again.")
        }
    }

    /// The 14-day plan is included only on Pro's two WEEKLY scans; a credit
    /// scan (€1.99 extra / referral bonus) or a rating-only buy needs the
    /// €3.99 plan purchase — made right here on the potential screen's CTA.
    private var planAllowed: Bool {
        (purchases.isPro && !model.usedCredit)
            || (model.record.map { UnlockStore.shared.isRoutineUnlocked($0.id) } ?? false)
    }

    private var hasActivePlan: Bool { allPlans.contains { $0.isActive } }

    /// The potential screen's CTA title: plain when the plan is included,
    /// price-suffixed when tapping it starts the €3.99 purchase (no surprise
    /// charges), and a busy label mid-purchase.
    private var planCTATitle: String {
        if planAllowed { return String(localized: "Build my 14-day plan") }
        if planPurchasing { return String(localized: "Unlocking…") }
        // Only append the price once StoreKit has the live figure — never a
        // hard-coded currency amount that could mismatch the user's storefront.
        guard let price = purchases.displayPrice(for: VeriteProducts.routineOnce) else {
            return String(localized: "Build my 14-day plan")
        }
        return String(format: String(localized: "Build my 14-day plan · %@"), price)
    }

    /// When a Pro user is on a credit scan, their NEXT weekly-included scan
    /// (plan included) frees up once the oldest scan leaves the 7-day window —
    /// same arithmetic as ScanQuota's weekly cap.
    private var nextIncludedScan: Date? {
        guard purchases.isPro, model.usedCredit else { return nil }
        let weekAgo = Date.now.addingTimeInterval(-7 * 24 * 3600)
        return scans.filter { $0.date > weekAgo }
            .map(\.date).min()?
            .addingTimeInterval(7 * 24 * 3600)
    }

    /// Caption under the paid plan CTA: the honest one-time line, plus — for
    /// Pro on a credit scan — a countdown to the next included plan.
    private var planCTACaption: String? {
        guard !planAllowed else { return nil }
        var caption = String(localized: "One-time purchase — your 14-day plan, built from this scan.")
        if let next = nextIncludedScan {
            let rel = next.formatted(.relative(presentation: .named))
            caption += "\n" + String(format: String(localized: "Or wait — your next weekly scan includes the plan (%@)."), rel)
        }
        return caption
    }

    /// Single entry point for the plan CTA: warn if a plan already exists
    /// (BEFORE any charge), otherwise continue or buy.
    private func planCTATapped() {
        if hasActivePlan {
            showPlanReplaceWarning = true
        } else {
            proceedToPlan()
        }
    }

    private func proceedToPlan() {
        if planAllowed { advanceToRoutineGen() } else { buyPlan() }
    }

    /// Buy the 14-day plan for THIS scan (€3.99, plan only), then build it.
    private func buyPlan() {
        guard let record = model.record, !planPurchasing else { return }
        planPurchasing = true
        Task {
            defer { planPurchasing = false }
            guard purchases.displayPrice(for: VeriteProducts.routineOnce) != nil else {
                planPurchaseFailed = true
                return
            }
            guard await purchases.purchaseConsumable(productID: VeriteProducts.routineOnce) else { return }
            UnlockStore.shared.unlock(.routine, scanID: record.id)
            RampAnalytics.track("plan_purchased")
            advanceToRoutineGen()
        }
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
