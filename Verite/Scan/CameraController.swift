import AVFoundation
import Vision
import CoreImage
import UIKit

/// Owns the `AVCaptureSession` for the front-camera face scan. Runs Vision face
/// detection + a luminance estimate on the video stream (throttled, off the main
/// thread) to drive the AR alignment guide, and captures a still photo on demand.
///
/// Everything here stays on-device. Nothing is transmitted; the captured image is
/// handed back to the caller, which stores only a local thumbnail.
final class CameraController: NSObject, ObservableObject, @unchecked Sendable,
                             AVCaptureVideoDataOutputSampleBufferDelegate,
                             AVCapturePhotoCaptureDelegate {

    /// Live framing assessment for the UI (updated on the main thread, ~5 Hz).
    @Published private(set) var quality = CaptureQuality()
    @Published private(set) var isRunning = false
    
    /// Delegate callback for real-time frame consumers (e.g. RealtimeSkinMonitor)
    var onFrame: ((CMSampleBuffer) -> Void)?

    let session = AVCaptureSession()

    private let sessionQueue = DispatchQueue(label: "com.verite.camera.session")
    private let videoQueue = DispatchQueue(label: "com.verite.camera.video")
    private let photoOutput = AVCapturePhotoOutput()
    private let videoOutput = AVCaptureVideoDataOutput()

    private let ciContext = CIContext(options: [.workingColorSpace: NSNull()])
    private var isConfigured = false
    /// The active capture device — kept so exposure/white-balance can be locked
    /// for a standardized, repeatable capture.
    private var device: AVCaptureDevice?
    private var lastAnalysis: CFTimeInterval = 0
    private let analysisInterval: CFTimeInterval = 0.2 // 5 Hz

    private var captureContinuation: CheckedContinuation<UIImage?, Never>?

    // MARK: Lifecycle

    /// Configure (once) then start the session. Safe to call on view appear.
    func start() {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            if !self.isConfigured { self.configure() }
            guard self.isConfigured, !self.session.isRunning else { return }
            self.session.startRunning()
            DispatchQueue.main.async { self.isRunning = self.session.isRunning }
        }
    }

    func stop() {
        sessionQueue.async { [weak self] in
            guard let self, self.session.isRunning else { return }
            self.session.stopRunning()
            DispatchQueue.main.async { self.isRunning = false }
        }
    }

    private func configure() {
        session.beginConfiguration()
        session.sessionPreset = .photo

        guard
            let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front),
            let input = try? AVCaptureDeviceInput(device: device),
            session.canAddInput(input)
        else {
            session.commitConfiguration()
            return
        }
        session.addInput(input)
        self.device = device

        if session.canAddOutput(photoOutput) {
            session.addOutput(photoOutput)
        }

        videoOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
        videoOutput.alwaysDiscardsLateVideoFrames = true
        videoOutput.setSampleBufferDelegate(self, queue: videoQueue)
        if session.canAddOutput(videoOutput) {
            session.addOutput(videoOutput)
        }

        // Portrait + front-camera mirroring for both outputs.
        for connection in [photoOutput.connection(with: .video), videoOutput.connection(with: .video)].compactMap({ $0 }) {
            if connection.isVideoRotationAngleSupported(90) {
                connection.videoRotationAngle = 90
            }
            if connection.isVideoMirroringSupported {
                connection.automaticallyAdjustsVideoMirroring = false
                connection.isVideoMirrored = true
            }
        }

        session.commitConfiguration()
        isConfigured = true
    }

    // MARK: Standardized capture

    /// Freeze exposure + white balance so a scan isn't re-metered differently
    /// each time — the first step toward a repeatable, instrument-like capture
    /// (call at the start of the hold-still countdown). Focus stays automatic to
    /// avoid blur. Every guard is capability-checked, so it's a no-op where the
    /// device doesn't support locking.
    func lockStandardizedSettings() {
        sessionQueue.async { [weak self] in
            guard let device = self?.device,
                  (try? device.lockForConfiguration()) != nil else { return }
            if device.isExposureModeSupported(.locked) { device.exposureMode = .locked }
            if device.isWhiteBalanceModeSupported(.locked) { device.whiteBalanceMode = .locked }
            device.unlockForConfiguration()
        }
    }

    /// Return exposure + white balance to continuous auto (call after capture or
    /// when leaving the scanner) so the live preview meters normally again.
    func unlockStandardizedSettings() {
        sessionQueue.async { [weak self] in
            guard let device = self?.device,
                  (try? device.lockForConfiguration()) != nil else { return }
            if device.isExposureModeSupported(.continuousAutoExposure) {
                device.exposureMode = .continuousAutoExposure
            }
            if device.isWhiteBalanceModeSupported(.continuousAutoWhiteBalance) {
                device.whiteBalanceMode = .continuousAutoWhiteBalance
            }
            device.unlockForConfiguration()
        }
    }

    // MARK: Still capture

    /// Capture a single still. Returns the image (already oriented/mirrored to
    /// match the preview) or nil on failure. Never throws.
    func capture() async -> UIImage? {
        await withCheckedContinuation { (continuation: CheckedContinuation<UIImage?, Never>) in
            sessionQueue.async { [weak self] in
                guard let self, self.session.isRunning else {
                    continuation.resume(returning: nil)
                    return
                }
                self.captureContinuation = continuation
                self.photoOutput.capturePhoto(with: AVCapturePhotoSettings(), delegate: self)
            }
        }
    }

    func photoOutput(_ output: AVCapturePhotoOutput,
                     didFinishProcessingPhoto photo: AVCapturePhoto,
                     error: Error?) {
        let continuation = captureContinuation
        captureContinuation = nil
        guard error == nil,
              let data = photo.fileDataRepresentation(),
              let image = UIImage(data: data) else {
            continuation?.resume(returning: nil)
            return
        }
        // Bake the capture orientation into upright pixels so every consumer
        // (thumbnail store, split-face result, before/after) shows the face the
        // right way up — fixes sideways thumbnails across all capture paths.
        continuation?.resume(returning: image.normalizedUp())
    }

    // MARK: Live analysis (video frames)

    func captureOutput(_ output: AVCaptureOutput,
                       didOutput sampleBuffer: CMSampleBuffer,
                       from connection: AVCaptureConnection) {
        onFrame?(sampleBuffer)
                       
        let now = CACurrentMediaTime()
        guard now - lastAnalysis >= analysisInterval else { return }
        lastAnalysis = now

        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        let brightness = averageLuminance(of: pixelBuffer)
        let (detected, height, offset) = detectFace(in: pixelBuffer)

        var updated = CaptureQuality()
        updated.faceDetected = detected
        updated.normalizedFaceHeight = height
        updated.faceCenterOffset = offset
        updated.brightness = brightness

        DispatchQueue.main.async { [weak self] in
            guard let self, self.quality != updated else { return }
            self.quality = updated
        }
    }

    /// Largest-face bounding-box height + center offset in normalized coordinates.
    private func detectFace(in pixelBuffer: CVPixelBuffer) -> (Bool, Double, Double) {
        let request = VNDetectFaceRectanglesRequest()
        // Front camera in portrait: the sensor buffer maps to `.leftMirrored`.
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .leftMirrored, options: [:])
        try? handler.perform([request])

        guard let face = (request.results ?? []).max(by: { $0.boundingBox.height < $1.boundingBox.height }) else {
            return (false, 0, 1)
        }
        let box = face.boundingBox
        let offset = hypot(box.midX - 0.5, box.midY - 0.5)
        return (true, Double(box.height), Double(offset))
    }

    /// Average frame luminance (0...1) via a 1×1 area-average reduction.
    private func averageLuminance(of pixelBuffer: CVPixelBuffer) -> Double {
        let image = CIImage(cvPixelBuffer: pixelBuffer)
        let extent = image.extent
        guard let filter = CIFilter(name: "CIAreaAverage", parameters: [
            kCIInputImageKey: image,
            kCIInputExtentKey: CIVector(cgRect: extent),
        ]), let output = filter.outputImage else { return 0 }

        var bitmap = [UInt8](repeating: 0, count: 4)
        ciContext.render(output,
                         toBitmap: &bitmap,
                         rowBytes: 4,
                         bounds: CGRect(x: 0, y: 0, width: 1, height: 1),
                         format: .RGBA8,
                         colorSpace: CGColorSpaceCreateDeviceRGB())
        let r = Double(bitmap[0]), g = Double(bitmap[1]), b = Double(bitmap[2])
        return (0.299 * r + 0.587 * g + 0.114 * b) / 255.0
    }
}
