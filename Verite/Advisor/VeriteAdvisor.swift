import Foundation

/// Vérité AI advisor: takes the user's skin summary + goal + candidate products
/// and returns the 3 best-fitting products with honest reviews. Off by default
/// (`DisabledAdvisor`); the Claude-backed impl only runs when enabled *and*
/// configured. Only numbers + text are sent — never a photo.
protocol VeriteAdvisorService: Sendable {
    var isEnabled: Bool { get }
    func recommend(_ request: AdvisorRequest) async throws -> AdvisorResult
}

struct DisabledAdvisor: VeriteAdvisorService {
    var isEnabled: Bool { false }
    func recommend(_ request: AdvisorRequest) async throws -> AdvisorResult {
        throw AdvisorError.notConfigured
    }
}

/// Claude-backed advisor. Assembles a strictly honesty-oriented prompt, asks for
/// a schema-constrained JSON answer, and decodes it.
struct ClaudeAdvisor: VeriteAdvisorService {
    let client: ClaudeClient

    var isEnabled: Bool { client.config.isConfigured }

    func recommend(_ request: AdvisorRequest) async throws -> AdvisorResult {
        guard isEnabled else { throw AdvisorError.notConfigured }
        guard !request.candidates.isEmpty else { throw AdvisorError.badResponse }

        let data = try await client.structuredCompletion(
            system: Self.systemPrompt,
            user: userPrompt(request),
            schema: Self.schema
        )
        return try JSONDecoder().decode(AdvisorResult.self, from: data)
    }

    // MARK: Prompt

    private static let systemPrompt = """
    You are Vérité's skincare advisor. Vérité's whole brand is radical honesty, \
    so you are blunt and evidence-cautious, never a hype machine.

    Rules:
    - Recommend ONLY from the candidate products provided. Never invent products.
    - Pick the 3 that best fit THIS user's skin and stated goal, ranked best first.
    - Be honest in every review: name the downsides, irritation risks, and \
    whether a cheaper/simpler option would do the same job. If a product is a \
    poor fit or overhyped, say so even while recommending it as the least-bad option.
    - Never promise results. Describe likely fit and mechanism ("niacinamide can \
    help with X"), not guarantees ("this will fix your acne"). Correlation, not causation.
    - You are not a doctor; give no medical/diagnostic claims. For anything that \
    sounds like a skin condition, suggest seeing a dermatologist.
    - Always remind the user to patch-test / run a half-face test before committing.
    - fit_score is 0-100 for how well the product suits this specific skin + goal.
    - Keep each field tight and specific to this user; no generic filler.
    """

    private func userPrompt(_ r: AdvisorRequest) -> String {
        var lines: [String] = []
        lines.append("USER SKIN SUMMARY:\n\(r.skinSummary)")

        var goals = r.goalLabels
        if !r.freeText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            goals.append("in their own words: \"\(r.freeText)\"")
        }
        lines.append("USER GOAL(S): " + (goals.isEmpty ? "general skin health" : goals.joined(separator: "; ")))

        lines.append("CANDIDATE PRODUCTS (choose 3, echo product_id exactly):")
        for c in r.candidates.prefix(30) {
            let actives = c.actives.isEmpty ? "none listed" : c.actives.joined(separator: ", ")
            let flags = c.riskFlags.isEmpty ? "none" : c.riskFlags.joined(separator: ", ")
            lines.append("- product_id=\(c.id) | \(c.brand) \(c.name) | actives: \(actives) | risk flags: \(flags) | comedogenic max: \(c.comedogenicMax)")
        }
        lines.append("Return exactly 3 recommendations ranked best-first, plus an honest overall_note.")
        return lines.joined(separator: "\n\n")
    }

    // MARK: Structured-output schema

    private static let schema: [String: Any] = [
        "type": "object",
        "additionalProperties": false,
        "required": ["recommendations", "overall_note"],
        "properties": [
            "recommendations": [
                "type": "array",
                "items": [
                    "type": "object",
                    "additionalProperties": false,
                    "required": ["product_id", "product_name", "fit_score", "why", "honest_review", "caution"],
                    "properties": [
                        "product_id": ["type": "string"],
                        "product_name": ["type": "string"],
                        "fit_score": ["type": "integer"],
                        "why": ["type": "string"],
                        "honest_review": ["type": "string"],
                        "caution": ["type": "string"],
                    ],
                ],
            ],
            "overall_note": ["type": "string"],
        ],
    ]
}
