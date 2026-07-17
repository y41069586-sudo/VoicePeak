import SwiftUI
import AVFoundation
import PhotosUI
import Vision

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
    @State private var flash = false
    /// Gallery import: a picked photo goes through a basic face check before
    /// entering the same pipeline as a live capture.
    @State private var pickerItem: PhotosPickerItem?
    @State private var checkingGallery = false
    @State private var galleryRejected = false

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

            // Front-fill flash: a bright white sheet on capture that lights the
            // face like a ring light (helps low-light scans) and reads as a
            // camera "snap".
            Color.white
                .opacity(flash ? 0.92 : 0)
                .ignoresSafeArea()
                .allowsHitTesting(false)
        }
        .task { await startCamera() }
        .onDisappear {
            camera.stop()
            restoreBrightness()
        }
        .alert("That photo won't work", isPresented: $galleryRejected) {
            Button("OK", role: .cancel) { pickerItem = nil }
        } message: {
            Text("Pick a clear, front-facing photo of one face in good light.")
        }
    }

    /// Screen brightness before the front-fill boost — nil until we boost, so
    /// disappearing without a capture never changes the user's brightness.
    @State private var savedBrightness: CGFloat?

    private func restoreBrightness() {
        if let savedBrightness {
            UIScreen.main.brightness = savedBrightness
        }
        savedBrightness = nil
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

            // Shutter centered, gallery-import button bottom-right.
            ZStack {
                shutter
                HStack {
                    Spacer()
                    galleryButton
                }
                .padding(.trailing, 34)
            }
            .padding(.bottom, 30)
        }
    }

    /// Import a photo from the library instead of taking one live. Uses
    /// PhotosPicker (out-of-process, so it needs NO photo-library permission
    /// prompt and no Info.plist key — the user only shares the one photo they
    /// pick).
    private var galleryButton: some View {
        PhotosPicker(selection: $pickerItem, matching: .images) {
            ZStack {
                Circle()
                    .fill(DQColor.surface.opacity(0.7))
                    .frame(width: 52, height: 52)
                if checkingGallery {
                    ProgressView().tint(DQColor.textPrimary)
                } else {
                    Image(systemName: "photo.on.rectangle")
                        .font(.system(size: 19, weight: .semibold))
                        .foregroundStyle(DQColor.textPrimary)
                }
            }
        }
        .disabled(checkingGallery || capturing)
        .accessibilityLabel("Choose from library")
        .onChange(of: pickerItem) { _, item in
            guard let item else { return }
            Task { await importFromGallery(item) }
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

        // Raise the screen to full brightness and flash white so the front
        // "fill light" actually reaches the face before the shutter fires.
        savedBrightness = UIScreen.main.brightness
        UIScreen.main.brightness = 1.0
        withAnimation(.easeIn(duration: 0.12)) { flash = true }
        Haptics.fire(.capture) // .rigid

        Task {
            try? await Task.sleep(for: .milliseconds(200)) // let the fill land
            let image = await camera.capture()
            withAnimation(.easeOut(duration: 0.28)) { flash = false }
            restoreBrightness()

            guard let image else {
                capturing = false
                return
            }
            frozenFrame = image // freeze frame
            camera.stop()
            try? await Task.sleep(for: .milliseconds(350))
            onCaptured(image)
        }
    }

    // MARK: Gallery import

    /// Load the picked photo, check it's actually usable for a scan (one
    /// clear face, big enough), and if so feed it into the same pipeline as a
    /// live capture. Not pixel-perfect — just "is there a face to read?".
    private func importFromGallery(_ item: PhotosPickerItem) async {
        checkingGallery = true
        defer { checkingGallery = false; pickerItem = nil }

        guard let data = try? await item.loadTransferable(type: Data.self),
              let raw = UIImage(data: data) else {
            galleryRejected = true
            return
        }
        let image = raw.uprightForScan()

        // Suitability: enough resolution + exactly one detectable face that
        // fills a reasonable part of the frame (not a tiny background face).
        guard min(image.size.width, image.size.height) >= 400,
              await Self.faceIsScannable(image) else {
            galleryRejected = true
            return
        }

        Haptics.fire(.capture)
        frozenFrame = image
        camera.stop()
        try? await Task.sleep(for: .milliseconds(300))
        onCaptured(image)
    }

    /// One face that occupies at least ~18% of the frame width — enough for a
    /// skin read. Runs Vision off the main actor.
    private static func faceIsScannable(_ image: UIImage) async -> Bool {
        guard let cg = image.cgImage else { return false }
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let request = VNDetectFaceRectanglesRequest()
                let handler = VNImageRequestHandler(cgImage: cg, orientation: .up, options: [:])
                try? handler.perform([request])
                let faces = request.results ?? []
                let biggest = faces.max { $0.boundingBox.width < $1.boundingBox.width }
                let ok = faces.count >= 1 && (biggest?.boundingBox.width ?? 0) >= 0.18
                continuation.resume(returning: ok)
            }
        }
    }
}

private extension UIImage {
    /// Redraw with orientation baked in, so Vision + the analysis engine both
    /// see an upright image regardless of the source photo's EXIF orientation.
    func uprightForScan() -> UIImage {
        guard imageOrientation != .up else { return self }
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = scale
        return UIGraphicsImageRenderer(size: size, format: format).image { _ in
            draw(in: CGRect(origin: .zero, size: size))
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
            Text(LocalizedStringKey(label))
                .font(DQFont.mono(13))
                .foregroundStyle(passed ? DQColor.textPrimary : DQColor.textSecondary)
        }
        .animation(VMotion.snappy, value: passed)
    }
}
