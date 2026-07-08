import Foundation
import SwiftData

/// The user's declared profile from onboarding. Feeds the Match engine.
/// Stored on-device only. No photos here — those live as local file refs on `Scan`.
@Model
final class UserProfile {
    @Attribute(.unique) var id: UUID
    /// BCP-47 identifier of the user's chosen/override language (e.g. "de").
    var localeIdentifier: String
    var skinType: SkinType?
    var concerns: [SkinConcern]
    /// Free-text sensitivities/allergies the user typed (e.g. "fragrance", "niacinamide").
    var sensitivities: [String]
    /// Products the user already uses — used for the routine-conflict check.
    var currentProducts: [String]
    var goal: String?
    var onboardingComplete: Bool
    var createdAt: Date

    // Onboarding-quiz answers (raw values of the RampQuizAnswers enums).
    // Read by the routine/plan generation and shown back on the profile —
    // the quiz must visibly influence what the engine recommends.
    /// Q1 — how the user rated their own skin ("rough" … "honestlyGood").
    var selfRating: String?
    /// Q3 — current routine depth ("nothing" … "fullStack").
    var routineLevel: String?
    /// Q4 — average nightly sleep ("under6" … "eightPlus").
    var sleepBucket: String?
    /// Q5 — SPF habit ("daily" / "sometimes" / "whatsSPF").
    var sunProtection: String?

    init(
        id: UUID = UUID(),
        localeIdentifier: String = Locale.current.identifier,
        skinType: SkinType? = nil,
        concerns: [SkinConcern] = [],
        sensitivities: [String] = [],
        currentProducts: [String] = [],
        goal: String? = nil,
        onboardingComplete: Bool = false,
        createdAt: Date = .now,
        selfRating: String? = nil,
        routineLevel: String? = nil,
        sleepBucket: String? = nil,
        sunProtection: String? = nil
    ) {
        self.id = id
        self.localeIdentifier = localeIdentifier
        self.skinType = skinType
        self.concerns = concerns
        self.sensitivities = sensitivities
        self.currentProducts = currentProducts
        self.goal = goal
        self.onboardingComplete = onboardingComplete
        self.createdAt = createdAt
        self.selfRating = selfRating
        self.routineLevel = routineLevel
        self.sleepBucket = sleepBucket
        self.sunProtection = sunProtection
    }
}
