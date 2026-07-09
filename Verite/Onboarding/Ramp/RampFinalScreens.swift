import SwiftUI
import StoreKit

// ============================================================
// MARK: — Screen 9: The Curve (where do you land?)
// ============================================================

/// Social comparison without a single fabricated testimonial (App Review
/// 2.3.1-safe): a soft population curve with a "?" that keeps searching for
/// the user's spot and never finds it — because only a scan can place it.
struct RampCurveScreen: View {
    let onAdvance: () -> Void

    @Environment(AppState.self) private var appState
    @Environment(\.requestReview) private var requestReview

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: VSpace.md) {
                Text("Where do\nyou land?")
                    .font(RampStage.serif(30, italic: true))
                    .foregroundStyle(RampStage.ink)
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
                    .vStaggeredAppear(index: 0)
                Text("Every score forms a curve. Yours is the one point still missing.")
                    .font(VType.bodyLarge)
                    .foregroundStyle(RampStage.textSecondary)
                    .multilineTextAlignment(.center)
                    .vStaggeredAppear(index: 1)
            }
            .padding(.horizontal, VSpace.xl)

            RampDistributionCurve()
                .padding(.horizontal, VSpace.lg)
                .padding(.top, VSpace.lg)
                .vStaggeredAppear(index: 2)

            HStack(spacing: VSpace.md) {
                RampMiniClaim(icon: "iphone.gen3", text: "On-device")
                RampMiniClaim(icon: "square.grid.3x3.fill", text: "7 metrics")
                RampMiniClaim(icon: "gauge.with.dots.needle.bottom.50percent", text: "Honest 0–100")
            }
            .padding(.horizontal, VSpace.lg)
            .padding(.top, VSpace.lg)
            .vStaggeredAppear(index: 3)

            Spacer()

            RampPrimaryButton(title: "Find my spot") { onAdvance() }
                .padding(.horizontal, VSpace.lg)
            Spacer().frame(height: VSpace.xxl)
        }
        .onAppear {
            if appState.featureFlags.onboardingRatingAskEnabled {
                requestReview()
            }
        }
    }
}

private struct RampMiniClaim: View {
    let icon: String
    let text: String

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .regular))
                .foregroundStyle(RampStage.accentDeep)
            Text(text)
                .font(VType.micro)
                .foregroundStyle(RampStage.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, VSpace.sm)
        .background(RampStage.card, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(RampStage.hairline, lineWidth: 1)
        )
    }
}

// ============================================================
// MARK: — Screen 10: Daily ritual (notifications, reframed)
// ============================================================

/// Custom screen BEFORE the system dialog — a denied system prompt is
/// unrecoverable, so the real request only fires from the primary button.
struct RampDailyReportScreen: View {
    let onAdvance: () -> Void

    @State private var requesting = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer() // orb sits small at the top (staged by the container)

            VStack(spacing: VSpace.md) {
                Text("A gentle note,\nonce a day.")
                    .font(RampStage.serif(30, italic: true))
                    .foregroundStyle(RampStage.ink)
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
                Text("Your score shifts daily. One quiet reminder keeps your 14-day ritual on track.")
                    .font(VType.bodyLarge)
                    .foregroundStyle(RampStage.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, VSpace.xl)
            .vStaggeredAppear(index: 0)

            Spacer()

            VStack(spacing: VSpace.sm) {
                RampPrimaryButton(title: "Enable reminders", isEnabled: !requesting) {
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
// MARK: — Screen 11: Handoff (the real you)
// ============================================================

/// The resolution: the orb glows full and calm, and the invitation is simple —
/// the estimate is done, now the real reading. Camera permission is requested
/// HERE, on tap, at peak motivation. No brackets, no sonar — just an open door.
struct RampHandoffScreen: View {
    let onComplete: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shown = false
    @State private var starting = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            Spacer() // orb, full and calm (staged by the container)

            Text(verbatim: "READY WHEN YOU ARE")
                .font(VType.micro)
                .tracking(3)
                .foregroundStyle(RampStage.accentDeep)
                .opacity(shown ? 1 : 0)

            VStack(spacing: VSpace.sm) {
                Text("Now, the\nreal you.")
                    .font(RampStage.serif(34, italic: true))
                    .foregroundStyle(RampStage.ink)
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
                Text("Good light, no filter. One photo, and the estimate becomes your number.")
                    .font(VType.body)
                    .foregroundStyle(RampStage.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, VSpace.xl)
            .padding(.top, VSpace.sm)
            .opacity(shown ? 1 : 0)
            .offset(y: shown ? 0 : 12)

            Spacer()

            RampPrimaryButton(title: "Scan my skin", systemImage: "camera.fill") {
                guard !starting else { return }
                starting = true
                Task {
                    let granted = await CameraPermission.request()
                    RampAnalytics.track("onboarding_camera_permission",
                                        ["granted": String(granted)])
                    onComplete()
                }
            }
            .padding(.horizontal, VSpace.lg)

            Spacer().frame(height: VSpace.xxl)
        }
        .task {
            try? await Task.sleep(for: .milliseconds(reduceMotion ? 100 : 500))
            withAnimation(.easeOut(duration: 1.0)) { shown = true }
        }
    }
}
