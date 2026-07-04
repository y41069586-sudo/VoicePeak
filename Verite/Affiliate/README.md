# Affiliate module (optional, feature-flagged OFF)

The app is 100% functional on Open Beauty Facts alone. This module adds affiliate
offers (image / price / link) to the product screen. Ship it OFF; enable once you
have traffic.

## Principles
- **Radical transparency.** Every affiliate link is shown with an in-app
  disclosure, and affiliate status **never** changes a product's honest match.
- **Legal imagery only.** Use affiliate-provided or open-licensed images —
  never scraped brand/retailer assets.

## Enable it
1. Stand up a small **server-side** endpoint that queries your affiliate network
   (Amazon PA-API needs AWS SigV4 signing — do it server-side; never ship signing
   keys in the app) and returns JSON:
   ```json
   { "title": "...", "price": 12.99, "currency": "EUR",
     "image": "https://…", "url": "https://…?tag=YOURTAG", "provider": "Amazon" }
   ```
2. Set Info.plist keys from a git-ignored `Secrets.xcconfig`:
   ```
   AFFILIATE_ENDPOINT = https://your-proxy.example.com/offer
   AFFILIATE_TAG = your-affiliate-tag
   ```
3. Turn on `FeatureFlags.affiliateEnabled`. `AppState` switches from
   `DisabledAffiliate` to `ConfiguredAffiliateProvider` when the flag is on *and*
   config is present.

The provider is called with primitives (barcode + name + brand), so no SwiftData
model crosses an async boundary.
