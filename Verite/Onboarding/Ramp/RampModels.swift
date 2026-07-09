import Foundation
import os

// ============================================================
// MARK: — Flow steps
// ============================================================

/// Vérité onboarding v3 — "The Twin". One story: the engine builds your
/// digital twin from a scatter of points, each answer materializes it further,
/// and the final scan replaces the twin with the real you.
///
///   boot → number → split → 5-question interrogation → twin complete
///   → the curve → daily report → handoff (the scan).
///
/// Quiz selection IS the advance; every answer raises twin integrity, which
/// visibly densifies the head (see `ScanHeadController.setTwinIntegrity`).
enum RampStep: Int, CaseIterable {
    case boot            // 0 — terminal boot + point-cloud assembly
    case theNumber       // 1 — scrambling score + foreign ticker + hold-to-begin
    case theSplit        // 2 — interactive day1 ↔ day14 slider through the head
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

    /// Steps where the user may grab the head and spin it with a horizontal
    /// drag. Disabled where a dedicated gesture owns the touch (hold-to-begin,
    /// the split slider) or choreography is running.
    var allowsHeadDrag: Bool {
        switch self {
        case .quizSelfRating, .quizConcern, .quizRoutine, .quizSleep, .quizSPF,
             .dailyReport, .handoff:
            return true
        case .boot, .theNumber, .theSplit, .twinComplete, .theCurve:
            return false
        }
    }

    /// Twin integrity (0…1) for this step given how many questions are
    /// answered. Drives both the HUD percentage and the head's densification.
    func twinIntegrity(answeredCount: Int) -> Double {
        switch self {
        case .boot:       return 0.06
        case .theNumber:  return 0.10
        case .theSplit:   return 0.14
        case .quizSelfRating, .quizConcern, .quizRoutine, .quizSleep, .quizSPF:
            return min(0.14 + 0.14 * Double(answeredCount), 0.86)
        case .twinComplete, .theCurve, .dailyReport, .handoff:
            return 1.0
        }
    }

    /// How the persistent head is staged on this step.
    var headStage: HeadStage {
        switch self {
        case .boot:
            return HeadStage(y: 0.05, scale: 1.0, spinDuration: 16, transitionDuration: 1.0)
        case .theNumber:
            // Faint behind the giant number.
            return HeadStage(y: 0.9, z: -0.6, scale: 0.6, opacity: 0.7, spinDuration: 18)
        case .theSplit:
            // Front and centre, held facing the camera so the two halves read.
            return HeadStage(y: 0.0, scale: 1.15, spinDuration: nil, transitionDuration: 1.0)
        case .quizSelfRating, .quizConcern, .quizRoutine, .quizSleep, .quizSPF:
            // Upper-right, present enough to watch it densify with each answer.
            return HeadStage(x: 0.52, y: 1.34, scale: 0.4, opacity: 0.85, spinDuration: 10)
        case .twinComplete:
            return HeadStage(y: 0.15, scale: 1.05, spinDuration: 3.5)
        case .theCurve:
            return HeadStage(x: 0.5, y: 1.5, scale: 0.32, opacity: 0.5, spinDuration: 20)
        case .dailyReport:
            return HeadStage(x: 0.58, y: 1.4, scale: 0.34, opacity: 0.65, spinDuration: 14)
        case .handoff:
            // Full screen; rotation decelerates and holds facing the user.
            return HeadStage(y: -0.05, z: 0.8, scale: 1.5, spinDuration: nil, transitionDuration: 1.2)
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
