import SwiftUI
import AVFoundation

// ============================================================
// MARK: — Screen 2: Guided Capture
// ============================================================

/// Custom camera with a face-outline oval and a live Vision checklist:
/// face detected, centered, close enough, both eyes open, adequate light.
/// The shutter stays disabled until every condition passes. On capture:
/// freeze frame + .rigid haptic.
struct DermiqCaptureView: View {
    let onCaptured: (UIImage) -> Void
    let onCancel: () -> Void

    @StateObject private var camera = CameraController()
    @State private var permissionDenied = false
    @State private var frozenFrame: UIImage?
    @State private var capturing = false

    private var quality: CaptureQuality { camera.quality }
    private var allPass: Bool { quality.isStandardized && quality.eyesOK }

    var body: some View {
        ZStack {
            DQColor.background.ignoresSafeArea()

            if let frozenFrame {
                Image(uiImage: frozenFrame)
                    .resizable()
                    .scaledToFill()
                    .ignoresSafeArea()
            } else if permissionDenied {
                permissionFallback
            } else {
                CameraPreviewView(session: camera.session)
                    .ignoresSafeArea()
                faceOval
                overlayChrome
            }
        }
        .task { await startCamera() }
        .onDisappear { camera.stop() }
    }

    // MARK: Camera lifecycle

    private func startCamera() async {
        switch CameraPermission.status {
        case .authorized:
            camera.start()
        case .notDetermined:
            if await CameraPermission.request() { camera.start() }
            else { permissionDenied = true }
        default:
            permissionDenied = true
        }
    }

    // MARK: Overlay

    private var faceOval: some View {
        Ellipse()
            .stroke(
                allPass ? DQColor.deltaUp : DQColor.textPrimary.opacity(0.55),
                style: StrokeStyle(lineWidth: 1.5, dash: allPass ? [] : [7, 7])
            )
            .frame(width: 265, height: 360)
            .offset(y: -36)
            .animation(VMotion.crossfade, value: allPass)
    }

    private var overlayChrome: some View {
        VStack(spacing: 0) {
            HStack {
                Button(action: onCancel) {
                    Image(systemName: "xmark")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(DQColor.textPrimary)
                        .frame(width: 38, height: 38)
                        .background(DQColor.surface.opacity(0.7), in: Circle())
                }
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)

            Spacer()

            checklist
                .padding(.horizontal, 24)
                .padding(.bottom, 18)

            shutter
                .padding(.bottom, 30)
        }
    }

    private var checklist: some View {
        VStack(alignment: .leading, spacing: 7) {
            ChecklistRow(label: "Face detected", passed: quality.faceDetected)
            ChecklistRow(label: "Centered", passed: quality.centeredOK)
            ChecklistRow(label: "Distance", passed: quality.distanceOK)
            ChecklistRow(label: "Eyes open", passed: quality.eyesOK)
            ChecklistRow(label: "Lighting", passed: quality.lightingOK)
        }
        .padding(14)
        .background(DQColor.surface.opacity(0.78), in: RoundedRectangle(cornerRadius: DQRadius.card, style: .continuous))
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var shutter: some View {
        Button {
            capture()
        } label: {
            ZStack {
                Circle()
                    .stroke(allPass ? DQColor.accent : DQColor.textSecondary.opacity(0.4), lineWidth: 3)
                    .frame(width: 76, height: 76)
                Circle()
                    .fill(allPass ? AnyShapeStyle(DQColor.accentGradient) : AnyShapeStyle(DQColor.surfaceElevated))
                    .frame(width: 62, height: 62)
            }
            .shadow(color: DQColor.accent.opacity(allPass ? 0.45 : 0), radius: 18)
        }
        .disabled(!allPass || capturing)
        .animation(VMotion.crossfade, value: allPass)
        .accessibilityLabel("Capture")
    }

    private var permissionFallback: some View {
        VStack(spacing: 18) {
            Image(systemName: "camera.badge.ellipsis")
                .font(.system(size: 42, weight: .light))
                .foregroundStyle(DQColor.textSecondary)
            Text("Camera access is required to scan.")
                .font(DQFont.headline)
                .foregroundStyle(DQColor.textPrimary)
            DQPrimaryButton(title: "Open Settings") { CameraPermission.openSettings() }
                .padding(.horizontal, 48)
            Button("Not now", action: onCancel)
                .font(DQFont.body)
                .foregroundStyle(DQColor.textSecondary)
        }
    }

    // MARK: Capture

    private func capture() {
        guard !capturing else { return }
        capturing = true
        Task {
            guard let image = await camera.capture() else {
                capturing = false
                return
            }
            frozenFrame = image           // freeze frame
            Haptics.fire(.capture)        // .rigid
            camera.stop()
            try? await Task.sleep(for: .milliseconds(450))
            onCaptured(image)
        }
    }
}

/// One live checklist condition; ticks as it passes.
private struct ChecklistRow: View {
    let label: String
    let passed: Bool

    var body: some View {
        HStack(spacing: 9) {
            Image(systemName: passed ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(passed ? DQColor.deltaUp : DQColor.textSecondary.opacity(0.6))
                .contentTransition(.symbolEffect(.replace))
            Text(label)
                .font(DQFont.mono(13))
                .foregroundStyle(passed ? DQColor.textPrimary : DQColor.textSecondary)
        }
        .animation(VMotion.snappy, value: passed)
    }
}
