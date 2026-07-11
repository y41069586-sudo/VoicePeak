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
    @Environment(\.requestReview) private var requestReview
    @Query private var profiles: [UserProfile]

    @AppStorage("languageOverride") private var languageOverride = ""
    @AppStorage("dermiq.reminder") private var reminderPref = ReminderPref.off.rawValue
    @AppStorage("dermiq.unlocked") private var simulatedUnlock = false

    @State private var legalDocument: LegalDocument?
    @State private var showSignOutConfirm = false
    @State private var showDeleteConfirm = false
    @State private var restoring = false

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
            }
            divider
            HStack {
                rowLabel(icon: "bell.badge", text: "Daily reminder")
                Spacer()
                Picker("Daily reminder", selection: $reminderPref) {
                    ForEach(ReminderPref.allCases, id: \.rawValue) { pref in
                        Text(LocalizedStringKey(pref.label)).tag(pref.rawValue)
                    }
                }
                .tint(DQColor.accentBright)
            }
        }
        .onChange(of: reminderPref) { _, newValue in
            applyReminder(ReminderPref(rawValue: newValue) ?? .off)
        }
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
                }
            }
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
                if let url = URL(string: "mailto:support@verite.app?subject=V%C3%A9rit%C3%A9%20Support") {
                    UIApplication.shared.open(url)
                }
            }
            divider
            settingsButton(icon: "star", text: "Rate Vérité") {
                requestReview()
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
            Text("VÉRITÉ")
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
        try? modelContext.delete(model: ScanRecord.self)
        try? modelContext.delete(model: RoutinePlan.self)
        try? modelContext.delete(model: UserProfile.self)
        try? modelContext.delete(model: Scan.self)
        try? modelContext.delete(model: HalfFaceTest.self)
        try? modelContext.delete(model: RoutineItem.self)
        try? modelContext.delete(model: Streak.self)
        try? modelContext.delete(model: SavingsLedger.self)
        try? modelContext.delete(model: Product.self) // seed catalog reseeds on next launch
        try? modelContext.save()

        DermiqImageStore.wipeAll()
        BadgeCenter.shared.resetAll()

        simulatedUnlock = false
        languageOverride = ""
        reminderPref = ReminderPref.off.rawValue
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

    /// One local daily reminder at the chosen slot (Screen 8 spec: AM or PM).
    private func applyReminder(_ pref: ReminderPref) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: ["dermiq.daily"])
        guard pref != .off else { return }

        Task {
            let granted = (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
            guard granted else { return }
            let content = UNMutableNotificationContent()
            content.title = "Your plan is waiting."
            content.body = "Today's routine takes two minutes. The rescan is coming."
            content.sound = .default
            var components = DateComponents()
            components.hour = pref == .morning ? 8 : 20
            components.minute = 0
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
            try? await center.add(UNNotificationRequest(identifier: "dermiq.daily",
                                                        content: content,
                                                        trigger: trigger))
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
