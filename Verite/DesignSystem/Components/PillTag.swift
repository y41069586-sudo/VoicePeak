import SwiftUI

/// Status chip (DESIGN_SPEC §6.7): pill, colored background at 15% + full-color
/// text — never a solid-fill chip. `tone` maps to the semantic palette so a
/// `.danger` chip reads as a real honest flag, not decoration.
struct PillTag: View {
    let titleKey: LocalizedStringKey
    var systemImage: String? = nil
    var tone: Tone = .neutral

    enum Tone { case neutral, info, success, warning, danger }

    var body: some View {
        HStack(spacing: 5) {
            if let systemImage { Image(systemName: systemImage).font(.caption2) }
            Text(titleKey).font(VType.captionBold)
        }
        .foregroundStyle(foreground)
        .padding(.horizontal, 10)
        .padding(.vertical, VSpace.xs)
        .background(foreground.opacity(0.15), in: Capsule())
    }

    private var foreground: Color {
        switch tone {
        case .neutral: return VColor.textSecondary
        case .info:    return VColor.primary
        case .success: return VColor.success
        case .warning: return VColor.warning
        case .danger:  return VColor.danger
        }
    }
}
