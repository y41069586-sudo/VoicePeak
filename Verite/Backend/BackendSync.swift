import Foundation
import SwiftData

// ============================================================
// MARK: — Account sync (opt-in, numbers only)
// ============================================================
//
// Bridges the on-device SwiftData store and the backend. Photos NEVER leave the
// device (the payload carries scores + dates only), so this is a score-history
// sync: on a second device the timeline and trends restore, minus the images.
//
// Both entry points are fire-and-forget and fully guarded — a signed-out user
// or the local-only backend makes every call a no-op, so callers don't special-
// case it.

enum BackendSync {

    /// Push the local history up. Safe to call after any scan or plan change.
    @MainActor
    static func upload(backend: BackendService, context: ModelContext) {
        guard backend.isEnabled, backend.currentUser() != nil else { return }
        let payload = buildPayload(context: context)
        Task {
            try? await backend.syncMetrics(payload)
        }
    }

    /// Restore this user's score history onto a fresh device, then push the
    /// merged set back up. Call once right after a successful sign-in.
    @MainActor
    static func restoreThenUpload(backend: BackendService, context: ModelContext) {
        guard backend.isEnabled, backend.currentUser() != nil else { return }
        Task {
            if let remote = try? await backend.fetchMetrics() {
                await MainActor.run { merge(remote, into: context) }
            }
            let payload = await MainActor.run { buildPayload(context: context) }
            try? await backend.syncMetrics(payload)
        }
    }

    // MARK: Build

    @MainActor
    private static func buildPayload(context: ModelContext) -> MetricsPayload {
        let scans = (try? context.fetch(FetchDescriptor<ScanRecord>())) ?? []
        let scanMetrics: [MetricsPayload.ScanMetric] = scans.map { scan in
            var attrs: [String: Double] = [:]
            for sub in scan.analysis?.subScores ?? [] {
                attrs[sub.category.rawValue] = Double(sub.value)
            }
            return MetricsPayload.ScanMetric(
                date: scan.date,
                side: "full",
                isBaseline: !scan.isRescan,
                captureQuality: 1.0,
                attributes: attrs,
                overall: scan.overall
            )
        }

        var routine: [MetricsPayload.RoutineMetric] = []
        if let plan = (try? context.fetch(FetchDescriptor<RoutinePlan>()))?.first(where: { $0.isActive }) {
            for (i, _) in plan.steps(.am).enumerated() {
                routine.append(.init(timeOfDay: "am", order: i, proven: false))
            }
            for (i, _) in plan.steps(.pm).enumerated() {
                routine.append(.init(timeOfDay: "pm", order: i, proven: false))
            }
        }

        return MetricsPayload(scans: scanMetrics, routine: routine,
                              totalSaved: 0, currencyCode: "EUR")
    }

    // MARK: Merge (restore)

    @MainActor
    private static func merge(_ remote: MetricsPayload, into context: ModelContext) {
        let existing = (try? context.fetch(FetchDescriptor<ScanRecord>())) ?? []
        // Dedupe by date (~1 min tolerance) — the payload has no local UUID.
        func alreadyHave(_ date: Date) -> Bool {
            existing.contains { abs($0.date.timeIntervalSince(date)) < 60 }
        }
        var inserted = 0
        for metric in remote.scans where !alreadyHave(metric.date) {
            let overall = metric.overall ?? Int((metric.attributes.values.reduce(0, +)
                / Double(max(metric.attributes.count, 1))).rounded())
            let subs = DermiqCategory.allCases.map { cat in
                DermiqSubScore(category: cat,
                               value: metric.attributes[cat.rawValue].map { Int($0.rounded()) } ?? overall,
                               trend: nil)
            }
            let analysis = DermiqAnalysis(overall: overall, subScores: subs,
                                          skinType: .combination, topIssues: [],
                                          honestSummary: "")
            // Photoless historical record — drives the Progress timeline/charts.
            context.insert(ScanRecord(date: metric.date, analysis: analysis,
                                      photoFilename: nil, potentialFilename: nil,
                                      isRescan: !metric.isBaseline))
            inserted += 1
        }
        if inserted > 0 {
            try? context.save()
            DermiqDiagnostics.record("Restored \(inserted) scan(s) from account")
        }
    }
}
