# Vérité AI advisor module (feature-flagged ON, inert until configured)

The advisor is the app's conversational recommendation feature: the user picks a
goal (presets + free text — "talk to Vérité AI in your own words"), and Claude
returns the **3 best-fitting products** from the catalog for that goal and that
person's skin, each with an **honest review** (downsides and cautions included,
per Vérité's no-hype brand).

**No photo is ever sent.** The request contains only numbers + text: a short
skin summary built from `SkinContext` (scan-derived metric estimates, declared
skin type/concerns/sensitivities) plus the product ingredient lists. That makes
this the privacy-friendly counterpart to the CloudSkin/DermIQ module (which does
upload the photo).

`FeatureFlags.advisorEnabled` defaults to **true**, but `AppState` only builds a
real `ClaudeAdvisor` when the flag is on **and** `ClaudeConfig.isConfigured` is
true (a real `ANTHROPIC_API_KEY` present at build time). No key is committed, so
the "Ask Vérité AI" dashboard card stays hidden out of the box.

## Supply the key

Info.plist's `ANTHROPIC_API_KEY` resolves from `Secrets.xcconfig` (git-ignored),
exactly like `DERMIQ_API_KEY`:

- **Local Xcode:** copy `Secrets.xcconfig.example` → `Secrets.xcconfig`, fill in
  the key, `xcodegen generate`.
- **Codemagic:** add `ANTHROPIC_API_KEY` (Secure) to the `Verite` environment
  variable group; the "Write Secrets.xcconfig" step already writes it.

Only the **API key** goes through xcconfig — never a base URL (xcconfig treats
`//` as a comment and would mangle it). Base URLs are hardcoded in
`ClaudeConfig` / `DermIQConfig`.

## How it works

`ClaudeAdvisor` builds an honesty-first prompt (skin summary + goals + candidate
products) and calls Anthropic's Messages API via `ClaudeClient` using
**structured outputs** (`output_config.format`) so the reply is schema-validated
JSON — ranked `recommendations` (product_id, fit_score, why, honest_review,
caution) + an `overall_note` — decoded into `AdvisorResult`. Model defaults to
`claude-opus-4-8` (best honest reasoning); change `ClaudeConfig.model` to
`claude-sonnet-5` / `claude-haiku-4-5` to trade quality for cost.

## ⚠️ Production: proxy the key

`ClaudeClient` sends the key straight from the device. That's fine for testing,
but a key shipped in an app binary is **extractable and abusable** (it bills
*your* Anthropic account). For a real release, stand up a tiny backend that
holds the key and forwards to Anthropic, and point `ClaudeConfig.baseURL` at it
(change the hardcoded default). Then no key needs to ship in the app at all.

## Not yet wired

- Multi-turn chat: today it's one goal → one recommendation set. A full back-and-
  forth "chat with Vérité AI" would layer a conversation state on top of the same
  `ClaudeClient`.
- Uses the on-device `SkinContext` for the skin summary; when DermIQ is also
  enabled, its richer metrics could be folded into `summarize(...)`.
