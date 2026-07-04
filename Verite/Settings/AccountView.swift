import SwiftUI
import SwiftData
import AuthenticationServices

/// Optional account (backend module). Sign in with Apple, sync numeric metrics,
/// sign out, and delete the account + server rows. Only reachable when
/// `backendEnabled`. No photos are ever synced.
struct AccountView: View {
    @Environment(AppState.self) private var appState
    @Query private var scans: [Scan]
    @Query private var routineItems: [RoutineItem]
    @Query private var ledgers: [SavingsLedger]

    @State private var user: BackendUser?
    @State private var currentNonce = ""
    @State private var statusKey: LocalizedStringKey?
    @State private var showDeleteConfirm = false

    private var backend: BackendService { appState.backend }

    var body: some View {
        Form {
            if let user {
                Section {
                    LabeledContent("account.signedInAs", value: user.email ?? user.id)
                }
                Section {
                    Button {
                        Task { await sync() }
                    } label: {
                        Label("account.sync", systemImage: "arrow.triangle.2.circlepath")
                    }
                } footer: {
                    Text("account.sync.footer")
                }
                Section {
                    Button("account.signOut") {
                        Task { await backend.signOut(); user = nil; statusKey = nil }
                    }
                }
                Section {
                    Button("account.delete", role: .destructive) { showDeleteConfirm = true }
                }
            } else {
                Section {
                    SignInWithAppleButton(.signIn) { request in
                        request.requestedScopes = [.email]
                        let nonce = AppleSignIn.randomNonce()
                        currentNonce = nonce
                        request.nonce = AppleSignIn.sha256(nonce)
                    } onCompletion: { result in
                        handleSignIn(result)
                    }
                    .signInWithAppleButtonStyle(.black)
                    .frame(height: 46)
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                } footer: {
                    Text("account.privacy")
                }
            }

            if let statusKey {
                Section {
                    Text(statusKey).font(.footnote).foregroundStyle(Theme.textSecondary)
                }
            }
        }
        .scrollContentBackground(.hidden)
        .navigationTitle("account.title")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { user = backend.currentUser() }
        .confirmationDialog("account.delete.confirmTitle", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
            Button("account.delete", role: .destructive) { Task { await deleteAccount() } }
            Button("common.cancel", role: .cancel) {}
        } message: {
            Text("account.delete.confirmMessage")
        }
    }

    private func handleSignIn(_ result: Result<ASAuthorization, Error>) {
        guard case .success(let authorization) = result,
              let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
              let tokenData = credential.identityToken,
              let token = String(data: tokenData, encoding: .utf8) else {
            statusKey = "account.error"
            return
        }
        Task {
            do {
                user = try await backend.signInWithApple(idToken: token, nonce: currentNonce)
                statusKey = nil
            } catch {
                statusKey = "account.error"
            }
        }
    }

    private func sync() async {
        do {
            try await backend.syncMetrics(buildPayload())
            statusKey = "account.synced"
        } catch {
            statusKey = "account.error"
        }
    }

    private func deleteAccount() async {
        try? await backend.deleteAccount()
        user = nil
        statusKey = "account.deleted"
    }

    private func buildPayload() -> MetricsPayload {
        MetricsPayload(
            scans: scans.map {
                .init(date: $0.date, side: $0.side.rawValue, isBaseline: $0.isBaseline,
                      captureQuality: $0.captureQuality, attributes: $0.attributeScores)
            },
            routine: routineItems.map {
                .init(timeOfDay: $0.timeOfDay.rawValue, order: $0.order, proven: $0.proven)
            },
            totalSaved: ledgers.first?.totalSaved ?? 0,
            currencyCode: ledgers.first?.currencyCode ?? "EUR"
        )
    }
}
