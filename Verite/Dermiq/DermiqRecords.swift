import Foundation
import SwiftData

// ============================================================
// MARK: — Scan record
// ============================================================

/// One completed Dermiq scan: local image refs, the full analysis (JSON), date.
@Model
final class ScanRecord {
    @Attribute(.unique) var id: UUID
    var date: Date
    /// Denormalized for cheap querying/charting.
    var overall: Int
    /// Full `DermiqAnalysis`, JSON-encoded (safest SwiftData shape).
    var analysisJSON: Data
    /// Local filenames in `DermiqImageStore` — never remote URLs.
    var photoFilename: String?
    var potentialFilename: String?
    /// True when this scan closed a 14-day plan (drives the delta screen).
    var isRescan: Bool

    init(
        id: UUID = UUID(),
        date: Date = .now,
        analysis: DermiqAnalysis,
        photoFilename: String? = nil,
        potentialFilename: String? = nil,
        isRescan: Bool = false
    ) {
        self.id = id
        self.date = date
        self.overall = analysis.overall
        self.analysisJSON = (try? JSONEncoder().encode(analysis)) ?? Data()
        self.photoFilename = photoFilename
        self.potentialFilename = potentialFilename
        self.isRescan = isRescan
    }

    var analysis: DermiqAnalysis? {
        try? JSONDecoder().decode(DermiqAnalysis.self, from: analysisJSON)
    }
}

// ============================================================
// MARK: — 14-day routine plan
// ============================================================

/// The active 14-day routine: derived targets, AM/PM steps, per-day/step
/// completion. Missing a day is never punished — tiles just stay unfilled.
@Model
final class RoutinePlan {
    @Attribute(.unique) var id: UUID
    var createdAt: Date
    /// Day 1 (start of day). Day index = whole days since this + 1.
    var startDate: Date
    /// The scan this plan was derived from.
    var scanID: UUID?
    var targetsJSON: Data     // [DermiqSubScore] — the bottom 3, worst first
    var amJSON: Data          // [RoutineStep]
    var pmJSON: Data          // [RoutineStep]
    /// Completed step keys: "\(day).\(block).\(stepKey)", e.g. "3.am.am.spf".
    var completedKeys: [String]
    var isActive: Bool

    init(
        id: UUID = UUID(),
        createdAt: Date = .now,
        startDate: Date = Calendar.current.startOfDay(for: .now),
        scanID: UUID? = nil,
        targets: [DermiqSubScore],
        am: [RoutineStep],
        pm: [RoutineStep],
        isActive: Bool = true
    ) {
        self.id = id
        self.createdAt = createdAt
        self.startDate = startDate
        self.scanID = scanID
        self.targetsJSON = (try? JSONEncoder().encode(targets)) ?? Data()
        self.amJSON = (try? JSONEncoder().encode(am)) ?? Data()
        self.pmJSON = (try? JSONEncoder().encode(pm)) ?? Data()
        self.completedKeys = []
        self.isActive = isActive
    }

    // MARK: Decoded access

    var targets: [DermiqSubScore] {
        (try? JSONDecoder().decode([DermiqSubScore].self, from: targetsJSON)) ?? []
    }

    func steps(_ block: RoutineBlock) -> [RoutineStep] {
        let data = block == .am ? amJSON : pmJSON
        return (try? JSONDecoder().decode([RoutineStep].self, from: data)) ?? []
    }

    // MARK: Day math

    /// 1-based day index for a date, clamped to 1...14.
    func dayIndex(for date: Date = .now) -> Int {
        let days = Calendar.current.dateComponents(
            [.day],
            from: startDate,
            to: Calendar.current.startOfDay(for: date)
        ).day ?? 0
        return min(max(days + 1, 1), 14)
    }

    /// Day 14 reached (or passed) — the rescan unlocks.
    var rescanUnlocked: Bool {
        dayIndex() >= 14
    }

    // MARK: Completion

    private func key(day: Int, block: RoutineBlock, step: RoutineStep) -> String {
        "\(day).\(block.rawValue).\(step.key)"
    }

    func isDone(day: Int, block: RoutineBlock, step: RoutineStep) -> Bool {
        completedKeys.contains(key(day: day, block: block, step: step))
    }

    func toggle(day: Int, block: RoutineBlock, step: RoutineStep) {
        let key = key(day: day, block: block, step: step)
        if let index = completedKeys.firstIndex(of: key) {
            completedKeys.remove(at: index)
        } else {
            completedKeys.append(key)
        }
    }

    /// The steps actually scheduled for a given day (base daily steps +
    /// whichever active treatments fall on that day). This is what the UI
    /// shows and what completion is measured against. During a recovery window
    /// the strong actives are pulled — the barrier gets a few gentle days.
    func scheduledSteps(_ block: RoutineBlock, day: Int) -> [RoutineStep] {
        let recovering = RoutineRecovery.isActive(self, on: day)
        return steps(block).filter { step in
            if recovering && RoutineSchedule.isStrongActive(step) { return false }
            return RoutineSchedule.isScheduled(step, on: day)
        }
    }

    func blockComplete(day: Int, _ block: RoutineBlock) -> Bool {
        let steps = scheduledSteps(block, day: day)
        guard !steps.isEmpty else { return false }
        return steps.allSatisfy { isDone(day: day, block: block, step: $0) }
    }

    func dayComplete(_ day: Int) -> Bool {
        blockComplete(day: day, .am) && blockComplete(day: day, .pm)
    }

    /// Consecutive completed days ending at today (or yesterday, so an
    /// unfinished today doesn't zero the counter).
    var streak: Int {
        let today = dayIndex()
        var day = dayComplete(today) ? today : today - 1
        var count = 0
        while day >= 1, dayComplete(day) {
            count += 1
            day -= 1
        }
        return count
    }
}
