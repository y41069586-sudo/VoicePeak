import SwiftUI
import SwiftData
import UIKit

/// Milestone 2 — the guided face scan. Handles permission priming/denial, live
/// camera with the AR alignment guide, a hold-still countdown, standardized
/// capture, and local (on-device) thumbnail + `Scan` persistence. Per-attribute
/// analysis is layered on in Milestone 3.
struct ScanView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AppState.self) private var appState
    @Query private var scans: [Scan]
    @Query private var streaks: [Streak]

    @StateObject private var camera = CameraController()
    @State private var engine = SkinAnalysisEngine()

    @State private var authStatus = CameraPermission.status
    @State private var isCapturing = false
    @State private var countdown: Int?
    @State private var flash = false
    @State private var analyzing = false
    @State private var captured: CapturedScan?

    struct CapturedScan: Identifiable {
        let id = UUID()
        let image: UIImage
        let isBaseline: Bool
        let quality: Double
        let analysis: ScanAnalysis
    }

    private var isFirstBaseline: Bool { !scans.contains { $0.isBaseline } }

    var body: some View {
        NavigationStack {
            Group {
                switch authStatus {
                case .authorized:
                    liveScanner
                case .notDetermined:
                    CameraPrimingView { Task { await requestAccess() } }
                default:
                    CameraDeniedView()
                }
            }
            .navigationTitle("tab.scan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
        }
        .fullScreenCover(item: $captured) { cap in
            ScanResultView(image: cap.image,
                           analysis: cap.analysis,
                           isBaseline: cap.isBaseline,
                           captureQuality: cap.quality,
                           scans: scans) {
                let faceFound = cap.analysis.faceFound
                captured = nil
                if faceFound { appState.selectedTab = .home }
            }
        }
    }

    // MARK: Live scanner

    private var liveScanner: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            CameraPreviewView(session: camera.session).ignoresSafeArea()
            AlignmentGuideOverlay(quality: camera.quality)

            VStack {
                Spacer()
                controls
            }

            if let countdown {
                CountdownOverlay(value: countdown)
            }
            if analyzing {
                ScanAnalyzingOverlay()
                    .transition(.opacity)
            }
            if flash {
                Color.white.ignoresSafeArea()
                    .transition(.opacity)
            }
        }
        .animation(Motion.springSnappy, value: countdown)
        .animation(Motion.springSnappy, value: analyzing)
        .animation(.easeOut(duration: 0.18), value: flash)
        .onAppear { startIfAuthorized() }
        .onDisappear { camera.stop() }
    }

    private var controls: some View {
        VStack(spacing: 14) {
            if isFirstBaseline {
                HStack(spacing: 6) {
                    Image(systemName: "1.circle.fill")
                    Text("scan.baseline.hint")
                }
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Theme.textPrimary)
                .padding(.horizontal, 14).padding(.vertical, 8)
                .background(.ultraThinMaterial, in: Capsule())
            }

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

    // MARK: Actions

    private func startIfAuthorized() {
        authStatus = CameraPermission.status
        if authStatus == .authorized { camera.start() }
    }

    private func requestAccess() async {
        let granted = await CameraPermission.request()
        authStatus = CameraPermission.status
        if granted { camera.start() }
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
            // Shutter flash over the frozen frame.
            flash = true
            try? await Task.sleep(for: .seconds(0.09))
            flash = false
            if let image = await camera.capture() {
                await saveScan(image)
            }
            isCapturing = false
        }
    }

    private func saveScan(_ image: UIImage) async {
        let quality = camera.quality.overall
        let baseline = isFirstBaseline

        // Analyze the capture on a background task (Vision + CV metrics), showing
        // an honest "analyzing" beat over the frozen frame while it runs.
        analyzing = true
        let analysis: ScanAnalysis
        if let cgImage = image.normalizedUp().cgImage {
            analysis = await engine.analyze(cgImage: cgImage, captureQuality: quality)
        } else {
            analysis = .empty
        }
        analyzing = false

        // Only persist a scan when a face was actually read.
        if analysis.faceFound {
            let filename = ThumbnailStore.save(image)
            let scan = Scan(
                captureQuality: quality,
                attributeScores: analysis.attributeScores,
                isBaseline: baseline,
                side: .full,
                thumbnailFilename: filename
            )
            modelContext.insert(scan)
            updateStreak()
            try? modelContext.save()
            Haptics.fire(.verdictReveal)
        } else {
            Haptics.fire(.riskFlagged)
        }

        captured = CapturedScan(image: image, isBaseline: baseline, quality: quality, analysis: analysis)
    }

    private func updateStreak() {
        let streak: Streak
        if let existing = streaks.first {
            streak = existing
        } else {
            streak = Streak()
            modelContext.insert(streak)
        }

        let calendar = Calendar.current
        if let last = streak.lastScanDate {
            if !calendar.isDate(last, inSameDayAs: .now) {
                let days = calendar.dateComponents([.day],
                                                   from: calendar.startOfDay(for: last),
                                                   to: calendar.startOfDay(for: .now)).day ?? 0
                streak.current = (days == 1) ? streak.current + 1 : 1
            }
        } else {
            streak.current = 1
        }
        streak.longest = max(streak.longest, streak.current)
        streak.lastScanDate = .now
    }
}
