import SwiftUI
import UIKit
import CryptoKit

/// Disk + memory cache for open-licensed product images. Downloads once, then
/// serves from the local Caches directory — "cached locally" per the brief.
actor ImageCache {
    static let shared = ImageCache()

    private var memory: [String: UIImage] = [:]

    private var directory: URL {
        let base = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        let dir = base.appendingPathComponent("ProductImages", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    func image(for urlString: String?) async -> UIImage? {
        guard let urlString, let url = URL(string: urlString) else { return nil }

        if let cached = memory[urlString] { return cached }

        let fileURL = directory.appendingPathComponent(filename(for: urlString))
        if let data = try? Data(contentsOf: fileURL), let image = UIImage(data: data) {
            memory[urlString] = image
            return image
        }

        guard let (data, response) = try? await URLSession.shared.data(from: url),
              let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode),
              let image = UIImage(data: data) else { return nil }

        try? data.write(to: fileURL, options: .atomic)
        memory[urlString] = image
        return image
    }

    private func filename(for urlString: String) -> String {
        let digest = SHA256.hash(data: Data(urlString.utf8))
        return digest.map { String(format: "%02x", $0) }.joined() + ".img"
    }
}

/// SwiftUI image view backed by `ImageCache`, with a placeholder while loading.
struct RemoteImage<Placeholder: View>: View {
    let urlString: String?
    @ViewBuilder var placeholder: () -> Placeholder

    @State private var image: UIImage?

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image).resizable().scaledToFill()
            } else {
                placeholder()
            }
        }
        .animation(.easeInOut(duration: 0.25), value: image != nil) // gentle fade-in on load
        .task(id: urlString) {
            image = await ImageCache.shared.image(for: urlString)
        }
    }
}
