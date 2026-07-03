import SwiftUI
import SwiftData

/// Data & privacy controls. Export and true delete-all are wired to real SwiftData
/// wipes in Milestone 10; the destructive action is guarded by a confirmation.
struct DataPrivacyView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var showingDeleteConfirm = false

    var body: some View {
        Form {
            Section {
                Text("settings.data.explainer")
                    .font(.subheadline)
                    .foregroundStyle(Theme.textSecondary)
            }

            Section {
                Button {
                    // Full export (numeric metrics + routine, never photos) — M10.
                } label: {
                    Label("settings.data.export", systemImage: "square.and.arrow.up")
                }
            }

            Section {
                Button(role: .destructive) {
                    showingDeleteConfirm = true
                } label: {
                    Label("settings.data.deleteAll", systemImage: "trash")
                }
            } footer: {
                Text("settings.data.deleteAll.footer")
            }
        }
        .scrollContentBackground(.hidden)
        .navigationTitle("settings.data.title")
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog("settings.data.deleteAll.confirmTitle",
                            isPresented: $showingDeleteConfirm,
                            titleVisibility: .visible) {
            Button("settings.data.deleteAll.confirm", role: .destructive) {
                wipeAllData()
            }
            Button("common.cancel", role: .cancel) {}
        } message: {
            Text("settings.data.deleteAll.confirmMessage")
        }
    }

    /// Truly wipes local SwiftData. (Any synced server row is removed in M10 when
    /// the backend module exists.)
    private func wipeAllData() {
        try? modelContext.delete(model: UserProfile.self)
        try? modelContext.delete(model: Scan.self)
        try? modelContext.delete(model: Product.self)
        try? modelContext.delete(model: HalfFaceTest.self)
        try? modelContext.delete(model: RoutineItem.self)
        try? modelContext.delete(model: Streak.self)
        try? modelContext.delete(model: SavingsLedger.self)
        try? modelContext.save()
    }
}
