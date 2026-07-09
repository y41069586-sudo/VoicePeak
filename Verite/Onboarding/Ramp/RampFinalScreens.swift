import SwiftUI

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
// MARK: — Screen 11: Handoff (the real you)
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
