import SwiftData
import Foundation

/// Bridges Open Beauty Facts results into the local SwiftData catalog, de-duping
/// by barcode. Runs on the main actor since it mutates the model context.
@MainActor
enum CatalogStore {

    @discardableResult
    static func upsert(_ dto: CatalogProduct, into context: ModelContext) -> Product {
        let all = (try? context.fetch(FetchDescriptor<Product>())) ?? []
        if let existing = all.first(where: { $0.barcode == dto.barcode }) {
            existing.name = dto.name
            existing.brand = dto.brand
            if !dto.inci.isEmpty { existing.inci = dto.inci }
            existing.imageURLString = dto.imageURL
            if existing.source == .seed { existing.source = .openBeautyFacts }
            return existing
        }
        let product = Product(
            barcode: dto.barcode,
            name: dto.name,
            brand: dto.brand,
            imageURLString: dto.imageURL,
            inci: dto.inci,
            source: .openBeautyFacts
        )
        context.insert(product)
        return product
    }

    @discardableResult
    static func upsertAll(_ dtos: [CatalogProduct], into context: ModelContext) -> [Product] {
        dtos.map { upsert($0, into: context) }
    }
}
