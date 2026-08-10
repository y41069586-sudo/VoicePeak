import SwiftUI

/// The four localized legal documents reachable from Settings → Legal and from
/// the paywall's Terms/Privacy links. The Impressum, Privacy Policy, Terms and
/// medical disclaimer bodies are final and localized in all five languages,
/// with the real provider-identity details already filled in.
enum LegalDocument: String, CaseIterable, Identifiable {
    case impressum
    case privacy
    case terms
    case disclaimer

    var id: String { rawValue }

    /// Literal keys — NOT interpolated. A `LocalizedStringKey` built from
    /// `"legal.\(rawValue).title"` is parsed as the key `legal.%@.title` with
    /// `rawValue` as an argument; since the catalog has the concrete keys and
    /// no `%@` variant, the lookup misses and SwiftUI renders the raw key on
    /// screen. Returning compile-time literals keeps the lookup exact.
    var titleKey: LocalizedStringKey {
        switch self {
        case .impressum:  return "legal.impressum.title"
        case .privacy:    return "legal.privacy.title"
        case .terms:      return "legal.terms.title"
        case .disclaimer: return "legal.disclaimer.title"
        }
    }

    /// Localized body key. All four resolve to final localized copy.
    var bodyKey: LocalizedStringKey {
        switch self {
        case .impressum:  return "legal.impressum.body"
        case .privacy:    return "legal.privacy.body"
        case .terms:      return "legal.terms.body"
        case .disclaimer: return "disclaimer.full"
        }
    }

    var systemImage: String {
        switch self {
        case .impressum:  return "building.columns"
        case .privacy:    return "hand.raised"
        case .terms:      return "doc.text"
        case .disclaimer: return "cross.case"
        }
    }
}
