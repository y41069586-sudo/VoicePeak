import SwiftUI
import UIKit

/// Renders a SwiftUI view to an image entirely on-device (ImageRenderer) and
/// writes it to a temporary PNG for sharing. Nothing leaves the device except
/// what the user explicitly shares.
@MainActor
enum ShareRenderer {

    static func image(for view: some View, size: CGSize, scale: CGFloat = 3) -> UIImage? {
        let renderer = ImageRenderer(content: view.frame(width: size.width, height: size.height))
        renderer.scale = scale
        renderer.isOpaque = true
        return renderer.uiImage
    }

    static func pngURL(for image: UIImage, name: String = "verite-verified") -> URL? {
        guard let data = image.pngData() else { return nil }
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(name)-\(UUID().uuidString).png")
        do {
            try data.write(to: url)
            return url
        } catch {
            return nil
        }
    }
}
