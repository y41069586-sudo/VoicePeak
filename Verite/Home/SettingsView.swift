import SwiftUI

/// Settings modal accessible from Home tab. Organize account, preferences, and legal.
struct SettingsView: View {
    @Binding var isPresented: Bool
    @AppStorage("languageOverride") private var languageOverride: String = ""
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Account") {
                    NavigationLink(destination: ProfileSettingsView()) {
                        Label("Profile", systemImage: "person.fill")
                    }
                    
                    NavigationLink(destination: PrivacySettingsView()) {
                        Label("Privacy", systemImage: "lock.fill")
                    }
                }
                
                Section("Preferences") {
                    NavigationLink(destination: NotificationSettingsView()) {
                        Label("Notifications", systemImage: "bell.fill")
                    }
                    
                    LanguagePicker()
                }
                
                Section("Support") {
                    Link(destination: URL(string: "https://verite.app/help")!) {
                        Label("Help & FAQ", systemImage: "questionmark.circle.fill")
                    }
                    
                    Link(destination: URL(string: "https://verite.app/contact")!) {
                        Label("Contact Support", systemImage: "envelope.fill")
                    }
                }
                
                Section("Legal") {
                    NavigationLink(destination: LegalDocumentView(type: .terms)) {
                        Label("Terms of Service", systemImage: "doc.text.fill")
                    }
                    
                    NavigationLink(destination: LegalDocumentView(type: .privacy)) {
                        Label("Privacy Policy", systemImage: "doc.text.fill")
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        isPresented = false
                    }
                    .fontWeight(.semibold)
                    .foregroundStyle(VColor.primary)
                }
            }
        }
    }
}

private struct LanguagePicker: View {
    @AppStorage("languageOverride") private var languageOverride: String = ""
    
    let languages = [
        ("System", ""),
        ("English", "en"),
        ("Español", "es"),
        ("Français", "fr"),
        ("Deutsch", "de"),
    ]
    
    var body: some View {
        Picker("Language", selection: $languageOverride) {
            ForEach(languages, id: \.1) { name, code in
                Text(name).tag(code)
            }
        }
    }
}

private struct ProfileSettingsView: View {
    var body: some View {
        List {
            Section("Profile Information") {
                LabeledContent("Skin Type", value: "Combination")
                LabeledContent("Age Range", value: "25-34")
            }
            
            Section {
                Button(role: .destructive) {
                    // Handle logout
                } label: {
                    Label("Sign Out", systemImage: "arrow.right.circle.fill")
                }
            }
        }
        .navigationTitle("Profile")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct PrivacySettingsView: View {
    @State private var shareAnalytics = true
    @State private var shareDiagnostics = false
    
    var body: some View {
        List {
            Section("Data Sharing") {
                Toggle("Share Analytics", isOn: $shareAnalytics)
                Toggle("Share Diagnostics", isOn: $shareDiagnostics)
            }
            
            Section("Face Data") {
                Text("Your face photos are processed on-device only and never uploaded.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Privacy")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct NotificationSettingsView: View {
    @State private var dailyReminder = true
    @State private var weeklyReport = true
    @State private var productAlerts = false
    
    var body: some View {
        List {
            Section("Notifications") {
                Toggle("Daily Reminder", isOn: $dailyReminder)
                Toggle("Weekly Report", isOn: $weeklyReport)
                Toggle("Product Alerts", isOn: $productAlerts)
            }
        }
        .navigationTitle("Notifications")
        .navigationBarTitleDisplayMode(.inline)
    }
}

enum LegalType {
    case terms, privacy
}

private struct LegalDocumentView: View {
    let type: LegalType
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                switch type {
                case .terms:
                    Text("Terms of Service")
                        .font(.title2.weight(.bold))
                    Text("These terms govern your use of Vérité...")
                        .font(.body)
                    
                case .privacy:
                    Text("Privacy Policy")
                        .font(.title2.weight(.bold))
                    Text("We respect your privacy. Your face data stays on your device...")
                        .font(.body)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(20)
        }
        .navigationTitle(type == .terms ? "Terms" : "Privacy")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    @State var isPresented = true
    
    return SettingsView(isPresented: $isPresented)
}
