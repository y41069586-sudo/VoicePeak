import Foundation
import os

// ============================================================
// MARK: — Flow steps
// ============================================================

/// Vérité onboarding — "Lumière". A calm ritual: a soft opening, a serif
/// promise, a personalized score range, and a handoff to the real scan. The
/// luminous Teint-Orb lives behind every screen and only re-stages between
/// them.
///
///   opening → number → split → 5 questions → the reading → the curve
///   → daily ritual → handoff (the scan).
///
/// Quiz selection IS the advance. (Case names are kept stable so analytics and
/// the routing stay compatible with earlier builds.)
enum RampStep: Int, CaseIterable {
    case boot            // 0  — opening
    case sampleReading   // 1  — an illustrative reading card (the outcome, first)
    case theNumber       // 2  — the number, calmly
    case theSplit        // 3  — what 14 days moves (interactive bars)
    case name            // 4  — "what should we call you?" (optional)
    case quizSelfRating  // 5  — Q1 · your skin
    case quizConcern     // 6  — Q2 · your skin
    case quizAge         // 7  — Q3 · your skin
    case insightSkin     // 8  — mirrored insight, chapter 1
    case quizRoutine     // 9  — Q4 · your life
    case quizSleep       // 10 — Q5 · your life
    case quizSPF         // 11 — Q6 · your life
    case insightLife     // 12 — mirrored insight, chapter 2
    case theReading      // 13 — visible processing + prediction range
    case theCurve        // 14 — where do you land?
    case planPreview     // 15 — your first plan, previewed
    case commitment      // 16 — sign your 14-day commitment
    case dailyRitual     // 17 — time choice + notifications
    case signIn          // 18 — register before the first scan
    case handoff         // 19 — "now, the real you" → the scan

    var next: RampStep? { RampStep(rawValue: rawValue + 1) }

    /// True for the six interrogation questions.
    var isQuiz: Bool {
        switch self {
        case .quizSelfRating, .quizConcern, .quizAge,
             .quizRoutine, .quizSleep, .quizSPF:
            return true
        default:
            return false
        }
    }

    /// Conceptual screen index (0…19) for the progress hairline.
    var screenIndex: Int { rawValue }

    var analyticsName: String {
        switch self {
        case .boot:           return "boot"
        case .sampleReading:  return "sample_reading"
        case .theNumber:      return "the_number"
        case .theSplit:       return "the_split"
        case .name:           return "name"
        case .quizSelfRating: return "quiz_self_rating"
        case .quizConcern:    return "quiz_concern"
        case .quizAge:        return "quiz_age"
        case .insightSkin:    return "insight_skin"
        case .quizRoutine:    return "quiz_routine"
        case .quizSleep:      return "quiz_sleep"
        case .quizSPF:        return "quiz_spf"
        case .insightLife:    return "insight_life"
        case .theReading:     return "the_reading"
        case .theCurve:       return "the_curve"
        case .planPreview:    return "plan_preview"
        case .commitment:     return "commitment"
        case .dailyRitual:    return "daily_ritual"
        case .signIn:         return "sign_in"
        case .handoff:        return "handoff"
        }
    }

}

// ============================================================
// MARK: — Quiz answers
// ============================================================

/// Everything the user invests during screens 4–5. Persisted onto
/// `UserProfile` at completion so the routine/plan generation (master prompt
/// Screen 6) and the Match engine can visibly reflect it.
struct RampQuizAnswers {

    enum SelfRating: String, CaseIterable, Identifiable {
        case rough, average, decent, honestlyGood
        var id: String { rawValue }
        var label: String {
            switch self {
            case .rough:        return "Rough patch"
            case .average:      return "Average"
            case .decent:       return "Decent"
            case .honestlyGood: return "Honestly good"
            }
        }
        var chip: String { label }
    }

    enum MirrorConcern: String, CaseIterable, Identifiable {
        case breakouts, redness, pores, texture, dullness, nothing
        var id: String { rawValue }
        var label: String {
            switch self {
            case .breakouts: return "Breakouts"
            case .redness:   return "Redness"
            case .pores:     return "Pores"
            case .texture:   return "Texture"
            case .dullness:  return "Dullness"
            case .nothing:   return "Nothing specific"
            }
        }
        var icon: String {
            switch self {
            case .breakouts: return "allergens"
            case .redness:   return "flame"
            case .pores:     return "circle.grid.3x3"
            case .texture:   return "square.stack.3d.up"
            case .dullness:  return "cloud"
            case .nothing:   return "checkmark.seal"
            }
        }
        var chip: String? { self == .nothing ? nil : label }
        /// Maps onto the app-wide `SkinConcern` vocabulary the Match engine reads.
        var skinConcern: SkinConcern? {
            switch self {
            case .breakouts: return .acne
            case .redness:   return .redness
            case .pores:     return .pores
            case .texture:   return .texture
            case .dullness:  return .dullness
            case .nothing:   return nil
            }
        }
    }

    enum RoutineLevel: String, CaseIterable, Identifiable {
        case nothing, cleanserOnly, threePlus, fullStack
        var id: String { rawValue }
        var label: String {
            switch self {
            case .nothing:      return "Nothing"
            case .cleanserOnly: return "Just cleanser"
            case .threePlus:    return "3+ products"
            case .fullStack:    return "Full stack"
            }
        }
        var chip: String { label + " routine" }
    }

    enum SleepBucket: String, CaseIterable, Identifiable {
        case under6, sixToSeven, sevenToEight, eightPlus
        var id: String { rawValue }
        var label: String {
            switch self {
            case .under6:       return "Under 6h"
            case .sixToSeven:   return "6–7h"
            case .sevenToEight: return "7–8h"
            case .eightPlus:    return "8h+"
            }
        }
        var chip: String { label + " sleep" }
    }

    enum SunProtection: String, CaseIterable, Identifiable {
        case daily, sometimes, whatsSPF
        var id: String { rawValue }
        var label: String {
            switch self {
            case .daily:     return "Daily"
            case .sometimes: return "Sometimes"
            case .whatsSPF:  return "What's SPF"
            }
        }
        var chip: String {
            switch self {
            case .daily:     return "SPF daily"
            case .sometimes: return "SPF sometimes"
            case .whatsSPF:  return "No SPF yet"
            }
        }
    }

    enum AgeBand: String, CaseIterable, Identifiable {
        case under25, from25to34, from35to44, over45
        var id: String { rawValue }
        var label: String {
            switch self {
            case .under25:    return "Under 25"
            case .from25to34: return "25 – 34"
            case .from35to44: return "35 – 44"
            case .over45:     return "45+"
            }
        }
        var chip: String { label }
    }

    /// Optional first name — personalizes copy from the quiz onward.
    var name: String?
    var selfRating: SelfRating?
    var concern: MirrorConcern?
    var age: AgeBand?
    var routine: RoutineLevel?
    var sleep: SleepBucket?
    var spf: SunProtection?

    /// Trimmed display name, nil when empty/skipped.
    var displayName: String? {
        guard let trimmed = name?.trimmingCharacters(in: .whitespacesAndNewlines),
              !trimmed.isEmpty else { return nil }
        return trimmed
    }

    /// Labels absorbed into the head on the "Twin complete" screen.
    var chipLabels: [String] {
        [selfRating?.chip, concern?.chip, routine?.chip, sleep?.chip, spf?.chip]
            .compactMap { $0 }
    }

    /// How many of the five questions have been answered.
    var answeredCount: Int {
        [selfRating != nil, concern != nil, age != nil,
         routine != nil, sleep != nil, spf != nil]
            .filter { $0 }.count
    }

    // MARK: Mirrored insights (the "we're listening" interstitials)

    /// Chapter-1 insight: reflects the skin answer back — one short line.
    /// Pure template logic over the user's OWN answers — nothing fabricated.
    var skinInsight: String {
        switch concern {
        case .redness?:   return "Redness is usually barrier-related — and recoverable."
        case .breakouts?: return "Breakouts respond fastest of all seven metrics."
        case .pores?:     return "Pores are texture and oil — both trainable."
        case .texture?:   return "Texture moves slowest, but most reliably."
        case .dullness?:  return "Dullness is buildup and hydration — a quick win."
        case .nothing?, nil:
            return "The scan usually finds headroom you don't feel."
        }
    }

    /// Chapter-2 insight: connects a lifestyle answer to the score — one line.
    var lifeInsight: String {
        switch (sleep, spf) {
        case (.under6?, .whatsSPF?), (.sixToSeven?, .whatsSPF?):
            return "Short sleep + no SPF cost the most — and win back fastest."
        case (_, .whatsSPF?):
            return "No SPF is the biggest lever in your answers."
        case (.under6?, _), (.sixToSeven?, _):
            return "Short sleep shows up in glow and redness first."
        default:
            return "Your habits protect your baseline — we aim above it."
        }
    }

    /// A plausible, personalized score band derived from the answers — the
    /// engine's estimate *before* it has seen a real photo. The whole point of
    /// the "Twin complete" screen: a range is an open wound only the scan can
    /// close. Deterministic (no fabricated precision — it's framed as a model
    /// estimate), and every lever the quiz asked about visibly moves it.
    var predictedRange: (low: Int, high: Int) {
        var center = 70.0

        switch selfRating {
        case .rough?:        center -= 11
        case .average?:      center -= 3
        case .decent?:       center += 4
        case .honestlyGood?: center += 9
        case nil:            break
        }
        switch routine {
        case .nothing?:      center -= 6
        case .cleanserOnly?: center -= 2
        case .threePlus?:    center += 3
        case .fullStack?:    center += 6
        case nil:            break
        }
        switch sleep {
        case .under6?:       center -= 5
        case .sixToSeven?:   center -= 1
        case .sevenToEight?: center += 3
        case .eightPlus?:    center += 5
        case nil:            break
        }
        switch spf {
        case .daily?:        center += 7
        case .sometimes?:    center += 1
        case .whatsSPF?:     center -= 6
        case nil:            break
        }
        switch concern {
        case .breakouts?, .redness?, .texture?: center -= 3
        case .pores?, .dullness?:               center -= 2
        case .nothing?:                         center += 2
        case nil:                               break
        }
        switch age {
        case .under25?:    center += 2
        case .from25to34?: center += 1
        case .from35to44?: break
        case .over45?:     center -= 2
        case nil:          break
        }

        let low  = max(30, min(90, Int((center - 13).rounded())))
        let high = max(low + 6, min(97, Int((center + 10).rounded())))
        return (low, high)
    }

    /// Persist onto the SwiftData profile. The routine/plan generation and the
    /// Match engine read these fields — this is where quiz answers start
    /// influencing the product, not just the funnel.
    func apply(to profile: UserProfile) {
        if let mapped = concern?.skinConcern, !profile.concerns.contains(mapped) {
            profile.concerns.append(mapped)
        }
        profile.selfRating = selfRating?.rawValue
        profile.routineLevel = routine?.rawValue
        profile.sleepBucket = sleep?.rawValue
        profile.sunProtection = spf?.rawValue
        profile.displayName = displayName
        profile.ageBand = age?.rawValue
    }
}

// ============================================================
// MARK: — Funnel analytics
// ============================================================

/// Destination for analytics events. Register a production provider at launch
/// (`RampAnalytics.sink = AmplitudeSink()`); os_log always runs alongside it.
protocol AnalyticsSink: Sendable {
    func send(event: String, properties: [String: String])
}

/// Funnel measurement from day one: every screen advance and every quiz answer.
/// Always emits structured os_log events (visible in Console/Instruments) and
/// forwards to `sink` when a production provider is registered.
enum RampAnalytics {
    private static let logger = Logger(subsystem: "com.verite.com", category: "onboarding.funnel")

    /// Set once at app launch. `nonisolated(unsafe)` is the documented escape
    /// hatch for a write-once global — it is assigned before any event fires.
    nonisolated(unsafe) static var sink: AnalyticsSink?

    static func screen(_ step: RampStep) {
        track("onboarding_screen", ["screen": step.analyticsName,
                                    "index": String(step.screenIndex)])
    }

    static func quizAnswer(question: String, answer: String) {
        track("onboarding_quiz_answer", ["question": question, "answer": answer])
    }

    static func track(_ event: String, _ properties: [String: String] = [:]) {
        let payload = properties.sorted { $0.key < $1.key }
            .map { "\($0.key)=\($0.value)" }
            .joined(separator: " ")
        logger.info("\(event, privacy: .public) \(payload, privacy: .public)")
        sink?.send(event: event, properties: properties)
    }
}
