import SwiftUI
import SwiftData
import UIKit

/// Onboarding baseline scan: the "before" the whole app pays off against. Guides
/// a standardized capture, stores the Day-0 baseline `Scan`, and reveals the
/// starting estimates. Skippable (a scan can always be taken later).
struct OnboardingBaselineView: View {
    let onDone: () -> Void

    @Environment(\.modelContext) private var modelContext
    @StateObject private var camera = CameraController()
    @State private var engine = SkinAnalysisEngine()
    @State private var authStatus = CameraPermission.status
    @State private var isCapturing = false
    @State private var countdown: Int?
    @State private var capturedImage: UIImage?
    @State private var reveal: ScanAnalysis?

    var body: some View {
        Group {
            if let reveal {
                revealView(reveal)
            } else {
                switch authStatus {
                case .authorized: scanner
                case .notDetermined: priming
                default: denied
                }
            }
        }
        .onDisappear { camera.stop() }
    }

    // MARK: Priming / denied

    private var priming: some View {
        CameraPrimingView {
            Task {
                let granted = await CameraPermission.request()
                authStatus = CameraPermission.status
                if granted { camera.start() }
            }
        }
        .overlay(alignment: .topTrailing) { skipButton }
    }

    private var denied: some View {
        VStack {
            CameraDeniedView()
            SecondaryButton(titleKey: "onboarding.baseline.skip", action: onDone)
                .padding(.horizontal, 24).padding(.bottom, 20)
        }
    }

    private var skipButton: some View {
        Button("onboarding.skip", action: onDone)
            .font(.subheadline)
            .foregroundStyle(Theme.textSecondary)
            .padding()
    }

    // MARK: Scanner

    private var scanner: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            CameraPreviewView(session: camera.session).ignoresSafeArea()
            AlignmentGuideOverlay(quality: camera.quality)

            VStack {
                HStack { Spacer(); skipButton.foregroundStyle(.white.opacity(0.85)) }
                Spacer()
                VStack(spacing: 12) {
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
        .onAppear { camera.start() }
    }

    // MARK: Reveal

    private func revealView(_ analysis: ScanAnalysis) -> some View {
        ZStack {
            GradientMeshBackground()
            VStack(spacing: 0) {
                ScrollView {
                    VStack(spacing: 16) {
                        if let capturedImage {
                            Image(uiImage: capturedImage)
                                .resizable().scaledToFill()
                                .frame(width: 130, height: 165)
                                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                                .blueGlow(Theme.accent, radius: 20, opacity: 0.3)
                                .padding(.top, 16)
                        }
                        Text("onboarding.baseline.reveal.title")
                            .font(Typography.display(28))
                            .foregroundStyle(Theme.textPrimary)
                            .multilineTextAlignment(.center)
                        GlassCard {
                            VStack(alignment: .leading, spacing: 12) {
                                ForEach(SkinAttribute.allCases) { attribute in
                                    ScoreBar(labelKey: attribute.localizationKey,
                                             value: analysis.attributes[attribute] ?? 0, tone: .info)
                                }
                                Text("result.estimatesNote")
                                    .font(.caption2).foregroundStyle(Theme.textSecondary)
                            }
                        }
                        DisclaimerBanner(style: .short)
                    }
                    .padding(24)
                }
                .scrollIndicators(.hidden)
                PrimaryButton(titleKey: "onboarding.continue", action: onDone)
                    .padding(.horizontal, 24).padding(.bottom, 20)
            }
        }
    }

    // MARK: Capture

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
            if let image = await camera.capture() { await saveBaseline(image) }
            isCapturing = false
        }
    }

    private func saveBaseline(_ image: UIImage) async {
        guard let cgImage = image.normalizedUp().cgImage else { return }
        let analysis = await engine.analyze(cgImage: cgImage, captureQuality: camera.quality.overall)
        guard analysis.faceFound else {
            Haptics.fire(.riskFlagged)
            return
        }
        let filename = ThumbnailStore.save(image)
        let scan = Scan(
            captureQuality: camera.quality.overall,
            attributeScores: analysis.attributeScores,
            isBaseline: true,
            side: .full,
            thumbnailFilename: filename
        )
        modelContext.insert(scan)
        try? modelContext.save()
        camera.stop()
        capturedImage = image
        Haptics.fire(.verdictReveal)
        withAnimation(Motion.springSoft) { reveal = analysis }
    }
}
