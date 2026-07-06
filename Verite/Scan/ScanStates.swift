import SwiftUI
import UIKit

// Supporting views for the scan flow: permission priming, denial, the shutter
// button, the countdown, and the post-capture confirmation.

/// Premium permission priming screen shown before the system prompt.
struct CameraPrimingView: View {
    let onEnable: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var scale: CGFloat = 0.95
    @State private var opacity: Double = 0.65

    var body: some View {
        ZStack {
            GradientMeshBackground()
                .ignoresSafeArea()

            VStack(spacing: 24) {
                Spacer()

                // Animated glowing camera icon
                ZStack {
                    Circle()
                        .fill(Theme.accent.opacity(0.08))
                        .frame(width: 140, height: 140)
                        .blueGlow(Theme.accent, radius: 24, opacity: 0.3)

                    Circle()
                        .stroke(Theme.accent.opacity(0.25), lineWidth: 1.5)
                        .frame(width: 110, height: 110)
                        .scaleEffect(scale)
                        .opacity(opacity)

                    Image(systemName: "camera.viewfinder")
                        .font(.system(size: 56, weight: .light))
                        .foregroundStyle(Theme.primary)
                }

                VStack(spacing: 12) {
                    Text("scan.permission.title")
                        .font(VType.heroTitle)
                        .foregroundStyle(VColor.textPrimary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)

                    Text("scan.permission.body")
                        .font(VType.bodyLarge)
                        .foregroundStyle(VColor.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }

                // Privacy lock card instead of basic disclaimer
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "lock.shield.fill")
                        .foregroundStyle(Theme.success)
                        .font(.title3)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("On-Device Processing Only")
                            .font(VType.bodyMedium.weight(.semibold))
                            .foregroundStyle(VColor.textPrimary)
                        Text("All biometric mapping and skin analysis occurs locally. Your photos and analysis metrics never leave your device.")
                            .font(VType.caption)
                            .foregroundStyle(VColor.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(16)
                .background(VColor.bgSurface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(VColor.strokeSubtle, lineWidth: 1)
                )
                .padding(.horizontal, 24)

                Spacer()

                VStack(spacing: 12) {
                    PrimaryButton(titleKey: "scan.permission.enable", systemImage: "camera.fill", action: onEnable)
                        .padding(.horizontal, 24)

                    Text("Your face never leaves your device")
                        .font(VType.micro)
                        .vEyebrow()
                        .foregroundStyle(VColor.textTertiary)
                }
                .padding(.bottom, 24)
            }
        }
        .onAppear {
            if !reduceMotion {
                withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true)) {
                    scale = 1.12
                    opacity = 0.9
                }
            }
        }
    }
}

/// Shown when camera access is denied.
struct CameraDeniedView: View {
    var body: some View {
        ZStack {
            GradientMeshBackground()
                .ignoresSafeArea()

            VStack(spacing: 24) {
                Spacer()

                Image(systemName: "camera.metering.none")
                    .font(.system(size: 56, weight: .light))
                    .foregroundStyle(Theme.warning)

                VStack(spacing: 12) {
                    Text("scan.denied.title")
                        .font(VType.heroTitle)
                        .foregroundStyle(VColor.textPrimary)
                        .multilineTextAlignment(.center)

                    Text("scan.denied.body")
                        .font(VType.bodyLarge)
                        .foregroundStyle(VColor.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }

                Spacer()

                PrimaryButton(titleKey: "scan.denied.openSettings", systemImage: "gearshape.fill") {
                    CameraPermission.openSettings()
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            }
        }
    }
}

/// The shutter. Enabled only when framing is standardized.
struct CaptureShutterButton: View {
    let enabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .strokeBorder(enabled ? AnyShapeStyle(Theme.signature) : AnyShapeStyle(VColor.strokeSubtle), lineWidth: 4.5)
                    .frame(width: 82, height: 82)
                Circle()
                    .fill(enabled ? Color.white : Color.white.opacity(0.35))
                    .frame(width: 66, height: 66)
            }
            .blueGlow(Theme.primary, radius: enabled ? 22 : 0, opacity: enabled ? 0.45 : 0)
            .opacity(enabled ? 1.0 : 0.6)
        }
        .disabled(!enabled)
        .accessibilityLabel("scan.capture.button")
    }
}

/// Full-screen countdown before capture ("hold still").
struct CountdownOverlay: View {
    let value: Int
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            Color.black.opacity(0.38).ignoresSafeArea()
            Text(verbatim: "\(value)")
                .font(Typography.number(110, weight: .bold))
                .foregroundStyle(.white)
                .blueGlow(Theme.accent, radius: 36, opacity: 0.65)
                .transition(reduceMotion ? .opacity : .scale.combined(with: .opacity))
                .id(value)
        }
        .allowsHitTesting(false)
    }
}
