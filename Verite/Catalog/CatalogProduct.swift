import Foundation

/// A product fetched from Open Beauty Facts, before it becomes a persisted
/// SwiftData `Product`. Imagery is an open-licensed OBF URL — never a scraped asset.
struct CatalogProduct: Identifiable, Sendable {
    let barcode: String
    let name: String
    let brand: String
    let ingredientsText: String?
    let imageURL: String?

    var id: String { barcode }
    var inci: [String] { INCIParser.parse(ingredientsText ?? "") }
}
