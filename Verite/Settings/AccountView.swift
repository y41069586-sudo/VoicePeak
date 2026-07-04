import SwiftUI
import SwiftData
import AuthenticationServices

/// Optional account (backend module). Sign in with Apple, sync numeric metrics,
/// sign out, and delete the account + server rows. Only reachable when
/// `backendEnabled`. No photos are ever synced.
///
/// `SignInWithAppleButton` (with its two multi-statement closures) is factored
/// into its own `AppleSignInButton` view: as one inline expression inside this
/// `Form` it pushed the body past the Swift type-checker's budget. Keeping the
/// rest of the body inline means its Button-action `Task`s still inherit `body`'s
/// `@MainActor` isolation (so capturing `self` is safe).
struct AccountView: View {
    @Environment(AppState.self) private var appState
    @Query private var scans: [Scan]
    @Query private var routineItems: [RoutineItem]
    @Query private var ledgers: [SavingsLedger]

    @State private var user: BackendUser?
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
                        let payload = buildPayload()      // @Query read on the main actor
                        Task { await sync(payload) }
                    } label: {
                        Label("account.sync", systemImage: "arrow.triangle.2.circlepath")
                    }
                } footer: {
                    Text("account.sync.footer")
                }
                Section {
                    Button("account.signOut") { Task { await signOut() } }
                }
                Section {
                    Button("account.delete", role: .destructive) { showDeleteConfirm = true }
                }
            } else {
                Section {
                    AppleSignInButton { idToken, nonce in
                        Task { await signIn(idToken: idToken, nonce: nonce) }
                    }
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
        .confirmationDialog("account.delete.confirmTitle",
                            isPresented: $showDeleteConfirm,
                            titleVisibility: .visible) {
            Button("account.delete", role: .destructive) { Task { await deleteAccount() } }
            Button("common.cancel", role: .cancel) {}
        } message: {
            Text("account.delete.confirmMessage")
        }
    }

    // MARK: Actions

    private func signIn(idToken: String, nonce: String) async {
        do {
            user = try await backend.signInWithApple(idToken: idToken, nonce: nonce)
            statusKey = nil
        } catch {
            statusKey = "account.error"
        }
    }

    private func signOut() async {
        await backend.signOut()
        user = nil
        statusKey = nil
    }

    private func sync(_ payload: MetricsPayload) async {
        do {
            try await backend.syncMetrics(payload)
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
        let scanMetrics: [MetricsPayload.ScanMetric] = scans.map { scan in
            MetricsPayload.ScanMetric(date: scan.date, side: scan.side.rawValue, isBaseline: scan.isBaseline,
                                      captureQuality: scan.captureQuality, attributes: scan.attributeScores)
        }
        let routineMetrics: [MetricsPayload.RoutineMetric] = routineItems.map { item in
            MetricsPayload.RoutineMetric(timeOfDay: item.timeOfDay.rawValue, order: item.order, proven: item.proven)
        }
        return MetricsPayload(
            scans: scanMetrics,
            routine: routineMetrics,
            totalSaved: ledgers.first?.totalSaved ?? 0,
            currencyCode: ledgers.first?.currencyCode ?? "EUR"
        )
    }
}

/// Sign in with Apple, isolated into its own view so its closures don't bloat
/// `AccountView`'s body. Extracts the id token as a `String` and hands it back —
/// the non-Sendable `ASAuthorization` never escapes this view.
private struct AppleSignInButton: View {
    /// Called on success with the id token + the raw nonce used in the request.
    let onToken: (_ idToken: String, _ nonce: String) -> Void

    @State private var currentNonce = ""

    var body: some View {
        SignInWithAppleButton(.signIn) { request in
            request.requestedScopes = [.email]
            let nonce = AppleSignIn.randomNonce()
            currentNonce = nonce
            request.nonce = AppleSignIn.sha256(nonce)
        } onCompletion: { result in
            guard case .success(let authorization) = result,
                  let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
                  let tokenData = credential.identityToken,
                  let token = String(data: tokenData, encoding: .utf8) else { return }
            onToken(token, currentNonce)
        }
        .signInWithAppleButtonStyle(.black)
        .frame(height: 46)
    }
}
