import SwiftUI
import SwiftData

/// A list of all half-face tests (active, queued, and finished), newest first.
struct TestsListView: View {
    @Query(sort: \HalfFaceTest.createdAt, order: .reverse) private var tests: [HalfFaceTest]
    @Query private var products: [Product]

    var body: some View {
        Group {
            if tests.isEmpty {
                ContentUnavailableView("halfface.list.empty", systemImage: "flask")
            } else {
                List {
                    ForEach(tests) { test in
                        NavigationLink {
                            HalfFaceTestDetailView(test: test)
                        } label: {
                            row(test)
                        }
                        .listRowBackground(Theme.bgSurface.opacity(0.6))
                    }
                }
                .scrollContentBackground(.hidden)
            }
        }
        .navigationTitle("halfface.list.title")
        .navigationBarTitleDisplayMode(.inline)
        .background(GradientMeshBackground())
    }

    private func row(_ test: HalfFaceTest) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "flask.fill")
                .foregroundStyle(Theme.accent)
            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: products.first { $0.id == test.productID }?.name ?? "—")
                    .font(.subheadline).foregroundStyle(Theme.textPrimary)
                Text(test.status.localizationKey)
                    .font(.caption).foregroundStyle(Theme.textSecondary)
            }
            Spacer()
        }
        .padding(.vertical, 4)
    }
}
