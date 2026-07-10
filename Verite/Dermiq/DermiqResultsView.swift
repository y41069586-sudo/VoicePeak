import SwiftUI
import SwiftData
import StoreKit

// ============================================================
// MARK: — Screen 4: Results (Now ⇄ After 14 days)
// ============================================================

/// The reveal, rebuilt around honesty-with-hope:
/// - YOUR photo sits at the top — this is a reading of you, not a template.
/// - A Now / After-14-days switch above the score flips every number between
///   the real result and a conservative, rule-based projection
///   (`DermiqProjection`) — always labeled as a projection, never a promise.
/// - A soft down-arrow invites the scroll to the full metric breakdown.
/// - The CTA is the plan: "Build my 14-day plan".
///
/// Everything renders BLURRED under the paywall — the shape is visible,
/// nothing readable. Unlock dissolves the blur, then the score counts up.
/// Post-unlock: shareable Reading Card + (3rd scan on, never in onboarding,
/// 5.6.3) the once-ever native review ask.
struct DermiqResultsView: View {
    let model: ScanFlowModel
    let onContinue: () -> Void
    /// Leave the paywall without buying — the scan is already saved, results
    /// stay locked until they subscribe. Required so the paywall is never a
    /// dead end (App Review 3.1.1 / basic UX).
    let onClose: () -> Void

    @Environment(PurchaseManager.self) private var purchases
    @Environment(\.requestReview) private var requestReview
    @Query private var scans: [ScanRecord]
    @Query private var profiles: [UserProfile]

    /// Simulated entitlement while StoreKit is disabled (mock/demo builds).
    @AppStorage("dermiq.unlocked") private var simulatedUnlock = false
    /// The post-scan review ask fires at most once, ever (system throttles too).
    @AppStorage("dermiq.reviewAsked") private var reviewAsked = false

    @State private var revealed = false
    @State private var countUpFinished = false
    @State private var shareURL: URL?

    private var unlocked: Bool { purchases.isPro || simulatedUnlock }

    var body: some View {
        ZStack {
            DQColor.background.ignoresSafeArea()

            if let analysis = model.analysis {
                results(analysis, locked: !revealed)
                    .allowsHitTesting(revealed)

                if !revealed {
                    DermiqPaywallCard {
                        unlockAndReveal()
                    }
                    closeButton
                }
            }
        }
        .onAppear {
            if unlocked { unlockAndReveal() }
        }
    }

    private var closeButton: some View {
        VStack {
            HStack {
                Button {
                    Haptics.fire(.selection)
                    onClose()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(DQColor.textPrimary)
                        .frame(width: 38, height: 38)
                        .background(DQColor.surface.opacity(0.9), in: Circle())
                }
                .accessibilityLabel("Close")
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            Spacer()
        }
    }

    // MARK: Results content

    private func results(_ analysis: DermiqAnalysis, locked: Bool) -> some View {
        let projection = DermiqProjection.project(analysis)
        return ScrollView {
            VStack(spacing: 20) {
                // ---- Header (the UMax "reveal" pattern) ----
                VStack(spacing: 8) {
                    Text(locked ? "👀 Reveal your results" : "Your skin analysis")
                        .font(.system(size: 26, weight: .heavy, design: .rounded))
                        .foregroundStyle(DQColor.textPrimary)
                        .multilineTextAlignment(.center)
                    Text(locked
                         ? "Unlock to see your full skin analysis and your 14-day potential."
                         : "A reading of you — with your 14-day potential.")
                        .font(DQFont.body)
                        .foregroundStyle(DQColor.textSecondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.top, 6)

                // ---- The card: your photo straddling a 2-column metric grid.
                // Under the paywall only the VALUES blur — photo + labels stay
                // crisp, exactly like the reference.
                gridCard(analysis, projection: projection, locked: locked)

                potentialNote

                if !locked {
                    summaryBlock(analysis)
                    shareRow
                    if countUpFinished {
                        DQPrimaryButton(title: "Build my 14-day plan",
                                        systemImage: "calendar.badge.plus") { onContinue() }
                            .animation(VMotion.gentle, value: countUpFinished)
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 12)
            .padding(.bottom, 40)
        }
        .scrollIndicators(.hidden)
    }

    /// The user's own capture, framed with a soft glow ring — sits half over
    /// the grid card, the proof this reading is about THEM.
    private var capturedAvatar: some View {
        Group {
            if let image = model.capturedImage {
                Image(uiImage: image).resizable().scaledToFill()
            } else {
                Circle().fill(DQColor.accentSoft)
            }
        }
        .frame(width: 92, height: 92)
        .clipShape(Circle())
        .overlay(Circle().strokeBorder(DQColor.surface, lineWidth: 4))
        .overlay(Circle().strokeBorder(DQColor.accentSoft, lineWidth: 4).padding(-4))
        .shadow(color: DQColor.accent.opacity(0.28), radius: 14, y: 8)
    }

    /// The metric grid card. Overall + Potential lead, then every sub-score,
    /// two columns. `locked` blurs only the numbers and bars (not the labels).
    private func gridCard(_ analysis: DermiqAnalysis,
                          projection: DermiqProjection.Projected,
                          locked: Bool) -> some View {
        let columns = [GridItem(.flexible(), spacing: 22),
                       GridItem(.flexible(), spacing: 22)]
        return ZStack(alignment: .top) {
            LazyVGrid(columns: columns, alignment: .leading, spacing: 20) {
                metricCell(label: "Overall", value: analysis.overall,
                           fill: DQColor.accent, emphasized: false, locked: locked)
                metricCell(label: "Potential", value: projection.overall,
                           fill: DQColor.accentBright, emphasized: true, locked: locked)
                ForEach(analysis.subScores) { score in
                    metricCell(label: score.category.displayName, value: score.value,
                               fill: DQColor.accent, emphasized: false, locked: locked)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 62)
            .padding(.bottom, 22)
            .frame(maxWidth: .infinity)
            .background(DQColor.surface, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 26, style: .continuous)
                .strokeBorder(DQColor.stroke, lineWidth: 1))

            capturedAvatar
                .offset(y: -46)
        }
        .padding(.top, 46)
    }

    /// One metric: label, big number, thin progress bar. "Potential" is tinted
    /// and carries a "14d" tag. Locked → the number and bar blur.
    private func metricCell(label: String, value: Int, fill: Color,
                            emphasized: Bool, locked: Bool) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 5) {
                Text(label)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(DQColor.textSecondary)
                    .lineLimit(1)
                if emphasized {
                    Text("14d")
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .foregroundStyle(DQColor.accentBright)
                        .padding(.horizontal, 5).padding(.vertical, 1)
                        .background(DQColor.accentSoft, in: Capsule())
                }
            }
            Text(verbatim: "\(value)")
                .font(.system(size: 27, weight: .heavy, design: .rounded).monospacedDigit())
                .foregroundStyle(emphasized ? DQColor.accentBright : DQColor.textPrimary)
                .blur(radius: locked ? 9 : 0)
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(DQColor.stroke.opacity(0.7))
                    Capsule().fill(fill)
                        .frame(width: proxy.size.width * CGFloat(value) / 100)
                }
            }
            .frame(height: 6)
            .blur(radius: locked ? 4 : 0)
            .opacity(locked ? 0.7 : 1)
        }
        .animation(VMotion.gentle, value: locked)
    }

    /// Honest note under the grid — Potential is a projection, never a promise.
    private var potentialNote: some View {
        HStack(spacing: 8) {
            Image(systemName: "sparkles")
                .font(.system(size: 12, weight: .semibold))
            Text("“Potential” is a careful 14-day projection if you follow your plan — not a promise.")
                .font(DQFont.micro)
                .fixedSize(horizontal: false, vertical: true)
        }
        .foregroundStyle(DQColor.accentBright)
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity)
        .background(DQColor.surfaceElevated, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func summaryBlock(_ analysis: DermiqAnalysis) -> some View {
        DQCard {
            VStack(alignment: .leading, spacing: 8) {
                Text("THE HONEST READ")
                    .font(DQFont.mono(11, weight: .semibold))
                    .foregroundStyle(DQColor.accentBright)
                    .tracking(2)
                Text(analysis.honestSummary)
                    .font(DQFont.body)
                    .foregroundStyle(DQColor.textPrimary)
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    /// Post-unlock: the story-sized Reading Card, rendered on-device.
    @ViewBuilder
    private var shareRow: some View {
        if let shareURL {
            ShareLink(item: shareURL) {
                HStack(spacing: 8) {
                    Image(systemName: "square.and.arrow.up")
                    Text("Share my reading")
                }
                .font(DQFont.headline)
                .foregroundStyle(DQColor.textPrimary)
                .frame(maxWidth: .infinity, minHeight: 50)
                .background(DQColor.surface, in: Capsule())
                .overlay(Capsule().strokeBorder(DQColor.stroke, lineWidth: 1))
            }
            .buttonStyle(PressableStyle())
            .simultaneousGesture(TapGesture().onEnded {
                RampAnalytics.track("reading_card_share")
            })
        }
    }

    // MARK: Reveal choreography

    private func unlockAndReveal() {
        guard !revealed else { return }
        // The value-blur dissolves as `revealed` flips; the CTA follows.
        withAnimation(.easeOut(duration: 0.7)) { revealed = true }
        Task {
            try? await Task.sleep(for: .milliseconds(800))
            withAnimation(VMotion.gentle) { countUpFinished = true }
        }
        afterUnlock()
    }

    /// Post-unlock side effects: render the shareable Reading Card, and — from
    /// the 3rd completed scan, once ever — the native review ask (5.6.3-safe:
    /// this is a real positive moment, far from onboarding).
    private func afterUnlock() {
        guard let analysis = model.analysis else { return }
        if shareURL == nil {
            let card = ReadingShareCard(
                analysis: analysis,
                date: .now,
                displayName: profiles.first?.displayName
            )
            if let image = ShareRenderer.image(for: card, size: ReadingShareCard.size),
               let url = ShareRenderer.pngURL(for: image, name: "verite-reading") {
                shareURL = url
            }
        }
        if !reviewAsked && scans.count >= 3 {
            reviewAsked = true
            Task {
                try? await Task.sleep(for: .milliseconds(2200))
                requestReview()
            }
        }
    }
}

// ============================================================
// MARK: — Hard paywall card
// ============================================================

/// Non-dismissible bottom sheet over the blurred results.
/// Weekly + annual, annual pre-selected.
struct DermiqPaywallCard: View {
    let onUnlocked: () -> Void

    @Environment(AppState.self) private var appState
    @Environment(PurchaseManager.self) private var purchases
    @AppStorage("dermiq.unlocked") private var simulatedUnlock = false

    private enum PlanChoice { case weekly, annual }
    @State private var choice: PlanChoice = .annual
    @State private var purchasing = false
    @State private var legalDocument: LegalDocument?

    var body: some View {
        VStack {
            Spacer()
            card
        }
        .ignoresSafeArea(edges: .bottom)
    }

    private var card: some View {
        VStack(spacing: 18) {
            Capsule()
                .fill(DQColor.stroke)
                .frame(width: 40, height: 4)
                .padding(.top, 12)

            VStack(spacing: 6) {
                Text("Your score is ready.")
                    .font(DQFont.title)
                    .foregroundStyle(DQColor.textPrimary)
                Text("Unlock your number, all seven metrics, your potential, and the 14-day plan built from them.")
                    .font(DQFont.body)
                    .foregroundStyle(DQColor.textSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 24)

            VStack(spacing: 10) {
                planRow(.annual,
                        title: "Annual",
                        price: price(for: VeriteProducts.proYearly, fallback: "$39.99 / year"),
                        badge: "BEST VALUE")
                planRow(.weekly,
                        title: "Weekly",
                        price: price(for: VeriteProducts.proWeekly, fallback: "$4.99 / week"),
                        badge: nil)
            }
            .padding(.horizontal, 20)

            DQPrimaryButton(title: purchasing ? "Unlocking…" : "Unlock my results",
                            isEnabled: !purchasing) {
                purchase()
            }
            .padding(.horizontal, 20)

            // A real invite (opens the system share sheet) — NOT a fake
            // "invite 3 to unlock" gate. It shares the app; it does not grant
            // Pro, because we cannot verify installs without referral tracking.
            // TODO: PRODUCTION — wire real referral tracking + an App Store URL
            // if invite-to-unlock should actually gate the paywall.
            ShareLink(item: inviteMessage) {
                HStack(spacing: 8) {
                    Image(systemName: "person.2.fill")
                    Text("Invite friends")
                }
                .font(Font.system(size: 16, weight: .bold))
                .foregroundStyle(DQColor.textPrimary)
                .frame(maxWidth: .infinity, minHeight: 52)
                .background(DQColor.surface,
                            in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(DQColor.stroke, lineWidth: 1))
            }
            .buttonStyle(PressableStyle())
            .padding(.horizontal, 20)
            .simultaneousGesture(TapGesture().onEnded {
                RampAnalytics.track("paywall_invite_share")
            })

            // Required subscription disclosure (App Review 3.1.2): renewal
            // terms + Terms of Use + Privacy Policy reachable from the paywall.
            VStack(spacing: 8) {
                Text("Auto-renewing subscription. Renews until cancelled; cancel anytime in your App Store settings.")
                    .font(DQFont.micro)
                    .foregroundStyle(DQColor.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 28)
                HStack(spacing: 14) {
                    Button("Terms of Use") { legalDocument = .terms }
                    Button("Privacy Policy") { legalDocument = .privacy }
                    Button("Restore") {
                        Task {
                            await purchases.restore()
                            if purchases.isPro { onUnlocked() }
                        }
                    }
                }
                .font(DQFont.caption)
                .foregroundStyle(DQColor.textSecondary)
            }
            .padding(.bottom, 30)
        }
        .sheet(item: $legalDocument) { document in
            DermiqLegalView(document: document)
        }
        .frame(maxWidth: .infinity)
        .background(
            DQColor.surfaceElevated,
            in: UnevenRoundedRectangle(topLeadingRadius: DQRadius.sheet,
                                       topTrailingRadius: DQRadius.sheet,
                                       style: .continuous)
        )
        .overlay(alignment: .top) {
            UnevenRoundedRectangle(topLeadingRadius: DQRadius.sheet,
                                   topTrailingRadius: DQRadius.sheet,
                                   style: .continuous)
                .strokeBorder(DQColor.stroke, lineWidth: 1)
        }
    }

    private func planRow(_ plan: PlanChoice, title: String, price: String, badge: String?) -> some View {
        Button {
            Haptics.fire(.selection)
            choice = plan
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 8) {
                        Text(title)
                            .font(DQFont.headline)
                            .foregroundStyle(DQColor.textPrimary)
                        if let badge {
                            Text(badge)
                                .font(DQFont.mono(9, weight: .bold))
                                .foregroundStyle(Color.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(DQColor.deltaUp, in: Capsule())
                        }
                    }
                    Text(price)
                        .font(DQFont.caption)
                        .foregroundStyle(DQColor.textSecondary)
                }
                Spacer()
                Image(systemName: choice == plan ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(choice == plan ? DQColor.accent : DQColor.stroke)
                    .font(.system(size: 22))
            }
            .padding(14)
            .background(DQColor.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(choice == plan ? DQColor.accent : DQColor.stroke,
                                  lineWidth: choice == plan ? 1.5 : 1)
            )
        }
        .buttonStyle(PressableStyle())
    }

    /// The text shared by the invite button. No fabricated App Store link —
    /// add a real one here once the app is live.
    private var inviteMessage: String {
        "I'm using Vérité to track my skin with an honest AI score and a 14-day plan. Come try it with me."
    }

    private func price(for productID: String, fallback: String) -> String {
        guard let product = purchases.products.first(where: { $0.id == productID }) else {
            return fallback
        }
        return product.displayPrice
    }

    private func purchase() {
        purchasing = true
        Task {
            defer { purchasing = false }
            if appState.featureFlags.purchasesEnabled {
                let id = choice == .annual ? VeriteProducts.proYearly : VeriteProducts.proWeekly
                guard let product = purchases.products.first(where: { $0.id == id }) else { return }
                if await purchases.purchase(product) {
                    RampAnalytics.track("paywall_purchase", ["plan": id])
                    onUnlocked()
                }
            } else {
                // TODO: PRODUCTION — remove the simulated unlock once StoreKit
                // products are configured and `purchasesEnabled` ships on.
                try? await Task.sleep(for: .milliseconds(900))
                simulatedUnlock = true
                RampAnalytics.track("paywall_purchase", ["plan": "simulated"])
                onUnlocked()
            }
        }
    }
}
