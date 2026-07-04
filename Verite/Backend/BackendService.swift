import Foundation

/// The optional backend contract. The app is fully functional against
/// `LocalOnlyBackend` (the default) — no server required. A `SupabaseBackend`
/// implementation is provided for opt-in account sync + community efficacy.
///
/// **Invariant:** no method accepts or returns face imagery. Photos never leave
/// the device.
protocol BackendService: Sendable {
    var isEnabled: Bool { get }

    func currentUser() -> BackendUser?
    func signInWithApple(idToken: String, nonce: String) async throws -> BackendUser
    func signOut() async

    /// Push numeric metrics + routine (opt-in). Never photos.
    func syncMetrics(_ payload: MetricsPayload) async throws

    /// Opt-in, anonymized aggregate efficacy.
    func fetchCommunityEfficacy(skinType: String?) async throws -> [CommunityEfficacy]
    func submitEfficacy(_ record: EfficacyRecord) async throws

    /// Apple-required: deletes the account + all server-side rows.
    func deleteAccount() async throws
}

/// The default: everything stays on-device. All cloud calls are no-ops or throw
/// `.notEnabled`, so the UI can call them uniformly without special-casing.
struct LocalOnlyBackend: BackendService {
    var isEnabled: Bool { false }

    func currentUser() -> BackendUser? { nil }
    func signInWithApple(idToken: String, nonce: String) async throws -> BackendUser {
        throw BackendError.notEnabled
    }
    func signOut() async {}
    func syncMetrics(_ payload: MetricsPayload) async throws {}
    func fetchCommunityEfficacy(skinType: String?) async throws -> [CommunityEfficacy] { [] }
    func submitEfficacy(_ record: EfficacyRecord) async throws {}
    func deleteAccount() async throws { throw BackendError.notEnabled }
}
