import Foundation
import SwiftData

/// One standardized capture + its estimated attributes. Attributes are stored as
/// change vs the user's own Day-0 baseline (see the analysis engine, Milestone 3).
///
/// Only a **local** thumbnail filename is persisted — the full image (and all
/// analysis) stays on-device and is never uploaded.
@Model
final class Scan {
    @Attribute(.unique) var id: UUID
    var date: Date
    /// 0...1 quality from the AR guide (lighting evenness, face size/centering).
    var captureQuality: Double
    /// Raw per-attribute estimates for this capture, keyed by `SkinAttribute.rawValue`.
    /// (Stored as `[String: Double]` — the safest documented SwiftData shape.)
    var attributeScores: [String: Double]
    var isBaseline: Bool
    var side: FaceSide
    /// Filename (relative to the app's Application Support dir) of the local
    /// thumbnail. Never a remote URL.
    var thumbnailFilename: String?
    /// Optional link back to the half-face test this scan belongs to.
    var testID: UUID?
    var createdAt: Date

    init(
        id: UUID = UUID(),
        date: Date = .now,
        captureQuality: Double = 0,
        attributeScores: [String: Double] = [:],
        isBaseline: Bool = false,
        side: FaceSide = .full,
        thumbnailFilename: String? = nil,
        testID: UUID? = nil,
        createdAt: Date = .now
    ) {
        self.id = id
        self.date = date
        self.captureQuality = captureQuality
        self.attributeScores = attributeScores
        self.isBaseline = isBaseline
        self.side = side
        self.thumbnailFilename = thumbnailFilename
        self.testID = testID
        self.createdAt = createdAt
    }

    // MARK: Typed access

    func score(for attribute: SkinAttribute) -> Double? {
        attributeScores[attribute.rawValue]
    }

    func setScore(_ value: Double, for attribute: SkinAttribute) {
        attributeScores[attribute.rawValue] = value
    }
}
