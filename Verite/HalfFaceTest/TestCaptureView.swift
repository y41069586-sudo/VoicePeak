import SwiftUI
import SwiftData
import UIKit

/// Camera capture for one half-face test round. Captures the whole face (both
/// sides at once), analyzes each side, and stores a per-side `Scan`. Reuses the
/// scan components so framing stays standardized across rounds.
struct TestCaptureView: View {
    let test: HalfFaceTest
    let onCaptured: () -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @StateObject private var camera = CameraController()
    @State private var engine = SkinAnalysisEngine()
    @State private var authStatus = CameraPermission.status
    @State private var isCapturing = false
    @State private var countdown: Int?

    var body: some View {
        ZStack {
            switch authStatus {
            case .authorized:
                scanner
            case .notDetermined:
                CameraPrimingView {
                    Task {
                        let granted = await CameraPermission.request()
                        authStatus = CameraPermission.status
                        if granted { camera.start() }
                    }
                }
            default:
                CameraDeniedView()
            }

            VStack {
                HStack {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2).foregroundStyle(.white.opacity(0.85)).padding()
                    }
                    Spacer()
                }
                Spacer()
            }
        }
        .onAppear { if authStatus == .authorized { camera.start() } }
        .onDisappear { camera.stop() }
    }

    private var scanner: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            CameraPreviewView(session: camera.session).ignoresSafeArea()
            AlignmentGuideOverlay(quality: camera.quality)

            VStack {
                Spacer()
                VStack(spacing: 12) {
                    Text("test.capture.instruction")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(Theme.textPrimary)
                        .padding(.horizontal, 14).padding(.vertical, 8)
                        .background(.ultraThinMaterial, in: Capsule())
                    HStack(spacing: 10) {
                        GateChip(titleKey: "scan.gate.distance", ok: camera.quality.distanceOK,
                                 systemImage: "arrow.up.left.and.arrow.down.right")
                        GateChip(titleKey: "scan.gate.lighting", ok: camera.quality.lightingOK,
                                 systemImage: "sun.max")
                    }
                    CaptureShutterButton(enabled: camera.quality.isStandardized && !isCapturing) {
                        startCountdown()
                    }
                }
                .padding(.bottom, 28)
            }

            if let countdown { CountdownOverlay(value: countdown) }
        }
        .animation(Motion.springSnappy, value: countdown)
    }

    private func startCountdown() {
        guard !isCapturing else { return }
        isCapturing = true
        Task { @MainActor in
            for value in [3, 2, 1] {
                countdown = value
                Haptics.fire(.selection)
                try? await Task.sleep(for: .seconds(0.75))
            }
            countdown = nil
            Haptics.fire(.capture)
            if let image = await camera.capture() {
                await saveRound(image)
            }
            isCapturing = false
        }
    }

    private func saveRound(_ image: UIImage) async {
        guard let cgImage = image.normalizedUp().cgImage else { return }
        let sides = await engine.analyzeSides(cgImage: cgImage)
        guard sides.faceFound else {
            Haptics.fire(.riskFlagged)
            return
        }
        let thumbnail = ThumbnailStore.save(image)
        HalfFaceTestManager.recordRound(
            test: test,
            sideAnalysis: sides,
            quality: camera.quality.overall,
            thumbnailFilename: thumbnail,
            in: modelContext
        )
        Haptics.fire(.verdictReveal)
        onCaptured()
        dismiss()
    }
}
