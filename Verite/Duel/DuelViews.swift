import SwiftUI
import SwiftData

// ============================================================
// MARK: — Duel tab (guided, one step at a time)
// ============================================================
//
// The duel is a WIZARD, not a dashboard: every state shows exactly one
// focused card with one primary action. Start → share the link → run the
// 14 days → lock the final scan → swap results → reveal. A slim step rail
// on top shows where you are.

struct DuelTab: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ScanRecord.date, order: .reverse) private var scans: [ScanRecord]
    @Query private var profiles: [UserProfile]
    @Query(sort: \SkinDuel.createdAt, order: .reverse) private var duels: [SkinDuel]

    /// Ask the shell to open the camera (baseline / final scan).
    let onScan: () -> Void

    @State private var inbox = DuelInbox.shared
    @State private var incoming: DuelPayload?
    @State private var showPaste = false
    /// Bumped after mutations stored outside SwiftData (the shared-flag).
    @State private var refresh = 0

    private var active: SkinDuel? {
        duels.first { !($0.bothSubmitted && $0.revealed) } ?? duels.first
    }
    private var latestAnalysis: DermiqAnalysis? { scans.first?.analysis }
    private var myName: String {
        let name = profiles.first?.displayName ?? ""
        return name.isEmpty ? String(localized: "You") : name
    }

    // MARK: Step machine

    private enum Step: Int {
        case start = -1, share = 0, battle = 1, final = 2, exchange = 3, reveal = 4
    }

    private func sharedFlagKey(_ duel: SkinDuel) -> String { "dq.duel.shared.\(duel.code)" }
    private func linkShared(_ duel: SkinDuel) -> Bool {
        _ = refresh
        return UserDefaults.standard.bool(forKey: sharedFlagKey(duel))
    }

    private var step: Step {
        guard let duel = active else { return .start }
        if duel.bothSubmitted { return .reveal }
        if duel.iSubmitted { return .exchange }
        if duel.windowComplete { return .final }
        if !linkShared(duel) { return .share }
        return .battle
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header

                if step != .start {
                    stepRail
                }

                Group {
                    switch step {
                    case .start: startCard
                    case .share: if let duel = active { shareCard(duel) }
                    case .battle: if let duel = active { battleCard(duel) }
                    case .final: if let duel = active { finalCard(duel) }
                    case .exchange: if let duel = active { exchangeCard(duel) }
                    case .reveal: if let duel = active { revealCard(duel) }
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .trailing)))
                .animation(VMotion.snappy, value: step)
            }
            .padding(.horizontal, 20)
            .padding(.top, 18)
            .padding(.bottom, 28)
        }
        .scrollIndicators(.hidden)
        .background(DQColor.background.ignoresSafeArea())
        .onAppear(perform: handleInbox)
        .onChange(of: inbox.pending?.id) { _, _ in handleInbox() }
        .sheet(item: $incoming) { payload in
            acceptSheet(payload)
        }
        .sheet(isPresented: $showPaste) {
            DuelPasteSheet { text in
                guard let payload = DuelLink.payload(fromPastedText: text) else { return false }
                return applyIncoming(payload)
            }
        }
    }

    // MARK: Header + step rail

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Skin Duel")
                .font(.system(size: 30, weight: .heavy, design: .rounded))
                .foregroundStyle(DQColor.textPrimary)
            Text("14 days. Two faces. Biggest glow-up wins.")
                .font(DQFont.caption)
                .foregroundStyle(DQColor.textSecondary)
        }
    }

    /// Four little stations: share → 14 days → final scan → result.
    private var stepRail: some View {
        let labels = ["Share", "14 days", "Final scan", "Result"]
        let current = max(step.rawValue, 0)
        return HStack(spacing: 6) {
            ForEach(0..<4, id: \.self) { i in
                HStack(spacing: 4) {
                    ZStack {
                        Circle()
                            .fill(i < current ? DQColor.deltaUp
                                  : (i == current ? DQColor.accent : DQColor.stroke.opacity(0.6)))
                        if i < current {
                            Image(systemName: "checkmark")
                                .font(.system(size: 8, weight: .heavy))
                                .foregroundStyle(.white)
                        } else {
                            Text(verbatim: "\(i + 1)")
                                .font(.system(size: 10, weight: .heavy, design: .rounded))
                                .foregroundStyle(i == current ? .white : DQColor.textSecondary)
                        }
                    }
                    .frame(width: 20, height: 20)
                    Text(LocalizedStringKey(labels[i]))
                        .font(.system(size: 10.5, weight: i == current ? .bold : .medium, design: .rounded))
                        .foregroundStyle(i == current ? DQColor.textPrimary : DQColor.textSecondary)
                        .lineLimit(1)
                }
                if i < 3 {
                    Rectangle()
                        .fill(i < current ? DQColor.deltaUp.opacity(0.5) : DQColor.stroke.opacity(0.5))
                        .frame(height: 2)
                        .frame(maxWidth: .infinity)
                }
            }
        }
        .animation(VMotion.gentle, value: step)
    }

    // MARK: Step 0 — Start (one button)

    private var startCard: some View {
        stepCard {
            ZStack {
                Circle().fill(DQColor.accentSoft)
                Image(systemName: "flag.checkered.2.crossed")
                    .font(.system(size: 38, weight: .semibold))
                    .foregroundStyle(DQColor.accentBright)
            }
            .frame(width: 88, height: 88)
            .padding(.top, 10)

            Text("Challenge a friend")
                .font(.system(size: 22, weight: .heavy, design: .rounded))
                .foregroundStyle(DQColor.textPrimary)
            Text("You both run 14 days. Whoever improves their skin score more, wins.")
                .font(DQFont.caption)
                .foregroundStyle(DQColor.textSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            if latestAnalysis != nil {
                DQPrimaryButton(title: "Start a duel", systemImage: "flag.checkered") {
                    startDuel()
                }
                .padding(.top, 6)
            } else {
                DQPrimaryButton(title: "Scan to begin", systemImage: "camera.fill") { onScan() }
                    .padding(.top, 6)
                Text("Your scan sets your starting score.")
                    .font(DQFont.micro)
                    .foregroundStyle(DQColor.textSecondary)
            }

            Button {
                Haptics.fire(.selection)
                showPaste = true
            } label: {
                Text("Got a link from a friend?")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(DQColor.accentBright)
            }
            .padding(.top, 2)
        }
    }

    // MARK: Step 1 — Share the link (one button + done)

    private func shareCard(_ duel: SkinDuel) -> some View {
        stepCard {
            stepTitle(number: 1, title: "Send your rival the link")
            Text("They tap it, scan their face, and your 14 days start together.")
                .font(DQFont.caption)
                .foregroundStyle(DQColor.textSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            if let url = DuelLink.url(for: .invite(code: duel.code, name: duel.myName)) {
                ShareLink(item: url, subject: Text("Skin Duel"),
                          message: Text("Join my 14-day Skin Duel")) {
                    bigButtonLabel("Share the link", "paperplane.fill")
                }
                .simultaneousGesture(TapGesture().onEnded {
                    // Sharing counts as done — but keep the explicit continue
                    // so the user controls the pace.
                    UserDefaults.standard.set(true, forKey: sharedFlagKey(duel))
                })
            }

            Button {
                Haptics.fire(.selection)
                UserDefaults.standard.set(true, forKey: sharedFlagKey(duel))
                refresh += 1
            } label: {
                Text("Done — start my 14 days")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(DQColor.accentBright)
            }
            .padding(.top, 2)
        }
    }

    // MARK: Step 2 — The 14 days (compact status, nothing to configure)

    private func battleCard(_ duel: SkinDuel) -> some View {
        let today = duel.dayIndex()
        return stepCard {
            stepTitle(number: 2, title: "Run your 14 days")

            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("Day \(today)")
                    .font(.system(size: 30, weight: .heavy, design: .rounded))
                    .foregroundStyle(DQColor.textPrimary)
                Text(verbatim: "of 14")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(DQColor.textSecondary)
            }

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(DQColor.stroke.opacity(0.5))
                    Capsule().fill(DQColor.accent)
                        .frame(width: proxy.size.width * CGFloat(today) / 14)
                }
            }
            .frame(height: 6)
            .padding(.horizontal, 8)

            versusRow(duel)

            Text("Do your routine daily — the rescan unlocks on day 14.")
                .font(DQFont.micro)
                .foregroundStyle(DQColor.textSecondary)
                .multilineTextAlignment(.center)

            HStack(spacing: 18) {
                quietAction("Share link again", "paperplane") {
                    UserDefaults.standard.set(false, forKey: sharedFlagKey(duel))
                    refresh += 1
                }
                quietAction("Import result", "square.and.arrow.down") { showPaste = true }
            }
            .padding(.top, 2)
        }
    }

    // MARK: Step 3 — Final scan (one button)

    private func finalCard(_ duel: SkinDuel) -> some View {
        stepCard {
            stepTitle(number: 3, title: "Time's up — lock in your score")
            Text("Take your final scan, then hit the button. That's your result.")
                .font(DQFont.caption)
                .foregroundStyle(DQColor.textSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            if let analysis = latestAnalysis {
                Button {
                    DuelStore.submitFinal(duel, analysis: analysis, in: modelContext)
                    Haptics.fire(.milestone)
                } label: {
                    bigButtonLabel("Lock in my final score", "flag.checkered.2.crossed")
                }
                Button {
                    Haptics.fire(.selection)
                    onScan()
                } label: {
                    Text("Rescan first")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(DQColor.accentBright)
                }
            } else {
                DQPrimaryButton(title: "Scan my face", systemImage: "camera.fill") { onScan() }
            }
        }
    }

    // MARK: Step 4 — Swap results (two clear buttons)

    private func exchangeCard(_ duel: SkinDuel) -> some View {
        stepCard {
            stepTitle(number: 4, title: "Swap results")

            HStack(spacing: 8) {
                Image(systemName: "checkmark.seal.fill").foregroundStyle(DQColor.deltaUp)
                Text("Your result is locked in.")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(DQColor.textPrimary)
            }

            if let url = DuelLink.url(for: DuelStore.myResultPayload(duel)) {
                ShareLink(item: url) {
                    bigButtonLabel("Send my result", "paperplane.fill")
                }
            }

            Button {
                Haptics.fire(.selection)
                showPaste = true
            } label: {
                HStack(spacing: 7) {
                    Image(systemName: "square.and.arrow.down")
                    Text("Import my rival's result")
                }
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(DQColor.accentBright)
                .frame(maxWidth: .infinity, minHeight: 46)
                .background(DQColor.accentSoft, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }

            Text("As soon as their result lands, the winner is revealed.")
                .font(DQFont.micro)
                .foregroundStyle(DQColor.textSecondary)
                .multilineTextAlignment(.center)
        }
    }

    // MARK: Step 5 — Reveal

    private func revealCard(_ duel: SkinDuel) -> some View {
        DuelReveal(duel: duel)
            .onAppear {
                if !duel.revealed {
                    duel.revealed = true
                    Haptics.fire(.verdictReveal)
                }
            }
    }

    // MARK: Shared pieces

    /// One focused card per step — the whole wizard look.
    private func stepCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(spacing: 14) { content() }
            .frame(maxWidth: .infinity)
            .padding(20)
            .background(DQColor.surface, in: RoundedRectangle(cornerRadius: DQRadius.card, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: DQRadius.card, style: .continuous)
                    .strokeBorder(DQColor.stroke, lineWidth: 1)
            )
    }

    private func stepTitle(number: Int, title: String) -> some View {
        VStack(spacing: 5) {
            Text("STEP \(number)")
                .font(DQFont.mono(9, weight: .semibold)).tracking(2)
                .foregroundStyle(DQColor.accentBright)
            Text(LocalizedStringKey(title))
                .font(.system(size: 21, weight: .heavy, design: .rounded))
                .foregroundStyle(DQColor.textPrimary)
                .multilineTextAlignment(.center)
        }
    }

    private func bigButtonLabel(_ title: String, _ icon: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
            Text(LocalizedStringKey(title))
        }
        .font(.system(size: 16, weight: .bold, design: .rounded))
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity, minHeight: 54)
        .background(DQColor.accent, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: DQColor.accent.opacity(0.25), radius: 10, y: 5)
    }

    private func quietAction(_ title: String, _ icon: String, action: @escaping () -> Void) -> some View {
        Button {
            Haptics.fire(.selection)
            action()
        } label: {
            HStack(spacing: 5) {
                Image(systemName: icon).font(.system(size: 11, weight: .semibold))
                Text(LocalizedStringKey(title))
                    .font(.system(size: 12.5, weight: .semibold, design: .rounded))
            }
            .foregroundStyle(DQColor.textSecondary)
        }
    }

    private func versusRow(_ duel: SkinDuel) -> some View {
        HStack(spacing: 10) {
            playerChip(name: duel.myName.isEmpty ? String(localized: "You") : duel.myName, done: duel.iSubmitted)
            Text(verbatim: "VS")
                .font(.system(size: 12, weight: .heavy, design: .rounded))
                .foregroundStyle(DQColor.textSecondary)
            playerChip(name: duel.opponentName.isEmpty ? String(localized: "Rival") : duel.opponentName,
                       done: duel.opponentSubmitted)
        }
    }

    private func playerChip(name: String, done: Bool) -> some View {
        VStack(spacing: 3) {
            ZStack {
                Circle().fill(done ? DQColor.accent : DQColor.surfaceElevated)
                Text(verbatim: String(name.prefix(1)).uppercased())
                    .font(.system(size: 16, weight: .heavy, design: .rounded))
                    .foregroundStyle(done ? .white : DQColor.textSecondary)
            }
            .frame(width: 38, height: 38)
            Text(verbatim: name)
                .font(.system(size: 11.5, weight: .bold, design: .rounded))
                .foregroundStyle(DQColor.textPrimary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: Actions

    private func startDuel() {
        guard let baseline = latestAnalysis else { return }
        DuelStore.create(myName: myName, baseline: baseline, in: modelContext)
        Haptics.fire(.capture)
    }

    private func handleInbox() {
        guard let payload = inbox.consume() else { return }
        _ = applyIncoming(payload)
    }

    /// Results attach silently; invites open the accept sheet.
    @discardableResult
    private func applyIncoming(_ payload: DuelPayload) -> Bool {
        if payload.isResult {
            if DuelStore.importResult(payload, in: modelContext) != nil {
                Haptics.fire(.verdictReveal)
                return true
            }
            return false
        } else {
            incoming = payload
            return true
        }
    }

    // MARK: Accept sheet (one button, no forms)

    private func acceptSheet(_ payload: DuelPayload) -> some View {
        VStack(spacing: 16) {
            Capsule().fill(DQColor.stroke).frame(width: 40, height: 5).padding(.top, 10)

            ZStack {
                Circle().fill(DQColor.accentSoft)
                Image(systemName: "flag.checkered.2.crossed")
                    .font(.system(size: 30, weight: .semibold))
                    .foregroundStyle(DQColor.accentBright)
            }
            .frame(width: 72, height: 72)

            Text(verbatim: "\(payload.name.isEmpty ? "Someone" : payload.name)")
                .font(.system(size: 22, weight: .heavy, design: .rounded))
                .foregroundStyle(DQColor.textPrimary)
            Text("challenges you to a 14-day skin duel")
                .font(DQFont.caption)
                .foregroundStyle(DQColor.textSecondary)
                .multilineTextAlignment(.center)

            Spacer(minLength: 0)

            if let baseline = latestAnalysis {
                DQPrimaryButton(title: "Accept challenge", systemImage: "flag.checkered") {
                    DuelStore.accept(invite: payload, myName: myName,
                                     baseline: baseline, in: modelContext)
                    Haptics.fire(.capture)
                    incoming = nil
                }
                .padding(.horizontal, 24)
            } else {
                DQPrimaryButton(title: "Scan to accept", systemImage: "camera.fill") {
                    incoming = nil
                    onScan()
                }
                .padding(.horizontal, 24)
                Text("Your scan sets your starting score.")
                    .font(DQFont.micro).foregroundStyle(DQColor.textSecondary)
            }
        }
        .padding(.bottom, 26)
        .background(DQColor.background.ignoresSafeArea())
        .presentationDetents([.medium])
    }
}

// ============================================================
// MARK: — Reveal (head-to-head verdict)
// ============================================================

private struct DuelReveal: View {
    let duel: SkinDuel

    @State private var appeared = false
    @State private var shareURL: URL?

    private var iWon: Bool { duel.outcome == .win }
    private var draw: Bool { duel.outcome == .draw }

    var body: some View {
        VStack(spacing: 16) {
            Text(draw ? "Dead heat" : (iWon ? "You won 👑" : "So close"))
                .font(.system(size: 30, weight: .heavy, design: .rounded))
                .foregroundStyle(DQColor.textPrimary)
                .scaleEffect(appeared ? 1 : 0.7)
                .opacity(appeared ? 1 : 0)

            side(name: duel.myName.isEmpty ? String(localized: "You") : duel.myName,
                 delta: duel.myDelta ?? 0, winner: iWon || draw)
            Text(verbatim: "VS").font(.system(size: 13, weight: .heavy, design: .rounded))
                .foregroundStyle(DQColor.textSecondary)
            side(name: duel.opponentName.isEmpty ? String(localized: "Rival") : duel.opponentName,
                 delta: duel.opponentDelta ?? 0, winner: !iWon || draw)

            if let shareURL {
                ShareLink(item: shareURL) {
                    HStack(spacing: 7) {
                        Image(systemName: "square.and.arrow.up")
                        Text("Share the result")
                    }
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, minHeight: 52)
                    .background(DQColor.accent, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .padding(.top, 6)
            }
        }
        .padding(20)
        .background(DQColor.surface, in: RoundedRectangle(cornerRadius: DQRadius.card, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: DQRadius.card, style: .continuous)
                .strokeBorder(iWon ? DQColor.accent.opacity(0.5) : DQColor.stroke, lineWidth: iWon ? 2 : 1)
        )
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) { appeared = true }
            if shareURL == nil,
               let img = ShareRenderer.image(for: DuelResultCard(duel: duel), size: DuelResultCard.size) {
                shareURL = ShareRenderer.pngURL(for: img, name: "skin-duel-result")
            }
        }
    }

    private func side(name: String, delta: Int, winner: Bool) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle().fill(winner ? DQColor.accent : DQColor.surfaceElevated)
                Text(verbatim: String(name.prefix(1)).uppercased())
                    .font(.system(size: 20, weight: .heavy, design: .rounded))
                    .foregroundStyle(winner ? .white : DQColor.textSecondary)
            }
            .frame(width: 48, height: 48)
            .overlay(alignment: .topTrailing) {
                if winner && !draw {
                    Image(systemName: "crown.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(Color(red: 1.0, green: 0.78, blue: 0.24))
                        .offset(x: 5, y: -7)
                }
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: name).font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundStyle(DQColor.textPrimary).lineLimit(1)
                HStack(spacing: 3) {
                    Image(systemName: delta >= 0 ? "arrow.up.right" : "arrow.down.right")
                        .font(.system(size: 12, weight: .heavy))
                    Text("\(delta >= 0 ? "+\(delta)" : "\(delta)") in 14 days")
                        .font(.system(size: 14, weight: .semibold, design: .rounded).monospacedDigit())
                }
                .foregroundStyle(delta >= 0 ? DQColor.deltaUp : DQColor.deltaDown)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .frame(maxWidth: .infinity)
        .background(DQColor.surfaceElevated, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

// ============================================================
// MARK: — Paste a link/code
// ============================================================

private struct DuelPasteSheet: View {
    /// Returns true when the pasted text resolved to a payload.
    let onSubmit: (String) -> Bool

    @Environment(\.dismiss) private var dismiss
    @State private var text = ""
    @State private var failed = false

    var body: some View {
        VStack(spacing: 18) {
            Capsule().fill(DQColor.stroke).frame(width: 40, height: 5).padding(.top, 10)
            Text("Join a duel")
                .font(.system(size: 22, weight: .heavy, design: .rounded))
                .foregroundStyle(DQColor.textPrimary)
            Text("Paste the invite or result link your friend sent you.")
                .font(DQFont.caption).foregroundStyle(DQColor.textSecondary)
                .multilineTextAlignment(.center).padding(.horizontal, 24)

            TextField("Paste link", text: $text, axis: .vertical)
                .font(.system(size: 14, weight: .medium, design: .monospaced))
                .lineLimit(2...4)
                .padding(14)
                .background(DQColor.surfaceElevated, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .padding(.horizontal, 24)

            if failed {
                Text("That link didn't work. Check you copied all of it.")
                    .font(DQFont.micro).foregroundStyle(DQColor.deltaDown)
            }

            Spacer(minLength: 0)

            DQPrimaryButton(title: "Join", systemImage: "arrow.right.circle.fill",
                            isEnabled: !text.isEmpty) {
                if onSubmit(text) { dismiss() } else { failed = true; Haptics.fire(.riskFlagged) }
            }
            .padding(.horizontal, 24)
        }
        .padding(.bottom, 24)
        .background(DQColor.background.ignoresSafeArea())
        .presentationDetents([.medium])
    }
}
