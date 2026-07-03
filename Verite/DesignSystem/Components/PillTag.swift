import SwiftUI

/// Small capsule label used for concerns, ingredient classes, and honest flags.
/// `tone` maps to the semantic palette so a "danger" pill reads as a real warning.
struct PillTag: View {
    let titleKey: LocalizedStringKey
    var systemImage: String? = nil
    var tone: Tone = .neutral

    enum Tone { case neutral, info, success, warning, danger }

    var body: some View {
        HStack(spacing: 5) {
            if let systemImage { Image(systemName: systemImage).font(.caption2) }
            Text(titleKey).font(.caption.weight(.semibold))
        }
        .foregroundStyle(foreground)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(background, in: Capsule())
        .overlay(Capsule().strokeBorder(foreground.opacity(0.25), lineWidth: 1))
    }

    private var foreground: Color {
        switch tone {
        case .neutral: return Theme.textSecondary
        case .info:    return Theme.accent
        case .success: return Theme.success
        case .warning: return Theme.warning
        case .danger:  return Theme.danger
        }
    }

    private var background: Color { foreground.opacity(0.12) }
}
