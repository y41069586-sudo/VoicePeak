# SkinFix share-link redirect

Chats (WhatsApp, iMessage, …) only make `https://` links tappable — never a
custom scheme like `verite://`. This one-file page makes share links clickable:
a friend taps the `https://` link, this page opens and bounces them into the
app via `verite://` (or shows a "Get SkinFix" button if the app isn't installed).

## Setup (one-time)

1. **Host `index.html` at your domain root** — any static host works
   (GitHub Pages, Netlify, Vercel, Cloudflare Pages, your own server). The page
   is hash-routed, so it needs **no** server-side rules or redirects.
2. **Point the app at it:** set `webBase` in
   `Verite/Referral/LinkConfig.swift` to your domain, e.g.

   ```swift
   static let webBase = "https://glowe.app"
   ```

   While `webBase` is empty, the app keeps sending `verite://` links (only work
   via copy-paste). Once set, share links go out as
   `https://glowe.app/?go=invite&code=ABC` and are tappable everywhere.

## How the mapping works

```
https://glowe.app/?go=invite&code=ABC    →  verite://invite?code=ABC   (bonus scan)
https://glowe.app/?go=compare&d=<token>  →  verite://compare?d=<token> (skin duel)
```

The target host travels in a `go=` QUERY parameter, never in a `#fragment`.
Chat link detectors (WhatsApp, iMessage, Instagram) stop at a fragment holding
a `?`, so the older `/#invite?code=ABC` form was linkified only up to the
domain — tapping it loaded this page with an empty hash and the invite did
nothing. `index.html` still accepts that legacy form for links already shared.

The app's `onOpenURL` handling is unchanged — it still receives `verite://`.
Only the outgoing (shared) link changed.
