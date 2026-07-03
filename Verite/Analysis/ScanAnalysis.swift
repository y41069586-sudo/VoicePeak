import Foundation

/// The result of analyzing one capture: raw per-attribute estimates (0...1),
/// the per-region breakdown, and whether a face was actually read. Raw values are
/// stored on the `Scan`; change-vs-baseline is computed at read time.
struct ScanAnalysis: Sendable {
    var attributes: [SkinAttribute: Double]
    var regions: [String: RegionMetrics]   // keyed by FaceRegion.rawValue
    var faceFound: Bool
    /// Normalized image-x of the face midline (from eye landmarks) for the
    /// half-face test. Nil when landmarks were unavailable.
    var midlineX: Double?

    static let empty = ScanAnalysis(attributes: [:], regions: [:], faceFound: false, midlineX: nil)

    /// Storage shape for `Scan.attributeScores`.
    var attributeScores: [String: Double] {
        Dictionary(uniqueKeysWithValues: attributes.map { ($0.key.rawValue, $0.value) })
    }
}

/// One attribute's change from the user's own Day-0 baseline. Direction is
/// interpreted honestly: for most attributes lower is better; hydration is the
/// exception (see `SkinAttribute.lowerIsBetter`).
struct AttributeChange: Identifiable {
    let attribute: SkinAttribute
    let baseline: Double
    let current: Double

    var id: String { attribute.rawValue }
    var delta: Double { current - baseline }
    var magnitude: Double { abs(delta) }
    var isImprovement: Bool { attribute.lowerIsBetter ? delta < 0 : delta > 0 }

    /// True only when the change is above measurement noise (worth showing as real).
    var isMeaningful: Bool { magnitude >= 0.06 }

    /// Signed percentage-point change, for display (e.g. "−18%").
    var signedPercent: Double { delta * 100 }
}
