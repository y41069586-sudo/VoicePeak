import Foundation
import SwiftData

/// A skincare product and its (later, in Milestone 4) classified ingredient
/// profile. Imagery is legal/open-licensed only — never scraped brand images.
@Model
final class Product {
    @Attribute(.unique) var id: UUID
    var barcode: String?
    var name: String
    var brand: String
    /// Local filename of a cached, legally-sourced image (Open Beauty Facts /
    /// affiliate / user-supplied). Never a scraped remote asset baked in.
    var imageFilename: String?
    /// Raw INCI ingredient list, in label order.
    var inci: [String]
    var source: ProductSource
    /// Classified profile, produced by the Ingredient engine (Milestone 4) and
    /// stored as JSON so the schema stays stable before that engine lands.
    var profileJSON: String?
    var createdAt: Date

    init(
        id: UUID = UUID(),
        barcode: String? = nil,
        name: String,
        brand: String,
        imageFilename: String? = nil,
        inci: [String] = [],
        source: ProductSource = .seed,
        profileJSON: String? = nil,
        createdAt: Date = .now
    ) {
        self.id = id
        self.barcode = barcode
        self.name = name
        self.brand = brand
        self.imageFilename = imageFilename
        self.inci = inci
        self.source = source
        self.profileJSON = profileJSON
        self.createdAt = createdAt
    }
}
