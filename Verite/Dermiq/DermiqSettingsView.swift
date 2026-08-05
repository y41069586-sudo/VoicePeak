import SwiftUI
import SwiftData
import StoreKit
import UserNotifications

// ============================================================
// MARK: — Settings
// ============================================================

/// Everything App Review expects to find: language, daily reminder,
/// subscription management + restore, legal documents (privacy/terms/
/// impressum/medical disclaimer), support contact, sign out, and full
/// account & data deletion. Sign out really signs out: onboarding state is
/// cleared and RootView returns to the onboarding flow.
struct DermiqSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(PurchaseManager.self) private var purchases
    @Environment(AppState.self) private var appState
    @Environment(\.requestReview) private var requestReview
    @Query private var profiles: [UserProfile]
    @Query(sort: \ScanRecord.date, order: .reverse) private var scans: [ScanRecord]

    @AppStorage("languageOverride") private var languageOverride = ""

    @State private var legalDocument: LegalDocument?
    @State private var showSignOutConfirm = false
    @State private var showDeleteConfirm = false
    @State private var restoring = false
    @State private var restoreDone = false

    private enum ReminderPref: String, CaseIterable {
        case off, morning, evening
        var label: String {
            switch self {
            case .off:     return "Off"
            case .morning: return "Morning · 8:00"
            case .evening: return "Evening · 20:00"
            }
        }
    }

    private let languages: [(code: String, label: String)] = [
        ("",   "System"),
        ("en", "English"),
        ("de", "Deutsch"),
        ("fr", "Français"),
        ("es", "Español"),
        ("it", "Italiano"),
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    preferencesSection
                    subscriptionSection
                    referralSection
                    legalSection
                    supportSection
                    accountSection
                    footer
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
            .scrollIndicators(.hidden)
            .background(DQColor.background.ignoresSafeArea())
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(DQColor.accentBright)
                }
            }
            .sheet(item: $legalDocument) { document in
                DermiqLegalView(document: document)
            }
        }
        .preferredColorScheme(.light)
    }

    // MARK: Preferences

    private var preferencesSection: some View {
        settingsCard("PREFERENCES") {
            HStack {
                rowLabel(icon: "globe", text: "Language")
                Spacer()
                Picker("Language", selection: $languageOverride) {
                    ForEach(languages, id: \.code) { language in
                        Text(LocalizedStringKey(language.label)).tag(language.code)
                    }
                }
                .tint(DQColor.accentBright)
                // Stage AppleLanguages NOW, not at next launch — Foundation
                // reads it before our launch code runs, so writing it lazily
                // meant the first reopen still showed the old language and
                // only the second one applied the change.
                .onChange(of: languageOverride) { _, code in
                    AppLanguage.stage(code)
                }
            }
            // The language is read once as the app starts (AppleLanguages), so a
            // change shows on the next launch. Saying so beats a picker that
            // looks broken because tapping it changes nothing on screen.
            if AppLanguage.needsRelaunch(for: languageOverride) {
                // "Reopen" alone reads as "switch away and back", which does
                // NOT restart the process — iOS keeps the app alive in the
                // background, so nothing changes and the hint looks broken.
                // Spell out the force-quit.
                Text("Close Glowé completely (swipe it away in the app switcher), then open it again.")
                    .font(DQFont.micro)
                    .foregroundStyle(DQColor.accentBright)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 6)
            }
            divider
            HStack {
                rowLabel(icon: "bell.badge", text: "Daily reminder")
                Spacer()
                Picker("Daily reminder", selection: reminderBinding) {
                    ForEach(ReminderPref.allCases, id: \.rawValue) { pref in
                        Text(LocalizedStringKey(pref.label)).tag(pref.rawValue)
                    }
                }
                .tint(DQColor.accentBright)
            }
        }
    }

    /// The picker reads the real reminder state (owned by NotificationManager,
    /// armed in onboarding) and writes through `applyReminder`. Deriving the
    /// value — instead of a separate @AppStorage — means the picker can never
    /// show "Off" while reminders are actually firing, so "Off" always works.
    private var reminderBinding: Binding<String> {
        Binding(
            get: {
                let d = UserDefaults.standard
                guard d.bool(forKey: "notif.routine.desired") else { return ReminderPref.off.rawValue }
                let pmHour = d.object(forKey: "notif.routine.pmHour") as? Int ?? 21
                return (pmHour == 8 ? ReminderPref.morning : ReminderPref.evening).rawValue
            },
            set: { applyReminder(ReminderPref(rawValue: $0) ?? .off) }
        )
    }

    // MARK: Subscription

    private var subscriptionSection: some View {
        settingsCard("SUBSCRIPTION") {
            settingsButton(icon: "creditcard", text: "Manage subscription") {
                openSubscriptionManagement()
            }
            divider
            settingsButton(icon: "arrow.clockwise",
                           text: restoring ? "Restoring…" : "Restore purchases") {
                guard !restoring else { return }
                restoring = true
                Task {
                    await purchases.restore()
                    restoring = false
                    // Without this the button feels dead when there was
                    // nothing to restore.
                    restoreDone = true
                }
            }
            .alert("Restore complete", isPresented: $restoreDone) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("If you had an active purchase, it's back. Nothing found? There was nothing to restore.")
            }
        }
    }

    // MARK: Referral (invite a friend → bonus once they sign up and go Pro)

    private var referralSection: some View {
        settingsCard("INVITE A FRIEND") {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 10) {
                    Image(systemName: "person.2.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(DQColor.accentBright)
                        .frame(width: 32, height: 32)
                        .background(DQColor.accentBright.opacity(0.10),
                                    in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Earn bonus scans")
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                            .foregroundStyle(DQColor.textPrimary)
                        Text("Bonus scans available: \(ReferralStore.shared.credits)")
                            .font(DQFont.micro)
                            .foregroundStyle(DQColor.textSecondary)
                    }
                    Spacer()
                }
                Text("Your friend gets a free scan right away. Your bonus lands once they go Pro.")
                    .font(DQFont.micro)
                    .foregroundStyle(DQColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                // Short message on purpose: the link is an https://glowé.app
                // URL, which chats DO make tappable — one tap opens the app
                // (or the App Store if it isn't installed) and credits the
                // scan. The old "copy this whole message and paste it" line
                // was a leftover from the verite:// era, when the link wasn't
                // tappable; it just cluttered every invite. Paste-to-redeem
                // still works as a silent fallback for the rare chat that
                // doesn't linkify.
                ShareLink(item: ReferralStore.shared.inviteURL,
                          message: Text("Scan your skin with me — here's a free scan 👇")) {
                    Label("Share invite link", systemImage: "square.and.arrow.up")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(DQColor.accentBright)
                        .frame(maxWidth: .infinity, minHeight: 42)
                        .background(DQColor.accentBright.opacity(0.10),
                                    in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                // The pay-back link only unlocks once THIS user actually
                // CONVERTED (went Pro) — that's what makes the inviter's
                // reward mean "my friend bought", not "my friend tapped a
                // link". (No sign-in requirement: accounts aren't live, so
                // gating on currentUser() made the bonus unreachable.)
                if ReferralStore.shared.thankYouURL != nil {
                    if purchases.isPro,
                       let thanks = ReferralStore.shared.thankYouURL {
                        ShareLink(item: thanks,
                                  message: Text("Thanks for the invite — open this so you get your bonus scan!")) {
                            Label("Send your inviter their bonus", systemImage: "gift")
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                                .foregroundStyle(DQColor.textSecondary)
                                .frame(maxWidth: .infinity, minHeight: 38)
                        }
                    } else {
                        HStack(spacing: 6) {
                            Image(systemName: "lock")
                                .font(.system(size: 11, weight: .semibold))
                            Text("Sign up and go Pro to send your inviter their bonus.")
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .font(DQFont.micro)
                        .foregroundStyle(DQColor.textSecondary)
                    }
                }
            }
            .padding(.vertical, 4)
        }
    }

    // MARK: Legal (required for review: privacy policy + terms reachable in-app)

    private var legalSection: some View {
        settingsCard("LEGAL") {
            ForEach(Array(LegalDocument.allCases.enumerated()), id: \.element.id) { index, document in
                if index > 0 { divider }
                settingsButton(icon: document.systemImage, text: documentTitle(document)) {
                    legalDocument = document
                }
            }
        }
    }

    private func documentTitle(_ document: LegalDocument) -> String {
        switch document {
        case .privacy:    return "Privacy Policy"
        case .terms:      return "Terms of Use"
        case .impressum:  return "Impressum"
        case .disclaimer: return "Medical Disclaimer"
        }
    }

    // MARK: Support

    private var supportSection: some View {
        settingsCard("SUPPORT") {
            settingsButton(icon: "envelope", text: "Contact support") {
                if let url = URL(string: "mailto:glowe.skinapp@gmail.com?subject=Glow%C3%A9%20Support") {
                    UIApplication.shared.open(url)
                }
            }
            divider
            // Deliberately NOT requestReview(): that is a request the system
            // may silently ignore (hard cap of 3 prompts per year, and in
            // TestFlight it never shows at all) — which turns an explicit
            // button into a dead one. Apple's documented pattern for a
            // user-initiated "rate us" action is the App Store write-review
            // deep link, which always opens.
            settingsButton(icon: "star", text: "Rate Glowé") {
                if let url = URL(string:
                    "https://apps.apple.com/app/id6787454842?action=write-review") {
                    UIApplication.shared.open(url)
                }
            }
        }
    }

    // MARK: Account

    private var accountSection: some View {
        settingsCard("ACCOUNT") {
            settingsButton(icon: "rectangle.portrait.and.arrow.right", text: "Sign out") {
                showSignOutConfirm = true
            }
            divider
            settingsButton(icon: "trash", text: "Delete account & data", destructive: true) {
                showDeleteConfirm = true
            }
        }
        .confirmationDialog(
            "Sign out?",
            isPresented: $showSignOutConfirm,
            titleVisibility: .visible
        ) {
            Button("Sign out", role: .destructive) { signOut() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("You'll return to the start. Your scans stay on this device.")
        }
        .confirmationDialog(
            "Delete account & data?",
            isPresented: $showDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button("Delete everything", role: .destructive) { deleteEverything() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Permanently deletes all scans, photos, routines, and badges from this device. This cannot be undone. Subscriptions can be restored via your Apple ID.")
        }
    }

    private var footer: some View {
        VStack(spacing: 3) {
            Text("Glowé")
                .font(DQFont.mono(11, weight: .semibold))
                .tracking(4)
                .foregroundStyle(DQColor.textSecondary)
            Text(verbatim: appVersion)
                .font(DQFont.micro)
                .foregroundStyle(DQColor.textSecondary.opacity(0.7))
        }
        .padding(.top, 10)
    }

    private var appVersion: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "—"
        return "Version \(version) (\(build))"
    }

    // MARK: Actions

    /// Sign out: clear the session, keep on-device data, return to onboarding.
    private func signOut() {
        // Invalidate the server session too — otherwise a live backend token
        // survives sign-out (no-op on the local-only backend). Detach the
        // RevenueCat account link as well (purchases stay Apple-ID-restorable).
        Task {
            await appState.backend.signOut()
            await purchases.logOut()
        }
        for profile in profiles {
            profile.onboardingComplete = false
        }
        try? modelContext.save()
        RampAnalytics.track("settings_sign_out")
        Haptics.fire(.transition)
        dismiss()
        // RootView observes the profile and flips back to the onboarding flow.
    }

    /// Full wipe: every SwiftData model, stored images, badges, preferences,
    /// scheduled notifications. Then back to onboarding (no profile left).
    private func deleteEverything() {
        // If there's a backend session, delete the server-side account too
        // (Guideline 5.1.1(v) — a real account must be removable, not just
        // local data). Best-effort + fire-and-forget; the backend guards the
        // no-session case, and local data is wiped regardless below.
        Task {
            try? await appState.backend.deleteAccount()
            await purchases.logOut()
        }

        try? modelContext.delete(model: ScanRecord.self)
        try? modelContext.delete(model: RoutinePlan.self)
        try? modelContext.delete(model: UserProfile.self)
        try? modelContext.save()

        DermiqImageStore.wipeAll()
        BadgeCenter.shared.resetAll()

        // Wipe ALL app-side UserDefaults so a fresh account starts truly clean
        // — otherwise leftover markers (free scan already used, credits, bought
        // unlocks, the one-time win-back, the reminder wish, per-plan recovery,
        // onboarding coach/review flags) make a "new" account behave weirdly.
        ReferralStore.shared.resetAll()   // credits, code, free-scan, credit marker
        UnlockStore.shared.resetAll()     // per-scan rating/routine unlocks + pending
        let d = UserDefaults.standard
        for key in ["dermiq.unlocked", "dq.winback.shown", "dq.attribution.source",
                    "notif.routine.desired", "notif.routine.pmHour", "notif.routine.pmMinute",
                    "dq.swipeCoachSeen", "dermiq.reviewAsked", "dermiq.reviewAskedRoutine"] {
            d.removeObject(forKey: key)
        }
        // Per-plan recovery windows are keyed by plan UUID — sweep the prefix.
        for key in d.dictionaryRepresentation().keys where key.hasPrefix("dq.recovery.begin.") {
            d.removeObject(forKey: key)
        }
        languageOverride = ""
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()

        RampAnalytics.track("settings_delete_account")
        Haptics.fire(.verdictReveal)
        dismiss()
    }

    private func openSubscriptionManagement() {
        if let url = URL(string: "https://apps.apple.com/account/subscriptions") {
            UIApplication.shared.open(url)
        }
    }

    private var planUnlocked: Bool { purchases.isPro && !scans.isEmpty }

    /// The daily reminder is a SINGLE system (NotificationManager): the picker
    /// stores the preference + evening time, then reconciles which reminder is
    /// live (routine once Pro+plan, else a conversion nudge). No separate
    /// scheduler, so "Off" really silences everything and nothing double-fires.
    private func applyReminder(_ pref: ReminderPref) {
        // Clear the legacy standalone reminder from older builds so it can't
        // linger alongside the unified one.
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["dermiq.daily"])

        let enabled = pref != .off
        NotificationManager.setRoutinePreference(enabled: enabled,
                                                 pmHour: pref == .morning ? 8 : 20,
                                                 pmMinute: 0)
        guard enabled else {
            NotificationManager.syncReminders(planUnlocked: planUnlocked)
            return
        }
        Task {
            _ = await NotificationManager.requestAuthorization()
            NotificationManager.syncReminders(planUnlocked: planUnlocked)
        }
    }

    // MARK: Row building blocks

    private func settingsCard(_ title: String, @ViewBuilder rows: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(LocalizedStringKey(title))
                .font(DQFont.mono(11, weight: .semibold))
                .foregroundStyle(DQColor.textSecondary)
                .tracking(2)
                .padding(.bottom, 8)
            VStack(spacing: 0) { rows() }
                .padding(.horizontal, 14)
                .background(DQColor.surface, in: RoundedRectangle(cornerRadius: DQRadius.card, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: DQRadius.card, style: .continuous)
                        .strokeBorder(DQColor.stroke, lineWidth: 1)
                )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func rowLabel(icon: String, text: String, destructive: Bool = false) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(destructive ? DQColor.deltaDown : DQColor.accentBright)
                .frame(width: 24)
            Text(LocalizedStringKey(text))
                .font(DQFont.body)
                .foregroundStyle(destructive ? DQColor.deltaDown : DQColor.textPrimary)
        }
        .padding(.vertical, 13)
    }

    private func settingsButton(icon: String, text: String,
                                destructive: Bool = false,
                                action: @escaping () -> Void) -> some View {
        Button {
            Haptics.fire(.selection)
            action()
        } label: {
            HStack {
                rowLabel(icon: icon, text: text, destructive: destructive)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(DQColor.textSecondary.opacity(0.5))
            }
        }
        .buttonStyle(.plain)
    }

    private var divider: some View {
        Rectangle().fill(DQColor.stroke).frame(height: 1)
    }
}

// ============================================================
// MARK: — Legal document viewer (v2 styling, existing localized bodies)
// ============================================================

struct DermiqLegalView: View {
    let document: LegalDocument
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text(document.titleKey)
                        .font(DQFont.title)
                        .foregroundStyle(DQColor.textPrimary)
                    Text(document.bodyKey)
                        .font(DQFont.body)
                        .foregroundStyle(DQColor.textSecondary)
                        .lineSpacing(4)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(20)
            }
            .scrollIndicators(.hidden)
            .background(DQColor.background.ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(DQColor.accentBright)
                }
            }
        }
        .preferredColorScheme(.light)
    }
}
