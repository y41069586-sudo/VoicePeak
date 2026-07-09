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
    case boot            // 0 — opening
    case theNumber       // 1 — the number, calmly
    case theSplit        // 2 — what 14 days moves (interactive bars)
    case quizSelfRating  // 3 — Q1
    case quizConcern     // 4 — Q2
    case quizRoutine     // 5 — Q3
    case quizSleep       // 6 — Q4
    case quizSPF         // 7 — Q5
    case twinComplete    // 8 — payoff + personalized prediction range
    case theCurve        // 9 — where do you land?
    case dailyReport     // 10 — notifications, reframed
    case handoff         // 11 — "awaiting original" → the scan

    var next: RampStep? { RampStep(rawValue: rawValue + 1) }

    /// True for the five interrogation questions.
    var isQuiz: Bool {
        switch self {
        case .quizSelfRating, .quizConcern, .quizRoutine, .quizSleep, .quizSPF:
            return true
        default:
            return false
        }
    }

    /// Conceptual screen index (0…11) for the segmented progress bar.
    var screenIndex: Int { rawValue }

    var analyticsName: String {
        switch self {
        case .boot:           return "boot"
        case .theNumber:      return "the_number"
        case .theSplit:       return "the_split"
        case .quizSelfRating: return "quiz_self_rating"
        case .quizConcern:    return "quiz_concern"
        case .quizRoutine:    return "quiz_routine"
        case .quizSleep:      return "quiz_sleep"
        case .quizSPF:        return "quiz_spf"
        case .twinComplete:   return "twin_complete"
        case .theCurve:       return "the_curve"
        case .dailyReport:    return "daily_report"
        case .handoff:        return "handoff"
        }
    }

    /// Where the luminous Teint-Orb sits on this step (screen space). It is the
    /// calm hero that lives behind every screen and only re-stages between them.
    var orbStage: RampOrbStage {
        switch self {
        case .boot:
            return RampOrbStage(yFraction: -0.06, scale: 1.0, opacity: 1.0)
        case .theNumber:
            return RampOrbStage(yFraction: -0.30, scale: 0.52, opacity: 0.9)
        case .theSplit:
            return RampOrbStage(yFraction: -0.08, scale: 1.0, opacity: 1.0)
        case .quizSelfRating, .quizConcern, .quizRoutine, .quizSleep, .quizSPF:
            // A small, calm presence near the top while questions are answered.
            return RampOrbStage(yFraction: -0.34, scale: 0.42, opacity: 0.85)
        case .twinComplete:
            return RampOrbStage(yFraction: -0.16, scale: 0.72, opacity: 1.0)
        case .theCurve:
            return RampOrbStage(yFraction: -0.36, scale: 0.4, opacity: 0.5, haloed: false)
        case .dailyReport:
            return RampOrbStage(yFraction: -0.33, scale: 0.44, opacity: 0.75)
        case .handoff:
            return RampOrbStage(yFraction: -0.04, scale: 1.15, opacity: 1.0)
        }
    }
}

/// Screen-space placement of the Teint-Orb for one step. `yFraction` is an
/// offset from the vertical centre as a fraction of the container height
/// (negative = up).
struct RampOrbStage {
    var yFraction: CGFloat = 0
    var scale: CGFloat = 1
    var opacity: CGFloat = 1
    var haloed: Bool = true
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

    var selfRating: SelfRating?
    var concern: MirrorConcern?
    var routine: RoutineLevel?
    var sleep: SleepBucket?
    var spf: SunProtection?

    /// Labels absorbed into the head on the "Twin complete" screen.
    var chipLabels: [String] {
        [selfRating?.chip, concern?.chip, routine?.chip, sleep?.chip, spf?.chip]
            .compactMap { $0 }
    }

    /// How many of the five questions have been answered.
    var answeredCount: Int {
        [selfRating != nil, concern != nil, routine != nil, sleep != nil, spf != nil]
            .filter { $0 }.count
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
