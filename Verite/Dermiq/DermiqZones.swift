import Foundation

// ============================================================
// MARK: — Face zones (per-region scores for the zone map)
// ============================================================
//
// Perfect Corp returns some metrics split by facial region (pore comes as
// forehead / nose / cheek / whole, etc.). We fold those rows into five
// friendly zones. Where the live API gives no per-zone rows (mock engine,
// older stored scans), zones are derived as weighted blends of the seven
// sub-scores — clearly deterministic, so the same scan always shows the
// same map.

enum DermiqZone: String, Codable, CaseIterable, Identifiable, Sendable {
    case forehead, eyes, nose, cheeks, chin

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .forehead: return "Forehead"
        case .eyes: return "Eye area"
        case .nose: return "Nose"
        case .cheeks: return "Cheeks"
        case .chin: return "Chin"
        }
    }

    /// Maps a Perfect Corp `region` string onto a zone. Unknown regions → nil.
    static func fromRegion(_ region: String) -> DermiqZone? {
        let r = region.lowercased()
        if r.contains("forehead") { return .forehead }
        if r.contains("nose") { return .nose }
        if r.contains("cheek") { return .cheeks }
        if r.contains("chin") || r.contains("jaw") { return .chin }
        if r.contains("eye") || r.contains("orbital") || r.contains("ocular") { return .eyes }
        return nil
    }
}

/// One zone's reading: a 0–100 health value plus the category that drags it
/// down the most (what to focus on there).
struct DermiqZoneScore: Codable, Hashable, Identifiable, Sendable {
    let zone: DermiqZone
    let value: Int
    let focus: DermiqCategory

    var id: String { zone.rawValue }
}

// ============================================================
// MARK: — Deriver
// ============================================================

enum DermiqZoneDeriver {

    /// Which sub-scores drive each zone, and how strongly. Weights sum to 1.
    private static let drivers: [DermiqZone: [(DermiqCategory, Double)]] = [
        .forehead: [(.texture, 0.40), (.blemishes, 0.35), (.glow, 0.25)],
        .eyes:     [(.hydration, 0.50), (.glow, 0.30), (.texture, 0.20)],
        .nose:     [(.pores, 0.60), (.blemishes, 0.25), (.redness, 0.15)],
        .cheeks:   [(.redness, 0.35), (.evenness, 0.35), (.pores, 0.30)],
        .chin:     [(.blemishes, 0.50), (.texture, 0.30), (.pores, 0.20)],
    ]

    /// Zones for any analysis: stored live zones when present, else derived.
    static func zones(for analysis: DermiqAnalysis) -> [DermiqZoneScore] {
        if let stored = analysis.zones, stored.count == DermiqZone.allCases.count {
            return ordered(stored)
        }
        var derived = derive(subScores: analysis.subScores, overall: analysis.overall)
        // Merge any partial live zones over the derived baseline.
        if let stored = analysis.zones {
            for live in stored {
                if let i = derived.firstIndex(where: { $0.zone == live.zone }) {
                    derived[i] = live
                }
            }
        }
        return derived
    }

    /// Live rows (region-split API output) + derived fill for missing zones.
    static func zones(
        fromLive accum: [DermiqZone: [(category: DermiqCategory, score: Int)]],
        subScores: [DermiqSubScore],
        overall: Int
    ) -> [DermiqZoneScore] {
        var result = derive(subScores: subScores, overall: overall)
        for (zone, rows) in accum where !rows.isEmpty {
            let value = rows.map(\.score).reduce(0, +) / rows.count
            let focus = rows.min { $0.score < $1.score }?.category
                ?? result.first { $0.zone == zone }?.focus
                ?? .texture
            if let i = result.firstIndex(where: { $0.zone == zone }) {
                result[i] = DermiqZoneScore(zone: zone, value: value, focus: focus)
            }
        }
        return result
    }

    /// Pure blend of the seven sub-scores, with a tiny deterministic offset so
    /// the map doesn't read as five copies of the overall.
    static func derive(subScores: [DermiqSubScore], overall: Int) -> [DermiqZoneScore] {
        func value(of category: DermiqCategory) -> Int {
            subScores.first { $0.category == category }?.value ?? overall
        }
        return DermiqZone.allCases.enumerated().map { index, zone in
            let weights = drivers[zone] ?? []
            let blended = weights.reduce(0.0) { $0 + Double(value(of: $1.0)) * $1.1 }
            // Stable ±2 wobble seeded by overall+zone — organic, never random.
            let wobble = ((overall &* 31 &+ index &* 17) % 5) - 2
            let clamped = min(max(Int(blended.rounded()) + wobble, 0), 100)
            let focus = weights.min { value(of: $0.0) < value(of: $1.0) }?.0 ?? .texture
            return DermiqZoneScore(zone: zone, value: clamped, focus: focus)
        }
    }

    /// One practical sentence for the zone's focus category.
    static func tip(for focus: DermiqCategory) -> String {
        switch focus {
        case .texture: return "Gentle exfoliation 2–3× a week smooths this zone."
        case .redness: return "Skip hot water here and keep products fragrance-free."
        case .pores: return "A BHA cleanser keeps pores in this zone clear."
        case .evenness: return "Daily SPF is what evens this zone out over time."
        case .glow: return "Hydration + sleep show up here first."
        case .hydration: return "Layer a humectant serum before moisturizer here."
        case .blemishes: return "Keep this zone clean and resist touching it."
        }
    }

    private static func ordered(_ zones: [DermiqZoneScore]) -> [DermiqZoneScore] {
        DermiqZone.allCases.compactMap { z in zones.first { $0.zone == z } }
    }
}
