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
    /// with every request. Structure matters for nano banana: an explicit
    /// edit framing, a hard identity contract, a whitelist of the ONLY
    /// allowed changes, and a realism anchor — so the result reads as the
    /// same photo on the person's best skin day, never a beauty filter.
    static let identityPrompt = """
    Edit this photograph. This is a skin-retouching task only.

    THE PERSON MUST REMAIN 100% IDENTICAL AND RECOGNIZABLE — treat this as \
    the same photo of the same person, taken on the same day:
    - Do not change face shape, bone structure, jawline, cheekbones, chin, \
    forehead, ears, nose, lips, teeth, or eyes (same iris color, same eye \
    shape, same eyebrows).
    - Do not change hair (same hairstyle, hairline, color, individual \
    strands), facial hair, makeup level, or facial expression.
    - Do not change head pose, camera angle, framing, crop, background, \
    clothing, jewelry, or the lighting's direction and color temperature.
    - Do not slim, reshape, or beautify any facial proportions. No \
    digital-art or beauty-filter look.

    CRITICAL — PRESERVE PERMANENT SKIN FEATURES PIXEL-FOR-PIXEL. These are \
    NOT blemishes and must stay exactly where they are, same size, shape, \
    color and count. Do not fade, shrink, blur, or remove any of them:
    - Moles and beauty marks (raised or flat, any color).
    - Freckles and the person's natural freckle pattern.
    - Birthmarks and permanent scars.
    - Natural skin lines, dimples, and pore structure.
    If you are unsure whether a mark is a temporary blemish or a permanent \
    feature, KEEP IT. Removing a mole or freckle destroys the person's \
    identity — that is a failure, not an improvement.

    CHANGE ONLY THE TEMPORARY SKIN CONDITION, as if this person had followed \
    a perfect skincare routine for two weeks. Only these transient issues may \
    be improved — everything else stays untouched:
    - Heal only active breakouts: pimples, whiteheads, pustules, acne spots, \
    and inflamed irritation. A flat brown mole or a freckle is never a \
    "spot" — leave it in place.
    - Calm diffuse redness around the nose, cheeks, and chin to an even, \
    healthy tone.
    - Even out patchy pigmentation and dark post-acne marks, while keeping \
    the person's natural skin tone and undertone at exactly the same depth — \
    never lighten or darken the overall complexion.
    - Slightly refine visible pores and rough texture in the T-zone; up \
    close the skin still shows realistic pores and fine natural texture.
    - Add a healthy, hydrated glow: subtle natural light reflection on the \
    high points (forehead, cheekbones, nose bridge), like well-moisturized \
    real skin — not oily shine, not a blur filter, not porcelain smoothing.
    - Slightly reduce dark under-eye tint, keeping natural under-eye anatomy.

    The result must look like a real, unedited photograph of this same \
    person on their best skin day — natural photo grain, realistic texture, \
    believable as a dermatologist's after-photo. Return only the edited \
    photograph.
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
