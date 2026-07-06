import Foundation
import SwiftUI

// Shared value types used across models, the analysis engine, and the UI.
// Every user-facing case exposes a `localizationKey` so display strings live in
// the String Catalog, never hardcoded.
// NOTE: All localizationKey properties use explicit switch statements (not string
// interpolation) so the .xcstrings runtime can resolve them correctly.

// MARK: - Skin type

enum SkinType: String, Codable, CaseIterable, Identifiable, Sendable {
    case normal, dry, oily, combination, sensitive
    var id: String { rawValue }
    var localizationKey: LocalizedStringKey {
        switch self {
        case .normal:      return "skinType.normal"
        case .dry:         return "skinType.dry"
        case .oily:        return "skinType.oily"
        case .combination: return "skinType.combination"
        case .sensitive:   return "skinType.sensitive"
        }
    }
}

// MARK: - Concerns (declared by the user in onboarding)

enum SkinConcern: String, Codable, CaseIterable, Identifiable, Sendable {
    case redness, acne, texture, pores, dryness, aging, oiliness, dullness, sensitivity, hyperpigmentation
    var id: String { rawValue }
    var localizationKey: LocalizedStringKey {
        switch self {
        case .redness:           return "concern.redness"
        case .acne:              return "concern.acne"
        case .texture:           return "concern.texture"
        case .pores:             return "concern.pores"
        case .dryness:           return "concern.dryness"
        case .aging:             return "concern.aging"
        case .oiliness:          return "concern.oiliness"
        case .dullness:          return "concern.dullness"
        case .sensitivity:       return "concern.sensitivity"
        case .hyperpigmentation: return "concern.hyperpigmentation"
        }
    }
}

// MARK: - Measured attributes (produced by the analysis engine)

/// The seven attributes the classical-CV pipeline estimates per scan.
/// These are **estimates**, tracked as change vs the user's own baseline —
/// never presented as clinical measurements.
enum SkinAttribute: String, Codable, CaseIterable, Identifiable, Sendable {
    case redness, oiliness, texture, pores, blemishes, hydration, sensitivity
    var id: String { rawValue }
    var localizationKey: LocalizedStringKey {
        switch self {
        case .redness:     return "attribute.redness"
        case .oiliness:    return "attribute.oiliness"
        case .texture:     return "attribute.texture"
        case .pores:       return "attribute.pores"
        case .blemishes:   return "attribute.blemishes"
        case .hydration:   return "attribute.hydration"
        case .sensitivity: return "attribute.sensitivity"
        }
    }

    /// For most attributes a *lower* value is a better outcome; hydration is the
    /// exception (higher is better). Used when coloring change vs baseline.
    var lowerIsBetter: Bool { self != .hydration }
}

// MARK: - Face side (for the half-face test)

enum FaceSide: String, Codable, CaseIterable, Identifiable, Sendable {
    case full, left, right
    var id: String { rawValue }
    var localizationKey: LocalizedStringKey {
        switch self {
        case .full:  return "side.full"
        case .left:  return "side.left"
        case .right: return "side.right"
        }
    }

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
    var localizationKey: LocalizedStringKey {
        switch self {
        case .seed:             return "source.seed"
        case .openBeautyFacts:  return "source.openBeautyFacts"
        case .userContribution: return "source.userContribution"
        case .affiliate:        return "source.affiliate"
        }
    }
}

// MARK: - Half-face test lifecycle

enum TestStatus: String, Codable, Sendable {
    case queued          // waiting behind the one active test
    case running
    case verdictReady    // enough data + significance to show a verdict
    case passed          // promoted into the proven routine
    case failed          // money-saved +1
    var localizationKey: LocalizedStringKey {
        switch self {
        case .queued:       return "test.status.queued"
        case .running:      return "test.status.running"
        case .verdictReady: return "test.status.verdictReady"
        case .passed:       return "test.status.passed"
        case .failed:       return "test.status.failed"
        }
    }
}

// MARK: - Routine timing

enum TimeOfDay: String, Codable, CaseIterable, Identifiable, Sendable {
    case am, pm
    var id: String { rawValue }
    var localizationKey: LocalizedStringKey {
        switch self {
        case .am: return "timeOfDay.am"
        case .pm: return "timeOfDay.pm"
        }
    }
}

// MARK: - Ingredient classification (INCI engine, Milestone 4)

enum IngredientClass: String, Codable, CaseIterable, Sendable {
    case active, irritant, fragrance, alcohol, comedogenic, humectant, emollient, other
    var localizationKey: LocalizedStringKey {
        switch self {
        case .active:      return "ingredient.class.active"
        case .irritant:    return "ingredient.class.irritant"
        case .fragrance:   return "ingredient.class.fragrance"
        case .alcohol:     return "ingredient.class.alcohol"
        case .comedogenic: return "ingredient.class.comedogenic"
        case .humectant:   return "ingredient.class.humectant"
        case .emollient:   return "ingredient.class.emollient"
        case .other:       return "ingredient.class.other"
        }
    }
    /// Localized plain-language "what this type does".
    var descriptionKey: LocalizedStringKey {
        switch self {
        case .active:      return "ingredient.class.active.desc"
        case .irritant:    return "ingredient.class.irritant.desc"
        case .fragrance:   return "ingredient.class.fragrance.desc"
        case .alcohol:     return "ingredient.class.alcohol.desc"
        case .comedogenic: return "ingredient.class.comedogenic.desc"
        case .humectant:   return "ingredient.class.humectant.desc"
        case .emollient:   return "ingredient.class.emollient.desc"
        case .other:       return "ingredient.class.other.desc"
        }
    }

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
