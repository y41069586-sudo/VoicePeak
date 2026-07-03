import SwiftUI

/// Renders a localized legal document. Bodies come from the String Catalog so
/// every document is available in the active language.
struct LegalDocumentView: View {
    let document: LegalDocument

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(document.titleKey)
                    .font(Typography.display(28))
                    .foregroundStyle(Theme.textPrimary)
                Text(document.bodyKey)
                    .font(.body)
                    .foregroundStyle(Theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(20)
        }
        .scrollIndicators(.hidden)
        .navigationTitle(document.titleKey)
        .navigationBarTitleDisplayMode(.inline)
    }
}
