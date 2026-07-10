import SwiftUI
import SwiftData
import StoreKit

// ============================================================
// MARK: — Screen 4: Results (teased, then paywalled)
// ============================================================

/// The classic gate: the WHOLE reading — score, metrics, written read —
/// renders blurred under the paywall; the shape is visible, nothing is
/// readable. Unlock dissolves the blur, THEN the count-up plays (the reveal
/// is the reward for paying). Post-unlock the card becomes shareable
/// (story-sized Reading Card) and — from the 3rd completed scan on, never
/// during onboarding (5.6.3) — the native review ask may fire once.
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
    @State private var playCountUp = false
    @State private var ringProgress: Double = 0
    @State private var countUpFinished = false
    @State private var shareURL: URL?

    private var unlocked: Bool { purchases.isPro || simulatedUnlock }

    var body: some View {
        ZStack {
            DQColor.background.ignoresSafeArea()

            if let analysis = model.analysis {
                results(analysis, locked: !revealed)
                    .blur(radius: revealed ? 0 : 26)
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
                        .background(DQColor.surface.opacity(0.7), in: Circle())
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
        ScrollView {
            VStack(spacing: 28) {
                scoreHeader(analysis)
                subScoreGrid(analysis)
                summaryBlock(analysis)
                if !locked {
                    shareRow
                    if countUpFinished {
                        DQPrimaryButton(title: "See my potential") { onContinue() }
                            .animation(VMotion.gentle, value: countUpFinished)
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 48)
            .padding(.bottom, 40)
        }
        .scrollIndicators(.hidden)
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

    private func scoreHeader(_ analysis: DermiqAnalysis) -> some View {
        ZStack {
            DQScoreRing(progress: ringProgress, lineWidth: 11)
                .frame(width: 218, height: 218)
            VStack(spacing: 2) {
                DQCountUpScore(
                    target: analysis.overall,
                    size: 84,
                    play: playCountUp
                ) {
                    countUpFinished = true
                }
                Text("SKIN SCORE")
                    .font(DQFont.mono(11, weight: .semibold))
                    .foregroundStyle(DQColor.textSecondary)
                    .tracking(2)
            }
        }
        .padding(.top, 8)
    }

    private func subScoreGrid(_ analysis: DermiqAnalysis) -> some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)],
                  spacing: 12) {
            ForEach(analysis.subScores) { score in
                DQSubScoreCard(score: score)
            }
        }
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

    // MARK: Reveal choreography

    private func unlockAndReveal() {
        guard !revealed else { return }
        guard let analysis = model.analysis else { return }
        withAnimation(.easeOut(duration: 0.6)) { revealed = true }
        Task {
            // Blur fully dissolves first; THEN the count-up plays.
            try? await Task.sleep(for: .milliseconds(650))
            playCountUp = true
            withAnimation(.easeOut(duration: 1.9)) {
                ringProgress = Double(analysis.overall) / 100
            }
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
                                .foregroundStyle(DQColor.background)
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
