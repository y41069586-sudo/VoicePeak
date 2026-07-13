import Foundation
import SwiftData

// ============================================================
// MARK: — AI routine review (Gemini text, hybrid safety model)
// ============================================================
//
// The rule engine builds the SAFE plan (products, ordering, dosing tiers).
// Gemini then reviews it: sanity-checks the combination, rewrites each
// step's "why" so it speaks to THIS user's actual scores and quiz answers,
// and writes a short personal summary — in the user's language. The AI can
// polish and explain; it can never invent or swap products. On any failure
// (no key, offline, quota) the plan simply stays rule-worded — nothing
// breaks, the badge just doesn't appear.
//
// Text calls on gemini-2.5-flash are free-tier — unlike image generation,
// no billing account is required.

enum RoutineAIReview {

    private static let model = "gemini-2.5-flash"
    private static let endpoint =
        "https://generativelanguage.googleapis.com/v1beta/models/\(model):generateContent"

    // MARK: Storage (summary + badge, keyed per plan — no schema change)

    private static func summaryKey(_ plan: RoutinePlan) -> String {
        "dq.ai.summary.\(plan.id.uuidString)"
    }

    /// The AI's personal summary for this plan, if the check succeeded.
    static func summary(for plan: RoutinePlan) -> String? {
        let value = UserDefaults.standard.string(forKey: summaryKey(plan))
        return (value?.isEmpty == false) ? value : nil
    }

    // MARK: Kickoff (fire-and-forget from createPlan)

    /// Runs the review in the background and applies it to the plan.
    /// Safe to call always — exits silently without a key.
    @MainActor
    static func kickoff(plan: RoutinePlan, analysis: DermiqAnalysis, context: ModelContext) {
        guard !DermiqSecrets.geminiAPIKey.isEmpty else { return }
        let prefs = SkinPrefs.load()
        let planID = plan.id
        Task { @MainActor in
            do {
                let review = try await request(analysis: analysis, prefs: prefs,
                                               am: plan.steps(.am), pm: plan.steps(.pm))
                // Re-fetch by id — the plan may have been replaced meanwhile.
                let all = (try? context.fetch(FetchDescriptor<RoutinePlan>())) ?? []
                guard let target = all.first(where: { $0.id == planID }) else { return }
                apply(review, to: target)
                try? context.save()
                UserDefaults.standard.set(review.summary, forKey: summaryKey(target))
                DermiqDiagnostics.record("AI routine check ✓ — \(review.steps.count) steps personalized")
            } catch {
                DermiqDiagnostics.record("AI routine check skipped: \(error.localizedDescription)")
            }
        }
    }

    // MARK: Model call

    struct Review: Decodable {
        struct StepWhy: Decodable {
            let key: String
            let why: String
        }
        let ok: Bool
        let steps: [StepWhy]
        let summary: String
    }

    static func request(
        analysis: DermiqAnalysis,
        prefs: SkinPrefs?,
        am: [RoutineStep],
        pm: [RoutineStep]
    ) async throws -> Review {
        let language = Locale.current.language.languageCode?.identifier ?? "en"
        let scores = analysis.subScores
            .map { "\($0.category.rawValue): \($0.value)" }
            .joined(separator: ", ")
        func describe(_ steps: [RoutineStep]) -> String {
            steps.map { step in
                let cadence = RoutineSchedule.frequencyLabel(for: step) ?? "daily"
                return "- key=\(step.key) | \(step.productType) | active: \(step.active) | cadence: \(cadence)"
            }.joined(separator: "\n")
        }
        let quiz = prefs.map {
            "Skin feel: \($0.feel.rawValue). Current concern: \($0.concern.rawValue)."
        } ?? "No questionnaire answers."

        let prompt = """
        You are a dermatology-informed skincare assistant reviewing a 14-day \
        routine that was generated from a real AI face scan.

        USER DATA
        Overall skin score: \(analysis.overall)/100.
        Sub-scores (0-100, higher is better): \(scores).
        Skin type: \(analysis.skinType.rawValue). \(quiz)

        THE PLAN
        Morning:
        \(describe(am))
        Evening:
        \(describe(pm))

        YOUR TASK
        1. Sanity-check the plan (ordering, no unsafe active combinations). \
        Assume the product selection itself is fixed — do NOT add, remove or \
        replace products.
        2. For EVERY step key, write ONE short "why" sentence (max 18 words) \
        that is personal and concrete: reference the user's actual scores or \
        questionnaire answers where relevant. Friendly, direct, no fluff.
        3. Write a personal 2–3 sentence summary of the plan: what it targets \
        first and what the user should expect by day 14. Honest, motivating, \
        no medical claims, no exclamation marks.
        Write ALL text in this language: \(language).

        Respond with ONLY this JSON, nothing else:
        {"ok": true, "steps": [{"key": "<step key>", "why": "<sentence>"}], \
        "summary": "<2-3 sentences>"}
        """

        var request = URLRequest(url: URL(string: endpoint)!)
        request.httpMethod = "POST"
        request.timeoutInterval = 20
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(DermiqSecrets.geminiAPIKey, forHTTPHeaderField: "x-goog-api-key")
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "contents": [["parts": [["text": prompt]]]],
            "generationConfig": [
                "responseMimeType": "application/json",
                "temperature": 0.4,
            ],
        ])

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw DermiqEngineError.badResponse
        }
        // Reply shape: candidates[0].content.parts[0].text = the JSON string.
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let candidates = json["candidates"] as? [[String: Any]],
              let content = candidates.first?["content"] as? [String: Any],
              let parts = content["parts"] as? [[String: Any]],
              let text = parts.first?["text"] as? String,
              let payload = text.data(using: .utf8)
        else { throw DermiqEngineError.badResponse }

        return try JSONDecoder().decode(Review.self, from: payload)
    }

    // MARK: Apply (rewrites only the why-lines, never the products)

    private static func apply(_ review: Review, to plan: RoutinePlan) {
        let whys = Dictionary(uniqueKeysWithValues: review.steps.map { ($0.key, $0.why) })
        func rewrite(_ steps: [RoutineStep]) -> [RoutineStep] {
            steps.map { step in
                guard let why = whys[step.key], !why.isEmpty else { return step }
                return RoutineStep(
                    key: step.key,
                    productType: step.productType,
                    active: step.active,
                    why: why,
                    examples: step.examples
                )
            }
        }
        if let am = try? JSONEncoder().encode(rewrite(plan.steps(.am))) {
            plan.amJSON = am
        }
        if let pm = try? JSONEncoder().encode(rewrite(plan.steps(.pm))) {
            plan.pmJSON = pm
        }
    }
}
