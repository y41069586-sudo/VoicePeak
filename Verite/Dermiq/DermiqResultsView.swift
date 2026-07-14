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

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var revealed = false
    @State private var countUpFinished = false
    @State private var shareURL: URL?
    /// 0…1 multiplier on every score during the reveal count-up.
    @State private var countReveal: Double = 1
    /// Brief scale bump on the Overall number when the count-up lands.
    @State private var overallPulse = false

    /// The iOS-style segmented toggle: false = your score now, true = the
    /// conservative 14-day projection. Flipping it re-drives every grid cell.
    @State private var showProjected = false
    @Namespace private var segmentNS

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

                // ---- Now ⇄ In 14 days. Flips the whole grid between the real
                // reading and the conservative projection. Only after unlock —
                // under the paywall the numbers are blurred anyway.
                if !locked {
                    modeSwitch
                }

                // ---- The card: your photo straddling a 2-column metric grid.
                // Overall lives inside the grid as the lead cell — never a big
                // number under the photo. Under the paywall only the VALUES
                // blur; photo + labels stay crisp, exactly like the reference.
                gridCard(analysis, projection: projection, locked: locked)

                if !locked {
                    percentileCard(analysis)
                    potentialNote
                    expectationsCard(analysis)
                }

                if !locked {
                    DermiqZoneMapCard(analysis: analysis)
                    summaryBlock(analysis)
                    shareRow
                    // Leads to the Potential reveal (the before/after image);
                    // the plan CTA lives on THAT screen. "Done" is the repeat
                    // scanner's exit — check the reading, keep the current
                    // plan, no regeneration every time.
                    if countUpFinished {
                        VStack(spacing: 10) {
                            DQPrimaryButton(title: "Make me a 10/10",
                                            systemImage: "sparkles") { onContinue() }
                            Button {
                                Haptics.fire(.selection)
                                onClose()
                            } label: {
                                Text("Done")
                                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                                    .foregroundStyle(DQColor.textSecondary)
                                    .frame(maxWidth: .infinity, minHeight: 44)
                            }
                            .buttonStyle(PressableStyle())
                        }
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
        .frame(width: 116, height: 116)
        .clipShape(Circle())
        .overlay(Circle().strokeBorder(DQColor.surface, lineWidth: 4))
        .overlay(Circle().strokeBorder(DQColor.accentSoft, lineWidth: 4).padding(-4))
        .shadow(color: DQColor.accent.opacity(0.28), radius: 14, y: 8)
    }

    /// The iOS-style segmented toggle. A white pill slides between the two
    /// segments (matchedGeometry), flipping the whole grid Now ⇄ In 14 days.
    private var modeSwitch: some View {
        HStack(spacing: 4) {
            segment(title: "Now", active: !showProjected) { setProjected(false) }
            segment(title: "In 14 days", active: showProjected) { setProjected(true) }
        }
        .padding(4)
        .background(DQColor.accentSoft, in: Capsule())
        .frame(maxWidth: 300)
    }

    private func segment(title: String, active: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(LocalizedStringKey(title))
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(active ? DQColor.accentBright : DQColor.textSecondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 9)
                .background {
                    if active {
                        Capsule()
                            .fill(DQColor.surface)
                            .shadow(color: DQColor.accent.opacity(0.18), radius: 6, y: 2)
                            .matchedGeometryEffect(id: "segmentPill", in: segmentNS)
                    }
                }
        }
        .buttonStyle(.plain)
    }

    private func setProjected(_ value: Bool) {
        guard showProjected != value else { return }
        Haptics.fire(.selection)
        withAnimation(VMotion.gentle) { showProjected = value }
    }

    /// The metric grid card. Overall is the lead cell, then every sub-score,
    /// two columns — exactly the six-grid reference, with Overall *inside* the
    /// grid (not a big number under the photo). Each cell reads the "Now" value
    /// or the projected one depending on the toggle. `locked` blurs only the
    /// numbers and bars (not the labels).
    private func gridCard(_ analysis: DermiqAnalysis,
                          projection: DermiqProjection.Projected,
                          locked: Bool) -> some View {
        let columns = [GridItem(.flexible(), spacing: 22),
                       GridItem(.flexible(), spacing: 22)]
        return ZStack(alignment: .top) {
            LazyVGrid(columns: columns, alignment: .leading, spacing: 20) {
                metricCell(label: "Overall",
                           now: analysis.overall,
                           projected: projection.overall,
                           lead: true, locked: locked,
                           reveal: countReveal, pulse: overallPulse)
                ForEach(analysis.subScores) { score in
                    metricCell(label: score.category.displayName,
                               now: score.value,
                               projected: projection.value(for: score.category) ?? score.value,
                               lead: false, locked: locked,
                               reveal: countReveal)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 76)
            .padding(.bottom, 22)
            .frame(maxWidth: .infinity)
            .background(DQColor.surface, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 26, style: .continuous)
                .strokeBorder(DQColor.stroke, lineWidth: 1))

            capturedAvatar
                .offset(y: -58)
        }
        .padding(.top, 58)
    }

    /// One metric: label, big number, thin progress bar. In projected mode the
    /// value morphs to the 14-day figure, the bar tints brighter, and a small
    /// ↑/↓ delta chip shows the change. `lead` (Overall) tints its number.
    private func metricCell(label: String, now: Int, projected: Int,
                            lead: Bool, locked: Bool,
                            reveal: Double = 1, pulse: Bool = false) -> some View {
        let value = showProjected ? projected : now
        let shown = Int((Double(value) * reveal).rounded())   // count-up multiplier
        let delta = projected - now
        let tinted = lead || showProjected
        return VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 5) {
                Text(LocalizedStringKey(label))
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(DQColor.textSecondary)
                    .lineLimit(1)
                Spacer(minLength: 0)
                if showProjected && delta != 0 {
                    deltaChip(delta)
                }
            }
            Text(verbatim: "\(shown)")
                .font(.system(size: 27, weight: .heavy, design: .rounded).monospacedDigit())
                .foregroundStyle(tinted ? DQColor.accentBright : DQColor.textPrimary)
                .contentTransition(.numericText(value: Double(shown)))
                .scaleEffect(pulse ? 1.08 : 1)
                .blur(radius: locked ? 9 : 0)
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(DQColor.stroke.opacity(0.7))
                    Capsule().fill(showProjected ? DQColor.accentBright : DQColor.accent)
                        .frame(width: proxy.size.width * CGFloat(shown) / 100)
                }
            }
            .frame(height: 6)
            .blur(radius: locked ? 4 : 0)
            .opacity(locked ? 0.7 : 1)
        }
        .animation(VMotion.gentle, value: locked)
        .animation(VMotion.gentle, value: showProjected)
    }

    /// The ↑/↓ change pill shown on each cell in projected mode.
    private func deltaChip(_ delta: Int) -> some View {
        let up = delta >= 0
        return HStack(spacing: 2) {
            Image(systemName: up ? "arrow.up" : "arrow.down")
                .font(.system(size: 8, weight: .black))
            Text(verbatim: "\(abs(delta))")
                .font(.system(size: 10, weight: .bold, design: .rounded).monospacedDigit())
        }
        .foregroundStyle(up ? DQColor.deltaUp : DQColor.deltaDown)
        .padding(.horizontal, 5).padding(.vertical, 1)
        .background((up ? DQColor.deltaUp : DQColor.deltaDown).opacity(0.12), in: Capsule())
    }

    /// Honest note under the grid — Potential is a projection, never a promise.
    private var potentialNote: some View {
        HStack(spacing: 8) {
            Image(systemName: "sparkles")
                .font(.system(size: 12, weight: .semibold))
            Text("“In 14 days” is a careful projection if you follow your plan — not a promise.")
                .font(DQFont.micro)
                .fixedSize(horizontal: false, vertical: true)
        }
        .foregroundStyle(DQColor.accentBright)
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity)
        .background(DQColor.surfaceElevated, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    /// The competitive hook: estimated standing. Overall "Top X%" plus the
    /// user's STRONGEST metric called out ("Top 8% Glow"). Clearly labeled as
    /// an estimate against a reference distribution — no fake live leaderboard.
    private func percentileCard(_ analysis: DermiqAnalysis) -> some View {
        let top = DermiqPercentile.topPercent(overall: analysis.overall)
        let best = analysis.subScores.max { $0.value < $1.value }
        return DQCard {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("YOUR STANDING")
                        .font(DQFont.mono(11, weight: .semibold))
                        .foregroundStyle(DQColor.accentBright)
                    Spacer()
                    Text("est.")
                        .font(DQFont.mono(9, weight: .semibold))
                        .foregroundStyle(DQColor.textSecondary)
                }
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text("Top")
                        Text(verbatim: "\(top)%")
                    }
                    .font(.system(size: 40, weight: .heavy, design: .rounded).monospacedDigit())
                    .foregroundStyle(DQColor.accentBright)
                    Spacer()
                    if top <= 25 {
                        Image(systemName: "trophy.fill")
                            .font(.system(size: 22))
                            .foregroundStyle(DQColor.accentBright)
                    }
                }
                if let best {
                    let bestTop = DermiqPercentile.topPercent(overall: best.value)
                    HStack(spacing: 6) {
                        Image(systemName: "flame.fill")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(DQColor.accentBright)
                        Text("Your strongest:")
                            .font(DQFont.caption)
                            .foregroundStyle(DQColor.textSecondary)
                        Text(LocalizedStringKey(best.category.displayName))
                            .font(DQFont.caption.weight(.semibold))
                            .foregroundStyle(DQColor.textPrimary)
                        Text(verbatim: "· Top \(bestTop)%")
                            .font(DQFont.caption.weight(.semibold))
                            .foregroundStyle(DQColor.accentBright)
                    }
                }
                Text("Estimated against a typical score distribution — not a live ranking.")
                    .font(DQFont.micro)
                    .foregroundStyle(DQColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    /// Honest per-area timeline: the plan targets the three weakest scores, and
    /// they don't all move at the same speed. Groups them into what's realistic
    /// by day 14 vs. what's a longer play — so the projection above never reads
    /// as "everything fixed in two weeks".
    private func expectationsCard(_ analysis: DermiqAnalysis) -> some View {
        let targeted = analysis.weakestThree
        let order: [DermiqProjection.Horizon] = [.fast, .gradual, .slow]
        let groups: [(DermiqProjection.Horizon, [DermiqSubScore])] =
            order.compactMap { horizon in
                let scores = targeted.filter { DermiqProjection.horizon(for: $0.category) == horizon }
                return scores.isEmpty ? nil : (horizon, scores)
            }
        return DQCard {
            VStack(alignment: .leading, spacing: 16) {
                Text("WHAT TO EXPECT")
                    .font(DQFont.mono(11, weight: .semibold))
                    .foregroundStyle(DQColor.accentBright)
                ForEach(groups.indices, id: \.self) { index in
                    let horizon = groups[index].0
                    let scores = groups[index].1
                    VStack(alignment: .leading, spacing: 9) {
                        HStack(spacing: 6) {
                            Image(systemName: horizon.icon)
                                .font(.system(size: 11, weight: .bold))
                            Text(LocalizedStringKey(horizon.heading))
                                .font(DQFont.mono(10, weight: .bold))
                                .tracking(1)
                        }
                        .foregroundStyle(horizon == .slow ? DQColor.textSecondary : DQColor.accentBright)
                        ForEach(scores) { score in
                            HStack(alignment: .top, spacing: 8) {
                                Text(LocalizedStringKey(score.category.displayName))
                                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                                    .foregroundStyle(DQColor.textPrimary)
                                    .frame(width: 74, alignment: .leading)
                                Text(LocalizedStringKey(DermiqProjection.expectation(for: score.category)))
                                    .font(DQFont.micro)
                                    .foregroundStyle(DQColor.textSecondary)
                                    .fixedSize(horizontal: false, vertical: true)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                    }
                }
                Text("Your plan hits all three from day one — you just see the fast ones first.")
                    .font(DQFont.micro)
                    .foregroundStyle(DQColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 2)
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
        // The value-blur dissolves as `revealed` flips; the scores then race up.
        withAnimation(.easeOut(duration: 0.6)) { revealed = true }
        afterUnlock()

        if reduceMotion {
            countReveal = 1
            withAnimation(VMotion.gentle) { countUpFinished = true }
            return
        }
        countReveal = 0
        Task { await runScoreCountUp() }
    }

    /// The reveal moment: every number races up, decelerates as it lands, a
    /// haptic crescendo thins out with it, then a milestone tap + a brief pulse
    /// on the Overall. No grid flash — the count-up carries the moment.
    private func runScoreCountUp() async {
        let steps = 26
        for i in 1...steps {
            let t = Double(i) / Double(steps)
            withAnimation(.linear(duration: 0.05)) {
                countReveal = 1 - pow(1 - t, 2.4)          // easeOut → decelerates
            }
            if i % 2 == 0 { Haptics.fire(.tick) }          // ticks thin out as it slows
            try? await Task.sleep(for: .seconds(0.026 + 0.055 * t))
            if Task.isCancelled { return }
        }
        withAnimation(.easeOut(duration: 0.12)) { countReveal = 1 }
        Haptics.fire(.milestone)
        withAnimation(VMotion.snappy) { overallPulse = true }
        try? await Task.sleep(for: .milliseconds(170))
        withAnimation(VMotion.gentle) { overallPulse = false }
        withAnimation(VMotion.gentle) { countUpFinished = true }
    }

    /// Post-unlock side effects: render the shareable Reading Card, and — from
    /// the 3rd completed scan, once ever — the native review ask (5.6.3-safe:
    /// this is a real positive moment, far from onboarding).
    private func afterUnlock() {
        guard let analysis = model.analysis else { return }
        if shareURL == nil {
            // v2: the share image mirrors THIS screen — photo over the score
            // grid — instead of the old porcelain reading card.
            let card = DermiqShareCard(
                analysis: analysis,
                photo: model.capturedImage,
                displayName: profiles.first?.displayName
            )
            if let image = ShareRenderer.image(for: card, size: DermiqShareCard.size),
               let url = ShareRenderer.pngURL(for: image, name: "skin-analysis") {
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

            VStack(spacing: 12) {
                Text("Your score is ready.")
                    .font(DQFont.title)
                    .foregroundStyle(DQColor.textPrimary)

                // The value stack — what unlocking actually gets you, scannable
                // in two seconds at the moment of peak curiosity.
                VStack(alignment: .leading, spacing: 7) {
                    valueRow("Your score + all 7 metrics revealed")
                    valueRow("14-day routine, AI-checked for your skin")
                    valueRow("Zone map & your 14-day potential")
                    valueRow("Skin Duel, Glow-Up Reel & rescans")
                }
            }
            .padding(.horizontal, 24)

            VStack(spacing: 10) {
                planRow(.annual,
                        title: "Annual",
                        price: price(for: VeriteProducts.proYearly, fallback: "$39.99 / year"),
                        badge: "SAVE 84%",
                        sub: annualWeeklyEquivalent)
                planRow(.weekly,
                        title: "Weekly",
                        price: price(for: VeriteProducts.proWeekly, fallback: "$4.99 / week"),
                        badge: nil,
                        sub: nil)
            }
            .padding(.horizontal, 20)

            DQPrimaryButton(title: purchasing ? "Unlocking…" : "Unlock my results",
                            isEnabled: !purchasing) {
                purchase()
            }
            .padding(.horizontal, 20)

            // The real referral link: the friend redeems it for a bonus scan
            // (ReferralStore), and can send a thank-you link back. Sharing
            // never unlocks Pro — no fake "invite 3 to unlock" gate.
            ShareLink(item: ReferralStore.shared.inviteURL,
                      message: Text("Scan your skin with me — this link gives us both a free scan.")) {
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

    private func valueRow(_ text: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(DQColor.accentBright)
            Text(LocalizedStringKey(text))
                .font(DQFont.caption)
                .foregroundStyle(DQColor.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
    }

    /// "≈ $0.77 / week" — the annual price broken down so the anchor lands.
    private var annualWeeklyEquivalent: String {
        guard let product = purchases.products.first(where: { $0.id == VeriteProducts.proYearly })
        else { return "≈ $0.77 / week" }
        let weekly = product.price / 52
        return "≈ \(weekly.formatted(product.priceFormatStyle)) / week"
    }

    private func planRow(_ plan: PlanChoice, title: String, price: String,
                         badge: String?, sub: String?) -> some View {
        Button {
            Haptics.fire(.selection)
            choice = plan
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 8) {
                        Text(LocalizedStringKey(title))
                            .font(DQFont.headline)
                            .foregroundStyle(DQColor.textPrimary)
                        if let badge {
                            Text(LocalizedStringKey(badge))
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
                    if let sub {
                        Text(verbatim: sub)
                            .font(DQFont.micro)
                            .foregroundStyle(DQColor.accentBright)
                    }
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
