import SwiftUI
import StoreKit

// ============================================================
// MARK: — Screen 7: Social Proof + Rating Ask
// ============================================================

struct RampSocialProofScreen: View {
    let onAdvance: () -> Void

    @Environment(AppState.self) private var appState
    // Native StoreKit review request (the SKStoreReviewController hook).
    @Environment(\.requestReview) private var requestReview

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // Laurels + rating
            HStack(spacing: VSpace.md) {
                Image(systemName: "laurel.leading")
                    .font(.system(size: 52, weight: .light))
                    .foregroundStyle(RampStage.accent)
                VStack(spacing: VSpace.xs) {
                    Text(verbatim: "4.8")
                        .font(VType.number(52))
                        .foregroundStyle(RampStage.textPrimary)
                    HStack(spacing: 3) {
                        ForEach(0..<5, id: \.self) { _ in
                            Image(systemName: "star.fill")
                                .font(.system(size: 13))
                                .foregroundStyle(RampStage.accent)
                        }
                    }
                }
                Image(systemName: "laurel.trailing")
                    .font(.system(size: 52, weight: .light))
                    .foregroundStyle(RampStage.accent)
            }
            .vGlow(RampStage.accent, radius: 26, opacity: 0.25)
            .vStaggeredAppear(index: 0)

            Spacer().frame(height: VSpace.xl)

            // SAMPLE COPY: replace with real, permissioned user reviews before ship.
            VStack(spacing: VSpace.sm) {
                RampReviewCard(
                    quote: "Finally an app that doesn't flatter me. 58 → 81 in three weeks.",
                    author: "Maya · scanning for 6 weeks"
                )
                .vStaggeredAppear(index: 1)
                RampReviewCard(
                    quote: "The ceiling view is addictive. I actually stuck to the plan.",
                    author: "Jonas · scanning for 2 months"
                )
                .vStaggeredAppear(index: 2)
            }
            .padding(.horizontal, VSpace.lg)

            Spacer()

            DQPrimaryButton(title: "Continue") { onAdvance() }
                .padding(.horizontal, VSpace.lg)
            Spacer().frame(height: VSpace.xxl)
        }
        .onAppear {
            // Rating-prompt hook — gated behind a config flag, default OFF.
            // Intended for later app versions once organic ratings justify it.
            if appState.featureFlags.onboardingRatingAskEnabled {
                requestReview()
            }
        }
    }
}

private struct RampReviewCard: View {
    let quote: String
    let author: String

    var body: some View {
        VStack(alignment: .leading, spacing: VSpace.xs) {
            Text(verbatim: "“\(quote)”")
                .font(VType.body)
                .foregroundStyle(RampStage.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
            Text(verbatim: author)
                .font(VType.micro)
                .foregroundStyle(RampStage.textTertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(VSpace.md)
        .background(RampStage.card, in: RoundedRectangle(cornerRadius: VRadius.md, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: VRadius.md, style: .continuous)
                .strokeBorder(RampStage.hairline, lineWidth: 1)
        )
    }
}

// ============================================================
// MARK: — Screen 8: Notification pre-prompt
// ============================================================

/// Custom screen BEFORE the system dialog — a denied system prompt is
/// unrecoverable, so the real request only fires from the accent button.
struct RampNotificationScreen: View {
    let onAdvance: () -> Void

    @State private var requesting = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer() // head sits small in the corner (staged by the container)

            VStack(spacing: VSpace.md) {
                Text("Your score changes daily.")
                    .font(VType.hero(30))
                    .foregroundStyle(RampStage.textPrimary)
                    .multilineTextAlignment(.center)
                Text("One reminder a day keeps your 14-day plan on track.")
                    .font(VType.bodyLarge)
                    .foregroundStyle(RampStage.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, VSpace.xl)
            .vStaggeredAppear(index: 0)

            Spacer()

            VStack(spacing: VSpace.sm) {
                DQPrimaryButton(title: "Enable reminders", isEnabled: !requesting) {
                    guard !requesting else { return }
                    requesting = true
                    Task {
                        let granted = await NotificationManager.requestAuthorization()
                        if granted { NotificationManager.scheduleRoutineReminders() }
                        RampAnalytics.track("onboarding_notifications",
                                            ["choice": "enable", "granted": String(granted)])
                        onAdvance()
                    }
                }
                RampGhostButton(title: "Not now") {
                    RampAnalytics.track("onboarding_notifications", ["choice": "not_now"])
                    onAdvance()
                }
            }
            .padding(.horizontal, VSpace.lg)
            Spacer().frame(height: VSpace.xxl)
        }
    }
}

// ============================================================
// MARK: — Screen 9: Scan Ramp (the handoff)
// ============================================================

/// The climax: head full screen, rotation stops facing the user for the first
/// time, one slow deliberate sweep, a single pulsing CTA. Camera permission is
/// requested HERE, on tap — the moment of maximum motivation.
struct RampScanRampScreen: View {
    let controller: ScanHeadController
    let onComplete: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pulsing = false
    @State private var starting = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            Spacer()

            VStack(spacing: VSpace.sm) {
                Text("Your turn.")
                    .font(VType.hero(36))
                    .foregroundStyle(RampStage.textPrimary)
                Text("Good light. No filter. The engine sees everything anyway.")
                    .font(VType.body)
                    .foregroundStyle(RampStage.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, VSpace.xl)
            .vStaggeredAppear(index: 0)

            Spacer().frame(height: VSpace.xl)

            DQPrimaryButton(title: "Start my scan", systemImage: "camera.fill") {
                guard !starting else { return }
                starting = true
                Task {
                    let granted = await CameraPermission.request()
                    RampAnalytics.track("onboarding_camera_permission",
                                        ["granted": String(granted)])
                    onComplete()
                }
            }
            .scaleEffect(pulsing && !reduceMotion ? 1.03 : 1.0)
            .animation(
                reduceMotion ? nil : .easeInOut(duration: 1.1).repeatForever(autoreverses: true),
                value: pulsing
            )
            .padding(.horizontal, VSpace.lg)

            Spacer().frame(height: VSpace.xxl)
        }
        .task {
            // One slow, deliberate sweep once the head has settled facing forward.
            try? await Task.sleep(for: .milliseconds(1800))
            guard !Task.isCancelled else { return }
            if !reduceMotion { controller.sweep(duration: 2.4) }
            pulsing = true
        }
    }
}
