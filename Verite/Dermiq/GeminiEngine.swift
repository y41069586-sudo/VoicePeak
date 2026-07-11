import UIKit

// ============================================================
// MARK: — Live "Potential" enhancement: Google Gemini (nano banana)
// ============================================================
//
// Image-in / image-out edit with gemini-2.5-flash-image. We hand it the
// user's own photo plus a strict identity-preservation instruction and it
// returns the same face with the skin brought to a realistic optimum. On any
// failure it throws, and ScanFlowModel falls back to MockEnhancementEngine
// (the on-device retouch), so the Potential reveal never dead-ends.
//
// Endpoint (verified):
//   POST https://generativelanguage.googleapis.com/v1beta/models/
//        gemini-2.5-flash-image:generateContent
//   header  x-goog-api-key: <key>
//   body    { contents:[{ parts:[ {text}, {inline_data:{mime_type,data}} ] }] }
//   reply   candidates[].content.parts[].inlineData.data  (base64 image)

final class GeminiEnhancementEngine: FaceEnhancementEngine {

    private static let model = "gemini-2.5-flash-image"
    private static let endpoint =
        "https://generativelanguage.googleapis.com/v1beta/models/\(model):generateContent"

    /// IDENTITY PRESERVATION IS NON-NEGOTIABLE. This exact instruction ships
    /// with every request: same person, same structure — only skin improved.
    static let identityPrompt = """
    Edit this exact photograph. Enhance ONLY the skin of this exact person. \
    Preserve identity completely: same person, same facial structure, same \
    angle, same lighting, same expression, same hair, same background. Improve \
    ONLY skin clarity, texture, tone evenness, and glow to a realistic, natural \
    optimal state — no makeup, no reshaping. Never alter bone structure, eyes, \
    nose, lips, hair, or face shape. Return the edited photograph.
    """

    func enhance(image: UIImage) async throws -> UIImage {
        guard DermiqConfig.hasLiveEnhancement,
              let url = URL(string: Self.endpoint),
              let jpeg = image.jpegData(compressionQuality: 0.9) else {
            throw DermiqEngineError.notConfigured
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 60
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(DermiqSecrets.geminiAPIKey, forHTTPHeaderField: "x-goog-api-key")

        let textPart: [String: Any] = ["text": Self.identityPrompt]
        let imagePart: [String: Any] = [
            "inline_data": ["mime_type": "image/jpeg", "data": jpeg.base64EncodedString()],
        ]
        let content: [String: Any] = ["parts": [textPart, imagePart]]
        let body: [String: Any] = [
            "contents": [content],
            "generationConfig": ["responseModalities": ["IMAGE"]],
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            let code = (response as? HTTPURLResponse)?.statusCode ?? -1
            print("[Gemini] HTTP \(code): \(String(data: data.prefix(400), encoding: .utf8) ?? "<binary>")")
            throw DermiqEngineError.badResponse
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let base64 = Self.firstImage(in: json),
              let imageData = Data(base64Encoded: base64),
              let result = UIImage(data: imageData) else {
            print("[Gemini] no image part in response: \(String(data: data.prefix(400), encoding: .utf8) ?? "")")
            throw DermiqEngineError.badResponse
        }
        return result
    }

    /// Pull the first inline image out of candidates → content → parts.
    /// The reply uses camelCase `inlineData`; accept snake_case too for safety.
    private static func firstImage(in json: [String: Any]) -> String? {
        guard let candidates = json["candidates"] as? [[String: Any]] else { return nil }
        for candidate in candidates {
            let content = candidate["content"] as? [String: Any]
            let parts = content?["parts"] as? [[String: Any]] ?? []
            for part in parts {
                let inline = (part["inlineData"] ?? part["inline_data"]) as? [String: Any]
                if let base64 = inline?["data"] as? String { return base64 }
            }
        }
        return nil
    }
}
