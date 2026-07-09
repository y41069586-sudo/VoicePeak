import SwiftUI
import StoreKit

// ============================================================
// MARK: — Screen 9: The Curve (where do you land?)
// ============================================================

/// Social comparison without a single fabricated testimonial (App Review
/// 2.3.1-safe): an abstract population curve with a glowing "?" that keeps
/// searching for the user's spot and never finds it — because only a scan can.
struct RampCurveScreen: View {
    let onAdvance: () -> Void

    @Environment(AppState.self) private var appState
    @Environment(\.requestReview) private var requestReview

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: VSpace.md) {
                Text("Where do you land?")
                    .font(VType.hero(30))
                    .foregroundStyle(RampStage.textPrimary)
                    .multilineTextAlignment(.center)
                Text("Every score forms a curve.\nYours is the one point still missing.")
                    .font(VType.bodyLarge)
                    .foregroundStyle(RampStage.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, VSpace.xl)
            .vStaggeredAppear(index: 0)

            RampDistributionCurve()
                .padding(.horizontal, VSpace.lg)
                .padding(.top, VSpace.xl)
                .vStaggeredAppear(index: 1)

            // Honest differentiators — one compact line, no invented ratings.
            HStack(spacing: VSpace.md) {
                RampMiniClaim(icon: "iphone.gen3", text: "On-device")
                RampMiniClaim(icon: "square.grid.3x3.fill", text: "7 metrics")
                RampMiniClaim(icon: "gauge.with.dots.needle.bottom.50percent", text: "Honest 0–100")
            }
            .padding(.top, VSpace.lg)
            .vStaggeredAppear(index: 2)

            Spacer()

            DQPrimaryButton(title: "Find my spot") { onAdvance() }
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
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(RampStage.accent)
            Text(text)
                .font(VType.micro)
                .foregroundStyle(RampStage.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, VSpace.sm)
        .background(RampStage.card, in: RoundedRectangle(cornerRadius: VRadius.md, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: VRadius.md, style: .continuous)
                .strokeBorder(RampStage.hairline, lineWidth: 1)
        )
    }
}

// ============================================================
// MARK: — Screen 10: Daily Report (notifications, reframed)
// ============================================================

/// Custom screen BEFORE the system dialog — a denied system prompt is
/// unrecoverable, so the real request only fires from the accent button.
/// Reframed around the twin: it updates daily and reports back.
struct RampDailyReportScreen: View {
    let controller: ScanHeadController
    let onAdvance: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var requesting = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer() // head sits small in the corner (staged by the container)

            VStack(spacing: VSpace.md) {
                Text("Your twin updates daily.")
                    .font(VType.hero(30))
                    .foregroundStyle(RampStage.textPrimary)
                    .multilineTextAlignment(.center)
                Text("Let it report back. One nudge a day keeps your 14-day plan on track.")
                    .font(VType.bodyLarge)
                    .foregroundStyle(RampStage.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, VSpace.xl)
            .vStaggeredAppear(index: 0)

            Spacer()

            VStack(spacing: VSpace.sm) {
                DQPrimaryButton(title: "Enable daily report", isEnabled: !requesting) {
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
        .task {
            // The twin turns toward you — acknowledgement.
            guard !reduceMotion else { return }
            try? await Task.sleep(for: .milliseconds(500))
            controller.nudge(dx: 0.28)
        }
    }
}

// ============================================================
// MARK: — Screen 11: Handoff (awaiting the original)
// ============================================================

/// The climax and the resolution of the story: the finished twin turns to
/// face you, HUD brackets lock on — but instead of "scan ready" they read
/// AWAITING ORIGINAL. The scan is not a feature; it is the end of the film.
/// Camera permission is requested HERE, on tap — peak motivation.
struct RampHandoffScreen: View {
    let controller: ScanHeadController
    let onComplete: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pulsing = false
    @State private var starting = false
    @State private var locked = false

    var body: some View {
        ZStack {
            VStack {
                Spacer()
                ZStack {
                    if !reduceMotion {
                        RampPulseRings()
                    }
                    RampViewfinderBrackets(locked: locked)
                        .frame(width: 272, height: 330)
                }
                .frame(maxHeight: .infinity)
                Spacer().frame(height: 260)
            }
            .allowsHitTesting(false)

            VStack(spacing: 0) {
                Spacer()
                Spacer()

                VStack(spacing: VSpace.sm) {
                    Text("The twin is ready.")
                        .font(VType.hero(34))
                        .foregroundStyle(RampStage.textPrimary)
                    Text("Now the original. Good light, no filter — the engine sees everything anyway.")
                        .font(VType.body)
                        .foregroundStyle(RampStage.textSecondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, VSpace.xl)
                .vStaggeredAppear(index: 0)

                Spacer().frame(height: VSpace.xl)

                DQPrimaryButton(title: "Scan the original", systemImage: "camera.fill") {
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
        }
        .task {
            try? await Task.sleep(for: .milliseconds(1800))
            guard !Task.isCancelled else { return }
            if !reduceMotion { controller.sweep(duration: 2.4) }
            withAnimation(VMotion.gentle) { locked = true }
            Haptics.fire(.tick)
            pulsing = true
        }
    }
}

// ============================================================
// MARK: — Handoff HUD pieces
// ============================================================

/// Four corner brackets that draw themselves around the head, then breathe.
/// `locked` lights them up with an AWAITING ORIGINAL tag once the head settles.
private struct RampViewfinderBrackets: View {
    let locked: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var drawn = false
    @State private var breathing = false

    var body: some View {
        ZStack(alignment: .top) {
            RampCornerBrackets()
                .trim(from: 0, to: drawn ? 1 : 0)
                .stroke(
                    RampStage.accent.opacity(locked ? 0.85 : 0.4),
                    style: StrokeStyle(lineWidth: 2, lineCap: .round)
                )
                .vGlow(RampStage.accent, radius: 14, opacity: locked ? 0.5 : 0)

            Text(verbatim: "AWAITING ORIGINAL")
                .font(DQFont.mono(11, weight: .semibold))
                .tracking(3)
                .foregroundStyle(RampStage.accent)
                .opacity(locked ? 1 : 0)
                .offset(y: -26)
        }
        .scaleEffect(breathing && !reduceMotion ? 1.015 : 1)
        .animation(VMotion.gentle, value: locked)
        .onAppear {
            if reduceMotion {
                drawn = true
                return
            }
            withAnimation(.easeInOut(duration: 1.1).delay(0.5)) { drawn = true }
            withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true)) {
                breathing = true
            }
        }
        .accessibilityHidden(true)
    }
}

/// The four L-shaped viewfinder corners as one trimmable path.
private struct RampCornerBrackets: Shape {
    func path(in rect: CGRect) -> Path {
        let l = min(rect.width, rect.height) * 0.11
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.minY + l))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.minX + l, y: rect.minY))
        p.move(to: CGPoint(x: rect.maxX - l, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + l))
        p.move(to: CGPoint(x: rect.maxX, y: rect.maxY - l))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.maxX - l, y: rect.maxY))
        p.move(to: CGPoint(x: rect.minX + l, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY - l))
        return p
    }
}

/// Slow concentric rings radiating from the head — sonar, not alarm.
private struct RampPulseRings: View {
    var body: some View {
        ZStack {
            RampPulseRing(delay: 0)
            RampPulseRing(delay: 1.4)
        }
        .frame(width: 210, height: 210)
    }
}

private struct RampPulseRing: View {
    let delay: Double
    @State private var expanded = false

    var body: some View {
        Circle()
            .strokeBorder(RampStage.accent.opacity(0.35), lineWidth: 1)
            .scaleEffect(expanded ? 1.55 : 0.85)
            .opacity(expanded ? 0 : 0.7)
            .onAppear {
                withAnimation(
                    .easeOut(duration: 2.8)
                    .repeatForever(autoreverses: false)
                    .delay(delay)
                ) {
                    expanded = true
                }
            }
            .accessibilityHidden(true)
    }
}
