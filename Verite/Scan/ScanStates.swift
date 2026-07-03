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
                    .fill(enabled ? Theme.textPrimary : Theme.textSecondary.opacity(0.4))
                    .frame(width: 62, height: 62)
            }
            .blueGlow(Theme.primary, radius: enabled ? 20 : 0, opacity: enabled ? 0.5 : 0)
        }
        .disabled(!enabled)
        .accessibilityLabel("scan.capture.button")
    }
}

/// Full-screen countdown before capture ("hold still").
struct CountdownOverlay: View {
    let value: Int

    var body: some View {
        ZStack {
            Theme.bgBase.opacity(0.35).ignoresSafeArea()
            Text(verbatim: "\(value)")
                .font(Typography.number(96, weight: .bold))
                .foregroundStyle(Theme.textPrimary)
                .blueGlow(Theme.accent, radius: 30, opacity: 0.6)
                .transition(.scale.combined(with: .opacity))
                .id(value)
        }
        .allowsHitTesting(false)
    }
}

/// Post-capture confirmation. Honest about what was (and wasn't) computed — the
/// per-attribute analysis arrives with the analysis engine (Milestone 3).
struct ScanCapturedView: View {
    let thumbnail: UIImage?
    let isBaseline: Bool
    let quality: Double
    let onDone: () -> Void

    var body: some View {
        VStack(spacing: 18) {
            Spacer()
            if let thumbnail {
                Image(uiImage: thumbnail)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 150, height: 190)
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(Theme.strokeSubtle, lineWidth: 1))
                    .blueGlow(Theme.accent, radius: 22, opacity: 0.35)
            }
            Image(systemName: "checkmark.seal.fill")
                .font(.title)
                .foregroundStyle(Theme.success)
            Text(isBaseline ? "scan.captured.baseline" : "scan.captured.saved")
                .font(Typography.display(26))
                .foregroundStyle(Theme.textPrimary)
                .multilineTextAlignment(.center)
            GateChip(titleKey: "scan.captured.quality", ok: quality >= 0.75, systemImage: "gauge.medium")
            Text("scan.captured.analysisNote")
                .font(.footnote)
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 36)
            Spacer()
            PrimaryButton(titleKey: "common.done", action: onDone)
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.ultraThinMaterial)
    }
}
