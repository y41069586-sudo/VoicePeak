import Foundation
import SwiftData

// ============================================================
// MARK: — Skin Duel (serverless 14-day head-to-head)
// ============================================================
//
// A duel is fully local + link-based: two people each run their OWN 14-day
// plan (the normal scan → routine flow), then swap a self-contained "result
// card" link at the end. Whoever improved their overall score the most wins.
// No backend, no account — the payload travels inside the shared link.

/// A flat per-category score, small enough to ride inside a share link.
struct DuelScore: Codable, Hashable {
    var c: String   // DermiqCategory.rawValue
    var v: Int      // 0…100

    static func from(_ subs: [DermiqSubScore]) -> [DuelScore] {
        subs.map { DuelScore(c: $0.category.rawValue, v: $0.value) }
    }
}

/// Who came out ahead.
enum DuelOutcome {
    case pending      // still waiting on a final (mine or theirs)
    case win
    case loss
    case draw
}

@Model
final class SkinDuel {
    @Attribute(.unique) var id: UUID
    /// Short human code shared between the two players' local duels.
    var code: String
    var createdAt: Date
    /// My day 1 (start of day). Day index = whole days since + 1.
    var startDate: Date
    /// Filled once known (from the invite I accepted, or their result card).
    var opponentName: String

    // My side — baseline is captured at creation, final when I submit.
    var myName: String
    var myBaselineOverall: Int
    var myBaselineSubsJSON: Data
    var myFinalOverall: Int          // -1 until I submit
    var myFinalSubsJSON: Data

    // Opponent side — all -1 / empty until I import their result card.
    var opponentBaselineOverall: Int // -1 until imported
    var opponentFinalOverall: Int    // -1 until imported
    var opponentBaselineSubsJSON: Data
    var opponentFinalSubsJSON: Data

    /// True once the head-to-head reveal has been shown (so it plays once).
    var revealed: Bool

    init(
        id: UUID = UUID(),
        code: String,
        createdAt: Date = .now,
        startDate: Date = Calendar.current.startOfDay(for: .now),
        myName: String,
        opponentName: String = "",
        baselineOverall: Int,
        baselineSubs: [DuelScore]
    ) {
        self.id = id
        self.code = code
        self.createdAt = createdAt
        self.startDate = startDate
        self.myName = myName
        self.opponentName = opponentName
        self.myBaselineOverall = baselineOverall
        self.myBaselineSubsJSON = (try? JSONEncoder().encode(baselineSubs)) ?? Data()
        self.myFinalOverall = -1
        self.myFinalSubsJSON = Data()
        self.opponentBaselineOverall = -1
        self.opponentFinalOverall = -1
        self.opponentBaselineSubsJSON = Data()
        self.opponentFinalSubsJSON = Data()
        self.revealed = false
    }

    // MARK: Decoded access

    var myBaselineSubs: [DuelScore] { decode(myBaselineSubsJSON) }
    var myFinalSubs: [DuelScore] { decode(myFinalSubsJSON) }
    var opponentBaselineSubs: [DuelScore] { decode(opponentBaselineSubsJSON) }
    var opponentFinalSubs: [DuelScore] { decode(opponentFinalSubsJSON) }

    private func decode(_ data: Data) -> [DuelScore] {
        (try? JSONDecoder().decode([DuelScore].self, from: data)) ?? []
    }

    // MARK: Day math (mirrors RoutinePlan)

    /// 1-based day index, clamped to 1…14.
    func dayIndex(for date: Date = .now) -> Int {
        let days = Calendar.current.dateComponents(
            [.day], from: startDate,
            to: Calendar.current.startOfDay(for: date)
        ).day ?? 0
        return min(max(days + 1, 1), 14)
    }

    /// The 14-day window has elapsed — the final scan unlocks.
    var windowComplete: Bool { dayIndex() >= 14 }

    // MARK: Status

    var iSubmitted: Bool { myFinalOverall >= 0 }
    var opponentSubmitted: Bool { opponentFinalOverall >= 0 }

    /// My improvement (final − baseline); nil until I submit.
    var myDelta: Int? { iSubmitted ? myFinalOverall - myBaselineOverall : nil }
    var opponentDelta: Int? {
        opponentSubmitted ? opponentFinalOverall - opponentBaselineOverall : nil
    }

    /// The verdict, once both sides have submitted.
    var outcome: DuelOutcome {
        guard let mine = myDelta, let theirs = opponentDelta else { return .pending }
        if mine > theirs { return .win }
        if mine < theirs { return .loss }
        return .draw
    }

    var bothSubmitted: Bool { iSubmitted && opponentSubmitted }

    // MARK: Mutation

    func submitMyFinal(overall: Int, subs: [DuelScore]) {
        myFinalOverall = overall
        myFinalSubsJSON = (try? JSONEncoder().encode(subs)) ?? Data()
    }

    func fillOpponentResult(
        name: String,
        baselineOverall: Int, baselineSubs: [DuelScore],
        finalOverall: Int, finalSubs: [DuelScore]
    ) {
        if !name.isEmpty { opponentName = name }
        opponentBaselineOverall = baselineOverall
        opponentFinalOverall = finalOverall
        opponentBaselineSubsJSON = (try? JSONEncoder().encode(baselineSubs)) ?? Data()
        opponentFinalSubsJSON = (try? JSONEncoder().encode(finalSubs)) ?? Data()
    }

    // MARK: Code generation

    /// A friendly, unambiguous code like "GLOW-7K2". No 0/O/1/I.
    static func makeCode() -> String {
        let alphabet = Array("ABCDEFGHJKLMNPQRSTUVWXYZ23456789")
        func chunk(_ n: Int) -> String { String((0..<n).map { _ in alphabet.randomElement()! }) }
        return "GLOW-\(chunk(3))"
    }
}
