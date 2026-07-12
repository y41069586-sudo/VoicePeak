import Foundation
import SwiftData
import SwiftUI

// ============================================================
// MARK: — Duel store (SwiftData operations)
// ============================================================

@MainActor
enum DuelStore {

    /// The duel we should surface: the newest one that isn't finished-and-seen.
    static func active(in context: ModelContext) -> SkinDuel? {
        let all = (try? context.fetch(
            FetchDescriptor<SkinDuel>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)])
        )) ?? []
        return all.first { !($0.bothSubmitted && $0.revealed) } ?? all.first
    }

    static func duel(withCode code: String, in context: ModelContext) -> SkinDuel? {
        let all = (try? context.fetch(FetchDescriptor<SkinDuel>())) ?? []
        return all.first { $0.code == code }
    }

    /// Starts a new duel from my latest analysis. `opponentName` is optional
    /// (known only when accepting an invite).
    @discardableResult
    static func create(
        myName: String,
        baseline: DermiqAnalysis,
        code: String = SkinDuel.makeCode(),
        opponentName: String = "",
        in context: ModelContext
    ) -> SkinDuel {
        let duel = SkinDuel(
            code: code,
            myName: myName.isEmpty ? "You" : myName,
            opponentName: opponentName,
            baselineOverall: baseline.overall,
            baselineSubs: DuelScore.from(baseline.subScores)
        )
        context.insert(duel)
        try? context.save()
        RampAnalytics.track("duel_created", ["code": code])
        return duel
    }

    /// Accepting a shared invite → my own duel that mirrors their code.
    @discardableResult
    static func accept(
        invite: DuelPayload,
        myName: String,
        baseline: DermiqAnalysis,
        in context: ModelContext
    ) -> SkinDuel {
        create(
            myName: myName,
            baseline: baseline,
            code: invite.code,
            opponentName: invite.name,
            in: context
        )
    }

    /// Records my final scan into the duel.
    static func submitFinal(_ duel: SkinDuel, analysis: DermiqAnalysis, in context: ModelContext) {
        duel.submitMyFinal(overall: analysis.overall, subs: DuelScore.from(analysis.subScores))
        try? context.save()
        RampAnalytics.track("duel_final_submitted", ["code": duel.code])
    }

    /// Imports an opponent's result card. Matches by code, else falls back to
    /// the active duel. Returns the duel it landed on (nil if none to attach to).
    @discardableResult
    static func importResult(_ payload: DuelPayload, in context: ModelContext) -> SkinDuel? {
        guard payload.isResult,
              let bOverall = payload.bOverall, let fOverall = payload.fOverall else { return nil }
        let target = duel(withCode: payload.code, in: context) ?? active(in: context)
        guard let duel = target else { return nil }
        duel.fillOpponentResult(
            name: payload.name,
            baselineOverall: bOverall, baselineSubs: payload.bSubs ?? [],
            finalOverall: fOverall, finalSubs: payload.fSubs ?? []
        )
        try? context.save()
        RampAnalytics.track("duel_result_imported", ["code": duel.code])
        return duel
    }

    /// My shareable result card payload (only valid once I've submitted).
    static func myResultPayload(_ duel: SkinDuel) -> DuelPayload {
        DuelPayload.result(
            code: duel.code, name: duel.myName,
            baselineOverall: duel.myBaselineOverall, baselineSubs: duel.myBaselineSubs,
            finalOverall: max(duel.myFinalOverall, 0), finalSubs: duel.myFinalSubs
        )
    }
}

// ============================================================
// MARK: — Deep-link inbox
// ============================================================

/// Holds a payload parsed from an incoming `verite://duel?d=…` link until the
/// UI can present it. `RootView.onOpenURL` fills it; the tab shell consumes it.
@Observable
@MainActor
final class DuelInbox {
    static let shared = DuelInbox()
    private init() {}

    /// The most recently opened duel link, awaiting handling.
    var pending: DuelPayload?

    func handle(_ url: URL) {
        guard let payload = DuelLink.payload(from: url) else { return }
        pending = payload
    }

    func consume() -> DuelPayload? {
        defer { pending = nil }
        return pending
    }
}
