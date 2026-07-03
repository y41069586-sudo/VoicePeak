import SwiftUI
import SwiftData

/// Onboarding shell. Milestone 1 ships the hero + honest promise and a single
/// path into the app; the full conversion flow (personalization quiz → baseline
/// scan → paywall handoff, fully animated) is built in Milestone 8.
struct OnboardingFlowView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Query private var profiles: [UserProfile]

    @State private var appeared = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // Hero
            VStack(spacing: 18) {
                Text(Brand.name)
                    .font(Typography.display(56))
                    .foregroundStyle(Theme.textPrimary)
                    .blueGlow(Theme.accent, radius: 24, opacity: 0.4)
                Text("onboarding.hero.valueProp")
                    .font(.title3)
                    .foregroundStyle(Theme.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 16)

            Spacer()

            // The promise — three honest cards.
            VStack(spacing: 12) {
                PromiseRow(icon: "camera.viewfinder", titleKey: "onboarding.promise.scan")
                PromiseRow(icon: "checkmark.seal", titleKey: "onboarding.promise.match")
                PromiseRow(icon: "flask", titleKey: "onboarding.promise.prove")
            }
            .padding(.horizontal, 24)
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 24)

            Spacer()

            VStack(spacing: 8) {
                PrimaryButton(titleKey: "onboarding.cta.start") {
                    beginProfile()
                }
                DisclaimerBanner(style: .short)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            if reduceMotion { appeared = true }
            else { withAnimation(Motion.springSoft.delay(0.1)) { appeared = true } }
        }
    }

    /// Creates (or completes) the on-device profile and drops the user into the
    /// app. The real quiz populates skin type / concerns in Milestone 8.
    private func beginProfile() {
        let profile = profiles.first ?? {
            let created = UserProfile()
            modelContext.insert(created)
            return created
        }()
        profile.onboardingComplete = true
        try? modelContext.save()
    }
}

private struct PromiseRow: View {
    let icon: String
    let titleKey: LocalizedStringKey

    var body: some View {
        GlassCard {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundStyle(Theme.accent)
                    .frame(width: 32)
                Text(titleKey)
                    .font(.headline)
                    .foregroundStyle(Theme.textPrimary)
                Spacer()
            }
        }
    }
}

#Preview {
    ZStack {
        GradientMeshBackground()
        OnboardingFlowView()
    }
    .modelContainer(Persistence.previewContainer)
    .preferredColorScheme(.dark)
}
