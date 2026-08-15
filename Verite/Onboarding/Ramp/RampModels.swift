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
///   opening → the acne chapter (kind → how long → what you've tried →
///   what it costs → what we heard) → demo → questions → insights
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
    // THE ACNE CHAPTER. `acneType` used to hand straight over to
    // `sampleReading` — the user named the thing they came here about, and
    // the very next screen was a product demo. It reads as being cut off
    // mid-sentence: we asked the one question that matters and then changed
    // the subject to ourselves.
    //
    // These three questions and the interstitial that follows are the answer.
    // They ask how long it has been going on, what has already been tried,
    // and what it actually costs them — and then say something true back
    // before any product appears. Two of the three feed the plan (duration
    // sets the ramp, history keeps us from re-selling what already failed);
    // the third feeds nothing and is asked anyway, which is the point.
    case acneDuration    // 2  — how long has this been going on
    case acneTried       // 3  — what have you already tried
    case acneImpact      // 4  — how much does it get to you
    case acneEmpathy     // 5  — what we heard, said back
    case sampleReading   // 6  — the real results chart, previewed
    case theSplit        // 7  — what 14 days moves (interactive bars)
    case quizSelfRating  // 8  — Q · your skin
    case quizAge         // 9  — Q · your skin
    case insightSkin     // 10 — mirrored insight, chapter 1
    // Asked once, immediately after the first insight — so the name is given
    // in exchange for something, not before anything.
    case name            // 11 — "what should we call you?" (optional)
    case quizRoutine     // 12 — Q · your life
    case quizSleep       // 13 — Q · your life
    case quizSPF         // 14 — Q · your life
    case insightLife     // 15 — mirrored insight, chapter 2
    case sensitivities   // 16 — allergies the routine must avoid
    case brands          // 17 — what's already on the shelf (names, never logos)
    // Spend, then the loop it bought. Naming the monthly figure and THEN
    // naming the cycle it funded is the argument for a plan, made with the
    // user's own number rather than ours — and it is the anchor every later
    // price is read against.
    case spend           // 18 — what you already spend each month
    case theCycle        // 19 — the loop, named
    // The goal-setting act. Everything downstream — the curve, the plan, the
    // paywall headline — refers back to the sentence chosen here.
    case goal            // 20 — "what does better look like for you?"
    case theReading      // 21 — visible processing + prediction range
    case theCurve        // 22 — where do you land?
    case planPreview     // 23 — your first plan, previewed
    case evidence        // 24 — the science behind the plan (tappable sources)
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
    case attribution     // 25 — "where did you find us?" (marketing attribution)
    case commitment      // 26 — sign your 14-day commitment
    case dailyRitual     // 27 — time choice + notifications
    case signIn          // 28 — register before the first scan
    case handoff         // 29 — "now, the real you" → the scan

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
        case .acneDuration:   return "acne_duration"
        case .acneTried:      return "acne_tried"
        case .acneImpact:     return "acne_impact"
        case .acneEmpathy:    return "acne_empathy"
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

    /// How long the user has been living with this. The single most bonding
    /// question in the flow: everything before it asks what their skin looks
    /// like, this is the first one that asks what it has COST them. It also
    /// earns its place in the product — skin that has been breaking out for
    /// six years and skin that started three months ago are not the same
    /// starting point, and the plan's ramp reads this.
    enum AcneDuration: String, CaseIterable, Identifiable {
        case months, aboutAYear, fewYears, asLongAsIRemember
        var id: String { rawValue }
        var label: String {
            switch self {
            case .months:             return "A few months"
            case .aboutAYear:         return "About a year"
            case .fewYears:           return "A few years"
            case .asLongAsIRemember:  return "As long as I can remember"
            }
        }
        var icon: String {
            switch self {
            case .months:             return "calendar"
            case .aboutAYear:         return "calendar.badge.clock"
            case .fewYears:           return "clock.arrow.circlepath"
            case .asLongAsIRemember:  return "infinity"
            }
        }
        var chip: String {
            switch self {
            case .months:             return "A few months"
            case .aboutAYear:         return "~1 year"
            case .fewYears:           return "Years"
            case .asLongAsIRemember:  return "Always"
            }
        }
    }

    /// What they have already thrown at it. Multi-select, and deliberately
    /// specific: "drugstore products" and "a course of antibiotics" are
    /// wildly different histories, and a user who has done both has been at
    /// this long enough to be sick of being sold the first one again.
    enum AcneTried: String, CaseIterable, Identifiable {
        case drugstore, prescription, antibiotics, diet, dermatologist
        var id: String { rawValue }
        var label: String {
            switch self {
            case .drugstore:     return "Drugstore products"
            case .prescription:  return "Prescription creams"
            case .antibiotics:   return "Antibiotics or the pill"
            case .diet:          return "Changing what I eat"
            case .dermatologist: return "Seen a dermatologist"
            }
        }
        var icon: String {
            switch self {
            case .drugstore:     return "cart"
            case .prescription:  return "cross.case"
            case .antibiotics:   return "pills"
            case .diet:          return "fork.knife"
            case .dermatologist: return "stethoscope"
            }
        }
        /// Two or three words for the empathy screen's recap row, where the
        /// full label ("Antibiotics or the pill") would wrap a chip.
        var chip: String {
            switch self {
            case .drugstore:     return "Drugstore"
            case .prescription:  return "Prescriptions"
            case .antibiotics:   return "Antibiotics"
            case .diet:          return "Diet"
            case .dermatologist: return "Dermatologist"
            }
        }
    }

    /// The emotional weight, asked plainly. It changes no ingredient in the
    /// plan and it is told as much on the screen — what it changes is the
    /// voice everything downstream is written in, and whether the user feels
    /// like a case or a person by the time they reach the scan.
    enum AcneImpact: String, CaseIterable, Identifiable {
        case notMuch, someDays, moreThanILetOn, everyMirror
        var id: String { rawValue }
        var label: String {
            switch self {
            case .notMuch:        return "Not much, honestly"
            case .someDays:       return "Some days"
            case .moreThanILetOn: return "More than I let on"
            case .everyMirror:    return "Every time I pass a mirror"
            }
        }
        var icon: String {
            switch self {
            case .notMuch:        return "cloud"
            case .someDays:       return "cloud.sun"
            case .moreThanILetOn: return "cloud.rain"
            case .everyMirror:    return "cloud.bolt.rain"
            }
        }
        /// True for the two answers that mean this genuinely weighs on them —
        /// the empathy screen and the goal copy both branch on it.
        var isHeavy: Bool { self == .moreThanILetOn || self == .everyMirror }
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
    var age: AgeBand?
    var routine: RoutineLevel?
    var sleep: SleepBucket?
    var spf: SunProtection?
    var acneDuration: AcneDuration?
    /// Raw `AcneTried` values. Empty is a real answer ("Nothing yet"), so
    /// `sawAcneTried` is what says whether the question was actually asked.
    var acneTried: Set<String> = []
    var acneImpact: AcneImpact?
    var sawAcneTried = false
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
        [selfRating?.chip, acneTypeChip, routine?.chip, sleep?.chip, spf?.chip]
            .compactMap { $0 }
    }

    /// How many questions have actually been answered — read back verbatim
    /// on the reading screen ("Built from your N answers"), so the acne
    /// chapter has to count here or that line quietly under-reports.
    /// `acneTried` counts on `sawAcneTried`, not on emptiness: "nothing yet"
    /// is an answer.
    var answeredCount: Int {
        [selfRating != nil, !acneTypes.isEmpty, age != nil,
         routine != nil, sleep != nil, spf != nil,
         acneDuration != nil, sawAcneTried, acneImpact != nil]
            .filter { $0 }.count
    }

    // MARK: Mirrored insights (the "we're listening" interstitials)

    /// Chapter-1 insight: reflects the skin answer back — one short line.
    /// Pure template logic over the user's OWN answers — nothing fabricated.
    var skinInsight: String {
        if acneTypes.contains("cysts") {
            return "Deep breakouts take longer, but they respond to the right actives."
        } else if acneTypes.contains("papules") {
            return "Inflamed breakouts calm fastest of all the metrics we track."
        } else if acneTypes.contains("blackheads") || acneTypes.contains("whiteheads") {
            return "Breakouts respond fastest of all seven metrics."
        } else if acneTypes.contains("scars") {
            return "Marks fade slower than active breakouts, but they do fade."
        } else {
            return "The scan usually finds headroom you don't feel."
        }
    }

    // MARK: The acne chapter (bonding, not data collection)

    /// Chips for the empathy screen — their three acne answers, in the order
    /// they gave them.
    var acneChips: [String] {
        var chips: [String] = []
        if let acneTypeChip { chips.append(acneTypeChip) }
        if let acneDuration { chips.append(acneDuration.chip) }
        // Name the thing when there is one thing to name. "Tried 1" read as
        // a tally on a screen whose entire job is to prove we were listening
        // — the other two chips say what the user chose, and this one said
        // how many boxes they ticked. "Drugstore" is the same width and
        // actually repeats them back.
        let tried = acneTried.compactMap(AcneTried.init(rawValue:))
        if tried.count == 1, let only = tried.first {
            chips.append(only.chip)
        } else if tried.count > 1 {
            chips.append("\(tried.count) things tried")
        }
        return chips
    }

    /// The headline of the empathy screen. Every branch is a statement about
    /// what the user just told us — never a claim about what the app will
    /// do, and never a number. The whole screen exists so the flow stops
    /// feeling like a form the moment before it starts showing product.
    var acneEmpathyHeadline: String {
        if acneDuration == .asLongAsIRemember || acneDuration == .fewYears,
           acneTried.count >= 2 {
            return "Years of trying things\nthat didn't hold."
        }
        if acneTried.count >= 3 {
            return "You've tried more\nthan most people ever do."
        }
        if acneImpact?.isHeavy == true {
            return "It's not vanity.\nIt takes up room."
        }
        if acneTried.isEmpty && sawAcneTried {
            return "Starting clean is\nan advantage."
        }
        return "That's more than\nmost scans ever ask."
    }

    /// The supporting paragraph. Same rule: honest framing of their own
    /// answer, no promise attached.
    var acneEmpathyBody: String {
        if acneTried.isEmpty && sawAcneTried {
            return "Nothing to undo, no half-finished routine to unpick. We can put the right things in the right order from day one — which is most of the battle."
        }
        if acneTried.count >= 2 {
            return "When something works for a few weeks and then stops, it usually wasn't the wrong product. It was a routine that never adjusted. That's the part a plan is actually for."
        }
        if acneImpact?.isHeavy == true {
            return "Skin you think about every morning costs you something real, and it's the part almost every skincare app skips straight past. We'd rather start there."
        }
        return "Most apps ask what your skin looks like and stop. What it's been like to live with is the part that decides whether a plan is worth following."
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
        if acneTypes.contains("cysts") {
            center -= 5
        } else if acneTypes.contains("papules") {
            center -= 3
        } else if acneTypes.contains("blackheads") || acneTypes.contains("whiteheads") {
            center -= 2
        } else if acneTypes.contains("scars") {
            center -= 1
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

    /// Brand IDs the user already owns (`RampBrandScreen.Brand.id`, e.g.
    /// "cerave") — resolved back to display names in `apply(to:)`.
    var brands: Set<String> = []

    /// `profile.concerns` — read by the real routine builder
    /// (`DermiqModels.swift`'s canonical-routine `promote` logic) — used to
    /// take its signal from the broad "what draws your eye" question. That
    /// question is gone; this is what replaced it. More specific than that
    /// question ever was: a papule and a cyst both said "breakouts" there,
    /// but only one needs a stronger active than the other.
    var impliedConcerns: [SkinConcern] {
        var result: [SkinConcern] = []
        if !acneTypes.isDisjoint(with: ["blackheads", "whiteheads", "papules", "cysts"]) {
            result.append(.acne)
        }
        if acneTypes.contains("scars") {
            result.append(.hyperpigmentation)
        }
        return result
    }

    /// Single source for the acne-type answer as a short display label —
    /// used as the plan-preview focus chip, the reading-screen answer chip,
    /// and `chipLabels` below. Priority follows severity, same as
    /// `impliedConcerns`.
    var acneTypeChip: String? {
        if acneTypes.contains("cysts")      { return "Deep breakouts" }
        if acneTypes.contains("papules")    { return "Red bumps" }
        if acneTypes.contains("blackheads") { return "Blackheads" }
        if acneTypes.contains("whiteheads") { return "Whiteheads" }
        if acneTypes.contains("scars")      { return "Scarring" }
        return nil
    }

    /// Index into the spend screen's buckets, not an amount. Kept as a bucket
    /// because nobody knows this figure precisely, and a number implying they
    /// do would be a false record.
    var spendBucket: Int = 2

    /// Set once the sensitivity screen has been seen. An EMPTY set is a real
    /// answer there ("Nothing I know of"), so emptiness alone can't tell us
    /// whether the question was asked — this flag can.
    var sawSensitivities = false

    func apply(to profile: UserProfile) {
        for mapped in impliedConcerns where !profile.concerns.contains(mapped) {
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
        if let goal { profile.goal = goal.label }
        // Resolve the picked brand IDs back to display names for the
        // routine-conflict check — was collected and written to
        // UserDefaults for analytics only, never to the profile that
        // actually feeds the routine builder.
        if !brands.isEmpty {
            let names = RampBrandScreen.brands.filter { brands.contains($0.id) }.map(\.name)
            if !names.isEmpty { profile.currentProducts = names }
        }
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
