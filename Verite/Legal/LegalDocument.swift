import SwiftUI

/// The four localized legal documents reachable from Settings → Legal. Full
/// localized bodies (Impressum, Datenschutz/Privacy, AGB/Terms) are authored in
/// Milestone 10 and marked "lawyer review before publishing". The medical
/// disclaimer body already exists (it's baked in from day one).
enum LegalDocument: String, CaseIterable, Identifiable {
    case impressum
    case privacy
    case terms
    case disclaimer

    var id: String { rawValue }

    var titleKey: LocalizedStringKey { "legal.\(rawValue).title" }

    /// Localized body key. The disclaimer resolves to real copy now; the others
    /// resolve to a "coming in a later milestone / see the Markdown file" notice
    /// until M10 fills them in.
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
