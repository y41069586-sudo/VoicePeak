import SwiftUI
import SwiftData

/// Data & privacy controls: export your data (numeric metrics + routine only,
/// never photos) and a truly-wipes-everything delete, guarded by confirmation.
struct DataPrivacyView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var showingDeleteConfirm = false
    @State private var exportURL: URL?

    var body: some View {
        Form {
            Section {
                Text("settings.data.explainer")
                    .font(.subheadline)
                    .foregroundStyle(Theme.textSecondary)
            }

            Section {
                Button {
                    exportURL = DataExporter.exportURL(context: modelContext)
                } label: {
                    Label("settings.data.export", systemImage: "square.and.arrow.up")
                }
                if let exportURL {
                    ShareLink(item: exportURL) {
                        Label("settings.data.export.share", systemImage: "arrow.up.doc")
                    }
                }
            } footer: {
                Text("settings.data.export.footer")
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

    /// Truly wipes local SwiftData + on-device thumbnails. Deleting the profile
    /// returns the app to onboarding. (Any synced server row is removed by the
    /// backend module when it's enabled.)
    private func wipeAllData() {
        try? modelContext.delete(model: UserProfile.self)
        try? modelContext.delete(model: Scan.self)
        try? modelContext.delete(model: Product.self)
        try? modelContext.delete(model: HalfFaceTest.self)
        try? modelContext.delete(model: RoutineItem.self)
        try? modelContext.delete(model: Streak.self)
        try? modelContext.delete(model: SavingsLedger.self)
        try? modelContext.save()
        ThumbnailStore.deleteAll()
        NotificationManager.cancelRoutineReminders()
        exportURL = nil
        Haptics.fire(.milestone)
    }
}
