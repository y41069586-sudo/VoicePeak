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
    /// Pretty IDN form — iOS 17+'s URL parser accepts the accented host and
    /// keeps it in `absoluteString`, so a shared link shows "glowé.app" in
    /// WhatsApp/iMessage instead of the raw punycode. If a platform ever fails
    /// to parse the IDN, `share(...)` falls back to `webBaseASCII`.
    static let webBase = "https://glowé.app"

    /// ASCII/punycode form of the same host — guaranteed-parseable fallback so a
    /// configured base never silently degrades to a `verite://` copy-only link.
    static let webBaseASCII = "https://xn--glow-epa.app"

    /// App Store URL for the redirect page's "Get the app" button. (Used by the
    /// web page, kept here for reference.)
    static let appStoreURL = "https://apps.apple.com/app/id6787454842"

    /// A shareable link for a `verite://host?query` action. The target host
    /// rides in a plain `go=` QUERY parameter so the redirect page still works
    /// on ANY static host with no server rules:
    ///   https://glowé.app/?go=invite&code=ABC  →  verite://invite?code=ABC
    ///
    /// NOT hash-routed. A `#fragment` containing a `?` (the old
    /// `/#invite?code=ABC` form) is where chat link detectors STOP: WhatsApp /
    /// iMessage / Instagram linkify only `https://glowé.app/` and leave the
    /// `#invite?code=ABC` tail as plain text. Tapping that truncated link loads
    /// the page with an empty `location.hash`, so the redirect has nothing to
    /// forward and the invite silently does nothing. A standard query string is
    /// linkified whole.
    static func share(host: String, query: String) -> URL {
        // Prefer the pretty IDN base (nicer in shared chats); fall back to the
        // ASCII/punycode base if the IDN string won't parse on this platform;
        // only then drop to the copy-only verite:// scheme.
        for base in [normalized(webBase), normalized(webBaseASCII)] {
            if let base, let url = URL(string: "\(base)/?go=\(host)&\(query)") { return url }
        }
        return veriteURL(host: host, query: query)
    }

    static func veriteURL(host: String, query: String) -> URL {
        URL(string: "verite://\(host)?\(query)")!
    }

    /// Extract a `verite://` URL from arbitrary pasted text — tolerant of BOTH
    /// the raw `verite://…` form AND an https link from our redirect page, so
    /// the paste fallback keeps working either way.
    static func veriteURL(fromPasted text: String) -> URL? {
        if let range = text.range(of: #"verite://[a-z]+\?[A-Za-z0-9\-_=&]+"#,
                                  options: .regularExpression) {
            return URL(string: String(text[range]))
        }
        if let range = text.range(of: #"https?://[^\s]+"#, options: .regularExpression) {
            // Trailing sentence punctuation isn't part of the link ("…code=ABC.").
            let raw = String(text[range])
                .trimmingCharacters(in: CharacterSet(charactersIn: ".,;:!)\"'"))
            return deepLink(fromWebURL: raw)
        }
        return nil
    }

    /// Decode a redirect-page URL into its `verite://` deep link. Understands
    /// the current query form (`/?go=invite&code=ABC`) AND the legacy hash form
    /// (`/#invite?code=ABC`) that links shared before the switch still carry —
    /// an old invite someone pastes months later must not silently fail.
    static func deepLink(fromWebURL raw: String) -> URL? {
        guard let comps = URLComponents(string: raw) else { return nil }

        if let items = comps.queryItems,
           let host = items.first(where: { $0.name == "go" })?.value, !host.isEmpty {
            let query = items
                .filter { $0.name != "go" }
                .compactMap { item in item.value.map { "\(item.name)=\($0)" } }
                .joined(separator: "&")
            return URL(string: "verite://\(host)?\(query)")
        }

        if let fragment = comps.fragment, !fragment.isEmpty {   // legacy #host?query
            return URL(string: "verite://\(fragment)")
        }
        return nil
    }

    private static func normalized(_ raw: String) -> String? {
        let base = raw.trimmingCharacters(in: .whitespaces)
        guard !base.isEmpty else { return nil }
        return base.hasSuffix("/") ? String(base.dropLast()) : base
    }
}
