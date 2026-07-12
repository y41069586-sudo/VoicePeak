import Foundation

// ============================================================
// MARK: — Shareable duel payload (rides inside the link)
// ============================================================
//
// Everything the other player needs travels inside the share link itself —
// there is no server. An "invite" carries just enough to start a matching
// duel; a "result" carries the full baseline+final so the recipient can
// compute the head-to-head verdict locally.

struct DuelPayload: Codable {
    var v: Int = 1
    var kind: String            // "invite" | "result"
    var code: String
    var name: String

    // result-only
    var bOverall: Int?          // baseline overall
    var fOverall: Int?          // final overall
    var bSubs: [DuelScore]?
    var fSubs: [DuelScore]?

    static func invite(code: String, name: String) -> DuelPayload {
        DuelPayload(kind: "invite", code: code, name: name)
    }

    static func result(
        code: String, name: String,
        baselineOverall: Int, baselineSubs: [DuelScore],
        finalOverall: Int, finalSubs: [DuelScore]
    ) -> DuelPayload {
        DuelPayload(
            kind: "result", code: code, name: name,
            bOverall: baselineOverall, fOverall: finalOverall,
            bSubs: baselineSubs, fSubs: finalSubs
        )
    }

    var isResult: Bool { kind == "result" }
}

extension DuelPayload: Identifiable {
    /// Non-stored, so it isn't part of the Codable payload — just lets SwiftUI
    /// present it via `.sheet(item:)` / diff it in `.onChange`.
    var id: String { "\(kind)-\(code)" }
}

// ============================================================
// MARK: — Link encode / decode
// ============================================================

enum DuelLink {
    static let scheme = "verite"
    static let host = "duel"

    /// Builds `verite://duel?d=<base64url(json)>`.
    static func url(for payload: DuelPayload) -> URL? {
        guard let json = try? JSONEncoder().encode(payload) else { return nil }
        let token = base64url(json)
        var components = URLComponents()
        components.scheme = scheme
        components.host = host
        components.queryItems = [URLQueryItem(name: "d", value: token)]
        return components.url
    }

    /// Parses a `verite://duel?d=…` URL — OR a bare token / full link pasted as
    /// text — back into a payload.
    static func payload(from url: URL) -> DuelPayload? {
        guard url.scheme == scheme, url.host == host,
              let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems,
              let token = items.first(where: { $0.name == "d" })?.value else { return nil }
        return payload(fromToken: token)
    }

    /// Tolerant text parse: accepts a full `verite://…` link or a raw token.
    static func payload(fromPastedText text: String) -> DuelPayload? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if let url = URL(string: trimmed), url.scheme == scheme {
            return payload(from: url)
        }
        // Maybe they pasted just the token, or a "?d=" fragment.
        if let range = trimmed.range(of: "d=") {
            return payload(fromToken: String(trimmed[range.upperBound...]))
        }
        return payload(fromToken: trimmed)
    }

    private static func payload(fromToken token: String) -> DuelPayload? {
        guard let data = base64urlDecode(token),
              let payload = try? JSONDecoder().decode(DuelPayload.self, from: data) else { return nil }
        return payload
    }

    // MARK: base64url

    private static func base64url(_ data: Data) -> String {
        data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    private static func base64urlDecode(_ token: String) -> Data? {
        var s = token
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        // Restore padding to a multiple of 4.
        let remainder = s.count % 4
        if remainder > 0 { s += String(repeating: "=", count: 4 - remainder) }
        return Data(base64Encoded: s)
    }
}
