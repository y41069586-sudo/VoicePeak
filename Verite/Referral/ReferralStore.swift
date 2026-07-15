import Foundation
import SwiftUI

// ============================================================
// MARK: — Referral loop + weekly scan quota
// ============================================================
//
// Serverless, like the friend compare: rewards travel inside `verite://` links.
//
//   INVITE   verite://invite?code=<inviter's code>
//            → the friend redeems once: +1 bonus scan, and the inviter's code
//              is remembered so a confirm link can be sent back LATER.
//   CONFIRM  verite://invite?confirm=<code>
//            → only the device whose OWN code matches gets +1 (that's the
//              inviter). Capped so links can't be farmed.
//
// The inviter's reward is EARNED, not clicked: the confirm link is only
// offered (Settings) once the invited friend has signed up AND gone Pro —
// so "my friend converted", never "my friend tapped a link".
//
// Bonus scans matter because there is NO free tier: a non-Pro install gets
// exactly one scan (the onboarding one) — a gifted bonus scan is another
// blurred-score moment, results stay Pro-locked. If a real backend lands
// later, only this file changes — the links and call sites stay.

@Observable
@MainActor
final class ReferralStore {
    static let shared = ReferralStore()

    private static let codeKey = "dq.referral.code"
    private static let creditsKey = "dq.referral.credits"
    private static let redeemedKey = "dq.referral.redeemed"
    private static let inviterKey = "dq.referral.inviter"
    private static let confirmsKey = "dq.referral.confirms"
    private static let confirmCap = 10

    /// Bonus scans available (earned via referrals).
    private(set) var credits: Int

    private init() {
        credits = UserDefaults.standard.integer(forKey: Self.creditsKey)
    }

    // MARK: My code + links

    /// Stable 6-char code for this install.
    var myCode: String {
        if let existing = UserDefaults.standard.string(forKey: Self.codeKey) { return existing }
        let fresh = String(UUID().uuidString.replacingOccurrences(of: "-", with: "").prefix(6))
        UserDefaults.standard.set(fresh, forKey: Self.codeKey)
        return fresh
    }

    var inviteURL: URL {
        URL(string: "verite://invite?code=\(myCode)")!
    }

    /// The thank-you link the redeemer can send back so the inviter gets paid.
    var thankYouURL: URL? {
        guard let inviter = UserDefaults.standard.string(forKey: Self.inviterKey) else { return nil }
        return URL(string: "verite://invite?confirm=\(inviter)")
    }

    // MARK: Credits

    func addCredit() {
        credits += 1
        UserDefaults.standard.set(credits, forKey: Self.creditsKey)
    }

    func consumeCredit() {
        guard credits > 0 else { return }
        credits -= 1
        UserDefaults.standard.set(credits, forKey: Self.creditsKey)
    }

    // MARK: Link handling

    /// Returns true when the URL was a referral link (handled here).
    func handle(_ url: URL) -> Bool {
        guard url.scheme == "verite", url.host == "invite",
              let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems
        else { return false }

        if let code = items.first(where: { $0.name == "code" })?.value, !code.isEmpty {
            redeemInvite(from: code)
            return true
        }
        if let code = items.first(where: { $0.name == "confirm" })?.value, !code.isEmpty {
            confirm(code)
            return true
        }
        return false
    }

    /// Friend's side: one redemption per install, never your own code.
    private func redeemInvite(from code: String) {
        let defaults = UserDefaults.standard
        guard code != myCode, !defaults.bool(forKey: Self.redeemedKey) else { return }
        defaults.set(true, forKey: Self.redeemedKey)
        defaults.set(code, forKey: Self.inviterKey)
        addCredit()
        Haptics.fire(.milestone)
        DermiqDiagnostics.record("Referral redeemed — +1 bonus scan")
    }

    /// Inviter's side: only my own code pays out, capped.
    private func confirm(_ code: String) {
        let defaults = UserDefaults.standard
        let confirms = defaults.integer(forKey: Self.confirmsKey)
        guard code == myCode, confirms < Self.confirmCap else { return }
        defaults.set(confirms + 1, forKey: Self.confirmsKey)
        addCredit()
        Haptics.fire(.milestone)
        DermiqDiagnostics.record("Referral confirmed — +1 bonus scan")
    }
}

// ============================================================
// MARK: — Scan quota (no free tier)
// ============================================================

enum ScanQuota {

    /// There is NO recurring free tier. A non-Pro user gets exactly ONE scan
    /// (the onboarding scan — it produces the blurred score that IS the
    /// paywall moment) plus any referral bonus scans; results stay Pro-locked
    /// either way. Pro is capped per WEEK, GlamUp-style: 2 covers the honest
    /// weekly reading plus a redo (bad light, hair) — the day-14 rescan falls
    /// into its own week anyway. Skin moves weekly, not daily — and every
    /// analysis is a paid API call, so an uncapped heavy user could cost more
    /// than a yearly sub earns.
    static let proPerWeek = 2

    enum Decision {
        case allow(useCredit: Bool)
        case blockedNeedsPro
        case blockedProWeekly(nextScan: Date?)
    }

    static func decide(scans: [ScanRecord], isPro: Bool, credits: Int) -> Decision {
        if isPro {
            let weekAgo = Date.now.addingTimeInterval(-7 * 24 * 3600)
            let inWindow = scans.filter { $0.date > weekAgo }
            if inWindow.count < proPerWeek { return .allow(useCredit: false) }
            // Past the weekly cap: a bought (€1.99) or referral-earned extra
            // scan lets them through; otherwise it's the countdown.
            if credits > 0 { return .allow(useCredit: true) }
            let nextScan = inWindow.map(\.date).min()?.addingTimeInterval(7 * 24 * 3600)
            return .blockedProWeekly(nextScan: nextScan)
        }
        if scans.isEmpty { return .allow(useCredit: false) }   // the one first scan
        if credits > 0 { return .allow(useCredit: true) }
        return .blockedNeedsPro
    }
}

// ============================================================
// MARK: — "Weekly scan used" sheet
// ============================================================

/// Two flavours: a non-Pro user tapping scan (the Pro pitch + invite escape
/// hatch), or a Pro user hitting the weekly fair-use cap (countdown only).
struct ScanLimitSheet: View {
    /// True when a Pro user hit the weekly cap; false = scanning needs Pro.
    var proCap = false
    var nextScan: Date?
    let onGetPro: (() -> Void)?
    /// Pro-cap only: buy one more scan now (€1.99). Displayed price passed in.
    var extraScanPrice: String = "€1.99"
    var onBuyExtraScan: (() -> Void)? = nil

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: proCap ? "camera.badge.clock" : "sparkles")
                .font(.system(size: 40, weight: .semibold))
                .foregroundStyle(DQColor.accentBright)
                .padding(.top, 26)

            VStack(spacing: 6) {
                Text(proCap ? "Weekly scan cap reached" : "Scanning is part of Pro")
                    .font(.system(size: 21, weight: .heavy, design: .rounded))
                    .foregroundStyle(DQColor.textPrimary)
                Text(proCap
                     ? "Skin moves week by week — your two weekly readings are in. Need one more now? Grab an extra scan, or the next one unlocks free soon."
                     : "Every scan runs a full AI skin analysis. Go Pro for your score, all seven metrics and your 14-day plan.")
                    .font(DQFont.caption)
                    .foregroundStyle(DQColor.textSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 26)

            if proCap, let nextScan {
                HStack(spacing: 6) {
                    Image(systemName: "clock")
                        .font(.system(size: 12, weight: .semibold))
                    Text("Next scan:")
                    Text(nextScan, style: .relative)
                        .fontWeight(.bold)
                }
                .font(DQFont.caption)
                .foregroundStyle(DQColor.accentBright)
                .padding(.horizontal, 14).padding(.vertical, 9)
                .background(DQColor.accentSoft.opacity(0.6), in: Capsule())
            }

            VStack(spacing: 10) {
                if !proCap, let onGetPro {
                    Button {
                        dismiss()
                        onGetPro()
                    } label: {
                        Label("Unlock scanning with Pro", systemImage: "sparkles")
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity, minHeight: 54)
                            .background(DQColor.accentBright,
                                        in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    }
                    .buttonStyle(PressableStyle())
                }

                // Pro user past the weekly cap: buy one more scan right now.
                if proCap, let onBuyExtraScan {
                    Button {
                        dismiss()
                        onBuyExtraScan()
                    } label: {
                        Label("Buy 1 extra scan · \(extraScanPrice)", systemImage: "bolt.fill")
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity, minHeight: 54)
                            .background(DQColor.accentBright,
                                        in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    }
                    .buttonStyle(PressableStyle())
                }

                if !proCap {
                    ShareLink(item: ReferralStore.shared.inviteURL,
                              message: Text("Scan your skin with me — this link gives you a free scan.")) {
                        Label("Invite a friend — you both get a scan", systemImage: "person.2.fill")
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                            .foregroundStyle(DQColor.accentBright)
                            .frame(maxWidth: .infinity, minHeight: 50)
                            .background(DQColor.accentBright.opacity(0.10),
                                        in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                }
            }
            .padding(.horizontal, 22)

            Spacer(minLength: 12)
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
        .background(DQColor.background)
    }
}
