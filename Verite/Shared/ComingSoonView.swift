import SwiftUI

/// Honest placeholder for tabs whose real implementation lands in a later
/// milestone. No dead-ends: it explains what's coming rather than crashing or
/// showing a blank screen.
struct ComingSoonView: View {
    let titleKey: LocalizedStringKey
    let systemImage: String
    var messageKey: LocalizedStringKey = "comingSoon.message"

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Image(systemName: systemImage)
                    .font(.system(size: 44, weight: .light))
                    .foregroundStyle(Theme.accent)
                    .blueGlow()
                Text(titleKey)
                    .font(Typography.display(28))
                    .foregroundStyle(Theme.textPrimary)
                Text(messageKey)
                    .font(.subheadline)
                    .foregroundStyle(Theme.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.clear)
            .navigationTitle(titleKey)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
        }
    }
}
