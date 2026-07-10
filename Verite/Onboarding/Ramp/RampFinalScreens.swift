import SwiftUI
import AuthenticationServices

// ============================================================
// MARK: — Screen 9: The Curve (where do you land?)
// ============================================================

/// Social comparison without a single fabricated testimonial (App Review
/// 2.3.1-safe): a soft population curve with a "?" that keeps searching for
/// the user's spot and never finds it — because only a scan can place it.
///
/// NOTE: deliberately NO review prompt here — Apple 5.6.3 forbids rating asks
/// during onboarding. The ask lives post-scan (results, 3rd+ completed scan).
struct RampCurveScreen: View {
    let onAdvance: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: VSpace.md) {
                Text("Where do\nyou land?")
                    .font(RampStage.serif(28))
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
                RampMiniClaim(icon: "lock.fill", text: "100% private")
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
/// The user picks a concrete time FIRST (implementation intention: a chosen
/// "when" measurably outperforms a generic "daily"), then grants permission.
struct RampDailyReportScreen: View {
    let onAdvance: () -> Void

    private enum RitualTime: String, CaseIterable {
        case morning, evening
        var label: String { self == .morning ? "Morning" : "Evening" }
        var sub: String { self == .morning ? "With your routine, 8:00" : "Wind-down check, 21:00" }
        var icon: String { self == .morning ? "sun.min" : "moon" }
        /// PM-reminder time handed to the scheduler (the AM nudge is fixed at
        /// 8:00) — earlier for morning people, later for evening people.
        var pmHour: (hour: Int, minute: Int) { self == .morning ? (19, 0) : (21, 0) }
    }

    @State private var time: RitualTime = .evening
    @State private var requesting = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: VSpace.md) {
                Text("A gentle note,\nonce a day.")
                    .font(RampStage.serif(28))
                    .foregroundStyle(RampStage.ink)
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
                Text("Your score shifts daily. When should your ritual check in?")
                    .font(VType.bodyLarge)
                    .foregroundStyle(RampStage.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, VSpace.xl)
            .vStaggeredAppear(index: 0)

            Spacer().frame(height: VSpace.xl)

            HStack(spacing: VSpace.sm) {
                ForEach(RitualTime.allCases, id: \.self) { option in
                    timeTile(option)
                }
            }
            .padding(.horizontal, VSpace.lg)
            .vStaggeredAppear(index: 1)

            Spacer()

            VStack(spacing: VSpace.sm) {
                RampPrimaryButton(title: "Enable reminders", isEnabled: !requesting) {
                    guard !requesting else { return }
                    requesting = true
                    let chosen = time
                    Task {
                        let granted = await NotificationManager.requestAuthorization()
                        if granted {
                            let pm = chosen.pmHour
                            NotificationManager.scheduleRoutineReminders(hour: pm.hour, minute: pm.minute)
                        }
                        RampAnalytics.track("onboarding_notifications",
                                            ["choice": "enable",
                                             "time": chosen.rawValue,
                                             "granted": String(granted)])
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

    private func timeTile(_ option: RitualTime) -> some View {
        let selected = time == option
        return Button {
            Haptics.fire(.selection)
            time = option
        } label: {
            VStack(spacing: 6) {
                Image(systemName: option.icon)
                    .font(.system(size: 18, weight: .regular))
                    .foregroundStyle(selected ? RampStage.accentDeep : RampStage.textTertiary)
                Text(option.label)
                    .font(VType.bodyMedium)
                    .foregroundStyle(selected ? RampStage.accentDeep : RampStage.ink)
                Text(option.sub)
                    .font(VType.micro)
                    .foregroundStyle(RampStage.textTertiary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, VSpace.md)
            .background(
                selected
                    ? AnyShapeStyle(RampStage.accent.opacity(0.12))
                    : AnyShapeStyle(RampStage.card),
                in: RoundedRectangle(cornerRadius: 18, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(selected ? RampStage.accent : RampStage.hairline, lineWidth: 1)
            )
        }
        .buttonStyle(PressableStyle())
        .animation(VMotion.gentle, value: time)
    }
}

// ============================================================
// MARK: — Screen 11: Sign in (Apple / Google, or neither)
// ============================================================

/// Account step right before the scan. Sign in with Apple is real (native,
/// no backend needed — the credential's given name personalizes the profile);
/// Google appears once the SDK + client ID are configured (feature flag —
/// a visible dead button would be an App Review 2.1 rejection). "Continue
/// without an account" stays: the app is fully functional without one, and
/// forcing registration for on-phone functionality violates 5.1.1(v).
struct RampSignInScreen: View {
    /// Reports the given name from Apple, if the user shared one.
    let onSignedIn: (String?) -> Void
    let onSkip: () -> Void

    @Environment(AppState.self) private var appState

    var body: some View {
        VStack(spacing: 0) {
            Spacer().frame(height: VSpace.xl)

            RampPhoto(name: "GlowHero", cornerRadius: 24)
                .frame(width: 216, height: 288) // 3:4, no crop

            Spacer()

            VStack(spacing: VSpace.md) {
                Text("Save your glow.")
                    .font(RampStage.serif(28))
                    .foregroundStyle(RampStage.ink)
                    .multilineTextAlignment(.center)
                Text("Keep your readings and your 14-day plan safe across devices.")
                    .font(VType.body)
                    .foregroundStyle(RampStage.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, VSpace.xl)

            Spacer()

            VStack(spacing: VSpace.sm) {
                SignInWithAppleButton(.signIn) { request in
                    request.requestedScopes = [.fullName]
                } onCompletion: { result in
                    switch result {
                    case .success(let authorization):
                        let credential = authorization.credential as? ASAuthorizationAppleIDCredential
                        let name = credential?.fullName?.givenName
                        RampAnalytics.track("onboarding_sign_in",
                                            ["provider": "apple", "result": "success"])
                        Haptics.fire(.milestone)
                        onSignedIn(name)
                    case .failure:
                        // Cancelled or failed — stay on the screen; the user
                        // can retry or continue without an account.
                        RampAnalytics.track("onboarding_sign_in",
                                            ["provider": "apple", "result": "cancelled"])
                    }
                }
                .signInWithAppleButtonStyle(.black)
                .frame(height: 54)
                .clipShape(Capsule())

                if appState.featureFlags.googleSignInEnabled {
                    Button {
                        // TODO: PRODUCTION — wire GoogleSignIn SDK here once
                        // the OAuth client ID exists; flag stays OFF until then.
                        RampAnalytics.track("onboarding_sign_in",
                                            ["provider": "google", "result": "tapped"])
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "g.circle.fill")
                            Text("Continue with Google")
                        }
                        .font(.system(size: 17, weight: .semibold, design: .rounded))
                        .foregroundStyle(RampStage.ink)
                        .frame(maxWidth: .infinity, minHeight: 54)
                        .background(Color.white, in: Capsule())
                        .overlay(Capsule().strokeBorder(RampStage.hairline, lineWidth: 1))
                    }
                    .buttonStyle(PressableStyle())
                }

                RampGhostButton(title: "Continue without an account") {
                    RampAnalytics.track("onboarding_sign_in", ["provider": "none"])
                    onSkip()
                }
            }
            .padding(.horizontal, VSpace.lg)
            Spacer().frame(height: VSpace.xxl)
        }
    }
}

// ============================================================
// MARK: — Screen 12: Handoff (the real you)
// ============================================================

/// The resolution: the estimate is done, now the real reading. Camera
/// permission is requested HERE, on tap, at peak motivation — an open door,
/// not a gate.
struct RampHandoffScreen: View {
    let onComplete: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shown = false
    @State private var starting = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: VSpace.md) {
                Text(verbatim: "READY WHEN YOU ARE")
                    .font(VType.micro)
                    .tracking(3)
                    .foregroundStyle(RampStage.accentDeep)
                Text("Now, the\nreal you.")
                    .font(RampStage.serif(32))
                    .foregroundStyle(RampStage.ink)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                Text("Good light, no filter. One photo, and the estimate becomes your number.")
                    .font(VType.body)
                    .foregroundStyle(RampStage.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, VSpace.xl)
            .opacity(shown ? 1 : 0)
            .offset(y: shown ? 0 : 12)

            Spacer()

            VStack(spacing: VSpace.sm) {
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
                Text("Your reading card and 14-day plan are built from this first scan.")
                    .font(VType.micro)
                    .foregroundStyle(RampStage.textTertiary)
                    .multilineTextAlignment(.center)
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
