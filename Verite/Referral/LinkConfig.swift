import Foundation

// ============================================================
// MARK: — Shareable link config (WhatsApp-clickable)
// ============================================================
//
// Chats (WhatsApp, iMessage, …) only make `https://` links tappable — never a
// custom scheme like `verite://`. So share links go out as https pointing at a
// tiny redirect page you host (web/index.html), which bounces the visitor into
// the app via `verite://`. The app still RECEIVES `verite://` exactly as before
// (onOpenURL is unchanged) — only the outgoing link changes.
//
// SETUP (one-time):
//   1. Host `web/index.html` (in this repo) at your domain root.
//   2. Set `webBase` below to that domain (no trailing slash).
// Until `webBase` is set, links fall back to `verite://` (copy-paste only).

enum LinkConfig {

    /// Your https site hosting the redirect page. Empty → `verite://` fallback.
    /// Punycode form of glowé.app — ASCII-safe for URL building everywhere;
    /// browsers resolve and display it as the registered IDN domain.
    static let webBase = "https://xn--glow-epa.app"

    /// App Store URL for the redirect page's "Get the app" button. (Used by the
    /// web page, kept here for reference.) Fill in once the app is live.
    static let appStoreURL = "https://apps.apple.com/app/id0000000000"

    /// A shareable link for a `verite://host?query` action. Hash-routed so the
    /// redirect page works on ANY static host with no server rules:
    ///   https://glowe.app/#invite?code=ABC  →  verite://invite?code=ABC
    static func share(host: String, query: String) -> URL {
        if let base = normalizedBase {
            if let url = URL(string: "\(base)/#\(host)?\(query)") { return url }
        }
        return veriteURL(host: host, query: query)
    }

    static func veriteURL(host: String, query: String) -> URL {
        URL(string: "verite://\(host)?\(query)")!
    }

    /// Extract a `verite://` URL from arbitrary pasted text — tolerant of BOTH
    /// the raw `verite://…` form AND an https link from our redirect page
    /// (`https://…/#host?query`), so the paste fallback keeps working either way.
    static func veriteURL(fromPasted text: String) -> URL? {
        if let range = text.range(of: #"verite://[a-z]+\?[A-Za-z0-9\-_=&]+"#,
                                  options: .regularExpression) {
            return URL(string: String(text[range]))
        }
        if let range = text.range(of: #"https?://[^\s]*#[a-z]+\?[A-Za-z0-9\-_=&]+"#,
                                  options: .regularExpression),
           let hash = String(text[range]).range(of: "#") {
            let fragment = String(String(text[range])[hash.upperBound...])   // host?query
            return URL(string: "verite://\(fragment)")
        }
        return nil
    }

    private static var normalizedBase: String? {
        let base = webBase.trimmingCharacters(in: .whitespaces)
        guard !base.isEmpty else { return nil }
        return base.hasSuffix("/") ? String(base.dropLast()) : base
    }
}
