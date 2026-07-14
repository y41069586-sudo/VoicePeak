import Foundation
import SwiftUI

// ============================================================
// MARK: — Referral loop + weekly scan quota
// ============================================================
//
// Serverless, like the Skin Duel: rewards travel inside `verite://` links.
//
//   INVITE   verite://invite?code=<inviter's code>
//            → the friend redeems once: +1 bonus scan, and the inviter's code
//              is remembered so a thank-you link can be sent back.
//   CONFIRM  verite://invite?confirm=<code>
//            → only the device whose OWN code matches gets +1 (that's the
//              inviter). Capped so links can't be farmed.
//
// Bonus scans matter because free users get ONE scan per week (a real API
// cost sits behind every scan, and skin doesn't change daily anyway — the
// plan runs on a 14-day cadence). Pro lifts the cap. If a real backend lands
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
// MARK: — Weekly scan quota
// ============================================================

enum ScanQuota {

    /// Free tier: one scan per rolling week. Pro: a generous daily cap that
    /// only exists to protect the analysis API from abuse.
    static let freePerWeek = 1
    static let proPerDay = 3

    enum Decision {
        case allow(useCredit: Bool)
        case blockedFree(nextFree: Date?)
        case blockedProDaily
    }

    static func decide(scans: [ScanRecord], isPro: Bool, credits: Int) -> Decision {
        let now = Date.now
        if isPro {
            let today = scans.filter { Calendar.current.isDate($0.date, inSameDayAs: now) }
            return today.count < proPerDay ? .allow(useCredit: false) : .blockedProDaily
        }
        let weekAgo = now.addingTimeInterval(-7 * 24 * 3600)
        let inWindow = scans.filter { $0.date > weekAgo }
        if inWindow.count < freePerWeek { return .allow(useCredit: false) }
        if credits > 0 { return .allow(useCredit: true) }
        let nextFree = inWindow.map(\.date).min()?.addingTimeInterval(7 * 24 * 3600)
        return .blockedFree(nextFree: nextFree)
    }
}

// ============================================================
// MARK: — "Weekly scan used" sheet
// ============================================================

/// Shown when a free user is out of scans: when the next one unlocks, the
/// invite-a-friend escape hatch, and (when purchases ship) the Pro upsell.
struct ScanLimitSheet: View {
    let nextFree: Date?
    let onGetPro: (() -> Void)?

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: "camera.badge.clock")
                .font(.system(size: 40, weight: .semibold))
                .foregroundStyle(DQColor.accentBright)
                .padding(.top, 26)

            VStack(spacing: 6) {
                Text("Your weekly scan is used")
                    .font(.system(size: 21, weight: .heavy, design: .rounded))
                    .foregroundStyle(DQColor.textPrimary)
                Text("Skin changes week by week, not day by day — one honest scan per week keeps the reading meaningful.")
                    .font(DQFont.caption)
                    .foregroundStyle(DQColor.textSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 26)

            if let nextFree {
                HStack(spacing: 6) {
                    Image(systemName: "clock")
                        .font(.system(size: 12, weight: .semibold))
                    Text("Next free scan:")
                    Text(nextFree, style: .relative)
                        .fontWeight(.bold)
                }
                .font(DQFont.caption)
                .foregroundStyle(DQColor.accentBright)
                .padding(.horizontal, 14).padding(.vertical, 9)
                .background(DQColor.accentSoft.opacity(0.6), in: Capsule())
            }

            VStack(spacing: 10) {
                if let onGetPro {
                    Button {
                        dismiss()
                        onGetPro()
                    } label: {
                        Label("Unlock unlimited scans with Pro", systemImage: "sparkles")
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity, minHeight: 54)
                            .background(DQColor.accentBright,
                                        in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    }
                    .buttonStyle(PressableStyle())
                }

                ShareLink(item: ReferralStore.shared.inviteURL,
                          message: Text("Scan your skin with me — this link gives us both a free scan.")) {
                    Label("Invite a friend — you both get a scan", systemImage: "person.2.fill")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(DQColor.accentBright)
                        .frame(maxWidth: .infinity, minHeight: 50)
                        .background(DQColor.accentBright.opacity(0.10),
                                    in: RoundedRectangle(cornerRadius: 16, style: .continuous))
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
