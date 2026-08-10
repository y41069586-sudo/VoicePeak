import Foundation

/// Payloads for optional cloud sync. **By construction these carry numbers and
/// routine only — there is no image/photo field anywhere.** Face data stays on
/// the device.

struct BackendUser: Codable, Sendable, Equatable {
    let id: String
    let email: String?
}

/// Numeric sync payload (opt-in). No thumbnails, no image references.
struct MetricsPayload: Codable, Sendable {
    struct ScanMetric: Codable, Sendable {
        let date: Date
        let side: String
        let isBaseline: Bool
        let captureQuality: Double
        let attributes: [String: Double]
        /// Overall 0–100. Optional for forward-compat with any older row.
        var overall: Int? = nil
    }
    struct RoutineMetric: Codable, Sendable {
        let timeOfDay: String
        let order: Int
        let proven: Bool
    }
    let scans: [ScanMetric]
    let routine: [RoutineMetric]
    let totalSaved: Double
    let currencyCode: String
}

/// Aggregate, anonymized community efficacy for a product (numbers only).
struct CommunityEfficacy: Codable, Sendable, Identifiable {
    let productKey: String
    let skinType: String?
    let worksPercent: Double   // 0...1
    let sampleSize: Int
    var id: String { productKey + (skinType ?? "") }
}

/// A single anonymized efficacy contribution (opt-in): did the test pass, for
/// this product + skin type. No identity, no photo.
struct EfficacyRecord: Codable, Sendable {
    let productKey: String
    let skinType: String?
    let passed: Bool
}

enum BackendError: Error {
    case notEnabled
    case notConfigured
    case notSignedIn
    case http(Int)
    case decoding
}
