import Foundation

/// Minimal client for Anthropic's Messages API (`POST /v1/messages`). Swift has
/// no official Anthropic SDK, so this speaks the raw HTTP shape. Uses structured
/// outputs (`output_config.format`) so the model returns JSON that validates
/// against a schema — no brittle text parsing.
///
/// Security note: this sends the API key directly from the device. That's fine
/// for local testing, but for a shipped app point `ClaudeConfig.baseURL` at your
/// own backend proxy instead, so the key isn't extractable from the binary
/// (see Advisor/README.md).
struct ClaudeClient {
    let config: ClaudeConfig

    /// Send a single-turn request and return the model's JSON text (the first
    /// text content block), which structured outputs guarantees matches `schema`.
    func structuredCompletion(system: String,
                              user: String,
                              schema: [String: Any],
                              maxTokens: Int = 3000) async throws -> Data {
        guard let url = URL(string: "/v1/messages", relativeTo: config.baseURL) else {
            throw AdvisorError.badResponse
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 45
        request.setValue(config.apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.setValue("application/json", forHTTPHeaderField: "content-type")

        let body: [String: Any] = [
            "model": config.model,
            "max_tokens": maxTokens,
            "system": system,
            "messages": [["role": "user", "content": user]],
            "output_config": [
                "format": ["type": "json_schema", "schema": schema]
            ],
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw AdvisorError.http(http.statusCode)
        }

        let decoded = try JSONDecoder().decode(AnthropicMessage.self, from: data)
        guard let text = decoded.content.first(where: { $0.type == "text" })?.text,
              let jsonData = text.data(using: .utf8) else {
            throw AdvisorError.badResponse
        }
        return jsonData
    }

    // MARK: Wire model (only the fields we read)

    private struct AnthropicMessage: Decodable {
        struct Block: Decodable { let type: String; let text: String? }
        let content: [Block]
        let stopReason: String?
        enum CodingKeys: String, CodingKey {
            case content
            case stopReason = "stop_reason"
        }
    }
}
