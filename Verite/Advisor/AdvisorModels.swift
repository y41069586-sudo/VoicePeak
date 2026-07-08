import Foundation

/// One product the advisor may choose from — a Sendable snapshot assembled by
/// the UI from the SwiftData catalog + `IngredientEngine` profile, so the
/// service layer never touches a `@Model`.
struct AdvisorCandidate: Sendable {
    let id: String        // Product.id UUID string — Claude echoes it back
    let name: String
    let brand: String
    let actives: [String]
    let riskFlags: [String]
    let comedogenicMax: Int
}

/// Everything the advisor needs for one recommendation request.
struct AdvisorRequest: Sendable {
    /// Plain-text summary of the user's skin (numbers + type + concerns),
    /// built by the caller from `SkinContext` / DermIQ — no photo, ever.
    let skinSummary: String
    /// Preset goal phrasings the user tapped.
    let goalLabels: [String]
    /// The user's own words ("talk to Vérité AI"), may be empty.
    let freeText: String
    let candidates: [AdvisorCandidate]
}

/// One honest recommendation from the advisor.
struct AdvisorRecommendation: Identifiable, Sendable, Decodable {
    var id: String { productID }
    let productID: String
    let productName: String
    let fitScore: Int
    let why: String
    let honestReview: String
    let caution: String

    enum CodingKeys: String, CodingKey {
        case productID = "product_id"
        case productName = "product_name"
        case fitScore = "fit_score"
        case why
        case honestReview = "honest_review"
        case caution
    }
}

/// The advisor's full answer: ranked picks + an honest overall note.
struct AdvisorResult: Sendable, Decodable {
    let recommendations: [AdvisorRecommendation]
    let overallNote: String

    enum CodingKeys: String, CodingKey {
        case recommendations
        case overallNote = "overall_note"
    }
}

enum AdvisorError: Error {
    case notConfigured, needsScan, badResponse, http(Int)
}
