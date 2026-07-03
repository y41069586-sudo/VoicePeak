import SwiftUI

/// The overall verdict — and it is honestly allowed to be negative. Risk leads.
enum MatchVerdict {
    case avoid, caution, neutral, favorable

    var headlineKey: LocalizedStringKey { "match.verdict.\(raw)" }
    private var raw: String {
        switch self {
        case .avoid: return "avoid"
        case .caution: return "caution"
        case .neutral: return "neutral"
        case .favorable: return "favorable"
        }
    }

    var systemImage: String {
        switch self {
        case .avoid: return "hand.raised.fill"
        case .caution: return "exclamationmark.triangle.fill"
        case .neutral: return "equal.circle.fill"
        case .favorable: return "checkmark.seal.fill"
        }
    }

    var color: Color {
        switch self {
        case .avoid: return Theme.danger
        case .caution: return Theme.warning
        case .neutral: return Theme.textSecondary
        case .favorable: return Theme.success
        }
    }
}

/// A small chip that is either a localized token (concern/class) or a verbatim
/// string (an INCI name, or the user's own typed sensitivity).
struct MatchChip: Identifiable {
    enum Content {
        case localized(LocalizedStringKey)
        case verbatim(String)
    }
    let id = UUID()
    let content: Content
}

/// One reason behind the verdict. Reasons are ordered risk-first for display.
struct MatchReason: Identifiable {
    enum Kind { case risk, benefit }
    let id = UUID()
    let kind: Kind
    let titleKey: LocalizedStringKey
    let chips: [MatchChip]
}

/// Per-region risk/benefit level for the heatmap over the real scan.
enum ZoneLevel {
    case risk, benefit, neutral
    var color: Color? {
        switch self {
        case .risk: return Theme.danger
        case .benefit: return Theme.success
        case .neutral: return nil
        }
    }
}

/// A routine conflict (e.g. retinol + acid) between this product and the user's
/// existing routine.
struct ConflictWarning: Identifiable {
    let id = UUID()
    let titleKey: LocalizedStringKey
}

/// A cheaper/alternative product that shares this product's core actives *and*
/// also fits the user's skin.
struct Dupe: Identifiable {
    let id = UUID()
    let product: Product
    let sharedActives: [String]
}

/// The full product × face result.
struct MatchResult {
    let verdict: MatchVerdict
    let reasons: [MatchReason]      // risk-first
    let zones: [FaceRegion: ZoneLevel]

    var riskReasons: [MatchReason] { reasons.filter { $0.kind == .risk } }
    var benefitReasons: [MatchReason] { reasons.filter { $0.kind == .benefit } }

    /// The lead line: the top reason (risk if any), else the verdict headline.
    var headlineKey: LocalizedStringKey { reasons.first?.titleKey ?? verdict.headlineKey }
}
