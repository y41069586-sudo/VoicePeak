import Foundation

/// Config for the Vérité AI advisor (Anthropic Claude), read from Info.plist
/// keys — populate them from a git-ignored `Secrets.xcconfig` (see
/// Advisor/README.md). Absent by default → not configured → the app falls back
/// to `DisabledAdvisor` and no request is ever made.
///
/// `baseURL` defaults to Anthropic directly, but can be pointed at your own
/// backend proxy — **strongly recommended for production**, so the API key
/// isn't embedded in the shipped app binary (see README).
struct ClaudeConfig: Sendable {
    let baseURL: URL
    let apiKey: String
    /// Model id. Opus is the most capable for honest, nuanced reviews; switch to
    /// `claude-sonnet-5` or `claude-haiku-4-5` to trade some quality for cost.
    let model: String

    var isConfigured: Bool { !apiKey.isEmpty }

    // Base URL is hardcoded (not read from Info.plist/xcconfig): xcconfig treats
    // "//" as a comment, so a URL stored there would be mangled to "https:". To
    // route through a backend proxy, change this default in code.
    static let shared = ClaudeConfig(
        baseURL: URL(string: "https://api.anthropic.com")!,
        apiKey: (Bundle.main.object(forInfoDictionaryKey: "ANTHROPIC_API_KEY") as? String) ?? "",
        model: "claude-opus-4-8"
    )
}
