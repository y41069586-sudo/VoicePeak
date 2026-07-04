import Foundation

/// Supabase connection config, read from Info.plist keys (populate them from a
/// git-ignored xcconfig — see Backend/README.md). Empty by default → not
/// configured → the app uses `LocalOnlyBackend`.
struct BackendConfig: Sendable {
    let url: URL?
    let anonKey: String

    var isConfigured: Bool { url != nil && !anonKey.isEmpty }

    static let shared = BackendConfig(
        url: (Bundle.main.object(forInfoDictionaryKey: "SUPABASE_URL") as? String)
            .flatMap { $0.isEmpty ? nil : URL(string: $0) },
        anonKey: (Bundle.main.object(forInfoDictionaryKey: "SUPABASE_ANON_KEY") as? String) ?? ""
    )
}
