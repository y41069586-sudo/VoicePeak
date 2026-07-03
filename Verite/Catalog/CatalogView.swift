import SwiftUI

/// Placeholder for product browse/search + barcode scanning (Open Beauty Facts).
/// Real catalog arrives in Milestone 4.
struct CatalogView: View {
    var body: some View {
        ComingSoonView(titleKey: AppTab.catalog.titleKey,
                       systemImage: AppTab.catalog.systemImage,
                       messageKey: "catalog.comingSoon")
    }
}
