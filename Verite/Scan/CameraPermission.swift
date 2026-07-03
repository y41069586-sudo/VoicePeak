import AVFoundation
import UIKit

/// Thin wrapper over camera authorization. Kept separate so the UI layer never
/// touches `AVCaptureDevice` directly and permission handling stays testable.
enum CameraPermission {

    static var status: AVAuthorizationStatus {
        AVCaptureDevice.authorizationStatus(for: .video)
    }

    /// Prompts for camera access (only meaningful when status is `.notDetermined`).
    static func request() async -> Bool {
        await AVCaptureDevice.requestAccess(for: .video)
    }

    /// Deep-link to this app's Settings page so a denied user is never dead-ended.
    @MainActor
    static func openSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
}
