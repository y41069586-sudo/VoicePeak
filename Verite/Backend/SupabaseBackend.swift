import Foundation

/// Supabase implementation of `BackendService` over plain URLSession (no SDK
/// dependency). Handles Sign in with Apple (GoTrue), numeric metric sync +
/// community efficacy (PostgREST), and account deletion (RPC).
///
/// Session is persisted in `UserDefaults` (a template choice — move to the
/// Keychain for production). The class holds no other mutable state, so it's
/// safe to share. **No method touches face imagery.**
final class SupabaseBackend: BackendService, @unchecked Sendable {
    private let config: BackendConfig
    private let tokenKey = "supabase.accessToken"
    private let userKey = "supabase.user"

    init(config: BackendConfig = .shared) {
        self.config = config
    }

    var isEnabled: Bool { config.isConfigured }

    // MARK: Session (persisted)

    private var accessToken: String? {
        UserDefaults.standard.string(forKey: tokenKey)
    }

    func currentUser() -> BackendUser? {
        guard let data = UserDefaults.standard.data(forKey: userKey) else { return nil }
        return try? JSONDecoder().decode(BackendUser.self, from: data)
    }

    private func store(token: String, user: BackendUser) {
        UserDefaults.standard.set(token, forKey: tokenKey)
        if let data = try? JSONEncoder().encode(user) {
            UserDefaults.standard.set(data, forKey: userKey)
        }
    }

    private func clearSession() {
        UserDefaults.standard.removeObject(forKey: tokenKey)
        UserDefaults.standard.removeObject(forKey: userKey)
    }

    // MARK: Auth (GoTrue)

    func signInWithApple(idToken: String, nonce: String) async throws -> BackendUser {
        try await idTokenGrant(provider: "apple", idToken: idToken, nonce: nonce)
    }

    func signInWithGoogle(idToken: String) async throws -> BackendUser {
        // Google's native ID token needs no nonce (the GoogleSignIn SDK handles
        // it). Supabase verifies the token's audience against the configured
        // Google client IDs.
        try await idTokenGrant(provider: "google", idToken: idToken, nonce: nil)
    }

    /// Shared GoTrue `grant_type=id_token` exchange for Apple/Google.
    private func idTokenGrant(provider: String, idToken: String, nonce: String?) async throws -> BackendUser {
        var body: [String: String] = ["provider": provider, "id_token": idToken]
        if let nonce { body["nonce"] = nonce }
        let data = try await send("auth/v1/token", query: [URLQueryItem(name: "grant_type", value: "id_token")],
                                  method: "POST", authorized: false,
                                  body: try JSONSerialization.data(withJSONObject: body))
        struct TokenResponse: Decodable {
            let accessToken: String
            let user: RawUser
            struct RawUser: Decodable { let id: String; let email: String? }
            enum CodingKeys: String, CodingKey { case accessToken = "access_token", user }
        }
        guard let response = try? JSONDecoder().decode(TokenResponse.self, from: data) else {
            throw BackendError.decoding
        }
        let user = BackendUser(id: response.user.id, email: response.user.email)
        store(token: response.accessToken, user: user)
        return user
    }

    func signOut() async {
        _ = try? await send("auth/v1/logout", method: "POST", authorized: true, body: nil)
        clearSession()
    }

    // MARK: Sync (PostgREST)

    func syncMetrics(_ payload: MetricsPayload) async throws {
        guard currentUser() != nil else { throw BackendError.notSignedIn }
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        // Upsert a single row keyed by the authenticated user (RLS enforces owner).
        let body = try encoder.encode(["metrics": payload])
        _ = try await send("rest/v1/user_metrics", method: "POST", authorized: true, body: body,
                           extraHeaders: ["Prefer": "resolution=merge-duplicates"])
    }

    func fetchCommunityEfficacy(skinType: String?) async throws -> [CommunityEfficacy] {
        var query = [URLQueryItem(name: "select", value: "product_key,skin_type,works_percent,sample_size")]
        if let skinType { query.append(URLQueryItem(name: "skin_type", value: "eq.\(skinType)")) }
        let data = try await send("rest/v1/community_efficacy", query: query, method: "GET", authorized: false, body: nil)
        struct Row: Decodable {
            let productKey: String; let skinType: String?; let worksPercent: Double; let sampleSize: Int
            enum CodingKeys: String, CodingKey {
                case productKey = "product_key", skinType = "skin_type"
                case worksPercent = "works_percent", sampleSize = "sample_size"
            }
        }
        let rows = (try? JSONDecoder().decode([Row].self, from: data)) ?? []
        return rows.map { CommunityEfficacy(productKey: $0.productKey, skinType: $0.skinType,
                                            worksPercent: $0.worksPercent, sampleSize: $0.sampleSize) }
    }

    func submitEfficacy(_ record: EfficacyRecord) async throws {
        struct Row: Encodable {
            let product_key: String
            let skin_type: String?
            let passed: Bool
        }
        let body = try JSONEncoder().encode(Row(product_key: record.productKey,
                                                skin_type: record.skinType,
                                                passed: record.passed))
        _ = try await send("rest/v1/efficacy_records", method: "POST", authorized: currentUser() != nil, body: body)
    }

    func deleteAccount() async throws {
        guard currentUser() != nil else { throw BackendError.notSignedIn }
        // Uses the `delete-account` Edge Function (supabase/functions/) — the
        // Apple-compliant path that removes the auth user + cascades their rows.
        // (A SQL `delete_account()` RPC is kept in schema.sql as an alternative.)
        _ = try await send("functions/v1/delete-account", method: "POST", authorized: true,
                           body: Data("{}".utf8))
        clearSession()
    }

    // MARK: Request helper

    private func send(_ path: String,
                      query: [URLQueryItem] = [],
                      method: String,
                      authorized: Bool,
                      body: Data?,
                      extraHeaders: [String: String] = [:]) async throws -> Data {
        guard let base = config.url else { throw BackendError.notConfigured }
        var components = URLComponents(url: base.appendingPathComponent(path), resolvingAgainstBaseURL: false)
        if !query.isEmpty { components?.queryItems = query }
        guard let url = components?.url else { throw BackendError.notConfigured }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue(config.anonKey, forHTTPHeaderField: "apikey")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let bearer = (authorized ? accessToken : nil) ?? config.anonKey
        request.setValue("Bearer \(bearer)", forHTTPHeaderField: "Authorization")
        for (key, value) in extraHeaders { request.setValue(value, forHTTPHeaderField: key) }
        request.httpBody = body

        let (data, response) = try await URLSession.shared.data(for: request)
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw BackendError.http(http.statusCode)
        }
        return data
    }
}
