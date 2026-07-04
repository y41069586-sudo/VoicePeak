import SwiftUI
import AVFoundation

/// Live barcode scanner (back camera) using `AVCaptureMetadataOutput`. Emits the
/// first recognized code, then stops. Reuses the camera-permission flow.
final class BarcodeScannerController: NSObject, ObservableObject, AVCaptureMetadataOutputObjectsDelegate {
    let session = AVCaptureSession()

    private let sessionQueue = DispatchQueue(label: "com.verite.barcode.session")
    private let metadataOutput = AVCaptureMetadataOutput()
    private var isConfigured = false
    private var didFind = false

    var onCode: ((String) -> Void)?

    func start() {
        didFind = false
        sessionQueue.async { [weak self] in
            guard let self else { return }
            if !self.isConfigured { self.configure() }
            guard self.isConfigured, !self.session.isRunning else { return }
            self.session.startRunning()
        }
    }

    func stop() {
        sessionQueue.async { [weak self] in
            guard let self, self.session.isRunning else { return }
            self.session.stopRunning()
        }
    }

    private func configure() {
        session.beginConfiguration()
        let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back)
            ?? AVCaptureDevice.default(for: .video)
        guard let device,
              let input = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input) else {
            session.commitConfiguration()
            return
        }
        session.addInput(input)

        if session.canAddOutput(metadataOutput) {
            session.addOutput(metadataOutput)
            metadataOutput.setMetadataObjectsDelegate(self, queue: .main)
            let desired: [AVMetadataObject.ObjectType] = [.ean13, .ean8, .upce, .code128, .code39]
            metadataOutput.metadataObjectTypes = desired.filter {
                metadataOutput.availableMetadataObjectTypes.contains($0)
            }
        }

        session.commitConfiguration()
        isConfigured = true
    }

    func metadataOutput(_ output: AVCaptureMetadataOutput,
                        didOutput metadataObjects: [AVMetadataObject],
                        from connection: AVCaptureConnection) {
        guard !didFind,
              let object = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
              let code = object.stringValue, !code.isEmpty else { return }
        didFind = true
        stop()
        // The delegate queue is `.main`, but this method itself is nonisolated
        // (AVCaptureMetadataOutputObjectsDelegate isn't MainActor); hop explicitly
        // to call the MainActor-isolated Haptics.fire.
        Task { @MainActor in
            Haptics.fire(.capture)
            onCode?(code)
        }
    }
}

/// The scanner sheet: preview + reticle + honest permission states.
struct BarcodeScannerView: View {
    let onScanned: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @StateObject private var controller = BarcodeScannerController()
    @State private var authStatus = CameraPermission.status

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
                        if granted { controller.start() }
                    }
                }
            default:
                CameraDeniedView()
            }

            VStack {
                HStack {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.white.opacity(0.85))
                            .padding()
                    }
                    Spacer()
                }
                Spacer()
            }
        }
        .onAppear {
            controller.onCode = { code in
                onScanned(code)
                dismiss()
            }
            if authStatus == .authorized { controller.start() }
        }
        .onDisappear { controller.stop() }
    }

    private var scanner: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            CameraPreviewView(session: controller.session).ignoresSafeArea()
            VStack(spacing: 18) {
                Spacer()
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(Theme.accent, lineWidth: 3)
                    .frame(width: 260, height: 150)
                    .blueGlow(Theme.accent, radius: 16, opacity: 0.5)
                Text("catalog.scan.prompt")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.textPrimary)
                    .padding(.horizontal, 14).padding(.vertical, 9)
                    .background(.ultraThinMaterial, in: Capsule())
                Spacer()
            }
        }
    }
}
