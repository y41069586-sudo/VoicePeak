import Foundation
import SwiftData

/// Central definition of the SwiftData schema + container factories.
/// Keeping the model list in one place means every entry point (app, previews,
/// tests) shares the exact same schema.
enum Persistence {

    /// Every `@Model` in the app. Add new models here.
    static let schema = Schema([
        UserProfile.self,
        Scan.self,
        Product.self,
        HalfFaceTest.self,
        RoutineItem.self,
        Streak.self,
        SavingsLedger.self,
    ])

    /// The on-disk container the live app uses.
    static func makeContainer() -> ModelContainer {
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            // A container failure at launch is unrecoverable; fail loudly in
            // debug rather than limping along with a broken store.
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }

    /// An in-memory container for SwiftUI previews and unit tests.
    @MainActor
    static let previewContainer: ModelContainer = {
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        do {
            let container = try ModelContainer(for: schema, configurations: [configuration])
            SeedData.populatePreview(container.mainContext)
            return container
        } catch {
            fatalError("Failed to create preview ModelContainer: \(error)")
        }
    }()
}
