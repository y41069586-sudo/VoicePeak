import SwiftUI
import UIKit

// Supporting views for the scan flow: permission priming, denial, the shutter
// button, the countdown, and the post-capture confirmation. All localized.

/// Honest permission priming shown *before* the system prompt (never dark-pattern).
struct CameraPrimingView: View {
    let onEnable: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "camera.viewfinder")
                .font(.system(size: 52, weight: .light))
                .foregroundStyle(Theme.accent)
                .blueGlow()
            Text("scan.permission.title")
                .font(Typography.display(28))
                .foregroundStyle(Theme.textPrimary)
                .multilineTextAlignment(.center)
            Text("scan.permission.body")
                .font(.subheadline)
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Spacer()
            PrimaryButton(titleKey: "scan.permission.enable", systemImage: "camera.fill", action: onEnable)
                .padding(.horizontal, 24)
            DisclaimerBanner(style: .short)
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// Shown when camera access is denied/restricted — never a dead-end, always a way out.
struct CameraDeniedView: View {
    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "camera.metering.none")
                .font(.system(size: 52, weight: .light))
                .foregroundStyle(Theme.warning)
            Text("scan.denied.title")
                .font(Typography.display(28))
                .foregroundStyle(Theme.textPrimary)
                .multilineTextAlignment(.center)
            Text("scan.denied.body")
                .font(.subheadline)
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Spacer()
            PrimaryButton(titleKey: "scan.denied.openSettings", systemImage: "gearshape.fill") {
                CameraPermission.openSettings()
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// The shutter. Enabled only when framing is standardized — you can't take a
/// non-comparable scan.
struct CaptureShutterButton: View {
    let enabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .strokeBorder(enabled ? AnyShapeStyle(Theme.signature) : AnyShapeStyle(Theme.strokeSubtle), lineWidth: 4)
                    .frame(width: 78, height: 78)
                Circle()
                    .fill(enabled ? Color.white : Color.white.opacity(0.4)) // shutter dot, over camera
                    .frame(width: 62, height: 62)
            }
            .blueGlow(Theme.primary, radius: enabled ? 20 : 0, opacity: enabled ? 0.5 : 0)
        }
        .disabled(!enabled)
        .accessibilityLabel("scan.capture.button")
    }
}

/// Shown while the on-device engine reads the capture — a short, honest
/// "analyzing your skin" beat before the result. Never fakes speed; it simply
/// covers the real Vision + CV pass so the transition isn't an abrupt cut.
struct ScanAnalyzingOverlay: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var sweep = false

    var body: some View {
        ZStack {
            Color.black.opacity(0.55).ignoresSafeArea()
            VStack(spacing: 18) {
                ZStack {
                    Circle()
                        .stroke(Color.white.opacity(0.2), lineWidth: 4)
                        .frame(width: 88, height: 88)
                    Circle()
                        .trim(from: 0, to: 0.28)
                        .stroke(Theme.signature, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                        .frame(width: 88, height: 88)
                        .rotationEffect(.degrees(sweep ? 360 : 0))
                }
                Text("scan.analyzing")
                    .font(Typography.display(24))
                    .foregroundStyle(.white) // over the darkened camera
                    .multilineTextAlignment(.center)
                Text("scan.analyzing.sub")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.75))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
        }
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.linear(duration: 1.0).repeatForever(autoreverses: false)) { sweep = true }
        }
        .allowsHitTesting(false)
    }
}

/// Full-screen countdown before capture ("hold still").
struct CountdownOverlay: View {
    let value: Int
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            Color.black.opacity(0.35).ignoresSafeArea()
            Text(verbatim: "\(value)")
                .font(Typography.number(96, weight: .bold))
                .foregroundStyle(.white) // over the darkened camera
                .blueGlow(Theme.accent, radius: 30, opacity: 0.6)
                .transition(reduceMotion ? .opacity : .scale.combined(with: .opacity))
                .id(value)
        }
        .allowsHitTesting(false)
    }
}
