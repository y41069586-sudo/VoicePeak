import SwiftUI
import SwiftData

/// Product browse/search + barcode scanning, backed by the local catalog and the
/// Open Beauty Facts database. Saved/seeded products are searchable offline;
/// submitting a query fetches more from OBF and caches them locally.
struct CatalogView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Product.name) private var products: [Product]

    @State private var searchText = ""
    @State private var isSearchingOnline = false
    @State private var onlineError = false
    @State private var showScanner = false
    @State private var scannedProduct: Product?
    @State private var showScannedDetail = false

    private var filtered: [Product] {
        guard !searchText.isEmpty else { return products }
        return products.filter {
            $0.name.localizedCaseInsensitiveContains(searchText)
            || $0.brand.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if products.isEmpty {
                    emptyCatalog
                } else {
                    list
                }
            }
            .navigationTitle("catalog")
            .searchable(text: $searchText, prompt: Text("catalog.search.prompt"))
            .onSubmit(of: .search) { Task { await searchOnline() } }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showScanner = true } label: {
                        Image(systemName: "barcode.viewfinder")
                    }
                    .accessibilityLabel("catalog.scan.barcode")
                }
            }
            .sheet(isPresented: $showScanner) {
                BarcodeScannerView { code in
                    Task { await lookupBarcode(code) }
                }
            }
            .navigationDestination(isPresented: $showScannedDetail) {
                if let scannedProduct { ProductDetailView(product: scannedProduct) }
            }
        }
    }

    private var list: some View {
        List {
            if isSearchingOnline {
                HStack(spacing: 10) {
                    ProgressView()
                    Text("catalog.searching").foregroundStyle(Theme.textSecondary)
                }
                ForEach(0..<3, id: \.self) { _ in
                    SkeletonRow().listRowBackground(Theme.bgSurface.opacity(0.4))
                }
            }
            if onlineError {
                Label("catalog.error", systemImage: "wifi.exclamationmark")
                    .foregroundStyle(Theme.warning)
                    .font(.footnote)
            }
            if filtered.isEmpty {
                ContentUnavailableView {
                    Label("catalog.noResults.title", systemImage: "magnifyingglass")
                } description: {
                    Text("catalog.noResults.body")
                }
                .listRowBackground(Color.clear)
            } else {
                ForEach(filtered) { product in
                    NavigationLink {
                        ProductDetailView(product: product)
                    } label: {
                        ProductRow(product: product)
                    }
                    .listRowBackground(Theme.bgSurface.opacity(0.4))
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(GradientMeshBackground())
    }

    private var emptyCatalog: some View {
        VStack(spacing: 14) {
            Image(systemName: "barcode.viewfinder")
                .font(.system(size: 44, weight: .light))
                .foregroundStyle(Theme.accent)
            Text("catalog.empty.title")
                .font(Typography.display(24))
                .foregroundStyle(Theme.textPrimary)
            Text("catalog.empty.body")
                .font(.subheadline)
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 36)
            PrimaryButton(titleKey: "catalog.scan.barcode", systemImage: "barcode.viewfinder") {
                showScanner = true
            }
            .padding(.horizontal, 40)
            .padding(.top, 6)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(GradientMeshBackground())
    }

    // MARK: Actions

    private func searchOnline() async {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard query.count >= 2 else { return }
        isSearchingOnline = true
        onlineError = false
        defer { isSearchingOnline = false }
        do {
            let results = try await OpenBeautyFacts.search(query: query)
            CatalogStore.upsertAll(results, into: modelContext)
            try? modelContext.save()
        } catch {
            onlineError = true
        }
    }

    private func lookupBarcode(_ code: String) async {
        isSearchingOnline = true
        onlineError = false
        defer { isSearchingOnline = false }
        do {
            if let dto = try await OpenBeautyFacts.product(barcode: code) {
                let product = CatalogStore.upsert(dto, into: modelContext)
                try? modelContext.save()
                scannedProduct = product
                showScannedDetail = true
            } else {
                onlineError = true
            }
        } catch {
            onlineError = true
        }
    }
}

/// A catalog list row: thumbnail + brand + name.
struct ProductRow: View {
    let product: Product

    var body: some View {
        HStack(spacing: 12) {
            RemoteImage(urlString: product.imageURLString) {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Theme.bgElevated)
                    .overlay(Image(systemName: "sparkles").font(.caption).foregroundStyle(Theme.textSecondary))
            }
            .frame(width: 48, height: 48)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                if !product.brand.isEmpty {
                    Text(verbatim: product.brand)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Theme.textSecondary)
                }
                Text(verbatim: product.name)
                    .font(.subheadline)
                    .foregroundStyle(Theme.textPrimary)
                    .lineLimit(2)
            }
        }
        .padding(.vertical, 4)
    }
}
