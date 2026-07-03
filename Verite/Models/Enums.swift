import Foundation
import SwiftUI

// Shared value types used across models, the analysis engine, and the UI.
// Every user-facing case exposes a `localizationKey` so display strings live in
// the String Catalog, never hardcoded.

// MARK: - Skin type

enum SkinType: String, Codable, CaseIterable, Identifiable, Sendable {
    case normal, dry, oily, combination, sensitive
    var id: String { rawValue }
    var localizationKey: LocalizedStringKey { "skinType.\(rawValue)" }
}

// MARK: - Concerns (declared by the user in onboarding)

enum SkinConcern: String, Codable, CaseIterable, Identifiable, Sendable {
    case redness, acne, texture, pores, dryness, aging, oiliness, dullness, sensitivity, hyperpigmentation
    var id: String { rawValue }
    var localizationKey: LocalizedStringKey { "concern.\(rawValue)" }
}

// MARK: - Measured attributes (produced by the analysis engine)

/// The seven attributes the classical-CV pipeline estimates per scan.
/// These are **estimates**, tracked as change vs the user's own baseline —
/// never presented as clinical measurements.
enum SkinAttribute: String, Codable, CaseIterable, Identifiable, Sendable {
    case redness, oiliness, texture, pores, blemishes, hydration, sensitivity
    var id: String { rawValue }
    var localizationKey: LocalizedStringKey { "attribute.\(rawValue)" }

    /// For most attributes a *lower* value is a better outcome; hydration is the
    /// exception (higher is better). Used when coloring change vs baseline.
    var lowerIsBetter: Bool { self != .hydration }
}

// MARK: - Face side (for the half-face test)

enum FaceSide: String, Codable, CaseIterable, Identifiable, Sendable {
    case full, left, right
    var id: String { rawValue }
    var localizationKey: LocalizedStringKey { "side.\(rawValue)" }

    var opposite: FaceSide {
        switch self {
        case .left: return .right
        case .right: return .left
        case .full: return .full
        }
    }
}

// MARK: - Product provenance (legal/open sources only)

enum ProductSource: String, Codable, Sendable {
    case seed              // bundled starter catalog
    case openBeautyFacts   // open-licensed API
    case userContribution  // added by the user
    case affiliate         // only when the affiliate module is enabled
    var localizationKey: LocalizedStringKey { "source.\(rawValue)" }
}

// MARK: - Half-face test lifecycle

enum TestStatus: String, Codable, Sendable {
    case queued          // waiting behind the one active test
    case running
    case verdictReady    // enough data + significance to show a verdict
    case passed          // promoted into the proven routine
    case failed          // money-saved +1
    var localizationKey: LocalizedStringKey { "test.status.\(rawValue)" }
}

// MARK: - Routine timing

enum TimeOfDay: String, Codable, CaseIterable, Identifiable, Sendable {
    case am, pm
    var id: String { rawValue }
    var localizationKey: LocalizedStringKey { "timeOfDay.\(rawValue)" }
}

// MARK: - Ingredient classification (INCI engine, Milestone 4)

enum IngredientClass: String, Codable, CaseIterable, Sendable {
    case active, irritant, fragrance, alcohol, comedogenic, humectant, emollient, other
    var localizationKey: LocalizedStringKey { "ingredient.class.\(rawValue)" }
    /// Localized plain-language "what this type does".
    var descriptionKey: LocalizedStringKey { "ingredient.class.\(rawValue).desc" }

    /// Whether this class is an honesty *flag* worth surfacing risk-first.
    var isRiskFlag: Bool {
        switch self {
        case .irritant, .fragrance, .alcohol, .comedogenic: return true
        default: return false
        }
    }

    /// PillTag tone used when this class is shown as a chip.
    var tone: PillTag.Tone {
        switch self {
        case .active:      return .info
        case .irritant:    return .danger
        case .fragrance:   return .warning
        case .alcohol:     return .warning
        case .comedogenic: return .warning
        case .humectant:   return .success
        case .emollient:   return .success
        case .other:       return .neutral
        }
    }
}
