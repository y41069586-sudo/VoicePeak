# Glowé share-link redirect

Chats (WhatsApp, iMessage, …) only make `https://` links tappable — never a
custom scheme like `verite://`. This one-file page makes share links clickable:
a friend taps the `https://` link, this page opens and bounces them into the
app via `verite://` (or shows a "Get Glowé" button if the app isn't installed).

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
   `https://glowe.app/#invite?code=ABC` and are tappable everywhere.
3. **App Store button:** replace the placeholder `id0000000000` link in
   `index.html` (and `LinkConfig.appStoreURL`) with your real App Store URL once
   the app is live.

## How the mapping works

```
https://glowe.app/#invite?code=ABC   →   verite://invite?code=ABC   (bonus scan)
https://glowe.app/#compare?d=<token> →   verite://compare?d=<token> (skin duel)
```

The app's `onOpenURL` handling is unchanged — it still receives `verite://`.
Only the outgoing (shared) link changed.
