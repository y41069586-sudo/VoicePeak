import UIKit

/// Persists scan thumbnails to the app's Application Support directory — **local
/// only**, with complete file protection (encrypted at rest while the device is
/// locked). Face imagery never leaves the device; `Scan` stores only the filename.
enum ThumbnailStore {

    private static var directory: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let dir = base.appendingPathComponent("Thumbnails", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    /// Downscale + save as JPEG. Returns the filename (not a path) to store on `Scan`.
    static func save(_ image: UIImage, maxDimension: CGFloat = 640) -> String? {
        let thumb = image.downscaled(to: maxDimension)
        guard let data = thumb.jpegData(compressionQuality: 0.8) else { return nil }
        let name = UUID().uuidString + ".jpg"
        do {
            try data.write(to: directory.appendingPathComponent(name), options: .completeFileProtection)
            return name
        } catch {
            return nil
        }
    }

    static func load(_ filename: String) -> UIImage? {
        guard let data = try? Data(contentsOf: directory.appendingPathComponent(filename)) else { return nil }
        return UIImage(data: data)
    }

    static func delete(_ filename: String) {
        try? FileManager.default.removeItem(at: directory.appendingPathComponent(filename))
    }
}

extension UIImage {
    /// Aspect-preserving downscale so the longest side is at most `maxDimension`.
    func downscaled(to maxDimension: CGFloat) -> UIImage {
        let longest = max(size.width, size.height)
        guard longest > maxDimension else { return self }
        let scale = maxDimension / longest
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in draw(in: CGRect(origin: .zero, size: newSize)) }
    }
}
