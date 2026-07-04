import SwiftUI

/// Slim progress bar for the quiz steps.
struct OnboardingProgressBar: View {
    let current: Int
    let total: Int

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Theme.strokeSubtle)
                Capsule().fill(Theme.signature)
                    .frame(width: geo.size.width * fraction)
            }
        }
        .frame(height: 6)
        .veriteAnimation(value: current)
        .accessibilityLabel("onboarding.progress")
        .accessibilityValue(Text(verbatim: "\(current)/\(total)"))
    }

    private var fraction: CGFloat {
        guard total > 0 else { return 0 }
        return CGFloat(min(max(current, 0), total)) / CGFloat(total)
    }
}

/// A tappable selection card (single- or multi-select) with a selected state.
struct OnboardingSelectCard: View {
    let titleKey: LocalizedStringKey
    var systemImage: String? = nil
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button {
            Haptics.fire(.selection)
            action()
        } label: {
            HStack(spacing: 12) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .foregroundStyle(selected ? Theme.primary : Theme.textSecondary)
                        .frame(width: 26)
                }
                Text(titleKey)
                    .font(.headline)
                    .foregroundStyle(Theme.textPrimary)
                Spacer(minLength: 8)
                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(selected ? Theme.primary : Theme.strokeSubtle)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(selected ? Theme.primary : Theme.strokeSubtle, lineWidth: selected ? 2 : 1)
            )
        }
        .buttonStyle(PressableStyle())
    }
}

/// Standard layout for a quiz step: title + subtitle + content + Continue/Skip.
struct OnboardingScaffold<Content: View>: View {
    let titleKey: LocalizedStringKey
    var subtitleKey: LocalizedStringKey? = nil
    var progress: (current: Int, total: Int)? = nil
    var continueEnabled: Bool = true
    var onContinue: () -> Void
    var onSkip: (() -> Void)? = nil
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(spacing: 0) {
            if let progress {
                OnboardingProgressBar(current: progress.current, total: progress.total)
                    .padding(.horizontal, 24).padding(.top, 12)
            }
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(titleKey)
                            .font(Typography.display(30))
                            .foregroundStyle(Theme.textPrimary)
                        if let subtitleKey {
                            Text(subtitleKey)
                                .font(.subheadline)
                                .foregroundStyle(Theme.textSecondary)
                        }
                    }
                    .padding(.top, 20)
                    content()
                }
                .padding(24)
            }
            .scrollIndicators(.hidden)

            VStack(spacing: 6) {
                PrimaryButton(titleKey: "onboarding.continue", isEnabled: continueEnabled, action: onContinue)
                if let onSkip {
                    SecondaryButton(titleKey: "onboarding.skip", action: onSkip)
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 20)
        }
    }
}
