import Foundation

/// Confidence model: a verdict is only as trustworthy as the capture quality and
/// the amount of data behind it. Glowé never shows a verdict before it's earned.
enum AnalysisConfidence {
    /// Minimum full-face scans before any change verdict is shown.
    static let minScansForChange = 2
    /// Confidence below this reads as "not enough data yet".
    static let significanceThreshold = 0.5

    /// 0...1 from capture quality (60%) and how many comparable scans exist (40%,
    /// saturating around five scans).
    static func value(captureQuality: Double, scanCount: Int) -> Double {
        let quality = captureQuality.clamped01
        let coverage = min(Double(scanCount), 5) / 5.0
        return (0.6 * quality + 0.4 * coverage).clamped01
    }
}

/// Computes change vs the user's own Day-0 baseline from stored `Scan`s. This is
/// the single source of truth for "how is my skin changing" across the app.
enum BaselineTracker {

    /// Full-face scans, oldest → newest.
    static func fullScans(_ scans: [Scan]) -> [Scan] {
        scans.filter { $0.side == .full }.sorted { $0.date < $1.date }
    }

    /// The baseline: the explicit Day-0 scan, else the earliest full scan.
    static func baseline(_ scans: [Scan]) -> Scan? {
        let full = fullScans(scans)
        return full.first(where: { $0.isBaseline }) ?? full.first
    }

    static func latest(_ scans: [Scan]) -> Scan? {
        fullScans(scans).last
    }

    /// Per-attribute change from baseline to the latest scan. Empty when there
    /// isn't a distinct later scan to compare against.
    static func changes(_ scans: [Scan]) -> [AttributeChange] {
        guard let base = baseline(scans),
              let latest = latest(scans),
              base.id != latest.id else { return [] }

        return SkinAttribute.allCases.compactMap { attribute in
            guard let b = base.score(for: attribute),
                  let c = latest.score(for: attribute) else { return nil }
            return AttributeChange(attribute: attribute, baseline: b, current: c)
        }
    }

    /// Confidence in the current change readout (0 when there's nothing to compare).
    static func confidence(_ scans: [Scan]) -> Double {
        let full = fullScans(scans)
        guard full.count >= AnalysisConfidence.minScansForChange,
              let base = full.first, let latest = full.last, base.id != latest.id else { return 0 }
        let avgQuality = (base.captureQuality + latest.captureQuality) / 2
        return AnalysisConfidence.value(captureQuality: avgQuality, scanCount: full.count)
    }

    /// Whether a change verdict is trustworthy enough to surface.
    static func hasReliableVerdict(_ scans: [Scan]) -> Bool {
        fullScans(scans).count >= AnalysisConfidence.minScansForChange &&
        confidence(scans) >= AnalysisConfidence.significanceThreshold
    }

    /// The most notable meaningful changes (improvements + regressions), ranked
    /// by magnitude — for the dashboard summary.
    static func highlights(_ scans: [Scan], limit: Int = 3) -> [AttributeChange] {
        changes(scans)
            .filter { $0.isMeaningful }
            .sorted { $0.magnitude > $1.magnitude }
            .prefix(limit)
            .map { $0 }
    }
}
