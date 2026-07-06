import SwiftUI
import SwiftData

/// Settings: language switcher (5 + system), appearance, data export/delete,
/// localized legal, and purchases entry (only when the module is enabled).
/// Data export/delete + full legal text are completed in Milestone 10.
struct SettingsView: View {
    @Environment(AppState.self) private var appState
    @Environment(PurchaseManager.self) private var purchases
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @AppStorage("languageOverride") private var languageOverride: String = ""
    @AppStorage("routineReminders") private var routineReminders = false

    var body: some View {
        NavigationStack {
            Form {
                // Language
                Section("settings.section.language") {
                    Picker(selection: $languageOverride) {
                        Text("settings.language.system").tag("")
                        ForEach(AppLanguage.allCases) { lang in
                            Text(lang.displayName).tag(lang.code)
                        }
                    } label: {
                        Label("settings.language.title", systemImage: "globe")
                    }
                    .pickerStyle(.navigationLink)
                }

                // Data & privacy
                Section {
                    NavigationLink {
                        DataPrivacyView()
                    } label: {
                        Label("settings.data.title", systemImage: "lock.shield")
                    }
                } header: {
                    Text("settings.section.data")
                } footer: {
                    Text("settings.data.footer") // "Face photos never leave your device."
                }

                // Reminders
                Section {
                    Toggle(isOn: $routineReminders) {
                        Label("settings.reminders.routine", systemImage: "bell")
                    }
                } header: {
                    Text("settings.section.reminders")
                } footer: {
                    Text("settings.reminders.routine.footer")
                }

                // Purchases (only when the flag is on — off by default)
                if appState.featureFlags.purchasesEnabled {
                    Section("settings.section.purchases") {
                        if purchases.isPro {
                            Label("settings.purchases.active", systemImage: "checkmark.seal.fill")
                                .foregroundStyle(Theme.success)
                        }
                        Link(destination: URL(string: "https://apps.apple.com/account/subscriptions")!) {
                            Label("settings.purchases.manage", systemImage: "creditcard")
                        }
                        Button {
                            Task { await purchases.restore() }
                        } label: {
                            Label("settings.purchases.restore", systemImage: "arrow.clockwise")
                        }
                    }
                }

                // Account + community (backend module — off by default)
                if appState.featureFlags.backendEnabled {
                    Section("settings.section.account") {
                        NavigationLink {
                            AccountView()
                        } label: {
                            Label("account.title", systemImage: "person.crop.circle")
                        }
                        if appState.featureFlags.communityEnabled {
                            NavigationLink {
                                CommunityEfficacyView()
                            } label: {
                                Label("community.title", systemImage: "person.3")
                            }
                        }
                    }
                }

                // Legal
                Section("settings.section.legal") {
                    ForEach(LegalDocument.allCases) { doc in
                        NavigationLink {
                            LegalDocumentView(document: doc)
                        } label: {
                            Label(doc.titleKey, systemImage: doc.systemImage)
                        }
                    }
                }

                // About
                Section("settings.section.about") {
                    LabeledContent("settings.about.version", value: appVersion)
                }

                // Sign out / reset
                Section {
                    Button(role: .destructive) {
                        resetOnboarding()
                    } label: {
                        Label("settings.signOut", systemImage: "rectangle.portrait.and.arrow.right")
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(GradientMeshBackground().ignoresSafeArea())
            .navigationTitle("tab.settings")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .onChange(of: routineReminders) { _, enabled in
                Task { await updateReminders(enabled) }
            }
        }
    }

    private func updateReminders(_ enabled: Bool) async {
        if enabled {
            let granted = await NotificationManager.requestAuthorization()
            if granted {
                NotificationManager.scheduleRoutineReminders()
            } else {
                routineReminders = false // permission denied → reflect reality
            }
        } else {
            NotificationManager.cancelRoutineReminders()
        }
    }

    private func resetOnboarding() {
        // Fetch the profile directly from the context and reset it.
        // RootView observes profiles, so setting onboardingComplete = false
        // immediately transitions back to the onboarding flow.
        let descriptor = FetchDescriptor<UserProfile>()
        if let profile = try? modelContext.fetch(descriptor).first {
            profile.onboardingComplete = false
            try? modelContext.save()
        }
        dismiss()
    }

    private var appVersion: String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
        let b = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "—"
        return "\(v) (\(b))"
    }
}

/// The five shipped languages (plus a "follow system" default handled separately).
enum AppLanguage: String, CaseIterable, Identifiable {
    case en, de, es, fr, it
    var id: String { rawValue }
    var code: String { rawValue }
    /// Endonym so each language is shown in its own name.
    var displayName: String {
        switch self {
        case .en: return "English"
        case .de: return "Deutsch"
        case .es: return "Español"
        case .fr: return "Français"
        case .it: return "Italiano"
        }
    }
}

#Preview {
    SettingsView()
        .modelContainer(Persistence.previewContainer)
        .environment(AppState())
        .environment(PurchaseManager())
        .preferredColorScheme(.light)
}
