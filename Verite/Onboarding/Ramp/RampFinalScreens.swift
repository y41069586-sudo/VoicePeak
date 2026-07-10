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
                    .fixedSize(horizontal: false, vertical: true)
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
                    .fixedSize(horizontal: false, vertical: true)
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
// MARK: — Screen: Your first plan (preview)
// ============================================================

/// Shows the shape of the deliverable BEFORE the commitment screens: a Day-1
/// preview of the 14-day plan. Illustrative, clearly labeled — the real one
/// is built from the scan.
struct RampPlanPreviewScreen: View {
    let onAdvance: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Spacer().frame(height: VSpace.xxl * 1.6)

            VStack(spacing: VSpace.sm) {
                Text(verbatim: "AFTER YOUR SCAN")
                    .font(VType.micro)
                    .tracking(3)
                    .foregroundStyle(RampStage.accentDeep)
                Text("Your first plan,\nready in seconds.")
                    .font(RampStage.serif(28))
                    .foregroundStyle(RampStage.ink)
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
                Text("14 days, morning and evening — every step aimed at your three weakest scores.")
                    .font(VType.body)
                    .foregroundStyle(RampStage.textSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, VSpace.xl)

            Spacer()

            // Day-1 sample card.
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(verbatim: "DAY 1 · PREVIEW")
                        .font(VType.micro).tracking(3)
                        .foregroundStyle(RampStage.accentDeep)
                    Spacer()
                    Text(verbatim: "ILLUSTRATIVE")
                        .font(VType.micro).tracking(2)
                        .foregroundStyle(RampStage.textTertiary)
                }
                previewRow(icon: "sun.max.fill", title: "Morning",
                           steps: "Gentle cleanse · Hydrating serum · SPF 30+")
                previewRow(icon: "moon.stars.fill", title: "Evening",
                           steps: "Cleanse · Targeted active · Moisturizer")
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.seal")
                        .font(.system(size: 11, weight: .semibold))
                    Text("Yours is built from your scan — not a template.")
                        .font(VType.micro)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .foregroundStyle(RampStage.accentDeep)
            }
            .padding(VSpace.lg)
            .background(Color.white.opacity(0.75), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .strokeBorder(RampStage.hairline, lineWidth: 1)
            )
            .shadow(color: RampStage.accent.opacity(0.16), radius: 20, y: 10)
            .padding(.horizontal, VSpace.lg)

            Spacer()

            RampPrimaryButton(title: "Sounds good") { onAdvance() }
                .padding(.horizontal, VSpace.lg)
            Spacer().frame(height: VSpace.xxl)
        }
    }

    private func previewRow(icon: String, title: String, steps: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(RampStage.accentDeep)
                .frame(width: 22)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(VType.bodyMedium)
                    .foregroundStyle(RampStage.ink)
                Text(steps)
                    .font(VType.caption)
                    .foregroundStyle(RampStage.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

// ============================================================
// MARK: — Screen: Register (before the first scan)
// ============================================================

/// A dedicated, unhurried registration screen right before the scan — its own
/// full canvas, only Apple + Google, plenty of breathing room. Apple keeps the
/// black wordmark button; Google carries its authentic multicolor "G".
///
/// The buttons currently continue WITHOUT real authentication (per product
/// decision for TestFlight iteration).
/// TODO: PRODUCTION — before App Store submission these MUST either perform
/// real auth (re-add the entitlement + SDK) or be removed; placebo login
/// buttons are an App Review 2.1 rejection. If real Google auth is added, swap
/// GoogleGLogo for Google's official-brand asset per their sign-in guidelines.
struct RampSignInScreen: View {
    /// Reports an optional given name (real auth will supply one later).
    let onSignedIn: (String?) -> Void
    let onSkip: () -> Void

    @State private var shown = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // Soft emblem — a blush disc with a single coral mark.
            ZStack {
                Circle()
                    .fill(RampStage.dawnPeach)
                    .frame(width: 108, height: 108)
                Circle()
                    .strokeBorder(RampStage.glow, lineWidth: 1)
                    .frame(width: 108, height: 108)
                Image(systemName: "lock.fill")
                    .font(.system(size: 38, weight: .regular))
                    .foregroundStyle(RampStage.accentDeep)
            }
            .opacity(shown ? 1 : 0)
            .scaleEffect(shown ? 1 : 0.9)

            Spacer().frame(height: VSpace.xl)

            VStack(spacing: VSpace.md) {
                Text(verbatim: "CREATE YOUR ACCOUNT")
                    .font(VType.micro)
                    .tracking(3)
                    .foregroundStyle(RampStage.accentDeep)
                Text("Register before\nyour first scan.")
                    .font(RampStage.serif(30))
                    .foregroundStyle(RampStage.ink)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                Text("So your readings and your 14-day plan\nare always yours — on any device.")
                    .font(VType.body)
                    .foregroundStyle(RampStage.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, VSpace.xl)
            .opacity(shown ? 1 : 0)
            .offset(y: shown ? 0 : 10)

            Spacer()

            VStack(spacing: VSpace.md) {
                // Apple — black button, white wordmark.
                Button {
                    RampAnalytics.track("onboarding_sign_in", ["provider": "apple_mock"])
                    Haptics.fire(.milestone)
                    onSignedIn(nil)
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "apple.logo")
                            .font(.system(size: 18, weight: .medium))
                        Text("Continue with Apple")
                    }
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, minHeight: 58)
                    .background(Color.black, in: Capsule())
                }
                .buttonStyle(PressableStyle())

                // Google — white button, authentic four-color "G".
                Button {
                    RampAnalytics.track("onboarding_sign_in", ["provider": "google_mock"])
                    Haptics.fire(.milestone)
                    onSignedIn(nil)
                } label: {
                    HStack(spacing: 10) {
                        GoogleGLogo()
                            .frame(width: 20, height: 20)
                        Text("Continue with Google")
                    }
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color(red: 0.23, green: 0.23, blue: 0.24))
                    .frame(maxWidth: .infinity, minHeight: 58)
                    .background(Color.white, in: Capsule())
                    .overlay(Capsule().strokeBorder(RampStage.hairline, lineWidth: 1))
                }
                .buttonStyle(PressableStyle())

                RampGhostButton(title: "Not now") {
                    RampAnalytics.track("onboarding_sign_in", ["provider": "none"])
                    onSkip()
                }
                .padding(.top, VSpace.xs)
            }
            .padding(.horizontal, VSpace.lg)
            .opacity(shown ? 1 : 0)

            Spacer().frame(height: VSpace.xxl)
        }
        .task {
            try? await Task.sleep(for: .milliseconds(150))
            withAnimation(.easeOut(duration: 0.7)) { shown = true }
        }
    }
}

// ============================================================
// MARK: — Google "G" mark (authentic four colors)
// ============================================================

/// The recognizable Google "G" drawn as four arc segments in the brand palette
/// (blue #4285F4, green #34A853, yellow #FBBC05, red #EA4335) plus the blue
/// crossbar. This is a hand-built approximation for the mock button — if real
/// Google Sign-In is wired up, replace it with Google's official asset to stay
/// within their branding guidelines.
struct GoogleGLogo: View {
    private let blue   = Color(red: 0.259, green: 0.522, blue: 0.957) // #4285F4
    private let green  = Color(red: 0.204, green: 0.659, blue: 0.325) // #34A853
    private let yellow = Color(red: 0.984, green: 0.737, blue: 0.020) // #FBBC05
    private let red    = Color(red: 0.918, green: 0.263, blue: 0.208) // #EA4335

    var body: some View {
        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height)
            let lw = side * 0.22
            let center = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
            let radius = (side - lw) / 2

            ZStack {
                // Blue: right side, sweeping down into the crossbar area.
                arc(from: -20, to: 90, radius: radius, lineWidth: lw, center: center)
                    .foregroundStyle(blue)
                // Green: bottom-left.
                arc(from: 90, to: 160, radius: radius, lineWidth: lw, center: center)
                    .foregroundStyle(green)
                // Yellow: left.
                arc(from: 160, to: 230, radius: radius, lineWidth: lw, center: center)
                    .foregroundStyle(yellow)
                // Red: top.
                arc(from: 230, to: 340, radius: radius, lineWidth: lw, center: center)
                    .foregroundStyle(red)
                // The crossbar: blue bar from the center out to the right edge.
                Rectangle()
                    .fill(blue)
                    .frame(width: radius + lw / 2, height: lw)
                    .position(x: center.x + (radius + lw / 2) / 2, y: center.y)
            }
        }
    }

    private func arc(from start: Double, to end: Double, radius: CGFloat,
                     lineWidth: CGFloat, center: CGPoint) -> some View {
        Path { path in
            path.addArc(center: center, radius: radius,
                        startAngle: .degrees(start), endAngle: .degrees(end),
                        clockwise: false)
        }
        .stroke(style: StrokeStyle(lineWidth: lineWidth, lineCap: .butt))
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
                    .fixedSize(horizontal: false, vertical: true)
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
