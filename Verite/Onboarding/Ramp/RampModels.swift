import Foundation
import os

// ============================================================
// MARK: — Flow steps
// ============================================================

/// The ramp: spectacle (0–3) → investment (4–5) → momentum (6–9).
/// Quiz questions are separate steps (selection IS the advance) but share a
/// conceptual screen index for the progress bar.
enum RampStep: Int, CaseIterable {
    case coldOpen        // Screen 0 — non-interactive
    case claim           // Screen 1
    case proof           // Screen 2 — before/after theater
    case howItWorks      // Screen 3 — 3 beats
    case quizSelfRating  // Screen 4 — Q1
    case quizConcern     // Screen 4 — Q2
    case quizRoutine     // Screen 5 — Q3
    case quizSleep       // Screen 5 — Q4
    case quizSPF         // Screen 5 — Q5
    case calibrating     // Screen 6 — payoff
    case socialProof     // Screen 7
    case notifications   // Screen 8 — pre-prompt
    case scanRamp        // Screen 9 — handoff to Guided Capture

    var next: RampStep? { RampStep(rawValue: rawValue + 1) }

    /// Conceptual screen (0–9) for the segmented progress bar.
    var screenIndex: Int {
        switch self {
        case .coldOpen:                            return 0
        case .claim:                               return 1
        case .proof:                               return 2
        case .howItWorks:                          return 3
        case .quizSelfRating, .quizConcern:        return 4
        case .quizRoutine, .quizSleep, .quizSPF:   return 5
        case .calibrating:                         return 6
        case .socialProof:                         return 7
        case .notifications:                       return 8
        case .scanRamp:                            return 9
        }
    }

    var analyticsName: String {
        switch self {
        case .coldOpen:       return "cold_open"
        case .claim:          return "claim"
        case .proof:          return "proof"
        case .howItWorks:     return "how_it_works"
        case .quizSelfRating: return "quiz_self_rating"
        case .quizConcern:    return "quiz_concern"
        case .quizRoutine:    return "quiz_routine"
        case .quizSleep:      return "quiz_sleep"
        case .quizSPF:        return "quiz_spf"
        case .calibrating:    return "calibrating"
        case .socialProof:    return "social_proof"
        case .notifications:  return "notifications"
        case .scanRamp:       return "scan_ramp"
        }
    }

    /// How the persistent head is staged on this step.
    var headStage: HeadStage {
        switch self {
        case .coldOpen:
            return HeadStage(y: 0.05, scale: 1.0, spinDuration: 14, transitionDuration: 1.4)
        case .claim:
            return HeadStage(y: 1.0, z: -0.5, scale: 0.62, spinDuration: 14)
        case .proof:
            return HeadStage(y: 1.0, z: -0.5, scale: 0.62, opacity: 0, spinDuration: 14)
        case .howItWorks:
            return HeadStage(y: 0.35, scale: 0.85, spinDuration: 14)
        case .quizSelfRating, .quizConcern, .quizRoutine, .quizSleep, .quizSPF:
            // Small rotating watermark in the top corner — it "listens".
            return HeadStage(x: 0.62, y: 1.42, scale: 0.30, opacity: 0.55, spinDuration: 10)
        case .calibrating:
            return HeadStage(y: 0.1, scale: 1.0, spinDuration: 3.5)
        case .socialProof:
            return HeadStage(y: 0.1, scale: 1.0, opacity: 0, spinDuration: 14)
        case .notifications:
            return HeadStage(x: 0.60, y: 1.40, scale: 0.32, opacity: 0.6, spinDuration: 14)
        case .scanRamp:
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

    /// Labels absorbed into the head on the "Calibrating" screen.
    var chipLabels: [String] {
        [selfRating?.chip, concern?.chip, routine?.chip, sleep?.chip, spf?.chip]
            .compactMap { $0 }
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

/// Funnel measurement from day one: every screen advance and every quiz answer.
/// Currently emits structured os_log events (visible in Console/Instruments).
/// TODO(analytics): forward `track` to the production analytics provider once
/// one is wired up — the event vocabulary below is final.
enum RampAnalytics {
    private static let logger = Logger(subsystem: "com.verite.com", category: "onboarding.funnel")

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
    }
}
