import SwiftUI

/// The four localized legal documents reachable from Settings → Legal. The
/// Impressum, Privacy Policy, Terms and medical disclaimer bodies are final,
/// localized in all five languages. The only remaining fill-ins are the
/// provider-identity fields (name, address, contact email, responsible person),
/// which are bracketed placeholders in the Impressum/Privacy bodies and must be
/// completed with real details before App Store submission.
enum LegalDocument: String, CaseIterable, Identifiable {
    case impressum
    case privacy
    case terms
    case disclaimer

    var id: String { rawValue }

    var titleKey: LocalizedStringKey { "legal.\(rawValue).title" }

    /// Localized body key. All four resolve to final localized copy.
    var bodyKey: LocalizedStringKey {
        rawValue == "disclaimer" ? "disclaimer.full" : "legal.\(rawValue).body"
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
