import SwiftUI
import SwiftData

// ============================================================
// MARK: — Duel tab
// ============================================================

struct DuelTab: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ScanRecord.date, order: .reverse) private var scans: [ScanRecord]
    @Query private var profiles: [UserProfile]
    @Query(sort: \SkinDuel.createdAt, order: .reverse) private var duels: [SkinDuel]

    /// Ask the shell to open the camera (used when a baseline scan is needed).
    let onScan: () -> Void

    @State private var inbox = DuelInbox.shared
    @State private var showStart = false
    @State private var incoming: DuelPayload?
    @State private var showPaste = false

    private var active: SkinDuel? {
        duels.first { !($0.bothSubmitted && $0.revealed) } ?? duels.first
    }
    private var latestAnalysis: DermiqAnalysis? { scans.first?.analysis }
    private var myName: String { profiles.first?.displayName ?? "" }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                if let duel = active {
                    DuelActiveContent(
                        duel: duel,
                        canSubmitFinal: latestAnalysis != nil,
                        onSubmitFinal: { submitFinal(duel) },
                        onImport: { showPaste = true }
                    )
                } else {
                    emptyState
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 18)
            .padding(.bottom, 120)
        }
        .scrollIndicators(.hidden)
        .background(DQColor.background.ignoresSafeArea())
        .onAppear(perform: handleInbox)
        .onChange(of: inbox.pending?.id) { _, _ in handleInbox() }
        .sheet(isPresented: $showStart) {
            DuelStartSheet(
                prefillName: myName,
                baseline: latestAnalysis,
                onScan: onScan
            ) { name in
                guard let baseline = latestAnalysis else { return }
                DuelStore.create(myName: name, baseline: baseline, in: modelContext)
                Haptics.fire(.capture)
            }
        }
        .sheet(item: $incoming) { payload in
            DuelIncomingSheet(
                payload: payload,
                prefillName: myName,
                baseline: latestAnalysis,
                onScan: onScan
            ) { name in
                guard let baseline = latestAnalysis else { return }
                DuelStore.accept(invite: payload, myName: name, baseline: baseline, in: modelContext)
                Haptics.fire(.capture)
            }
        }
        .sheet(isPresented: $showPaste) {
            DuelPasteSheet { text in
                guard let payload = DuelLink.payload(fromPastedText: text) else { return false }
                return applyIncoming(payload)
            }
        }
    }

    // MARK: Header

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

    // MARK: Empty state

    private var emptyState: some View {
        VStack(spacing: 18) {
            ZStack {
                Circle().fill(DQColor.accentSoft)
                Image(systemName: "flag.checkered.2.crossed")
                    .font(.system(size: 40, weight: .semibold))
                    .foregroundStyle(DQColor.accentBright)
            }
            .frame(width: 96, height: 96)
            .padding(.top, 26)

            VStack(spacing: 8) {
                Text("Challenge a friend")
                    .font(.system(size: 22, weight: .heavy, design: .rounded))
                    .foregroundStyle(DQColor.textPrimary)
                Text("You both scan, run the 14-day plan, then rescan. Whoever improves their score the most wins.")
                    .font(DQFont.caption)
                    .foregroundStyle(DQColor.textSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 8)
            }

            if latestAnalysis != nil {
                DQPrimaryButton(title: "Start a duel", systemImage: "flag.checkered") {
                    showStart = true
                }
            } else {
                VStack(spacing: 10) {
                    Text("Scan your skin first to set your starting score.")
                        .font(DQFont.micro)
                        .foregroundStyle(DQColor.textSecondary)
                        .multilineTextAlignment(.center)
                    DQPrimaryButton(title: "Scan to begin", systemImage: "camera.fill") {
                        onScan()
                    }
                }
            }

            Button {
                Haptics.fire(.selection)
                showPaste = true
            } label: {
                Text("Have a code or link? Join a duel")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(DQColor.accentBright)
            }
            .padding(.top, 2)
        }
        .frame(maxWidth: .infinity)
        .padding(20)
        .background(DQColor.surface, in: RoundedRectangle(cornerRadius: DQRadius.card, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: DQRadius.card, style: .continuous)
                .strokeBorder(DQColor.stroke, lineWidth: 1)
        )
    }

    // MARK: Actions

    private func submitFinal(_ duel: SkinDuel) {
        guard let analysis = latestAnalysis else { return }
        DuelStore.submitFinal(duel, analysis: analysis, in: modelContext)
        Haptics.fire(.milestone)
    }

    private func handleInbox() {
        guard let payload = inbox.consume() else { return }
        _ = applyIncoming(payload)
    }

    /// Routes an incoming payload: results attach silently; invites open the
    /// accept sheet. Returns whether it was handled.
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
}

// ============================================================
// MARK: — Active duel content
// ============================================================

private struct DuelActiveContent: View {
    let duel: SkinDuel
    let canSubmitFinal: Bool
    let onSubmitFinal: () -> Void
    let onImport: () -> Void

    @State private var inviteURL: URL?
    @State private var challengeCardURL: URL?
    @State private var resultCardURL: URL?

    private var today: Int { duel.dayIndex() }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if duel.bothSubmitted {
                revealCard
            } else {
                progressCard
                actionCard
                inviteCard
            }
        }
        .onAppear(perform: prepareShareURLs)
    }

    // MARK: Progress

    private var progressCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("Day \(today)")
                    .font(.system(size: 28, weight: .heavy, design: .rounded))
                    .foregroundStyle(DQColor.textPrimary)
                Text(verbatim: "of 14")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(DQColor.textSecondary)
                Spacer()
                Text(duel.code)
                    .font(.system(size: 13, weight: .bold, design: .rounded).monospaced())
                    .foregroundStyle(DQColor.accentBright)
                    .padding(.horizontal, 10).padding(.vertical, 5)
                    .background(DQColor.accentSoft, in: Capsule())
            }

            // Track.
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(DQColor.stroke.opacity(0.5))
                    Capsule().fill(DQColor.accent)
                        .frame(width: proxy.size.width * CGFloat(today) / 14)
                }
            }
            .frame(height: 6)

            rosterRow

            if duel.windowComplete {
                Text("Time's up — take your final scan and lock in your result.")
                    .font(DQFont.micro)
                    .foregroundStyle(DQColor.accentBright)
            } else {
                Text("Keep to your routine. Come back on day 14 for the final scan.")
                    .font(DQFont.micro)
                    .foregroundStyle(DQColor.textSecondary)
            }
        }
        .padding(18)
        .background(DQColor.surface, in: RoundedRectangle(cornerRadius: DQRadius.card, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: DQRadius.card, style: .continuous)
                .strokeBorder(DQColor.stroke, lineWidth: 1)
        )
    }

    private var rosterRow: some View {
        HStack(spacing: 10) {
            playerChip(name: duel.myName.isEmpty ? "You" : duel.myName,
                       status: duel.iSubmitted ? "Final in ✓" : "Day \(today)",
                       done: duel.iSubmitted)
            Text("VS")
                .font(.system(size: 12, weight: .heavy, design: .rounded))
                .foregroundStyle(DQColor.textSecondary)
            playerChip(name: duel.opponentName.isEmpty ? "Waiting…" : duel.opponentName,
                       status: duel.opponentSubmitted ? "Final in ✓" : "Pending",
                       done: duel.opponentSubmitted)
        }
    }

    private func playerChip(name: String, status: String, done: Bool) -> some View {
        VStack(spacing: 3) {
            ZStack {
                Circle().fill(done ? DQColor.accent : DQColor.surfaceElevated)
                Text(String(name.prefix(1)).uppercased())
                    .font(.system(size: 17, weight: .heavy, design: .rounded))
                    .foregroundStyle(done ? .white : DQColor.textSecondary)
            }
            .frame(width: 40, height: 40)
            Text(name)
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(DQColor.textPrimary)
                .lineLimit(1)
            Text(status)
                .font(DQFont.micro)
                .foregroundStyle(done ? DQColor.deltaUp : DQColor.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: Action

    private var actionCard: some View {
        VStack(spacing: 10) {
            if duel.iSubmitted {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.seal.fill").foregroundStyle(DQColor.deltaUp)
                    Text("Your result is locked in.")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(DQColor.textPrimary)
                }
                if let url = resultCardURL {
                    ShareLink(item: url) {
                        shareLabel("Send your result card", "paperplane.fill")
                    }
                }
                Text("Then import your rival's result to see who won.")
                    .font(DQFont.micro).foregroundStyle(DQColor.textSecondary)
            } else if canSubmitFinal {
                DQPrimaryButton(title: "Lock in my final score", systemImage: "flag.checkered.2.crossed") {
                    onSubmitFinal()
                }
                Text("Uses your latest scan. Rescan first if you haven't today.")
                    .font(DQFont.micro).foregroundStyle(DQColor.textSecondary)
                    .multilineTextAlignment(.center)
            } else {
                Text("Scan your skin to record your final score.")
                    .font(DQFont.micro).foregroundStyle(DQColor.textSecondary)
            }

            Button {
                Haptics.fire(.selection)
                onImport()
            } label: {
                shareLabel("Import rival's result", "square.and.arrow.down", filled: false)
            }
        }
        .padding(16)
        .background(DQColor.surface, in: RoundedRectangle(cornerRadius: DQRadius.card, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: DQRadius.card, style: .continuous)
                .strokeBorder(DQColor.stroke, lineWidth: 1)
        )
    }

    // MARK: Invite

    private var inviteCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("INVITE YOUR RIVAL")
                .font(DQFont.mono(9, weight: .semibold)).tracking(1.5)
                .foregroundStyle(DQColor.textSecondary)
            HStack(spacing: 10) {
                if let url = inviteURL {
                    ShareLink(item: url, subject: Text("Skin Duel"),
                              message: Text("Join my 14-day Skin Duel on Vérité")) {
                        shareLabel("Share link", "link")
                    }
                }
                if let url = challengeCardURL {
                    ShareLink(item: url) {
                        shareLabel("Share card", "photo", filled: false)
                    }
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(DQColor.surfaceElevated, in: RoundedRectangle(cornerRadius: DQRadius.card, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: DQRadius.card, style: .continuous)
                .strokeBorder(DQColor.stroke, lineWidth: 1)
        )
    }

    // MARK: Reveal (both submitted)

    private var revealCard: some View {
        DuelReveal(duel: duel)
            .onAppear {
                if !duel.revealed {
                    duel.revealed = true
                    Haptics.fire(.verdictReveal)
                }
            }
    }

    // MARK: Helpers

    private func shareLabel(_ title: String, _ icon: String, filled: Bool = true) -> some View {
        HStack(spacing: 7) {
            Image(systemName: icon)
            Text(LocalizedStringKey(title))
        }
        .font(.system(size: 14, weight: .bold, design: .rounded))
        .foregroundStyle(filled ? .white : DQColor.accentBright)
        .frame(maxWidth: .infinity, minHeight: 46)
        .background(
            filled ? AnyShapeStyle(DQColor.accent) : AnyShapeStyle(DQColor.accentSoft),
            in: RoundedRectangle(cornerRadius: 14, style: .continuous)
        )
    }

    @MainActor
    private func prepareShareURLs() {
        if inviteURL == nil {
            inviteURL = DuelLink.url(for: .invite(code: duel.code, name: duel.myName))
        }
        if challengeCardURL == nil {
            let card = DuelChallengeCard(myName: duel.myName, code: duel.code)
            if let img = ShareRenderer.image(for: card, size: DuelChallengeCard.size) {
                challengeCardURL = ShareRenderer.pngURL(for: img, name: "verite-duel-invite")
            }
        }
        if resultCardURL == nil, duel.iSubmitted {
            // A self-contained result link (opens the app + attaches on the
            // rival's side). Shared as the "result card".
            resultCardURL = DuelLink.url(for: DuelStore.myResultPayload(duel))
        }
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

            side(name: duel.myName.isEmpty ? "You" : duel.myName,
                 delta: duel.myDelta ?? 0, winner: iWon || draw)
            Text("VS").font(.system(size: 13, weight: .heavy, design: .rounded))
                .foregroundStyle(DQColor.textSecondary)
            side(name: duel.opponentName.isEmpty ? "Rival" : duel.opponentName,
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
            // Render the head-to-head card to a shareable PNG (the viral image).
            if shareURL == nil,
               let img = ShareRenderer.image(for: DuelResultCard(duel: duel), size: DuelResultCard.size) {
                shareURL = ShareRenderer.pngURL(for: img, name: "verite-duel-result")
            }
        }
    }

    private func side(name: String, delta: Int, winner: Bool) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle().fill(winner ? DQColor.accent : DQColor.surfaceElevated)
                Text(String(name.prefix(1)).uppercased())
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
                Text(name).font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundStyle(DQColor.textPrimary).lineLimit(1)
                HStack(spacing: 3) {
                    Image(systemName: delta >= 0 ? "arrow.up.right" : "arrow.down.right")
                        .font(.system(size: 12, weight: .heavy))
                    Text(verbatim: "\(delta >= 0 ? "+" : "")\(delta) in 14 days")
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
// MARK: — Sheets: start / accept / paste
// ============================================================

/// Name confirmation before starting/accepting a duel.
private struct DuelNameForm: View {
    let title: String
    let subtitle: String
    let ctaTitle: String
    let prefillName: String
    let baseline: DermiqAnalysis?
    let onScan: () -> Void
    let onConfirm: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var name: String = ""

    var body: some View {
        VStack(spacing: 18) {
            Capsule().fill(DQColor.stroke).frame(width: 40, height: 5).padding(.top, 10)
            VStack(spacing: 6) {
                Text(LocalizedStringKey(title))
                    .font(.system(size: 22, weight: .heavy, design: .rounded))
                    .foregroundStyle(DQColor.textPrimary)
                Text(LocalizedStringKey(subtitle))
                    .font(DQFont.caption).foregroundStyle(DQColor.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 20)

            TextField("Your name", text: $name)
                .font(.system(size: 17, weight: .semibold, design: .rounded))
                .multilineTextAlignment(.center)
                .padding(.vertical, 14)
                .background(DQColor.surfaceElevated, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .padding(.horizontal, 24)

            if let baseline {
                HStack(spacing: 8) {
                    Text("Starting score")
                        .font(DQFont.caption).foregroundStyle(DQColor.textSecondary)
                    Text(verbatim: "\(baseline.overall)")
                        .font(.system(size: 20, weight: .heavy, design: .rounded).monospacedDigit())
                        .foregroundStyle(DQColor.accentBright)
                }
            }

            Spacer(minLength: 0)

            if baseline != nil {
                DQPrimaryButton(title: ctaTitle, systemImage: "flag.checkered") {
                    onConfirm(name.trimmingCharacters(in: .whitespaces))
                    dismiss()
                }
                .padding(.horizontal, 24)
            } else {
                VStack(spacing: 8) {
                    Text("Scan your skin first to set your starting score.")
                        .font(DQFont.micro).foregroundStyle(DQColor.textSecondary)
                        .multilineTextAlignment(.center)
                    DQPrimaryButton(title: "Scan now", systemImage: "camera.fill") {
                        dismiss(); onScan()
                    }
                    .padding(.horizontal, 24)
                }
            }
        }
        .padding(.bottom, 24)
        .background(DQColor.background.ignoresSafeArea())
        .onAppear { name = prefillName }
        .presentationDetents([.medium])
        .presentationDragIndicator(.hidden)
    }
}

private struct DuelStartSheet: View {
    let prefillName: String
    let baseline: DermiqAnalysis?
    let onScan: () -> Void
    let onConfirm: (String) -> Void

    var body: some View {
        DuelNameForm(
            title: "Start a duel",
            subtitle: "We'll lock in your starting score and give you a link to share.",
            ctaTitle: "Create duel",
            prefillName: prefillName, baseline: baseline, onScan: onScan, onConfirm: onConfirm
        )
    }
}

private struct DuelIncomingSheet: View {
    let payload: DuelPayload
    let prefillName: String
    let baseline: DermiqAnalysis?
    let onScan: () -> Void
    let onConfirm: (String) -> Void

    var body: some View {
        DuelNameForm(
            title: "\(payload.name.isEmpty ? "Someone" : payload.name) challenged you",
            subtitle: "Accept to lock in your starting score and race them for 14 days.",
            ctaTitle: "Accept challenge",
            prefillName: prefillName, baseline: baseline, onScan: onScan, onConfirm: onConfirm
        )
    }
}

/// Paste a link/code when the deep link didn't open the app directly.
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
