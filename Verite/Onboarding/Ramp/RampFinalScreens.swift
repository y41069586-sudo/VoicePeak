import SwiftUI
import StoreKit

// ============================================================
// MARK: — Screen 7: Social Proof + Rating Ask
// ============================================================

/// Honest differentiators — no invented ratings or testimonials (there are no
/// real users pre-launch; fabricated social proof is an App Review 2.3.1 risk).
/// The native rating prompt hook stays, gated OFF until organic ratings exist.
struct RampSocialProofScreen: View {
    let onAdvance: () -> Void

    @Environment(AppState.self) private var appState
    @Environment(\.requestReview) private var requestReview

    private struct Claim { let icon: String; let title: String; let sub: String }
    private let claims: [Claim] = [
        Claim(icon: "iphone.gen3", title: "100% on-device",
              sub: "Your photos never leave your phone. No cloud, no upload."),
        Claim(icon: "square.grid.3x3.fill", title: "7 skin metrics",
              sub: "Texture, redness, pores, evenness, glow, hydration, blemishes."),
        Claim(icon: "gauge.with.dots.needle.bottom.50percent", title: "Honest 0–100",
              sub: "No sugarcoating. A real number and the levers to move it."),
    ]

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            HStack(spacing: VSpace.md) {
                Image(systemName: "laurel.leading")
                    .font(.system(size: 44, weight: .light))
                    .foregroundStyle(RampStage.accent)
                Text("Built to be\nhonest.")
                    .font(VType.hero(26))
                    .foregroundStyle(RampStage.textPrimary)
                    .multilineTextAlignment(.center)
                Image(systemName: "laurel.trailing")
                    .font(.system(size: 44, weight: .light))
                    .foregroundStyle(RampStage.accent)
            }
            .vGlow(RampStage.accent, radius: 26, opacity: 0.22)
            .vStaggeredAppear(index: 0)

            Spacer().frame(height: VSpace.xl)

            VStack(spacing: VSpace.sm) {
                ForEach(Array(claims.enumerated()), id: \.offset) { index, claim in
                    RampClaimCard(icon: claim.icon, title: claim.title, sub: claim.sub)
                        .vStaggeredAppear(index: index + 1)
                }
            }
            .padding(.horizontal, VSpace.lg)

            Spacer()

            DQPrimaryButton(title: "Continue") { onAdvance() }
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

private struct RampClaimCard: View {
    let icon: String
    let title: String
    let sub: String

    var body: some View {
        HStack(spacing: VSpace.md) {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .medium))
                .foregroundStyle(RampStage.accent)
                .frame(width: 34)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(VType.bodyLarge.weight(.semibold))
                    .foregroundStyle(RampStage.textPrimary)
                Text(sub)
                    .font(VType.caption)
                    .foregroundStyle(RampStage.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
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
    @State private var locked = false

    var body: some View {
        ZStack {
            // Camera-HUD: pulse rings radiate from the head while corner
            // brackets draw themselves around the target and lock on.
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
        }
        .task {
            // One slow, deliberate sweep once the head has settled facing forward.
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
// MARK: — Scan-ramp HUD pieces
// ============================================================

/// Four corner brackets that draw themselves around the head, then breathe.
/// `locked` lights them up with a "SCAN READY" tag once the head has settled.
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

            Text(verbatim: "SCAN READY")
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
        // Top-left
        p.move(to: CGPoint(x: rect.minX, y: rect.minY + l))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.minX + l, y: rect.minY))
        // Top-right
        p.move(to: CGPoint(x: rect.maxX - l, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + l))
        // Bottom-right
        p.move(to: CGPoint(x: rect.maxX, y: rect.maxY - l))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.maxX - l, y: rect.maxY))
        // Bottom-left
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
            ring(delay: 0)
            ring(delay: 1.4)
        }
    }

    private func ring(delay: Double) -> some View {
        RampPulseRing(delay: delay)
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
