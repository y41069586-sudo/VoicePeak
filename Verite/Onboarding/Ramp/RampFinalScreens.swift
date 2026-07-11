import SwiftUI

// ============================================================
// MARK: — Screen 9: The Curve (where do you land?)
// ============================================================

/// Social comparison without a single fabricated testimonial (App Review
/// 2.3.1-safe): a population curve that draws itself live, then lights up the
/// user's own predicted band — with a "?" that keeps drifting inside it and
/// never settles, because only a scan can place it. Haptic ticks ride the
/// draw; a milestone pulse lands with the band.
///
/// NOTE: deliberately NO review prompt here — Apple 5.6.3 forbids rating asks
/// during onboarding. The ask lives post-scan (results, 3rd+ completed scan).
struct RampCurveScreen: View {
    let answers: RampQuizAnswers
    let onAdvance: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var bandShown = false

    private var range: (low: Int, high: Int) { answers.predictedRange }

    private var headline: String {
        if let name = answers.displayName { return "Where do you\nland, \(name)?" }
        return "Where do\nyou land?"
    }

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: VSpace.md) {
                Text(headline)
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

            RampDistributionCurve(range: range, startDelay: Self.drawStartDelay)
                .padding(.horizontal, VSpace.lg)
                .padding(.top, VSpace.lg)
                .vStaggeredAppear(index: 2)

            // The estimate echoed under its own band — lands with the pulse.
            Text(verbatim: "Your estimated range: \(range.low) – \(range.high)")
                .font(VType.caption)
                .foregroundStyle(RampStage.accentDeep)
                .padding(.top, VSpace.sm)
                .opacity(bandShown ? 1 : 0)
                .offset(y: bandShown ? 0 : 6)

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
        .task { await choreograph() }
    }

    /// The draw waits for the screen's own entrance (spring + stagger) so the
    /// user actually sees the line grow instead of it finishing invisibly.
    static let drawStartDelay: Double = 0.65

    /// Haptic ticks riding the curve draw, then a milestone pulse as the
    /// user's band lights up (timed to RampDistributionCurve's constants).
    private func choreograph() async {
        if reduceMotion {
            bandShown = true
            return
        }
        try? await Task.sleep(for: .milliseconds(Int(Self.drawStartDelay * 1000)))
        guard !Task.isCancelled else { return }
        let drawMs = Int(RampDistributionCurve.drawDuration * 1000)
        for quarter in 1...3 {
            try? await Task.sleep(for: .milliseconds(drawMs / 4))
            guard !Task.isCancelled else { return }
            Haptics.fire(.tick)
        }
        try? await Task.sleep(for: .milliseconds(
            drawMs / 4 + Int(RampDistributionCurve.bandDelay * 1000)))
        guard !Task.isCancelled else { return }
        Haptics.fire(.milestone)
        withAnimation(VMotion.gentle) { bandShown = true }
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
            Text(LocalizedStringKey(text))
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
                Text("A plan only works on the days you do it. When should yours check in?")
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

            // What you'll actually receive — an honest preview of the nudge,
            // rendered as a system-style banner. Updates with the choice.
            notificationPreview
                .padding(.horizontal, VSpace.lg)
                .padding(.top, VSpace.md)
                .vStaggeredAppear(index: 2)

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

    /// A faux notification banner — exactly what the chosen reminder will say.
    private var notificationPreview: some View {
        HStack(spacing: 10) {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(RampStage.accent)
                .frame(width: 34, height: 34)
                .overlay(
                    Text(verbatim: "V")
                        .font(.system(size: 17, weight: .heavy, design: .serif))
                        .foregroundStyle(.white)
                )
            VStack(alignment: .leading, spacing: 1) {
                HStack {
                    Text(verbatim: "VÉRITÉ")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(RampStage.ink)
                    Spacer()
                    Text(verbatim: time == .morning ? "8:00" : "21:00")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(RampStage.textTertiary)
                }
                Text(time == .morning
                     ? "Morning ritual — 3 steps, 4 minutes."
                     : "Evening ritual — 3 steps before bed.")
                    .font(.system(size: 12.5, weight: .medium, design: .rounded))
                    .foregroundStyle(RampStage.textSecondary)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color.white.opacity(0.9), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(RampStage.hairline, lineWidth: 1)
        )
        .shadow(color: RampStage.ink.opacity(0.06), radius: 10, y: 5)
        .animation(VMotion.gentle, value: time)
        .accessibilityLabel("Preview of your daily reminder")
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
                Text(LocalizedStringKey(option.label))
                    .font(VType.bodyMedium)
                    .foregroundStyle(selected ? RampStage.accentDeep : RampStage.ink)
                Text(LocalizedStringKey(option.sub))
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
/// is built from the scan. The user's own quiz answers surface INSIDE the
/// card (their concern names the evening active; SPF answer shapes the AM
/// line) so the preview reads as "already mine", not a template.
struct RampPlanPreviewScreen: View {
    let answers: RampQuizAnswers
    let onAdvance: () -> Void

    /// "Targeted active" becomes THEIR concern's active line.
    private var eveningSteps: String {
        switch answers.concern {
        case .breakouts?: return "Cleanse · Blemish active (BHA) · Moisturizer"
        case .redness?:   return "Cleanse · Calming active (azelaic) · Moisturizer"
        case .pores?:     return "Cleanse · Pore active (niacinamide) · Moisturizer"
        case .texture?:   return "Cleanse · Texture active (retinal) · Moisturizer"
        case .dullness?:  return "Cleanse · Glow active (vitamin C) · Moisturizer"
        case .nothing?, nil:
            return "Cleanse · Targeted active · Moisturizer"
        }
    }

    /// The AM line acknowledges their SPF answer.
    private var morningSteps: String {
        answers.spf == .daily
            ? "Gentle cleanse · Hydrating serum · Your SPF, kept"
            : "Gentle cleanse · Hydrating serum · SPF 30+ (new)"
    }

    private var focusChip: String? {
        answers.concern?.chip
    }

    var body: some View {
        VStack(spacing: 0) {
            Spacer().frame(height: VSpace.xxl * 1.6)

            VStack(spacing: VSpace.sm) {
                Text("AFTER YOUR SCAN")
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

            // Day-1 sample card, seeded with their own answers.
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("DAY 1 · PREVIEW")
                        .font(VType.micro).tracking(3)
                        .foregroundStyle(RampStage.accentDeep)
                    Spacer()
                    if let focusChip {
                        Text(verbatim: "FOR: \(focusChip.uppercased())")
                            .font(VType.micro).tracking(2)
                            .foregroundStyle(RampStage.accentDeep)
                            .padding(.horizontal, 8).padding(.vertical, 3)
                            .background(RampStage.accentSoft, in: Capsule())
                    } else {
                        Text("ILLUSTRATIVE")
                            .font(VType.micro).tracking(2)
                            .foregroundStyle(RampStage.textTertiary)
                    }
                }
                previewRow(icon: "sun.max.fill", title: "Morning", steps: morningSteps)
                previewRow(icon: "moon.stars.fill", title: "Evening", steps: eveningSteps)
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
// MARK: — Screen: The commitment (sign your 14 days)
// ============================================================

/// The strongest retention mechanic in consumer onboarding: a literal
/// signature. The user signs their 14 days with a finger — a contract with
/// themselves, not with us. Honesty guarantees: the drawing never leaves this
/// screen (only a signed yes/no goes to analytics), and the step is skippable.
struct RampCommitmentScreen: View {
    let name: String?
    let onAdvance: () -> Void

    @State private var strokes: [[CGPoint]] = []
    @State private var sealed = false

    private var signed: Bool {
        strokes.reduce(0) { $0 + $1.count } >= 12
    }

    private var headline: String {
        if let name { return "Make it official,\n\(name)." }
        return "Make it\nofficial."
    }

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: VSpace.md) {
                Text("YOUR 14-DAY COMMITMENT")
                    .font(VType.micro)
                    .tracking(3)
                    .foregroundStyle(RampStage.accentDeep)
                Text(headline)
                    .font(RampStage.serif(28))
                    .foregroundStyle(RampStage.ink)
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
                Text("14 days, morning and evening.\nSign it — for yourself, not for us.")
                    .font(VType.bodyLarge)
                    .foregroundStyle(RampStage.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, VSpace.xl)
            .vStaggeredAppear(index: 0)

            Spacer().frame(height: VSpace.xl)

            signaturePad
                .padding(.horizontal, VSpace.lg)
                .vStaggeredAppear(index: 1)

            Text("Your signature stays on this screen — never stored, never uploaded.")
                .font(VType.micro)
                .foregroundStyle(RampStage.textTertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, VSpace.xl)
                .padding(.top, VSpace.sm)
                .vStaggeredAppear(index: 2)

            Spacer()

            VStack(spacing: VSpace.sm) {
                RampPrimaryButton(title: "I'm in for 14 days", isEnabled: signed && !sealed) {
                    guard !sealed else { return }
                    sealed = true
                    Haptics.fire(.verdictReveal)
                    RampAnalytics.track("onboarding_commitment", ["signed": "true"])
                    onAdvance()
                }
                RampGhostButton(title: "Not now") {
                    RampAnalytics.track("onboarding_commitment", ["signed": "false"])
                    onAdvance()
                }
            }
            .padding(.horizontal, VSpace.lg)
            Spacer().frame(height: VSpace.xxl)
        }
        .animation(VMotion.gentle, value: signed)
    }

    // MARK: The pad

    private var signaturePad: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color.white.opacity(0.8))
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(signed ? RampStage.accent : RampStage.hairline,
                              lineWidth: signed ? 1.5 : 1)

            // Baseline + hint, fading once ink lands.
            VStack {
                Spacer()
                Rectangle()
                    .fill(RampStage.hair.opacity(0.8))
                    .frame(height: 1)
                    .padding(.horizontal, 28)
                Text(strokes.isEmpty ? "Sign with your finger" : " ")
                    .font(RampStage.serif(15))
                    .foregroundStyle(RampStage.textTertiary)
                    .padding(.top, 8)
                    .padding(.bottom, 18)
            }
            .opacity(strokes.isEmpty ? 1 : 0.4)

            SignatureCanvas(strokes: $strokes)

            // Clear, once there is something to clear.
            if !strokes.isEmpty {
                VStack {
                    HStack {
                        Spacer()
                        Button {
                            Haptics.fire(.selection)
                            strokes.removeAll()
                        } label: {
                            Image(systemName: "arrow.counterclockwise")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(RampStage.textSecondary)
                                .frame(width: 32, height: 32)
                                .background(RampStage.card, in: Circle())
                                .overlay(Circle().strokeBorder(RampStage.hairline, lineWidth: 1))
                        }
                        .accessibilityLabel("Clear signature")
                        .padding(10)
                    }
                    Spacer()
                }
                .transition(.opacity)
            }
        }
        .frame(height: 190)
        .shadow(color: RampStage.accent.opacity(signed ? 0.18 : 0.08), radius: 18, y: 8)
        .animation(VMotion.gentle, value: strokes.isEmpty)
    }
}

/// Finger-ink capture: strokes render live in a Canvas; nothing is persisted.
private struct SignatureCanvas: View {
    @Binding var strokes: [[CGPoint]]
    @State private var current: [CGPoint] = []

    var body: some View {
        Canvas { context, _ in
            for stroke in strokes + (current.isEmpty ? [] : [current]) {
                guard let first = stroke.first else { continue }
                var path = Path()
                path.move(to: first)
                for point in stroke.dropFirst() {
                    path.addLine(to: point)
                }
                context.stroke(path, with: .color(RampStage.ink),
                               style: StrokeStyle(lineWidth: 2.4, lineCap: .round, lineJoin: .round))
            }
        }
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    if current.isEmpty { Haptics.fire(.tick) }
                    current.append(value.location)
                }
                .onEnded { _ in
                    if !current.isEmpty {
                        strokes.append(current)
                        current = []
                    }
                }
        )
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
                Text("CREATE YOUR ACCOUNT")
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
                Text("READY WHEN YOU ARE")
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
