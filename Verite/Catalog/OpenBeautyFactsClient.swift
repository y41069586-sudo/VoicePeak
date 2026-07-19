import Foundation

/// Minimal async client for the open-licensed Open Beauty Facts database.
/// Used for barcode lookup + product search. No API key required; we send a
/// descriptive User-Agent as the project requests. Face data is never involved.
enum OpenBeautyFacts {

    enum ClientError: Error { case badURL, http(Int) }

    private static let base = "https://world.openbeautyfacts.org"
    private static let userAgent = "Glowe/0.1 (iOS)"
    private static let fields = "code,product_name,brands,ingredients_text,image_front_small_url,image_small_url"

    /// Look up a single product by its barcode. Returns nil when OBF has no record.
    static func product(barcode: String) async throws -> CatalogProduct? {
        guard let url = URL(string: "\(base)/api/v2/product/\(barcode).json?fields=\(fields)") else {
            throw ClientError.badURL
        }
        let data = try await get(url)
        let response = try JSONDecoder().decode(ProductResponse.self, from: data)
        guard response.status == 1, let product = response.product else { return nil }
        return map(product, fallbackBarcode: barcode)
    }

    /// Free-text product search, paginated.
    static func search(query: String, page: Int = 1, pageSize: Int = 20) async throws -> [CatalogProduct] {
        var components = URLComponents(string: "\(base)/cgi/search.pl")
        components?.queryItems = [
            URLQueryItem(name: "search_terms", value: query),
            URLQueryItem(name: "search_simple", value: "1"),
            URLQueryItem(name: "action", value: "process"),
            URLQueryItem(name: "json", value: "1"),
            URLQueryItem(name: "page_size", value: String(pageSize)),
            URLQueryItem(name: "page", value: String(page)),
            URLQueryItem(name: "fields", value: fields),
        ]
        guard let url = components?.url else { throw ClientError.badURL }
        let data = try await get(url)
        let response = try JSONDecoder().decode(SearchResponse.self, from: data)
        return (response.products ?? []).compactMap { map($0, fallbackBarcode: nil) }
    }

    // MARK: Networking

    private static func get(_ url: URL) async throws -> Data {
        var request = URLRequest(url: url)
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 20
        let (data, response) = try await URLSession.shared.data(for: request)
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw ClientError.http(http.statusCode)
        }
        return data
    }

    // MARK: Mapping

    private static func map(_ p: RawProduct, fallbackBarcode: String?) -> CatalogProduct? {
        guard let barcode = clean(p.code) ?? fallbackBarcode,
              let name = clean(p.productName) else { return nil }
        let brand = clean(p.brands.map { $0.components(separatedBy: ",").first ?? $0 }) ?? ""
        return CatalogProduct(
            barcode: barcode,
            name: name,
            brand: brand,
            ingredientsText: clean(p.ingredientsText),
            imageURL: clean(p.imageFrontSmallURL) ?? clean(p.imageSmallURL)
        )
    }

    private static func clean(_ value: String?) -> String? {
        guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else { return nil }
        return trimmed
    }

    // MARK: Decodable wire models

    private struct RawProduct: Decodable {
        let code: String?
        let productName: String?
        let brands: String?
        let ingredientsText: String?
        let imageFrontSmallURL: String?
        let imageSmallURL: String?

        enum CodingKeys: String, CodingKey {
            case code
            case productName = "product_name"
            case brands
            case ingredientsText = "ingredients_text"
            case imageFrontSmallURL = "image_front_small_url"
            case imageSmallURL = "image_small_url"
        }
    }

    private struct ProductResponse: Decodable {
        let status: Int?
        let product: RawProduct?
    }

    private struct SearchResponse: Decodable {
        let products: [RawProduct]?
        let count: Int?
    }
}
