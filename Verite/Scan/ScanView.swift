import SwiftUI
import SwiftData
import UIKit

/// The guided face scan. Handles permission priming/denial, live
/// camera with the AR alignment guide, a hold-still countdown, standardized
/// capture, and local thumbnail + Scan persistence.
struct ScanView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AppState.self) private var appState
    @Query private var scans: [Scan]
    @Query private var streaks: [Streak]

    @StateObject private var camera = CameraController()
    @State private var engine = SkinAnalysisEngine()
    @State private var monitor = RealtimeSkinMonitor()

    @State private var authStatus = CameraPermission.status
    @State private var phase: ScanPhase = .priming
    @State private var countdown: Int?
    @State private var flash = false
    @State private var captured: CapturedScan?

    enum ScanPhase {
        case priming
        case aligning
        case capturing
        case analyzing
        case results
    }

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
                if authStatus == .denied || authStatus == .restricted {
                    CameraDeniedView()
                } else if authStatus == .notDetermined {
                    CameraPrimingView { Task { await requestAccess() } }
                } else {
                    switch phase {
                    case .priming:
                        CameraPrimingView { Task { await requestAccess() } }
                    case .aligning, .capturing, .analyzing, .results:
                        liveScanner
                    }
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
                phase = .aligning
                if faceFound { appState.selectedTab = .home }
            }
        }
        .onAppear { updatePhase() }
    }

    // MARK: - Live scanner

    private var liveScanner: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            if UIDevice.current.userInterfaceIdiom == .pad {
                CameraPreviewView(session: camera.session)
                    .scaledToFit()
                    .ignoresSafeArea()
            } else {
                CameraPreviewView(session: camera.session)
                    .ignoresSafeArea()
            }
            
            if camera.quality.faceDetected && monitor.isReady {
                let liveMap = [
                    FaceRegion.forehead: monitor.liveAttributes[.hydration] ?? 0.0,
                    FaceRegion.leftCheek: monitor.liveAttributes[.redness] ?? 0.0,
                    FaceRegion.rightCheek: monitor.liveAttributes[.redness] ?? 0.0,
                    FaceRegion.nose: monitor.liveAttributes[.oiliness] ?? 0.0,
                    FaceRegion.chin: monitor.liveAttributes[.hydration] ?? 0.0
                ]
                
                GeometryReader { geo in
                    let ovalWidth = geo.size.width * 0.70
                    let ovalHeight = geo.size.height * 0.46
                    
                    RegionHeatmapOverlay(regionValues: liveMap, colorScheme: .concern, opacity: 0.35)
                        .frame(width: ovalWidth, height: ovalHeight)
                        .position(x: geo.size.width / 2, y: geo.size.height * 0.44)
                }
                .allowsHitTesting(false)
            }
            
            AlignmentGuideOverlay(quality: camera.quality)

            VStack {
                Spacer()
                controls
            }

            if phase == .capturing, let countdown {
                CountdownOverlay(value: countdown)
            }

            if phase == .analyzing {
                ScanningPhaseOverlay()
                    .transition(.opacity)
            }

            if flash {
                Color.white.ignoresSafeArea()
                    .transition(.opacity)
            }
        }
        .animation(Motion.springSnappy, value: countdown)
        .animation(Motion.springSnappy, value: phase)
        .animation(.easeOut(duration: 0.18), value: flash)
        .onAppear {
            camera.onFrame = { monitor.didReceiveSampleBuffer($0) }
            startIfAuthorized()
        }
        .onDisappear {
            camera.onFrame = nil
            camera.stop()
        }
    }

    private var controls: some View {
        VStack(spacing: 14) {
            if isFirstBaseline {
                HStack(spacing: 6) {
                    Image(systemName: "1.circle.fill")
                    Text("scan.baseline.hint")
                }
                .font(VType.captionBold)
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

            CaptureShutterButton(enabled: camera.quality.isStandardized && phase == .aligning) {
                startCountdown()
            }
        }
        .padding(.bottom, 28)
    }

    // MARK: - Actions

    private func updatePhase() {
        let status = CameraPermission.status
        authStatus = status
        if status == .authorized {
            if phase == .priming || phase == .results {
                phase = .aligning
            }
        } else if status == .notDetermined {
            phase = .priming
        }
    }

    private func startIfAuthorized() {
        authStatus = CameraPermission.status
        if authStatus == .authorized {
            camera.start()
            phase = .aligning
        }
    }

    private func requestAccess() async {
        let granted = await CameraPermission.request()
        authStatus = CameraPermission.status
        if granted {
            camera.start()
            phase = .aligning
        }
    }

    private func startCountdown() {
        guard phase == .aligning else { return }
        phase = .capturing
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
            } else {
                phase = .aligning
            }
        }
    }

    private func saveScan(_ image: UIImage) async {
        let quality = camera.quality.overall
        let baseline = isFirstBaseline

        // Transition to cinematic scanning overlay phase
        phase = .analyzing
        
        let startTime = Date()
        let analysis: ScanAnalysis
        if let cgImage = image.normalizedUp().cgImage {
            analysis = await engine.analyze(cgImage: cgImage, captureQuality: quality)
        } else {
            analysis = .empty
        }

        // To guarantee the user experiences the entire premium cinematic scan visual,
        // we enforce a minimum duration of 4.8 seconds for the overlay cycle.
        let elapsed = Date().timeIntervalSince(startTime)
        let remaining = 4.8 - elapsed
        if remaining > 0 {
            try? await Task.sleep(for: .seconds(remaining))
        }

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

        phase = .results
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
