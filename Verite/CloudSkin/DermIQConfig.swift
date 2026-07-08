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

    // Base URL is hardcoded (not read from Info.plist/xcconfig): xcconfig treats
    // "//" as a comment, so a URL stored there would be mangled to "https:".
    static let shared = DermIQConfig(
        baseURL: URL(string: "https://dev.dermiq.cloud")!,
        apiKey: (Bundle.main.object(forInfoDictionaryKey: "DERMIQ_API_KEY") as? String) ?? ""
    )
}
