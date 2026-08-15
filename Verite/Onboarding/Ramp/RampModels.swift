import Foundation
import os

// ============================================================
// MARK: — Flow steps
// ============================================================

/// SkinFix onboarding — "Lumière". A calm ritual: a soft opening, a serif
/// promise, a personalized score range, and a handoff to the real scan. The
/// luminous Teint-Orb lives behind every screen and only re-stages between
/// them.
///
///   opening → acne type → demo → questions → insights
///   → spend → the loop → goal → the reading → the curve → the plan
///   → commitment → daily ritual → handoff (the scan).
///
/// Quiz selection IS the advance. (Case names are kept stable so analytics and
/// the routing stay compatible with earlier builds.)
enum RampStep: Int, CaseIterable {
    case boot            // 0  — opening carousel
    // Acne type comes FIRST, before anything is demonstrated — no broad
    // "what draws your eye" question ahead of it asking about concerns
    // (redness, pores, texture...) this screen can't actually use. It is
    // the one question the user actually came to answer, specifically, and
    // every screen after it can mirror it back. A demo shown before we know
    // what is wrong is a demo about somebody else.
    case acneType        // 1  — which kind, over photographs
    case sampleReading   // 2  — the real results chart, previewed
    case theSplit        // 3  — what 14 days moves (interactive bars)
    case quizSelfRating  // 4  — Q · your skin
    case quizAge         // 5  — Q · your skin
    case insightSkin     // 6  — mirrored insight, chapter 1
    // Asked once, immediately after the first insight — so the name is given
    // in exchange for something, not before anything.
    case name            // 7  — "what should we call you?" (optional)
    case quizRoutine     // 8  — Q · your life
    case quizSleep       // 9  — Q · your life
    case quizSPF         // 10 — Q · your life
    case insightLife     // 11 — mirrored insight, chapter 2
    case sensitivities   // 12 — allergies the routine must avoid
    case brands          // 13 — what's already on the shelf (names, never logos)
    // Spend, then the loop it bought. Naming the monthly figure and THEN
    // naming the cycle it funded is the argument for a plan, made with the
    // user's own number rather than ours — and it is the anchor every later
    // price is read against.
    case spend           // 14 — what you already spend each month
    case theCycle        // 15 — the loop, named
    // The goal-setting act. Everything downstream — the curve, the plan, the
    // paywall headline — refers back to the sentence chosen here.
    case goal            // 16 — "what does better look like for you?"
    case theReading      // 17 — visible processing + prediction range
    case theCurve        // 18 — where do you land?
    case planPreview     // 19 — your first plan, previewed
    case evidence        // 20 — the science behind the plan (tappable sources)
    // Attribution sits here, not at position 3 and not right after the
    // signature. It serves our reporting, not the user, so it used to sit at
    // position 3 — a screen that takes before anything has been given — and
    // then moved to right after `commitment`, which wedged an unrelated
    // marketing question between the moment the user signs their 14 days and
    // the moment they act on it (dailyRitual → signIn → handoff). By
    // `evidence`, real value has already been shown (a plan, the science
    // behind it), so the ask is earned here too — and putting it BEFORE
    // commitment means nothing interrupts the signature → reminder-time →
    // sign-in → scan run that follows.
    case attribution     // 21 — "where did you find us?" (marketing attribution)
    case commitment      // 22 — sign your 14-day commitment
    case dailyRitual     // 23 — time choice + notifications
    case signIn          // 24 — register before the first scan
    case handoff         // 25 — "now, the real you" → the scan

    var next: RampStep? { RampStep(rawValue: rawValue + 1) }
    var previous: RampStep? { RampStep(rawValue: rawValue - 1) }

    /// Conceptual screen index (0…18) for the progress hairline.
    var screenIndex: Int { rawValue }

    var analyticsName: String {
        switch self {
        case .boot:           return "boot"
        case .sampleReading:  return "sample_reading"
        case .theSplit:       return "the_split"
        case .attribution:    return "attribution"
        case .name:           return "name"
        case .quizSelfRating: return "quiz_self_rating"
        case .quizAge:        return "quiz_age"
        case .insightSkin:    return "insight_skin"
        case .quizRoutine:    return "quiz_routine"
        case .quizSleep:      return "quiz_sleep"
        case .quizSPF:        return "quiz_spf"
        case .insightLife:    return "insight_life"
        case .acneType:       return "acne_type"
        case .sensitivities:  return "sensitivities"
        case .brands:         return "brands"
        case .spend:          return "spend"
        case .theCycle:       return "the_cycle"
        case .goal:           return "goal"
        case .theReading:     return "the_reading"
        case .theCurve:       return "the_curve"
        case .planPreview:    return "plan_preview"
        case .evidence:       return "evidence"
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

    /// Marketing attribution: which channel brought this install. Self-reported
    /// but the only attribution iOS reliably allows — drives where the creator
    /// budget goes. Persisted durably under `dq.attribution.source`.
    enum AcquisitionSource: String, CaseIterable, Identifiable {
        case tiktok, instagram, youtube, friend, appstore, other
        var id: String { rawValue }
        var label: String {
            switch self {
            case .tiktok:    return "TikTok"
            case .instagram: return "Instagram"
            case .youtube:   return "YouTube"
            case .friend:    return "A friend told me"
            case .appstore:  return "App Store search"
            case .other:     return "Somewhere else"
            }
        }
        var icon: String {
            switch self {
            case .tiktok:    return "music.note"
            case .instagram: return "camera"
            case .youtube:   return "play.rectangle"
            case .friend:    return "person.2"
            case .appstore:  return "magnifyingglass"
            case .other:     return "ellipsis.circle"
            }
        }
    }

    /// Optional first name — personalizes copy from the quiz onward.
    var name: String?
    var acquisition: AcquisitionSource?
    var selfRating: SelfRating?
    var concern: MirrorConcern?
    var age: AgeBand?
    var routine: RoutineLevel?
    var sleep: SleepBucket?
    var spf: SunProtection?
    /// Ingredients the user reacts to (raw `SkinSensitivity` values) — the
    /// routine builder swaps these for gentle alternatives.
    var sensitivities: Set<String> = []

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
    /// What "better" means to this person, in their words. Chosen on the goal
    /// screen and repeated verbatim by the curve, the plan and the paywall —
    /// the ask stops being a generic trial prompt and becomes the delivery of
    /// the thing they said they wanted.
    enum Goal: String, CaseIterable, Identifiable {
        case fewerBreakouts, calmerSkin, evenTone, smootherTexture, notThinkAboutIt
        var id: String { rawValue }

        /// First person, present tense — the sentence they are choosing to own.
        var label: String {
            switch self {
            case .fewerBreakouts:   return "Fewer breakouts"
            case .calmerSkin:       return "Calmer, less angry skin"
            case .evenTone:         return "Marks that finally fade"
            case .smootherTexture:  return "Skin that feels smooth"
            case .notThinkAboutIt:  return "Skin I don't think about"
            }
        }

        /// Used mid-sentence, e.g. "Your 14-day plan for fewer breakouts".
        var phrase: String {
            switch self {
            case .fewerBreakouts:   return "fewer breakouts"
            case .calmerSkin:       return "calmer skin"
            case .evenTone:         return "fading marks"
            case .smootherTexture:  return "smoother skin"
            case .notThinkAboutIt:  return "skin you don't think about"
            }
        }

        var icon: String {
            switch self {
            case .fewerBreakouts:   return "allergens"
            case .calmerSkin:       return "flame"
            case .evenTone:         return "circle.lefthalf.filled"
            case .smootherTexture:  return "square.stack.3d.up"
            case .notThinkAboutIt:  return "checkmark.seal"
            }
        }

        /// Where the paywall and the results screen read it back from. Kept in
        /// UserDefaults rather than on `UserProfile` deliberately: it is copy
        /// input, not skin data, and it costs no SwiftData migration.
        static let storageKey = "dq.goal"

        static var stored: Goal? {
            UserDefaults.standard.string(forKey: storageKey).flatMap(Goal.init(rawValue:))
        }

        func store() { UserDefaults.standard.set(rawValue, forKey: Self.storageKey) }
    }

    var goal: Goal?

    /// Which kinds of acne were recognised on the photo grid. Multi-select —
    /// most skin carries more than one, and the routine builder branches on it.
    var acneTypes: Set<String> = []

    /// Brand names the user already owns. Names only — see RampBrandScreen
    /// for why this app never ships third-party logos.
    var brands: Set<String> = []

    /// Index into the spend screen's buckets, not an amount. Kept as a bucket
    /// because nobody knows this figure precisely, and a number implying they
    /// do would be a false record.
    var spendBucket: Int = 2

    /// Set once the sensitivity screen has been seen. An EMPTY set is a real
    /// answer there ("Nothing I know of"), so emptiness alone can't tell us
    /// whether the question was asked — this flag can.
    var sawSensitivities = false

    func apply(to profile: UserProfile) {
        if let mapped = concern?.skinConcern, !profile.concerns.contains(mapped) {
            profile.concerns.append(mapped)
        }
        // Write only what was actually answered. Onboarding can now be left
        // early — "Already have an account?" jumps from the intro straight to
        // sign-in — and a re-run from Settings starts against a profile that
        // already holds answers. Assigning the optionals unconditionally would
        // blank those out with the nils of questions that were never asked.
        if let selfRating { profile.selfRating = selfRating.rawValue }
        if let routine    { profile.routineLevel = routine.rawValue }
        if let sleep      { profile.sleepBucket = sleep.rawValue }
        if let spf        { profile.sunProtection = spf.rawValue }
        if let age        { profile.ageBand = age.rawValue }
        if let displayName, !displayName.isEmpty { profile.displayName = displayName }
        // Persist sensitivities for the routine builder (avoid flagged actives).
        if sawSensitivities {
            SkinSensitivities.save(Set(sensitivities.compactMap(SkinSensitivity.init(rawValue:))))
        }
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
