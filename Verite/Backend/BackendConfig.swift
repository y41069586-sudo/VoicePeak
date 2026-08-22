import Foundation

/// Supabase connection config, read from the CI-injected `DermiqSecrets`
/// (same mechanism as the Perfect Corp / Gemini keys — committed empty,
/// overwritten in Codemagic from secure env vars). Empty by default → not
/// configured → the app uses `LocalOnlyBackend`.
struct BackendConfig: Sendable {
    let url: URL?
    let anonKey: String

    var isConfigured: Bool { url != nil && !anonKey.isEmpty }

    static let shared = BackendConfig(
        url: DermiqSecrets.supabaseURL.isEmpty ? nil : URL(string: DermiqSecrets.supabaseURL),
        anonKey: DermiqSecrets.supabaseAnonKey
    )
}
