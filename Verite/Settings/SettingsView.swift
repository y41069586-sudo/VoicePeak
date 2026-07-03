import SwiftUI
import SwiftData

/// Settings: language switcher (5 + system), appearance, data export/delete,
/// localized legal, and purchases entry (only when the module is enabled).
/// Data export/delete + full legal text are completed in Milestone 10.
struct SettingsView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext
    @AppStorage("languageOverride") private var languageOverride: String = ""

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

                // Purchases (only when the flag is on — off by default)
                if appState.featureFlags.purchasesEnabled {
                    Section("settings.section.purchases") {
                        Label("settings.purchases.manage", systemImage: "creditcard")
                        Label("settings.purchases.restore", systemImage: "arrow.clockwise")
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
            }
            .scrollContentBackground(.hidden)
            .navigationTitle("tab.settings")
        }
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
        .preferredColorScheme(.dark)
}
