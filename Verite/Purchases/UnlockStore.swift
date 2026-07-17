import Foundation

/// One-time (per-scan) unlocks bought on the paywall: "rating" reveals one
/// scan's results (score + all 7 metrics); "routine" additionally allows the
/// 14-day plan built from that scan. Pro subscribers bypass all of this.
///
/// Bought BEFORE a scan exists (from the scan-blocked paywall), the tier is
/// stored as `pending` plus one scan credit — and attaches to the next scan
/// the moment it reaches its result. Persisted in UserDefaults.
@Observable
@MainActor
final class UnlockStore {
    static let shared = UnlockStore()

    enum Tier: String { case rating, routine }

    private static let ratingKey = "dq.unlock.rating"
    private static let routineKey = "dq.unlock.routine"
    private static let pendingKey = "dq.unlock.pending"

    private(set) var ratingIDs: Set<String>
    private(set) var routineIDs: Set<String>
    private(set) var pending: Tier?

    private init() {
        let defaults = UserDefaults.standard
        ratingIDs = Set(defaults.stringArray(forKey: Self.ratingKey) ?? [])
        routineIDs = Set(defaults.stringArray(forKey: Self.routineKey) ?? [])
        pending = defaults.string(forKey: Self.pendingKey).flatMap(Tier.init)
        // Only a RATING unlock can be pending in the current flow (the plan
        // is bought directly on the potential screen's CTA, tied to its scan).
        // A stored .routine pending is stale state from an older build —
        // TestFlight updates keep UserDefaults — and would silently hand the
        // next scan a free plan. Drop it.
        if pending == .routine {
            pending = nil
            defaults.removeObject(forKey: Self.pendingKey)
        }
    }

    /// Routine implies rating — the bigger one-time pack reveals everything.
    func isRatingUnlocked(_ id: UUID) -> Bool {
        ratingIDs.contains(id.uuidString) || routineIDs.contains(id.uuidString)
    }

    func isRoutineUnlocked(_ id: UUID) -> Bool {
        routineIDs.contains(id.uuidString)
    }

    func unlock(_ tier: Tier, scanID: UUID) {
        switch tier {
        case .rating:  ratingIDs.insert(scanID.uuidString)
        case .routine: routineIDs.insert(scanID.uuidString)
        }
        persist()
    }

    /// Pre-scan purchase: remember the tier until the scan exists.
    func setPending(_ tier: Tier) {
        pending = tier
        UserDefaults.standard.set(tier.rawValue, forKey: Self.pendingKey)
    }

    /// Called when a scan reaches its result — a pre-scan purchase attaches
    /// to this scan and the pending marker clears.
    func applyPending(to scanID: UUID) {
        guard let pending else { return }
        unlock(pending, scanID: scanID)
        self.pending = nil
        UserDefaults.standard.removeObject(forKey: Self.pendingKey)
    }

    private func persist() {
        let defaults = UserDefaults.standard
        defaults.set(Array(ratingIDs), forKey: Self.ratingKey)
        defaults.set(Array(routineIDs), forKey: Self.routineKey)
    }
}
