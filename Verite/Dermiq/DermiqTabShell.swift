import SwiftUI
import SwiftData
import UIKit
import GoogleSignIn

// ============================================================
// MARK: — v2 shell: Scan / Routine / Progress
// ============================================================

struct DermiqTabShell: View {
    enum Tab: String, CaseIterable {
        case scan, routine, progress

        var title: String {
            switch self {
            case .scan: return "Home"
            case .routine: return "Routine"
            case .progress: return "Progress"
            }
        }

        var icon: String {
            switch self {
            case .scan: return "house.fill"
            case .routine: return "checklist"
            case .progress: return "chart.line.uptrend.xyaxis"
            }
        }
    }

    @Environment(\.modelContext) private var modelContext
    @Environment(PurchaseManager.self) private var purchases
    @Environment(AppState.self) private var appState
    @Query(sort: \ScanRecord.date, order: .reverse) private var scans: [ScanRecord]

    /// Single source of truth for entitlement: a real, verified StoreKit
    /// subscription. No simulated/free unlock — that path is gone now that
    /// purchases are live.
    private var hasPro: Bool { purchases.isPro }

    @State private var tab: Tab = .scan
    @State private var showFlow = false
    @State private var showSettings = false
    @State private var autoLaunched = false
    @State private var showQuotaSheet = false
    @State private var quotaNextFree: Date?
    @State private var showPaywall = false
    /// The user opened the paywall by trying to scan → once they unlock,
    /// carry them straight into the scan they wanted.
    @State private var scanAfterUnlock = false
    /// A tapped compare link (verite://compare) lands here.
    @State private var compareInbox = CompareInbox.shared
    /// Extra-scan product unavailable (not loaded from the App Store).
    @State private var extraScanFailed = false
    /// The €1.99 extra-scan purchase is in flight — drives the buy button's
    /// loading state in ScanLimitSheet.
    @State private var extraScanPurchasing = false
    /// The launched scan was paid with a credit (extra scan / bonus) — such
    /// scans don't auto-include a new 14-day plan, even for Pro.
    @State private var flowUsedCredit = false

    var body: some View {
        // Stock SwiftUI TabView — no custom bar. Built against the iOS 26 SDK
        // the system bar renders in Liquid Glass (floating, scroll-aware) on
        // its own; on earlier iOS it's the familiar native tab bar.
        nativeTabs
        .background(DQColor.background.ignoresSafeArea())
        .dermiqBadgeAwards()
        .sheet(isPresented: $showSettings) {
            DermiqSettingsView()
        }
        .sheet(isPresented: $showQuotaSheet) {
            // Pro weekly cap ONLY — non-Pro never reaches this sheet
            // (startScan sends them straight to the paywall).
            ScanLimitSheet(nextScan: quotaNextFree,
                           extraScanPrice: extraScanPrice,
                           purchasing: extraScanPurchasing,
                           onBuyExtraScan: { buyExtraScan() })
        }
        // The ONE paywall — the same card that sits over the blurred results.
        // Presented as a drag-dismissible sheet, so it's never a dead end.
        .sheet(isPresented: $showPaywall) {
            // Scan-blocked context: a one-time rating buy attaches to the
            // NEXT scan (scanID nil → UnlockStore.pending + one credit).
            DermiqPaywallCard(onUnlocked: {
                showPaywall = false
                // They unlocked to scan → start it once the sheet is gone.
                if scanAfterUnlock {
                    scanAfterUnlock = false
                    Task {
                        try? await Task.sleep(for: .milliseconds(350))
                        startScan()
                    }
                }
            })
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .fullScreenCover(isPresented: $showFlow) {
            DermiqScanFlowView(previousScan: scans.first,
                               usedCredit: flowUsedCredit) { planCreated in
                showFlow = false
                if planCreated { tab = .routine }
                // Push the new scan up to the account (no-op when signed out /
                // local-only). Keeps cross-device history current.
                BackendSync.upload(backend: appState.backend, context: modelContext)
                // Award scan badges once the cover is gone, so the popup
                // lands on the shell — never on top of the paywall.
                Task {
                    try? await Task.sleep(for: .milliseconds(700))
                    BadgeCenter.shared.evaluateScanMilestones(context: modelContext)
                }
            }
        }
        .onChange(of: purchases.isPro) { _, _ in
            NotificationManager.syncReminders(planUnlocked: hasPro && !scans.isEmpty)
        }
        .onReceive(NotificationCenter.default.publisher(for: .dqOpenRoute)) { note in
            // A tapped reminder deep-links to the right tab.
            switch note.object as? String {
            case "routine": tab = .routine
            case "scan":    tab = .scan
            default:        break
            }
        }
        .onAppear {
            // Arm (or clear) the routine reminders the user asked for during
            // onboarding — but only now that we know Pro + scan state. A
            // non-Pro with a locked plan gets none; a Pro with a real plan gets
            // theirs at the chosen time.
            NotificationManager.syncReminders(planUnlocked: hasPro && !scans.isEmpty)

            // Onboarding hands off straight into the camera: with zero scans
            // AND an unused free scan, open the capture flow IMMEDIATELY and
            // without the cover's slide animation, so the home dashboard never
            // flashes behind it. The `freeScanUsed` guard stops a re-launch on
            // a later cold start if the first scan's record never persisted.
            guard !autoLaunched, scans.isEmpty,
                  !ReferralStore.shared.freeScanUsed else { return }
            autoLaunched = true
            flowUsedCredit = false // the free onboarding scan is not a credit scan
            ReferralStore.shared.clearNextScanUsesCredit()
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) { showFlow = true }
        }
        // Deep links. This must be a SUPERSET of RootView's handler, not just
        // widget taps: SwiftUI delivers an opened URL to only ONE onOpenURL,
        // and this inner one shadows RootView's. Handling only routine/scan
        // here (with `default: break`) is exactly why a tapped duel/compare
        // link opened the app and then died — the compare + invite routing in
        // RootView never ran. So mirror all of it. Every branch is idempotent
        // (Google returns false for non-auth URLs, invite has a one-per-install
        // guard, compare only stashes `pending`), so it's safe even on the iOS
        // versions where BOTH handlers fire.
        .onOpenURL { url in
            if GIDSignIn.sharedInstance.handle(url) { return }
            if url.scheme == "verite" {
                switch url.host {
                case "routine": withAnimation(VMotion.snappy) { tab = .routine }; return
                case "scan": withAnimation(VMotion.snappy) { tab = .scan }; return
                default: break
                }
            }
            if ReferralStore.shared.handle(url) { return }
            // A duel link almost always arrives on a COLD launch — the friend
            // taps it with SkinFix not running. Stashing `pending` synchronously
            // here flips the face-off sheet's binding during SwiftUI's very
            // first render pass, before there's a presented shell to host it,
            // so the sheet is silently dropped: the app opens and nothing
            // happens. Hand it off one runloop later, once the shell is on
            // screen, so the sheet actually presents. Warm launches just see a
            // ~0.4s beat before the duel appears.
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(400))
                _ = CompareInbox.shared.handle(url)
            }
        }
        .alert("Purchase unavailable", isPresented: $extraScanFailed) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("The extra scan isn't available right now. Check your connection and try again.")
        }
        // A tapped compare link opens the face-off sheet.
        .sheet(isPresented: Binding(
            get: { compareInbox.pending != nil },
            set: { if !$0 { compareInbox.consume() } }
        )) {
            if let opponent = compareInbox.pending {
                CompareView(opponent: opponent, onScanFirst: { startScan() })
            }
        }
    }

    private func startScan() {
        Haptics.fire(.selection)
        // No free tier: non-Pro gets the one onboarding scan (+ referral bonus
        // scans); everything else is Pro. Pro has a weekly fair-use cap —
        // every scan hits the paid analysis API.
        switch ScanQuota.decide(scans: scans, isPro: hasPro,
                                credits: ReferralStore.shared.credits,
                                freeScanUsed: ReferralStore.shared.freeScanUsed) {
        case .allow(let useCredit):
            if useCredit { ReferralStore.shared.consumeCredit() }
            flowUsedCredit = useCredit
            // Durable belt-and-braces: the flow re-reads this marker when the
            // scan persists, so a rebuilt cover can never lose "credit scan".
            if useCredit { ReferralStore.shared.markNextScanUsesCredit() }
            else { ReferralStore.shared.clearNextScanUsesCredit() }
            DermiqDiagnostics.record("Scan launch — credit=\(useCredit) pro=\(hasPro)")
            showFlow = true
        case .blockedNeedsPro:
            // Non-Pro out of free scans → the Pro paywall directly. It's the
            // real "get Pro" surface (score, 7 metrics, plan, plans to buy);
            // inviting a friend stays as a small secondary link inside it, not
            // the headline.
            scanAfterUnlock = true
            showPaywall = true
        case .blockedProWeekly(let nextScan):
            quotaNextFree = nextScan
            showQuotaSheet = true
        }
    }

    /// Live StoreKit display price for the extra scan, or "" while products
    /// aren't loaded — the sheet drops the "· price" suffix rather than show a
    /// hard-coded currency amount that could be wrong in the user's storefront.
    private var extraScanPrice: String {
        purchases.displayPrice(for: VeriteProducts.extraScan) ?? ""
    }

    /// Buy one extra scan (consumable). On success it becomes a scan credit
    /// and we carry the user straight into the scan they wanted. The buy
    /// button stays in a loading state (via `extraScanPurchasing`) until this
    /// resolves — the sheet dismisses itself on success.
    private func buyExtraScan() {
        guard !extraScanPurchasing else { return }
        Task {
            extraScanPurchasing = true
            defer { extraScanPurchasing = false }
            // Product not loaded (ASC product missing/not ready, offline) —
            // SAY so; a silent return here read as "the button does nothing".
            guard purchases.displayPrice(for: VeriteProducts.extraScan) != nil else {
                showQuotaSheet = false
                extraScanFailed = true
                return
            }
            guard await purchases.purchaseConsumable(productID: VeriteProducts.extraScan) else { return }
            ReferralStore.shared.addCredit()
            RampAnalytics.track("extra_scan_purchased")
            showQuotaSheet = false   // dismiss the cap sheet
            // Let the sheet dismissal + the purchase confirmation settle.
            try? await Task.sleep(for: .milliseconds(300))
            startScan()
        }
    }

    /// The plain, by-the-book TabView. Each tab is tagged with the same enum
    /// the rest of the shell drives (post-scan jump to Routine, widget links),
    /// and the bar itself is 100% system — which is what makes it Liquid Glass.
    @ViewBuilder
    private var nativeTabs: some View {
        let tabs = TabView(selection: $tab) {
            DermiqScanHome(
                scans: scans,
                onScan: { startScan() },
                onSettings: { showSettings = true },
                onRoutine: { tab = .routine },
                onProgress: { tab = .progress }
            )
            .tabItem { Label(LocalizedStringKey(Tab.scan.title), systemImage: Tab.scan.icon) }
            .tag(Tab.scan)

            DermiqRoutineTab { startScan() }
                .tabItem { Label(LocalizedStringKey(Tab.routine.title), systemImage: Tab.routine.icon) }
                .tag(Tab.routine)

            DermiqProgressTab()
                .tabItem { Label(LocalizedStringKey(Tab.progress.title), systemImage: Tab.progress.icon) }
                .tag(Tab.progress)
        }
        .onChange(of: tab) { _, _ in Haptics.fire(.selection) }

        // iOS 26: let the glass bar tuck away while scrolling content.
        if #available(iOS 26.0, *) {
            tabs.tabBarMinimizeBehavior(.onScrollDown)
        } else {
            tabs
        }
    }
}

// ============================================================
// MARK: — Screen 1: Home (the daily dashboard)
// ============================================================

/// The home tab is a real dashboard, not just a scan button: a personal
/// greeting, the latest score with its delta, today's ritual progress, a
/// daily tip and the score history — with the scan CTA always one thumb away.
/// Zero scans → a focused first-scan hero instead.
struct DermiqScanHome: View {
    let scans: [ScanRecord]
    let onScan: () -> Void
    let onSettings: () -> Void
    var onRoutine: () -> Void = {}
    var onProgress: () -> Void = {}

    @Query private var profiles: [UserProfile]

    /// Hero-image AI note, toggled by the small info button on the hero.
    @State private var showHeroInfo = false

    // Text, not String: a composed "\(base), \(name)" would never match a
    // catalog key, so the greeting would render in English on every device.
    private var greeting: Text {
        let hour = Calendar.current.component(.hour, from: .now)
        let name = profiles.first?.displayName ?? ""
        switch (hour, name.isEmpty) {
        case (5..<12, false):  return Text("Good morning, \(name)")
        case (12..<18, false): return Text("Good afternoon, \(name)")
        case (_, false):       return Text("Good evening, \(name)")
        case (5..<12, true):   return Text("Good morning")
        case (12..<18, true):  return Text("Good afternoon")
        default:               return Text("Good evening")
        }
    }

    /// One gentle, rotating tip a day — deterministic by day-of-year.
    private var dailyTip: String {
        let tips = [
            "SPF is the single biggest lever for your score — even on cloudy days.",
            "Glow follows sleep. Tonight's 8 hours show up in Thursday's scan.",
            "Consistency beats intensity: two gentle steps daily outwork a weekly overhaul.",
            "Hydration reads instantly on camera — water before coffee.",
            "Redness calms fastest when you skip hot water on your face.",
            "Texture changes are slow and real — trust the 14-day rhythm.",
            "Your evening cleanse matters more than any serum layered on top.",
        ]
        let day = Calendar.current.ordinality(of: .day, in: .year, for: .now) ?? 0
        return tips[day % tips.count]
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            home
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(DQColor.background.ignoresSafeArea())
    }

    // MARK: Header

    private var header: some View {
        HStack(spacing: 14) {
            greeting
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(DQColor.textSecondary)
            Spacer()
            Button {
                Haptics.fire(.selection)
                onSettings()
            } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(DQColor.textSecondary)
                    .frame(width: 36, height: 36)
                    .background(DQColor.surface, in: Circle())
                    .overlay(Circle().strokeBorder(DQColor.stroke, lineWidth: 1))
            }
            .accessibilityLabel("Settings")
        }
        .padding(.horizontal, 24)
        .padding(.top, 14)
    }

    // MARK: Home (one focused scan card — Routine & Progress live in the tab bar)

    private var home: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Skin Analysis")
                    .font(.system(size: 30, weight: .heavy, design: .rounded))
                    .foregroundStyle(DQColor.textPrimary)
                    .padding(.horizontal, 24)
                    .padding(.top, 6)

                heroPager

                if let latest = scans.first {
                    lastReadingRow(latest)
                        .padding(.horizontal, 24)
                }

                tipCard
                    .padding(.horizontal, 24)
            }
            .padding(.bottom, 28)
        }
        .scrollIndicators(.hidden)
        .alert("No SkinFix link found", isPresented: $pasteFailed) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Copy your friend's whole message, then try again.")
        }
    }

    // MARK: Hero pager (Scan ↔ Duel)

    /// The hero is a horizontal pager: page 1 is the scan card, page 2 the
    /// full-size Skin Duel card — swipe between them; dots show where you are.
    @State private var heroPage = 0

    private var heroPager: some View {
        VStack(spacing: 12) {
            TabView(selection: $heroPage) {
                scanCard
                    .padding(.horizontal, 24)
                    .tag(0)
                duelCard
                    .padding(.horizontal, 24)
                    .tag(1)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .frame(height: 496)

            HStack(spacing: 6) {
                ForEach(0..<2, id: \.self) { page in
                    Capsule()
                        .fill(page == heroPage ? DQColor.accentBright : DQColor.stroke)
                        .frame(width: page == heroPage ? 20 : 7, height: 7)
                }
            }
            .frame(maxWidth: .infinity)
            .animation(VMotion.snappy, value: heroPage)
        }
    }

    // MARK: Duel card (hero page 2)

    /// Full-size Skin Duel hero: your card vs a friend's. Share your card
    /// (verite://compare) or redeem a pasted one. Chats never make custom-
    /// scheme links tappable, so redeeming reads the pasteboard instead —
    /// user-initiated, the system paste banner is expected.
    @State private var pasteFailed = false

    private var duelCard: some View {
        let latest = scans.first
        let name = profiles.first?.displayName ?? ""
        let shareURL: URL? = latest.flatMap { scan in
            scan.analysis.flatMap { analysis in
                CompareLink.url(for: ComparePayload.mine(
                    name: name, analysis: analysis,
                    photo: DermiqImageStore.load(scan.photoFilename)))
            }
        }
        return ZStack(alignment: .bottom) {
            // Lavender stage with a ghost VS watermark behind the avatars.
            LinearGradient(colors: [DQColor.accent, DQColor.accentBright],
                           startPoint: .top, endPoint: .bottom)
            Text(verbatim: "VS")
                .font(.system(size: 170, weight: .black, design: .rounded))
                .foregroundStyle(.white.opacity(0.12))
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                .offset(y: -78)

            // The face-off: you (photo + score) vs the empty rival slot.
            VStack {
                Spacer().frame(height: 46)
                HStack(spacing: 34) {
                    duelAvatar(photo: latest.flatMap { DermiqImageStore.load($0.photoFilename) },
                               label: "YOU", score: latest?.overall)
                    duelAvatar(photo: nil, label: "FRIEND", score: nil)
                }
                Spacer()
            }

            // Legibility gradient behind the bottom content.
            LinearGradient(
                gradient: Gradient(stops: [
                    .init(color: .clear, location: 0.0),
                    .init(color: .black.opacity(0.0), location: 0.40),
                    .init(color: .black.opacity(0.28), location: 0.62),
                    .init(color: .black.opacity(0.62), location: 0.82),
                    .init(color: .black.opacity(0.82), location: 1.0),
                ]),
                startPoint: .top, endPoint: .bottom
            )

            VStack(spacing: 12) {
                VStack(spacing: 4) {
                    Text("Skin Duel")
                        .font(.system(size: 26, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.45), radius: 10, y: 2)
                    Text("Send your card — higher score wins.")
                        .font(DQFont.caption)
                        .foregroundStyle(.white.opacity(0.85))
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if let shareURL {
                    ShareLink(item: shareURL,
                              message: Text("I scanned my skin — see how yours compares 👇")) {
                        duelCTALabel(icon: "person.2.fill", title: "Challenge a friend")
                    }
                    .buttonStyle(PressableStyle())
                } else {
                    Button {
                        Haptics.fire(.selection)
                        onScan()
                    } label: {
                        duelCTALabel(icon: "camera.fill", title: "Scan first — then send your card.")
                    }
                    .buttonStyle(PressableStyle())
                }

                Button {
                    Haptics.fire(.selection)
                    let text = UIPasteboard.general.string ?? ""
                    if let payload = CompareLink.payload(fromPastedText: text) {
                        CompareInbox.shared.pending = payload
                    } else if ReferralStore.shared.handlePasted(text) {
                        // Bonus scan credited — ReferralStore already fired the haptic.
                    } else {
                        pasteFailed = true
                    }
                } label: {
                    HStack(spacing: 7) {
                        Image(systemName: "doc.on.clipboard")
                            .font(.system(size: 12, weight: .semibold))
                        Text("Got a link from a friend?")
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                    }
                    .foregroundStyle(.white.opacity(0.92))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 9)
                    .background(.white.opacity(0.16), in: Capsule())
                    .overlay(Capsule().strokeBorder(.white.opacity(0.25), lineWidth: 1))
                }
                .buttonStyle(PressableStyle())
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 18)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 460)
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .strokeBorder(DQColor.stroke, lineWidth: 1)
        )
        .shadow(color: DQColor.accent.opacity(0.12), radius: 18, y: 8)
    }

    /// One side of the face-off: a big avatar ring, an eyebrow label and —
    /// for your side — the latest score. The rival slot stays a dashed "?".
    private func duelAvatar(photo: UIImage?, label: String, score: Int?) -> some View {
        VStack(spacing: 8) {
            ZStack {
                if let photo {
                    Image(uiImage: photo).resizable().scaledToFill()
                } else {
                    ZStack {
                        Color.white.opacity(0.14)
                        Text(verbatim: "?")
                            .font(.system(size: 34, weight: .heavy, design: .rounded))
                            .foregroundStyle(.white.opacity(0.85))
                    }
                }
            }
            .frame(width: 84, height: 84)
            .clipShape(Circle())
            .overlay {
                if photo == nil {
                    Circle().strokeBorder(.white.opacity(0.65),
                                          style: StrokeStyle(lineWidth: 2, dash: [5, 5]))
                } else {
                    Circle().strokeBorder(.white, lineWidth: 2.5)
                }
            }
            .shadow(color: .black.opacity(0.18), radius: 8, y: 3)

            Text(LocalizedStringKey(label))
                .font(DQFont.mono(10, weight: .bold))
                .tracking(2)
                .foregroundStyle(.white.opacity(0.9))

            if let score {
                Text(verbatim: "\(score)")
                    .font(.system(size: 17, weight: .heavy, design: .rounded).monospacedDigit())
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 2)
                    .background(.white.opacity(0.18), in: Capsule())
            }
        }
    }

    /// The duel card's primary CTA look — white pill so it pops on lavender.
    private func duelCTALabel(icon: String, title: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
            Text(LocalizedStringKey(title))
        }
        .font(.system(size: 16, weight: .bold, design: .rounded))
        .foregroundStyle(DQColor.accentBright)
        .frame(maxWidth: .infinity, minHeight: 52)
        .background(.white, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .lineLimit(1)
        .minimumScaleFactor(0.8)
        .padding(.horizontal, 2)
    }

    /// The home hero — a full-bleed scan photo (the UMax pattern) with a dark
    /// bottom gradient, our headline and the scan CTA sitting on top. Routine
    /// and Progress are one tap away in the tab bar, so Home stays focused on
    /// the next scan.
    private var scanCard: some View {
        ZStack(alignment: .bottom) {
            // The flexible Color.clear owns the layout; the photo fills it as an
            // overlay and is clipped, so a large source image can never push the
            // card wider than the screen (scaledToFill would otherwise report its
            // full intrinsic width up the layout chain).
            Color.clear
                .overlay { heroPhoto }
                .clipped()

            // Legibility gradient — a long, smooth fade from clear at the top
            // to a soft shadow behind the text at the base.
            LinearGradient(
                gradient: Gradient(stops: [
                    .init(color: .clear, location: 0.0),
                    .init(color: .black.opacity(0.0), location: 0.42),
                    .init(color: .black.opacity(0.30), location: 0.66),
                    .init(color: .black.opacity(0.72), location: 0.84),
                    .init(color: .black.opacity(0.92), location: 1.0),
                ]),
                startPoint: .top, endPoint: .bottom
            )

            VStack(spacing: 16) {
                Text("Scan your face and\nget your rating")
                    .font(.system(size: 26, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
                    .shadow(color: .black.opacity(0.45), radius: 10, y: 2)
                DQPrimaryButton(title: scans.isEmpty ? "Begin scan" : "New scan",
                                systemImage: "camera.fill") { onScan() }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 22)

            // Small info button, top-left: taps open the AI-illustration note.
            // Info-on-demand is enough here — the hero is decorative UI, not a
            // deep fake of a real person or a claimed result, so the AI Act's
            // always-visible disclosure duty doesn't attach to it. The note is
            // there for transparency, not because a statute demands it.
            //
            // Only when the actual AI illustration is on screen: heroPhoto
            // falls back to a hand-drawn gradient when the ScanHero asset is
            // missing, and "created with AI" would be a false statement about
            // that drawn placeholder.
            if RampPhoto.load("ScanHero") != nil {
            VStack {
                HStack(alignment: .top, spacing: 8) {
                    Button {
                        Haptics.fire(.selection)
                        withAnimation(VMotion.gentle) { showHeroInfo.toggle() }
                    } label: {
                        Image(systemName: "info")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.black.opacity(0.65))
                            .frame(width: 24, height: 24)
                            .background(.white.opacity(0.85), in: Circle())
                            // 44pt hit target around the 24pt dot — the visible
                            // circle stays small, the tap area meets the HIG min.
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }
                    .accessibilityLabel(Text("About this image"))
                    .accessibilityValue(Text(showHeroInfo ? "Shown" : "Hidden"))
                    .accessibilityHint(Text("Shows how this image was created"))
                    if showHeroInfo {
                        Text("Illustration created with AI for demonstration purposes.")
                            .font(DQFont.micro)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(.black.opacity(0.55),
                                        in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                            .transition(.opacity.combined(with: .move(edge: .leading)))
                    }
                    Spacer()
                }
                .padding(12)
                Spacer()
            }
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 460)
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .strokeBorder(DQColor.stroke, lineWidth: 1)
        )
        .shadow(color: DQColor.accent.opacity(0.12), radius: 18, y: 8)
    }

    /// The bundled scan hero image (a face with an analysis mesh). Falls back to
    /// a soft gradient + the drawn viewfinder if the asset isn't present yet.
    @ViewBuilder
    private var heroPhoto: some View {
        if let image = RampPhoto.load("ScanHero") {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
        } else {
            ZStack {
                LinearGradient(colors: [DQColor.accentSoft, DQColor.accent],
                               startPoint: .topLeading, endPoint: .bottomTrailing)
                DeckScanVisual(photo: nil)
                    .frame(width: 150, height: 172)
            }
        }
    }

    /// One slim personal row under the deck: your photo, last score, delta,
    /// projected potential — a tap opens Progress.
    private func lastReadingRow(_ latest: ScanRecord) -> some View {
        let previous = scans.dropFirst().first
        let delta = previous.map { latest.overall - $0.overall }
        let potential = latest.analysis.map { DermiqProjection.project($0).overall }
        return Button {
            Haptics.fire(.selection)
            onProgress()
        } label: {
            HStack(spacing: 12) {
                Group {
                    if let image = DermiqImageStore.load(latest.photoFilename) {
                        Image(uiImage: image).resizable().scaledToFill()
                    } else {
                        ZStack {
                            DQColor.accentSoft
                            Image(systemName: "faceid")
                                .font(.system(size: 15, weight: .light))
                                .foregroundStyle(DQColor.accentBright)
                        }
                    }
                }
                .frame(width: 42, height: 42)
                .clipShape(Circle())
                .overlay(Circle().strokeBorder(DQColor.accentSoft, lineWidth: 2))

                VStack(alignment: .leading, spacing: 1) {
                    Text("LAST READING")
                        .font(DQFont.mono(9, weight: .semibold))
                        .foregroundStyle(DQColor.textSecondary)
                        .tracking(1.5)
                    HStack(spacing: 6) {
                        Text(verbatim: "\(latest.overall)")
                            .font(.system(size: 20, weight: .heavy, design: .rounded).monospacedDigit())
                            .foregroundStyle(DQColor.textPrimary)
                        if let delta, delta != 0 {
                            HStack(spacing: 2) {
                                Image(systemName: delta > 0 ? "arrow.up" : "arrow.down")
                                    .font(.system(size: 9, weight: .bold))
                                Text(verbatim: "\(abs(delta))")
                                    .font(.system(size: 12, weight: .bold, design: .rounded))
                            }
                            .foregroundStyle(delta > 0 ? DQColor.deltaUp : DQColor.deltaDown)
                        }
                    }
                }
                Spacer()
                if let potential, potential > latest.overall {
                    VStack(alignment: .trailing, spacing: 1) {
                        Text("POTENTIAL · EST.")
                            .font(DQFont.mono(9, weight: .semibold))
                            .foregroundStyle(DQColor.textSecondary)
                            .tracking(1.5)
                        Text(verbatim: "\(potential)")
                            .font(.system(size: 17, weight: .bold, design: .rounded).monospacedDigit())
                            .foregroundStyle(DQColor.accentBright)
                    }
                }
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(DQColor.textSecondary)
            }
            .padding(13)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(DQColor.surface, in: RoundedRectangle(cornerRadius: DQRadius.card, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: DQRadius.card, style: .continuous)
                    .strokeBorder(DQColor.stroke, lineWidth: 1)
            )
        }
        .buttonStyle(PressableStyle())
    }

    private var tipCard: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "lightbulb.max")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(DQColor.accentBright)
                .padding(.top, 1)
            VStack(alignment: .leading, spacing: 3) {
                Text("TODAY'S TIP")
                    .font(DQFont.mono(9, weight: .semibold))
                    .foregroundStyle(DQColor.textSecondary)
                    .tracking(1.5)
                Text(LocalizedStringKey(dailyTip))
                    .font(DQFont.caption)
                    .foregroundStyle(DQColor.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(DQColor.surfaceElevated, in: RoundedRectangle(cornerRadius: DQRadius.card, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: DQRadius.card, style: .continuous)
                .strokeBorder(DQColor.stroke, lineWidth: 1)
        )
    }
}

// ============================================================
// MARK: — Deck visuals (designed, data-driven — no icon-in-a-disc)
// ============================================================

/// Scan card visual: a soft viewfinder with corner brackets and a scan line.
/// Shows YOUR latest capture when one exists; a friendly face sketch before.
private struct DeckScanVisual: View {
    let photo: UIImage?

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(DQColor.accentSoft.opacity(0.5))
            Group {
                if let photo {
                    Image(uiImage: photo)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 96, height: 118)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                } else {
                    DeckFaceSketch()
                        .frame(width: 96, height: 110)
                }
            }
            DeckBrackets()
                .stroke(DQColor.accent, style: StrokeStyle(lineWidth: 3.5, lineCap: .round))
                .frame(width: 130, height: 146)
            LinearGradient(colors: [.clear, DQColor.accent.opacity(0.7), .clear],
                           startPoint: .leading, endPoint: .trailing)
                .frame(width: 118, height: 2.5)
                .offset(y: 12)
        }
        .frame(width: 190, height: 158)
    }
}

/// A line-art girl recreated from the reference illustration: white fill, a
/// single accent outline, blunt bangs with a soft centre part, hair framing
/// the face, two dot eyes and a small smile. Coordinates are authored in a
/// 100×115 space and scaled to the view, so the drawing is exact at any size.
private struct DeckFaceSketch: View {
    var body: some View {
        GeometryReader { geo in
            let s = geo.size
            let lw = s.width / 100 * 2.4
            ZStack {
                // Paint order matches the reference: hair, face, then bangs on
                // top — each filled white, then outlined.
                piece(leftHair(s), lineWidth: lw)
                piece(rightHair(s), lineWidth: lw)
                piece(face(s), lineWidth: lw)
                piece(bangs(s), lineWidth: lw)

                // Eyes — two solid dots.
                Circle().fill(DQColor.accentBright)
                    .frame(width: s.width * 0.05, height: s.width * 0.05)
                    .position(pt(42, 61, s))
                Circle().fill(DQColor.accentBright)
                    .frame(width: s.width * 0.05, height: s.width * 0.05)
                    .position(pt(58, 61, s))

                // Smile.
                smile(s)
                    .stroke(DQColor.accentBright,
                            style: StrokeStyle(lineWidth: lw, lineCap: .round))
            }
        }
    }

    /// Fill a shape white, then outline it in the accent — one line-art piece.
    private func piece(_ path: Path, lineWidth: CGFloat) -> some View {
        ZStack {
            path.fill(DQColor.surface)
            path.stroke(DQColor.accentBright,
                        style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round))
        }
    }

    /// Map a point from the 100×115 authoring space to the view.
    private func pt(_ x: CGFloat, _ y: CGFloat, _ s: CGSize) -> CGPoint {
        CGPoint(x: x / 100 * s.width, y: y / 115 * s.height)
    }

    private func leftHair(_ s: CGSize) -> Path {
        var p = Path()
        p.move(to: pt(33, 44, s))
        p.addCurve(to: pt(27, 97, s), control1: pt(17, 54, s), control2: pt(15, 86, s))
        p.addCurve(to: pt(36, 47, s), control1: pt(31, 85, s), control2: pt(29, 60, s))
        p.closeSubpath()
        return p
    }

    private func rightHair(_ s: CGSize) -> Path {
        var p = Path()
        p.move(to: pt(67, 44, s))
        p.addCurve(to: pt(73, 97, s), control1: pt(83, 54, s), control2: pt(85, 86, s))
        p.addCurve(to: pt(64, 47, s), control1: pt(69, 85, s), control2: pt(71, 60, s))
        p.closeSubpath()
        return p
    }

    private func face(_ s: CGSize) -> Path {
        var p = Path()
        p.move(to: pt(50, 30, s))
        p.addCurve(to: pt(67, 82, s), control1: pt(71, 32, s), control2: pt(73, 60, s))
        p.addCurve(to: pt(33, 82, s), control1: pt(62, 99, s), control2: pt(38, 99, s))
        p.addCurve(to: pt(50, 30, s), control1: pt(27, 60, s), control2: pt(29, 32, s))
        p.closeSubpath()
        return p
    }

    private func bangs(_ s: CGSize) -> Path {
        var p = Path()
        p.move(to: pt(21, 48, s))
        p.addCurve(to: pt(79, 48, s), control1: pt(18, 13, s), control2: pt(82, 13, s))
        p.addCurve(to: pt(55, 47, s), control1: pt(70, 41, s), control2: pt(62, 47, s))
        p.addCurve(to: pt(50, 49, s), control1: pt(52, 47, s), control2: pt(50, 49, s))
        p.addCurve(to: pt(45, 47, s), control1: pt(50, 49, s), control2: pt(48, 47, s))
        p.addCurve(to: pt(21, 48, s), control1: pt(38, 47, s), control2: pt(30, 41, s))
        p.closeSubpath()
        return p
    }

    private func smile(_ s: CGSize) -> Path {
        var p = Path()
        p.move(to: pt(45, 74, s))
        p.addQuadCurve(to: pt(55, 74, s), control: pt(50, 80, s))
        return p
    }
}

/// Four rounded viewfinder corner brackets.
private struct DeckBrackets: Shape {
    func path(in rect: CGRect) -> Path {
        let len = min(rect.width, rect.height) * 0.18
        let r: CGFloat = 10
        var p = Path()
        // Top-left
        p.move(to: CGPoint(x: rect.minX, y: rect.minY + len))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.minY + r))
        p.addQuadCurve(to: CGPoint(x: rect.minX + r, y: rect.minY),
                       control: CGPoint(x: rect.minX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.minX + len, y: rect.minY))
        // Top-right
        p.move(to: CGPoint(x: rect.maxX - len, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX - r, y: rect.minY))
        p.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.minY + r),
                       control: CGPoint(x: rect.maxX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + len))
        // Bottom-right
        p.move(to: CGPoint(x: rect.maxX, y: rect.maxY - len))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - r))
        p.addQuadCurve(to: CGPoint(x: rect.maxX - r, y: rect.maxY),
                       control: CGPoint(x: rect.maxX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.maxX - len, y: rect.maxY))
        // Bottom-left
        p.move(to: CGPoint(x: rect.minX + len, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX + r, y: rect.maxY))
        p.addQuadCurve(to: CGPoint(x: rect.minX, y: rect.maxY - r),
                       control: CGPoint(x: rect.minX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY - len))
        return p
    }
}


