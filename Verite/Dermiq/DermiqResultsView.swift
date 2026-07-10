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
    @State private var displayedScore = 0
    @State private var ringProgress: Double = 0
    @State private var countUpFinished = false
    @State private var showProjected = false
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
        return ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: 24) {
                    // ---- First viewport: photo, toggle, the number ----
                    photoHeader
                        .id("top")
                    modeSwitch
                    scoreHeader(analysis, projection: projection)

                    if showProjected {
                        projectionBanner
                    }

                    // The invitation to go deeper — a soft, bouncing arrow.
                    Button {
                        Haptics.fire(.selection)
                        withAnimation(.easeInOut(duration: 0.55)) {
                            proxy.scrollTo("details", anchor: .top)
                        }
                    } label: {
                        DermiqScrollArrow()
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Show all metrics")

                    // ---- Details ----
                    metricList(analysis, projection: projection)
                        .id("details")
                    summaryBlock(analysis)

                    if !locked {
                        shareRow
                        if countUpFinished {
                            DQPrimaryButton(title: "Build my 14-day plan",
                                            systemImage: "calendar.badge.plus") { onContinue() }
                                .animation(VMotion.gentle, value: countUpFinished)
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 20)
                .padding(.bottom, 40)
            }
            .scrollIndicators(.hidden)
        }
    }

    /// The user's own capture, softly framed — the proof this reading is
    /// about THEM ("das hast du gerade gemacht").
    @ViewBuilder
    private var photoHeader: some View {
        if let image = model.capturedImage {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: 112, height: 112)
                .clipShape(Circle())
                .overlay(Circle().strokeBorder(DQColor.accent.opacity(0.6), lineWidth: 2))
                .shadow(color: DQColor.accent.opacity(0.3), radius: 18, y: 8)
                .padding(.top, 26)
        }
    }

    /// Now ⇄ After 14 days — a two-segment capsule with a sliding thumb.
    private var modeSwitch: some View {
        HStack(spacing: 0) {
            segment("Now", active: !showProjected) { setProjected(false) }
            segment("After 14 days", active: showProjected) { setProjected(true) }
        }
        .padding(4)
        .background(DQColor.surface, in: Capsule())
        .overlay(Capsule().strokeBorder(DQColor.stroke, lineWidth: 1))
        .frame(maxWidth: 300)
    }

    private func segment(_ title: String, active: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundStyle(active ? Color.white : DQColor.textSecondary)
                .frame(maxWidth: .infinity, minHeight: 36)
                .background(
                    active ? AnyShapeStyle(DQColor.accentGradient) : AnyShapeStyle(Color.clear),
                    in: Capsule()
                )
        }
        .buttonStyle(.plain)
        .animation(VMotion.snappy, value: active)
    }

    private func scoreHeader(_ analysis: DermiqAnalysis,
                             projection: DermiqProjection.Projected) -> some View {
        VStack(spacing: 12) {
            ZStack {
                DQScoreRing(progress: ringProgress, lineWidth: 11)
                    .frame(width: 210, height: 210)
                VStack(spacing: 2) {
                    Text(verbatim: "\(displayedScore)")
                        .font(.system(size: 76, weight: .heavy, design: .rounded).monospacedDigit())
                        .foregroundStyle(DQColor.textPrimary)
                        .contentTransition(.numericText(value: Double(displayedScore)))
                    Text(showProjected ? "PROJECTED" : "SKIN SCORE")
                        .font(DQFont.mono(11, weight: .semibold))
                        .foregroundStyle(showProjected ? DQColor.accentBright : DQColor.textSecondary)
                        .tracking(2)
                        .contentTransition(.opacity)
                }
            }
            // Honest standing estimate — only for the real score (never the
            // projection), and always flagged "est." so it never reads as a
            // live ranking. Count-up must be done so the number matches.
            if !showProjected && countUpFinished {
                percentileBadge(overall: analysis.overall)
                    .transition(.opacity)
            }
        }
    }

    /// A quiet "Top X% · est." pill. The `est.` and the tap-hint keep it honest:
    /// it is derived from typical score ranges, not a measured leaderboard.
    private func percentileBadge(overall: Int) -> some View {
        let top = DermiqPercentile.topPercent(overall: overall)
        return VStack(spacing: 3) {
            HStack(spacing: 6) {
                Image(systemName: "chart.bar.fill")
                    .font(.system(size: 11, weight: .semibold))
                Text(verbatim: "Top \(top)% · est.")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
            }
            .foregroundStyle(DQColor.accentBright)
            .padding(.horizontal, 13)
            .padding(.vertical, 7)
            .background(DQColor.accentSoft, in: Capsule())

            Text("Estimated from typical score ranges — not a live ranking.")
                .font(DQFont.micro)
                .foregroundStyle(DQColor.textSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .animation(VMotion.gentle, value: countUpFinished)
    }

    /// Shown only in projection mode — the honesty label.
    private var projectionBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: "sparkles")
                .font(.system(size: 12, weight: .semibold))
            Text("A careful projection if you follow your plan — not a promise.")
                .font(DQFont.micro)
                .fixedSize(horizontal: false, vertical: true)
        }
        .foregroundStyle(DQColor.accentBright)
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .background(DQColor.surfaceElevated, in: Capsule())
        .transition(.opacity.combined(with: .move(edge: .top)))
    }

    /// All seven metrics, values switching with the mode; projection mode
    /// shows the honest gain per metric.
    private func metricList(_ analysis: DermiqAnalysis,
                            projection: DermiqProjection.Projected) -> some View {
        VStack(spacing: 10) {
            ForEach(analysis.subScores) { score in
                let projected = projection.value(for: score.category) ?? score.value
                let value = showProjected ? projected : score.value
                let gain = projected - score.value
                HStack(spacing: 12) {
                    Text(score.category.displayName)
                        .font(DQFont.headline)
                        .foregroundStyle(DQColor.textPrimary)
                        .frame(width: 96, alignment: .leading)
                    GeometryReader { proxy in
                        ZStack(alignment: .leading) {
                            Capsule().fill(DQColor.stroke.opacity(0.6))
                            Capsule()
                                .fill(DQColor.accentGradient)
                                .frame(width: proxy.size.width * CGFloat(value) / 100)
                        }
                    }
                    .frame(height: 7)
                    Text(verbatim: "\(value)")
                        .font(DQFont.mono(15, weight: .bold))
                        .foregroundStyle(DQColor.textPrimary)
                        .monospacedDigit()
                        .contentTransition(.numericText(value: Double(value)))
                        .frame(width: 30, alignment: .trailing)
                    Text(verbatim: showProjected && gain > 0 ? "+\(gain)" : "")
                        .font(DQFont.mono(11, weight: .bold))
                        .foregroundStyle(DQColor.deltaUp)
                        .frame(width: 28, alignment: .leading)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(DQColor.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(DQColor.stroke, lineWidth: 1)
                )
            }
        }
        .animation(VMotion.gentle, value: showProjected)
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

    // MARK: Mode + reveal choreography

    private func setProjected(_ projected: Bool) {
        guard showProjected != projected, let analysis = model.analysis else { return }
        Haptics.fire(.tick)
        let target = projected
            ? DermiqProjection.project(analysis).overall
            : analysis.overall
        withAnimation(VMotion.gentle) {
            showProjected = projected
            displayedScore = target
            ringProgress = Double(target) / 100
        }
    }

    private func unlockAndReveal() {
        guard !revealed else { return }
        guard let analysis = model.analysis else { return }
        withAnimation(.easeOut(duration: 0.6)) { revealed = true }
        Task {
            // Blur fully dissolves first; THEN the score counts up.
            try? await Task.sleep(for: .milliseconds(650))
            withAnimation(.easeOut(duration: 1.9)) {
                displayedScore = analysis.overall
                ringProgress = Double(analysis.overall) / 100
            }
            try? await Task.sleep(for: .milliseconds(2000))
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

/// The gentle bouncing chevron that says "there's more below".
private struct DermiqScrollArrow: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var bob = false

    var body: some View {
        Image(systemName: "chevron.down")
            .font(.system(size: 18, weight: .semibold))
            .foregroundStyle(DQColor.accentBright)
            .frame(width: 44, height: 44)
            .background(DQColor.surface, in: Circle())
            .overlay(Circle().strokeBorder(DQColor.stroke, lineWidth: 1))
            .offset(y: bob && !reduceMotion ? 5 : -1)
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) {
                    bob = true
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
