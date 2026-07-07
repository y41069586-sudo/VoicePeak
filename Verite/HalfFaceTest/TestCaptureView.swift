import SwiftUI
import SwiftData
import UIKit

/// Camera capture for one half-face test round. Captures the whole face (both
/// sides at once), analyzes each side, stores a per-side `Scan`, then shows
/// the `HalfFaceResultView` split-face comparison screen.
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

    // Set after a successful capture to trigger the result sheet.
    private struct CaptureResult: Identifiable {
        let id = UUID()
        let image: UIImage
        let analysis: SideAnalysis
    }
    @State private var result: CaptureResult?

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
        // ── Split-face result pops up after capture ──
        .fullScreenCover(item: $result) { cap in
            HalfFaceResultView(
                image: cap.image,
                testSide: test.testSide,
                sideAnalysis: cap.analysis
            ) {
                onCaptured()
                dismiss()
            }
        }
    }

    private var scanner: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            GeometryReader { geo in
                let isPad = UIDevice.current.userInterfaceIdiom == .pad
                let previewWidth  = isPad ? min(geo.size.width, geo.size.height * 9 / 16) : geo.size.width
                let previewHeight = isPad ? min(geo.size.height, geo.size.width * 16 / 9) : geo.size.height
                CameraPreviewView(session: camera.session)
                    .frame(width: previewWidth, height: previewHeight)
                    .position(x: geo.size.width / 2, y: geo.size.height / 2)
                    .ignoresSafeArea()
            }
            AlignmentGuideOverlay(quality: camera.quality)

            VStack {
                Spacer()
                VStack(spacing: 12) {
                    Text("Align your full face in the oval")
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
        // Freeze exposure + white balance so both sides are captured under the
        // same conditions — essential for a fair treated-vs-control comparison.
        camera.lockStandardizedSettings()
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
            camera.unlockStandardizedSettings()
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
        // Show the split-face result screen instead of immediately dismissing.
        result = CaptureResult(image: image, analysis: sides)
    }
}
