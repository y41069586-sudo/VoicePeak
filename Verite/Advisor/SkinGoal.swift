import SwiftUI

/// The preset goals a user can pick before asking Vérité AI for product
/// recommendations. `promptLabel` is the plain-English phrasing sent to Claude;
/// `localizationKey` is what the UI shows.
enum SkinGoal: String, CaseIterable, Identifiable, Sendable {
    case hydration, smoothTexture, lessAcne, lessRedness
    case smallerPores, evenTone, antiAging, lessOiliness

    var id: String { rawValue }

    var localizationKey: LocalizedStringKey {
        switch self {
        case .hydration:     return "goal.hydration"
        case .smoothTexture: return "goal.smoothTexture"
        case .lessAcne:      return "goal.lessAcne"
        case .lessRedness:   return "goal.lessRedness"
        case .smallerPores:  return "goal.smallerPores"
        case .evenTone:      return "goal.evenTone"
        case .antiAging:     return "goal.antiAging"
        case .lessOiliness:  return "goal.lessOiliness"
        }
    }

    var systemImage: String {
        switch self {
        case .hydration:     return "drop.fill"
        case .smoothTexture: return "circle.grid.cross"
        case .lessAcne:      return "bandage.fill"
        case .lessRedness:   return "flame.fill"
        case .smallerPores:  return "circle.dotted"
        case .evenTone:      return "sun.max.fill"
        case .antiAging:     return "sparkles"
        case .lessOiliness:  return "humidity.fill"
        }
    }

    /// Plain-English goal phrasing for the model prompt (not shown in the UI).
    var promptLabel: String {
        switch self {
        case .hydration:     return "more hydration"
        case .smoothTexture: return "smoother skin texture"
        case .lessAcne:      return "fewer breakouts / less acne"
        case .lessRedness:   return "less redness"
        case .smallerPores:  return "smaller-looking pores"
        case .evenTone:      return "a more even skin tone"
        case .antiAging:     return "fewer fine lines / anti-aging"
        case .lessOiliness:  return "less oiliness / shine control"
        }
    }
}
