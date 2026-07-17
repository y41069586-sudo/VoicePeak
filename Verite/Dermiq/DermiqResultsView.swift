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

    /// Pro reveals everything; a one-time "rating"/"routine" purchase reveals
    /// exactly THIS scan (the record exists by the time results show).
    private var unlocked: Bool {
        purchases.isPro
            || (model.record.map { UnlockStore.shared.isRatingUnlocked($0.id) } ?? false)
    }

    /// The 14-day plan: auto-included only on Pro's two WEEKLY scans. A
    /// credit scan (€1.99 extra / bonus) — even for Pro — and any non-Pro
    /// scan needs the €3.99 one-time buy on the CTA (plan only).
    private var planAllowed: Bool {
        (purchases.isPro && !model.usedCredit)
            || (model.record.map { UnlockStore.shared.isRoutineUnlocked($0.id) } ?? false)
    }

    private var routineOncePrice: String {
        purchases.displayPrice(for: VeriteProducts.routineOnce) ?? "€3,99"
    }

    @State private var planPurchasing = false
    @State private var planPurchaseFailed = false

    /// Buy the 14-day plan for THIS scan, then continue into plan creation.
    private func buyPlan() {
        guard let record = model.record, !planPurchasing else { return }
        planPurchasing = true
        Task {
            defer { planPurchasing = false }
            guard purchases.displayPrice(for: VeriteProducts.routineOnce) != nil else {
                planPurchaseFailed = true
                return
            }
            guard await purchases.purchaseConsumable(productID: VeriteProducts.routineOnce) else { return }
            UnlockStore.shared.unlock(.routine, scanID: record.id)
            RampAnalytics.track("plan_purchased")
            onContinue()
        }
    }

    /// The paywall doesn't pounce: the blurred chart gets ~1.6s alone on
    /// screen (the tease), THEN the card slides up from the bottom.
    @State private var paywallShown = false
    /// The one-time win-back offer (shown once, on dismiss).
    @State private var showWinBack = false
    @AppStorage("dq.winback.shown") private var winBackSeen = false

    var body: some View {
        ZStack {
            DQColor.background.ignoresSafeArea()

            if let analysis = model.analysis {
                results(analysis, locked: !revealed)
                    .allowsHitTesting(revealed)

                if !revealed && paywallShown && !showWinBack {
                    DermiqPaywallCard(scanID: model.record?.id) {
                        unlockAndReveal()
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    closeButton
                        .transition(.opacity)
                }

                if showWinBack {
                    DermiqWinBackCard(
                        onSubscribed: { showWinBack = false; unlockAndReveal() },
                        onDismiss: { withAnimation { showWinBack = false }; onClose() }
                    )
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .zIndex(2)
                }
            }
        }
        .onAppear {
            if unlocked { unlockAndReveal() }
        }
        .alert("Couldn't load plans", isPresented: $planPurchaseFailed) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Check your connection and try again.")
        }
        .task {
            guard !unlocked else { return }
            try? await Task.sleep(for: .milliseconds(1600))
            guard !Task.isCancelled, !revealed else { return }
            Haptics.fire(.transition)
            if reduceMotion {
                paywallShown = true
            } else {
                withAnimation(.spring(response: 0.55, dampingFraction: 0.85)) {
                    paywallShown = true
                }
            }
        }
    }

    private var closeButton: some View {
        VStack {
            HStack {
                Button {
                    Haptics.fire(.selection)
                    // One-time win-back on the way out: only if it hasn't been
                    // seen, the user isn't already Pro, and the offer product
                    // actually loaded. Otherwise just leave — never trap them.
                    if !winBackSeen && !unlocked
                        && purchases.displayPrice(for: VeriteProducts.proYearlyOffer) != nil {
                        winBackSeen = true
                        RampAnalytics.track("winback_shown")
                        withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) {
                            showWinBack = true
                        }
                    } else {
                        onClose()
                    }
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
                    (locked ? Text("👀 Reveal your results") : Text("Your skin analysis"))
                        .font(.system(size: 26, weight: .heavy, design: .rounded))
                        .foregroundStyle(DQColor.textPrimary)
                        .multilineTextAlignment(.center)
                    (locked
                     ? Text("Unlock to see your full skin analysis and your 14-day potential.")
                     : Text("A reading of you — with your 14-day potential."))
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
                            // Pro (or already-bought plan) → straight through.
                            // Otherwise the CTA IS the €3.99 plan purchase —
                            // price on the button (no surprise charges, 3.1.1),
                            // and it buys ONLY the plan, not the charts.
                            if planAllowed {
                                DQPrimaryButton(title: "Make me a 10/10",
                                                systemImage: "sparkles") { onContinue() }
                            } else {
                                DQPrimaryButton(
                                    title: planPurchasing
                                        ? String(localized: "Unlocking…")
                                        : String(format: String(localized: "Make me a 10/10 · %@"),
                                                 routineOncePrice),
                                    systemImage: "sparkles",
                                    isEnabled: !planPurchasing
                                ) { buyPlan() }
                                Text("One-time purchase — your 14-day plan, built from this scan.")
                                    .font(DQFont.micro)
                                    .foregroundStyle(DQColor.textSecondary)
                                    .multilineTextAlignment(.center)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
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
            VStack(spacing: 14) {
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
                // Reading key — without this, "Blemishes 80" reads like a lot
                // of blemishes. Every metric is scored the same way up.
                HStack(spacing: 5) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(DQColor.accentBright)
                    Text("Every score runs 0–100 — higher is always better.")
                        .font(DQFont.micro)
                        .foregroundStyle(DQColor.textSecondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
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
                    .minimumScaleFactor(0.8)
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
                        .tracking(2)
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
                        Text("· Top \(bestTop)%")
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
    /// The scan a one-time purchase applies to. Nil when the paywall opens
    /// BEFORE a scan exists (scan-blocked) — then a one-time buy grants one
    /// scan credit and attaches to the next scan via UnlockStore.pending.
    var scanID: UUID? = nil
    let onUnlocked: () -> Void

    @Environment(PurchaseManager.self) private var purchases

    /// Two cards: the Pro sub or a one-time rating unlock. (The 14-day plan
    /// is sold contextually on the results CTA, not here.)
    private enum PlanChoice { case ratingOnce, pro }
    @State private var choice: PlanChoice = .pro
    /// Pro billing term — annual is the anchor, weekly the flexible option.
    @State private var proAnnual = true
    @State private var purchasing = false
    @State private var legalDocument: LegalDocument?
    @State private var purchaseFailed = false
    @State private var restoreDone = false

    var body: some View {
        VStack {
            Spacer()
            card
        }
        .ignoresSafeArea(edges: .bottom)
        .alert("Couldn't load plans", isPresented: $purchaseFailed) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Check your connection and try again.")
        }
        .alert("Restore complete", isPresented: $restoreDone) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("If you had an active purchase, it's back. Nothing found? There was nothing to restore.")
        }
    }

    private var card: some View {
        VStack(spacing: 18) {
            Capsule()
                .fill(DQColor.stroke)
                .frame(width: 40, height: 4)
                .padding(.top, 12)
            // Hugs its content when it fits (the normal case); on SE-class
            // heights it swaps to a ScrollView so every row stays reachable.
            ViewThatFits(in: .vertical) {
                cardContent
                ScrollView { cardContent }
            }
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

    private var cardContent: some View {
        VStack(spacing: 18) {
            VStack(spacing: 12) {
                Text("Your score is ready.")
                    .font(DQFont.title)
                    .foregroundStyle(DQColor.textPrimary)

                // The value stack — what unlocking actually gets you, scannable
                // in two seconds at the moment of peak curiosity.
                VStack(alignment: .leading, spacing: 7) {
                    valueRow("Your score + all 7 metrics revealed")
                    valueRow("2 fresh skin scans every week")
                    valueRow("14-day routine, AI-checked for your skin")
                    valueRow("Zone map & your 14-day potential")
                    valueRow("Glow-Up Reel, share cards & rescans")
                }
            }
            .padding(.horizontal, 24)

            VStack(spacing: 10) {
                planRow(.pro,
                        title: "Glowé Pro",
                        price: proAnnual
                            ? price(for: VeriteProducts.proYearly, fallback: String(localized: "$39.99 / year"))
                            : price(for: VeriteProducts.proWeekly, fallback: String(localized: "$4.99 / week")),
                        badge: proAnnual ? "SAVE 84%" : nil,
                        sub: proAnnual
                            ? "\(String(localized: "2 scans a week · routine included")) · \(annualWeeklyEquivalent)"
                            : String(localized: "2 scans a week · routine included"))

                // Pro billing term — only shown while Pro is the selection.
                if choice == .pro {
                    HStack(spacing: 8) {
                        proTermChip("Annual", active: proAnnual) { proAnnual = true }
                        proTermChip("Weekly", active: !proAnnual) { proAnnual = false }
                    }
                }

                planRow(.ratingOnce,
                        title: "Rating only",
                        price: price(for: VeriteProducts.ratingOnce, fallback: String(localized: "$1.99 one-time")),
                        badge: nil,
                        sub: String(localized: "This scan · score + all 7 metrics"))
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
                      message: Text("Scan your skin with me — copy this whole message and paste it in Glowé for a free scan.")) {
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
                            if purchases.isPro { onUnlocked() } else { restoreDone = true }
                        }
                    }
                }
                .font(DQFont.caption)
                .foregroundStyle(DQColor.textSecondary)
            }
            .padding(.bottom, 30)
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
        guard let weekly = purchases.weeklyEquivalent(forYearly: VeriteProducts.proYearly)
        else { return String(localized: "≈ $0.77 / week") }
        return "≈ \(weekly) / week"
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
        purchases.displayPrice(for: productID) ?? fallback
    }

    /// Small Annual/Weekly switch shown inside the Pro selection.
    private func proTermChip(_ title: String, active: Bool,
                             action: @escaping () -> Void) -> some View {
        Button {
            Haptics.fire(.selection)
            action()
        } label: {
            Text(LocalizedStringKey(title))
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(active ? Color.white : DQColor.textSecondary)
                .padding(.horizontal, 14).padding(.vertical, 7)
                .background(active ? AnyShapeStyle(DQColor.accentBright)
                                   : AnyShapeStyle(DQColor.surface),
                            in: Capsule())
                .overlay(Capsule().strokeBorder(
                    active ? Color.clear : DQColor.stroke, lineWidth: 1))
        }
        .buttonStyle(PressableStyle())
    }

    private func purchase() {
        purchasing = true
        Task {
            defer { purchasing = false }
            switch choice {
            case .ratingOnce:
                let id = VeriteProducts.ratingOnce
                guard purchases.displayPrice(for: id) != nil else {
                    purchaseFailed = true
                    return
                }
                guard await purchases.purchaseConsumable(productID: id) else { return }
                if let scanID {
                    // Bought on the blurred results — unlock THIS scan.
                    UnlockStore.shared.unlock(.rating, scanID: scanID)
                } else {
                    // Bought before scanning — grant one scan credit and
                    // attach the unlock to that upcoming scan.
                    UnlockStore.shared.setPending(.rating)
                    ReferralStore.shared.addCredit()
                }
                RampAnalytics.track("paywall_purchase", ["plan": id])
                onUnlocked()
            case .pro:
                let id = proAnnual ? VeriteProducts.proYearly : VeriteProducts.proWeekly
                guard purchases.displayPrice(for: id) != nil else {
                    // Products didn't load (offline / hiccup) — say so instead
                    // of silently resetting the button.
                    purchaseFailed = true
                    return
                }
                if await purchases.purchase(productID: id) {
                    RampAnalytics.track("paywall_purchase", ["plan": id])
                    onUnlocked()
                }
            }
        }
    }
}

// ============================================================
// MARK: — Win-back card (one-time discounted annual on dismiss)
// ============================================================

/// Shown ONCE, only when a non-subscriber dismisses the paywall: a genuine
/// discounted first-year annual (real StoreKit product, real price). App
/// Review-safe by construction:
///  • a real IAP — the price comes from StoreKit, never hard-coded;
///  • always dismissible via a clear ✕ — never a trap (2.3.1 / 3.1.1);
///  • honest framing ("one-time offer") — NO fake countdown / false urgency;
///  • full auto-renew disclosure + Terms + Privacy + Restore (3.1.2).
struct DermiqWinBackCard: View {
    let onSubscribed: () -> Void
    let onDismiss: () -> Void

    @Environment(PurchaseManager.self) private var purchases
    @State private var purchasing = false
    @State private var legalDocument: LegalDocument?
    @State private var purchaseFailed = false

    private var offerPrice: String {
        purchases.displayPrice(for: VeriteProducts.proYearlyOffer)
            ?? String(localized: "$21.99 / year")
    }
    private var fullPrice: String {
        purchases.displayPrice(for: VeriteProducts.proYearly)
            ?? String(localized: "$39.99 / year")
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.55).ignoresSafeArea()
                .onTapGesture { onDismiss() }
            VStack { Spacer(); card }
                .ignoresSafeArea(edges: .bottom)
        }
        .alert("Couldn't load the offer", isPresented: $purchaseFailed) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Check your connection and try again.")
        }
    }

    private var card: some View {
        VStack(spacing: 16) {
            HStack {
                Text("ONE-TIME OFFER")
                    .font(DQFont.mono(11, weight: .bold))
                    .tracking(2)
                    .foregroundStyle(DQColor.accentBright)
                Spacer()
                Button {
                    Haptics.fire(.selection)
                    onDismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(DQColor.textSecondary)
                        .frame(width: 34, height: 34)
                        .background(DQColor.surface, in: Circle())
                }
                .accessibilityLabel("Close")
            }

            Text("Before you go —\nyour first year, 45% off.")
                .font(DQFont.title)
                .foregroundStyle(DQColor.textPrimary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 10) {
                Text(verbatim: fullPrice)
                    .font(DQFont.headline)
                    .foregroundStyle(DQColor.textSecondary)
                    .strikethrough()
                Text(verbatim: offerPrice)
                    .font(.system(size: 22, weight: .heavy, design: .rounded))
                    .foregroundStyle(DQColor.textPrimary)
            }

            VStack(alignment: .leading, spacing: 7) {
                valueRow("Your score + all 7 metrics")
                valueRow("2 fresh skin scans every week")
                valueRow("Your 14-day routine, AI-checked")
            }
            .padding(.horizontal, 8)

            DQPrimaryButton(title: purchasing
                            ? String(localized: "Unlocking…")
                            : "\(String(localized: "Claim my offer")) · \(offerPrice)",
                            isEnabled: !purchasing) {
                purchase()
            }

            Button {
                Haptics.fire(.selection)
                onDismiss()
            } label: {
                Text("No thanks")
                    .font(DQFont.caption)
                    .foregroundStyle(DQColor.textSecondary)
            }

            VStack(spacing: 8) {
                Text("First year at the offer price, then renews at \(fullPrice). Auto-renewing; cancel anytime in your App Store settings.")
                    .font(DQFont.micro)
                    .foregroundStyle(DQColor.textSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 14) {
                    Button("Terms of Use") { legalDocument = .terms }
                    Button("Privacy Policy") { legalDocument = .privacy }
                    Button("Restore") {
                        Task {
                            await purchases.restore()
                            if purchases.isPro { onSubscribed() }
                        }
                    }
                }
                .font(DQFont.micro)
                .foregroundStyle(DQColor.textSecondary)
            }
        }
        .padding(22)
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
        .sheet(item: $legalDocument) { document in
            DermiqLegalView(document: document)
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

    private func purchase() {
        purchasing = true
        Task {
            defer { purchasing = false }
            guard purchases.displayPrice(for: VeriteProducts.proYearlyOffer) != nil else {
                purchaseFailed = true
                return
            }
            if await purchases.purchase(productID: VeriteProducts.proYearlyOffer) {
                RampAnalytics.track("winback_purchase")
                onSubscribed()
            }
        }
    }
}
