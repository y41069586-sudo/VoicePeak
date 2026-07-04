import Foundation

/// An affiliate offer for a product (open/affiliate-provided imagery + link only).
struct AffiliateOffer: Sendable, Equatable {
    let title: String
    let price: Double?
    let currencyCode: String?
    let imageURL: String?
    let url: URL
    let providerName: String
}

/// Optional affiliate enrichment. Default `DisabledAffiliate` returns nothing, so
/// the app is fully functional on Open Beauty Facts alone. When enabled, offers
/// are fetched programmatically and shown **with an in-app disclosure** — the
/// honesty brand requires transparency, and affiliate status never changes a match.
protocol AffiliateService: Sendable {
    var isEnabled: Bool { get }
    /// Primitives only (no SwiftData model) so this stays `Sendable`-clean.
    func offer(barcode: String?, name: String, brand: String) async -> AffiliateOffer?
}

struct DisabledAffiliate: AffiliateService {
    var isEnabled: Bool { false }
    func offer(barcode: String?, name: String, brand: String) async -> AffiliateOffer? { nil }
}

/// A generic HTTP provider: point it at your own signing proxy or an affiliate
/// network (Amazon PA-API / Awin / Impact) that returns a small JSON offer.
/// (Amazon PA-API needs AWS SigV4 signing — do that server-side and expose a
/// simple endpoint; never ship signing keys in the app.)
struct ConfiguredAffiliateProvider: AffiliateService {
    let config: AffiliateConfig

    var isEnabled: Bool { config.isConfigured }

    func offer(barcode: String?, name: String, brand: String) async -> AffiliateOffer? {
        guard let endpoint = config.endpoint else { return nil }
        var components = URLComponents(url: endpoint, resolvingAgainstBaseURL: false)
        components?.queryItems = [
            barcode.map { URLQueryItem(name: "barcode", value: $0) },
            URLQueryItem(name: "q", value: "\(brand) \(name)".trimmingCharacters(in: .whitespaces)),
            URLQueryItem(name: "tag", value: config.tag),
        ].compactMap { $0 }
        guard let url = components?.url,
              let (data, response) = try? await URLSession.shared.data(from: url),
              let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            return nil
        }
        struct Raw: Decodable {
            let title: String
            let price: Double?
            let currency: String?
            let image: String?
            let url: String
            let provider: String?
        }
        guard let raw = try? JSONDecoder().decode(Raw.self, from: data),
              let link = URL(string: raw.url) else { return nil }
        return AffiliateOffer(title: raw.title, price: raw.price, currencyCode: raw.currency,
                              imageURL: raw.image, url: link, providerName: raw.provider ?? "Partner")
    }
}

/// Endpoint + affiliate tag from Info.plist (git-ignored xcconfig). Empty →
/// not configured → `DisabledAffiliate`.
struct AffiliateConfig: Sendable {
    let endpoint: URL?
    let tag: String

    var isConfigured: Bool { endpoint != nil && !tag.isEmpty }

    static let shared = AffiliateConfig(
        endpoint: (Bundle.main.object(forInfoDictionaryKey: "AFFILIATE_ENDPOINT") as? String)
            .flatMap { $0.isEmpty ? nil : URL(string: $0) },
        tag: (Bundle.main.object(forInfoDictionaryKey: "AFFILIATE_TAG") as? String) ?? ""
    )
}
