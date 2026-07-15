import SwiftUI

// ============================================================
// MARK: — Skin Compare (serverless score face-off)
// ============================================================
//
// The simple version: no 14-day parallel plan, no baseline/final. You just
// compare your CURRENT scan against a friend's. Everything travels inside the
// share link — name, overall, the seven sub-scores, and a tiny round-photo
// thumbnail — so both people see the real chart (photo + two columns) and who
// leads. No backend, no account.

/// A flat per-category score, small enough to ride inside a share link.
struct CompareScore: Codable, Hashable {
    var c: String   // DermiqCategory.rawValue
    var v: Int      // 0…100

    static func from(_ subs: [DermiqSubScore]) -> [CompareScore] {
        subs.map { CompareScore(c: $0.category.rawValue, v: $0.value) }
    }
}

struct ComparePayload: Codable, Identifiable {
    var v = 1
    var name: String
    var overall: Int
    var subs: [CompareScore]
    var thumb: String?           // base64 of a small JPEG (optional)

    var id: String { "\(name)-\(overall)-\(subs.count)" }

    /// Value for a category, if present.
    func value(for category: DermiqCategory) -> Int? {
        subs.first { $0.c == category.rawValue }?.v
    }

    #if canImport(UIKit)
    /// The friend's round photo, decoded from the payload (nil → use a sketch).
    var thumbImage: UIImage? {
        guard let thumb, let data = Data(base64Encoded: thumb) else { return nil }
        return UIImage(data: data)
    }

    /// Build my own card from a scan — with a small thumbnail so the link
    /// stays light enough to travel (≈120px, low quality).
    static func mine(name: String, analysis: DermiqAnalysis, photo: UIImage?) -> ComparePayload {
        ComparePayload(
            name: name.isEmpty ? "A friend" : name,
            overall: analysis.overall,
            subs: CompareScore.from(analysis.subScores),
            thumb: photo.flatMap { thumbToken(from: $0) }
        )
    }

    /// Center-crop to a square, downscale, JPEG, base64. Kept tiny on purpose.
    private static func thumbToken(from image: UIImage, side: CGFloat = 120) -> String? {
        let source = image
        let minEdge = min(source.size.width, source.size.height)
        let cropRect = CGRect(
            x: (source.size.width - minEdge) / 2,
            y: (source.size.height - minEdge) / 2,
            width: minEdge, height: minEdge)
        guard let cg = source.cgImage?.cropping(to: CGRect(
            x: cropRect.origin.x * source.scale, y: cropRect.origin.y * source.scale,
            width: cropRect.width * source.scale, height: cropRect.height * source.scale))
        else { return nil }
        let square = UIImage(cgImage: cg, scale: source.scale, orientation: source.imageOrientation)

        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: side, height: side), format: format)
        let small = renderer.image { _ in
            square.draw(in: CGRect(x: 0, y: 0, width: side, height: side))
        }
        return small.jpegData(compressionQuality: 0.5)?.base64EncodedString()
    }
    #endif
}

// ============================================================
// MARK: — Link encode / decode  (verite://compare?d=…)
// ============================================================

enum CompareLink {
    static let scheme = "verite"
    static let host = "compare"

    static func url(for payload: ComparePayload) -> URL? {
        guard let json = try? JSONEncoder().encode(payload) else { return nil }
        var components = URLComponents()
        components.scheme = scheme
        components.host = host
        components.queryItems = [URLQueryItem(name: "d", value: base64url(json))]
        return components.url
    }

    static func payload(from url: URL) -> ComparePayload? {
        guard url.scheme == scheme, url.host == host,
              let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems,
              let token = items.first(where: { $0.name == "d" })?.value,
              let data = base64urlDecode(token),
              let payload = try? JSONDecoder().decode(ComparePayload.self, from: data)
        else { return nil }
        return payload
    }

    /// Messengers never make custom-scheme links tappable — the friend copies
    /// the whole message instead. Fish the compare link out of arbitrary text.
    static func payload(fromPastedText text: String) -> ComparePayload? {
        guard let range = text.range(of: #"verite://compare\?d=[A-Za-z0-9\-_=]+"#,
                                     options: .regularExpression),
              let url = URL(string: String(text[range]))
        else { return nil }
        return payload(from: url)
    }

    private static func base64url(_ data: Data) -> String {
        data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    private static func base64urlDecode(_ token: String) -> Data? {
        var s = token.replacingOccurrences(of: "-", with: "+")
                     .replacingOccurrences(of: "_", with: "/")
        let remainder = s.count % 4
        if remainder > 0 { s += String(repeating: "=", count: 4 - remainder) }
        return Data(base64Encoded: s)
    }
}

// ============================================================
// MARK: — Inbox (a tapped compare link lands here)
// ============================================================

@Observable
@MainActor
final class CompareInbox {
    static let shared = CompareInbox()
    private init() {}

    /// The friend's incoming card, waiting to be shown against mine.
    var pending: ComparePayload?

    /// Returns true when the URL was a compare link (handled here).
    func handle(_ url: URL) -> Bool {
        guard let payload = CompareLink.payload(from: url) else { return false }
        pending = payload
        Haptics.fire(.milestone)
        return true
    }

    func consume() { pending = nil }
}
