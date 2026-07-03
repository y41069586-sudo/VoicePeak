import SwiftUI

/// The persistent, discoverable honesty disclaimer. A short version rides along
/// on every analysis surface; the full text lives in Settings → Legal.
/// Baked in from day one — brand integrity **and** App-Review safety (§1/§11).
struct DisclaimerBanner: View {
    /// `.short` for analysis screens, `.full` for legal/first-run contexts.
    var style: Style = .short

    enum Style { case short, full }

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "info.circle")
                .font(.caption)
                .foregroundStyle(Theme.textSecondary)
            Text(style == .short ? "disclaimer.short" : "disclaimer.full")
                .font(.caption2)
                .foregroundStyle(Theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.bgSurface.opacity(0.5), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}
