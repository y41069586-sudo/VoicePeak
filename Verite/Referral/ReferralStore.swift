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
    private static let freeScanKey = "dq.scan.freeUsed"
    private static let confirmCap = 10

    /// Bonus scans available (earned via referrals).
    private(set) var credits: Int

    /// The one free (onboarding) scan has been taken. Durable and independent
    /// of whether a `ScanRecord` actually persisted — so a save race or a
    /// cancelled write can never hand out a second free reading.
    private(set) var freeScanUsed: Bool

    private init() {
        credits = UserDefaults.standard.integer(forKey: Self.creditsKey)
        freeScanUsed = UserDefaults.standard.bool(forKey: Self.freeScanKey)
    }

    /// Called once the user has reached a scan result — burns the free scan.
    func markFreeScanUsed() {
        guard !freeScanUsed else { return }
        freeScanUsed = true
        UserDefaults.standard.set(true, forKey: Self.freeScanKey)
    }

    /// Delete-account support: wipe every referral/scan-credit marker so a
    /// fresh account starts truly clean (free scan available again, no
    /// leftover credits, code, or invite state).
    func resetAll() {
        let d = UserDefaults.standard
        for key in [Self.codeKey, Self.creditsKey, Self.redeemedKey,
                    Self.inviterKey, Self.confirmsKey, Self.freeScanKey,
                    Self.creditScanKey] {
            d.removeObject(forKey: key)
        }
        credits = 0
        freeScanUsed = false
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
        LinkConfig.share(host: "invite", query: "code=\(myCode)")
    }

    /// The thank-you link the redeemer can send back so the inviter gets paid.
    var thankYouURL: URL? {
        guard let inviter = UserDefaults.standard.string(forKey: Self.inviterKey) else { return nil }
        return LinkConfig.share(host: "invite", query: "confirm=\(inviter)")
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

    // MARK: Credit-scan marker (durable)

    private static let creditScanKey = "dq.scan.nextIsCredit"

    /// Durable marker: the scan being launched was paid with a credit (extra
    /// scan / referral bonus). Kept in UserDefaults so a rebuilt scan cover
    /// can NEVER lose it — the flow re-reads it when the scan persists, and
    /// credit scans never auto-include a 14-day plan.
    func markNextScanUsesCredit() {
        UserDefaults.standard.set(true, forKey: Self.creditScanKey)
    }

    func clearNextScanUsesCredit() {
        UserDefaults.standard.removeObject(forKey: Self.creditScanKey)
    }

    func consumeNextScanUsesCredit() -> Bool {
        let flag = UserDefaults.standard.bool(forKey: Self.creditScanKey)
        UserDefaults.standard.removeObject(forKey: Self.creditScanKey)
        return flag
    }

    // MARK: Link handling

    /// Pasted-text redemption: chats never linkify verite:// URLs, so the
    /// friend copies the whole message and we fish the link out of it.
    /// Paste-to-redeem: returns true only when a bonus scan was ACTUALLY
    /// credited — so the paste button shows honest feedback. A link that's
    /// already been redeemed, or your own code, returns false (surfaces the
    /// error) instead of silently doing nothing.
    func handlePasted(_ text: String) -> Bool {
        guard let url = LinkConfig.veriteURL(fromPasted: text),
              url.scheme == "verite", url.host == "invite",
              let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems
        else { return false }

        if let code = items.first(where: { $0.name == "code" })?.value, !code.isEmpty {
            return redeemInvite(from: code)
        }
        if let code = items.first(where: { $0.name == "confirm" })?.value, !code.isEmpty {
            return confirm(code)
        }
        return false
    }

    /// Deep-link routing: returns true when the URL was a referral link (so
    /// RootView stops routing it), regardless of whether a credit was granted.
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
    /// Returns true only when a bonus was actually credited.
    @discardableResult
    private func redeemInvite(from code: String) -> Bool {
        let defaults = UserDefaults.standard
        guard code != myCode, !defaults.bool(forKey: Self.redeemedKey) else { return false }
        defaults.set(true, forKey: Self.redeemedKey)
        defaults.set(code, forKey: Self.inviterKey)
        addCredit()
        Haptics.fire(.milestone)
        DermiqDiagnostics.record("Referral redeemed — +1 bonus scan")
        return true
    }

    /// Inviter's side: only my own code pays out, capped.
    /// Returns true only when a bonus was actually credited.
    @discardableResult
    private func confirm(_ code: String) -> Bool {
        let defaults = UserDefaults.standard
        let confirms = defaults.integer(forKey: Self.confirmsKey)
        guard code == myCode, confirms < Self.confirmCap else { return false }
        defaults.set(confirms + 1, forKey: Self.confirmsKey)
        addCredit()
        Haptics.fire(.milestone)
        DermiqDiagnostics.record("Referral confirmed — +1 bonus scan")
        return true
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

    static func decide(scans: [ScanRecord], isPro: Bool, credits: Int,
                       freeScanUsed: Bool) -> Decision {
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
        // The one free scan: allowed only while it has NOT been burned AND no
        // record exists yet. Gating on `freeScanUsed` (set the moment the first
        // scan reaches its result) means a persistence race can never grant a
        // second free reading — the whole point of the flag.
        if !freeScanUsed && scans.isEmpty { return .allow(useCredit: false) }
        if credits > 0 { return .allow(useCredit: true) }
        return .blockedNeedsPro
    }
}

// ============================================================
// MARK: — "Weekly scan used" sheet
// ============================================================

/// ONE purpose only: a Pro user hit the weekly fair-use cap (countdown +
/// €1.99 extra scan). Non-Pro users NEVER see this sheet — tapping scan
/// without Pro goes straight to the paywall (DermiqTabShell.startScan).
struct ScanLimitSheet: View {
    var nextScan: Date?
    /// Buy one more scan now. Live StoreKit price passed in; "" while it hasn't
    /// loaded, in which case the button drops the "· price" suffix.
    var extraScanPrice: String = ""
    /// The purchase is in flight — the buy button shows a spinner and locks.
    var purchasing: Bool = false
    var onBuyExtraScan: (() -> Void)? = nil

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        // Scrollable so the bottom button stays reachable at the medium
        // detent on SE-class heights (German copy runs 4+ lines).
        ScrollView {
        VStack(spacing: 18) {
            Image(systemName: "camera.badge.clock")
                .font(.system(size: 40, weight: .semibold))
                .foregroundStyle(DQColor.accentBright)
                .padding(.top, 26)

            VStack(spacing: 6) {
                Text("Weekly scan cap reached")
                    .font(.system(size: 21, weight: .heavy, design: .rounded))
                    .foregroundStyle(DQColor.textPrimary)
                Text("Skin moves week by week — your two weekly readings are in. Need one more now? Grab an extra scan, or the next one unlocks free soon.")
                    .font(DQFont.caption)
                    .foregroundStyle(DQColor.textSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 26)

            if let nextScan {
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

            if let onBuyExtraScan {
                Button {
                    // Don't dismiss here — stay open showing the spinner; the
                    // shell dismisses this sheet once the purchase resolves.
                    onBuyExtraScan()
                } label: {
                    Group {
                        if purchasing {
                            ProgressView().tint(.white)
                        } else {
                            // No price on the button — it reads as a cost and
                            // deters the tap. The exact amount is still shown
                            // (and consented to) on Apple's purchase sheet the
                            // moment the buy starts, so nothing is hidden from
                            // the actual charge; this is a one-time consumable,
                            // not a subscription that must price on the paywall.
                            Label("Buy 1 extra scan", systemImage: "bolt.fill")
                        }
                    }
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, minHeight: 54)
                    .background(DQColor.accentBright,
                                in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                }
                .buttonStyle(PressableStyle())
                .disabled(purchasing)
                .padding(.horizontal, 22)
            }

            Spacer(minLength: 12)
        }
        }
        .scrollBounceBehavior(.basedOnSize)
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .background(DQColor.background)
    }
}
