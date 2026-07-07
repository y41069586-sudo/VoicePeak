import Foundation

/// DermIQ cloud skin-analysis connection config, read from Info.plist keys —
/// populate them from a git-ignored `Secrets.xcconfig` (never commit keys; see
/// README.md in this folder for the exact wiring steps). Absent by default →
/// not configured → the app falls back to `DisabledCloudSkinAnalysis` and
/// never uploads a face photo.
struct DermIQConfig: Sendable {
    let baseURL: URL
    let apiKey: String

    var isConfigured: Bool { !apiKey.isEmpty }

    static let shared = DermIQConfig(
        baseURL: (Bundle.main.object(forInfoDictionaryKey: "DERMIQ_BASE_URL") as? String)
            .flatMap { $0.isEmpty ? nil : URL(string: $0) }
            ?? URL(string: "https://dev.dermiq.cloud")!,
        apiKey: (Bundle.main.object(forInfoDictionaryKey: "DERMIQ_API_KEY") as? String) ?? ""
    )
}
