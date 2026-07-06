import SwiftUI
import SwiftData

/// Setup for a half-face test: which side gets the product, scan cadence, optional
/// price (for the money-saved counter), and the test-hygiene rules. Enforces one
/// active test — extra tests are queued.
struct HalfFaceTestSetupView: View {
    let product: Product

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(AppState.self) private var appState
    @Query private var tests: [HalfFaceTest]

    @State private var testSide: FaceSide = .left
    @State private var cadenceDays = 3
    @State private var priceText = ""

    private var hasActiveTest: Bool {
        tests.contains { $0.status == .running || $0.status == .verdictReady }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text(verbatim: product.name)
                        .font(.headline).foregroundStyle(Theme.textPrimary)
                    if !product.brand.isEmpty {
                        Text(verbatim: product.brand)
                            .font(.caption).foregroundStyle(Theme.textSecondary)
                    }
                }

                Section("test.setup.side") {
                    Picker("test.setup.side", selection: $testSide) {
                        Text("side.left").tag(FaceSide.left)
                        Text("side.right").tag(FaceSide.right)
                    }
                    .pickerStyle(.segmented)
                    Text("test.setup.side.help")
                        .font(.caption).foregroundStyle(Theme.textSecondary)
                }

                Section("test.setup.cadence") {
                    Stepper(value: $cadenceDays, in: 2...7) {
                        Text("test.setup.cadence.value \(cadenceDays)")
                    }
                }

                Section {
                    TextField("test.setup.price.placeholder", text: $priceText)
                        .keyboardType(.decimalPad)
                } header: {
                    Text("test.setup.price")
                } footer: {
                    Text("test.setup.price.help")
                }

                Section {
                    Label("test.setup.hygiene", systemImage: "checkmark.shield")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.textPrimary)
                    Text("test.setup.hygiene.body")
                        .font(.caption).foregroundStyle(Theme.textSecondary)
                }

                if hasActiveTest {
                    Section {
                        Label("test.setup.queued", systemImage: "clock")
                            .font(.footnote).foregroundStyle(Theme.warning)
                    }
                }

                Section {
                    Button {
                        startTest()
                    } label: {
                        Text("test.setup.start").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                }
            }
            .scrollContentBackground(.hidden)
            .background(GradientMeshBackground())
            .navigationTitle("test.setup.title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("common.cancel") { dismiss() }
                }
            }
        }
    }

    private func startTest() {
        let price = Double(priceText.replacingOccurrences(of: ",", with: "."))
        HalfFaceTestManager.start(
            product: product,
            testSide: testSide,
            cadenceDays: cadenceDays,
            price: price,
            existingTests: tests,
            in: modelContext
        )
        Haptics.fire(.milestone)
        dismiss()
        appState.selectedTab = .home
    }
}
