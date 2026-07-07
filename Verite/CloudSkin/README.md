# Cloud skin analysis module (optional, feature-flagged OFF)

The app's face scan is fully functional without this module — the on-device
`SkinAnalysisEngine` never leaves the device. This module adds an **opt-in**
cloud analysis via [DermIQ](https://dev.dermiq.cloud), a hosted, pre-trained
skin-analysis API (overall score, estimated skin age, and per-concern heatmap
masks).

**This is the one path in the app where a face photo leaves the device.**
Enabling it is a deliberate exception to the "face photos never leave the
device" invariant in `docs/ARCHITECTURE.md` — keep the in-app disclosure (and
`NSCameraUsageDescription` / legal copy) accurate if you turn it on for real
users.

## Enable it

1. Get an API key from your DermIQ dashboard.
2. Provide the connection values to the app via Info.plist keys — populate them
   from a **git-ignored** `Secrets.xcconfig` (never commit keys):
   ```
   DERMIQ_API_KEY = diq_sk_...
   DERMIQ_BASE_URL = https://dev.dermiq.cloud
   ```
3. Add matching `$(DERMIQ_API_KEY)` / `$(DERMIQ_BASE_URL)` keys to
   `Verite/Resources/Info.plist`, and reference `Secrets.xcconfig` from
   `project.yml`'s `configFiles:` for your target — this repo intentionally
   ships **without** either wired in, so `xcodegen generate` and the CI compile
   check never depend on a secrets file that doesn't exist in the repo.
4. Turn on `FeatureFlags.cloudSkinAnalysisEnabled`. `AppState` switches from
   `DisabledCloudSkinAnalysis` to `DermIQClient` when the flag is on *and*
   `DermIQConfig.isConfigured` is true.

## What it does

`POST /v1/analyze` (full) or `/v1/analyze/quick` (cheaper/faster — a candidate
for a live preview) accepts a JPEG and returns an `analysis_id` immediately;
`DermIQClient` polls `GET /v1/results/{id}` until the job finishes, then
downloads each named mask from `GET /v1/results/{id}/masks/{name}`.

Confirmed response fields: `overall_score`, `skin_age`, `mask_filenames`
(per-concern heatmap overlays — real, model-generated, unlike the app's own
rule-based zone heuristic). `result_json` carries the granular per-attribute
breakdown but isn't in the published OpenAPI schema (typed as a bare object) —
`DermIQJSONValue` decodes it safely as generic JSON; type concrete keys (e.g.
wrinkles, redness, pores) once a real response confirms their names, then map
them onto `SkinAttribute` alongside/instead of the on-device estimates.

`DermIQAnalysisResult.status` / `.analysisType` are similarly decoded as raw
strings rather than a hardcoded enum, since the OpenAPI schema declares them as
enums without exposing the exact member spelling — `isTerminal`/`isFailure`
poll off signals that don't depend on guessing that spelling.

## Cost

Credit-packs, cheaper per scan at higher tiers (checked live via
`GET /v1/billing/packs` — pricing isn't hardcoded anywhere in this module):
Starter 2,000 scans/$29, Growth 15,000/$149, Scale 100,000/$799. This is a real,
recurring per-scan cost, unlike the on-device engine — size the pack to
expected scan volume before enabling in production.

## Not yet wired

- `GET /v1/billing/balance` and `GET /v1/usage` (a low-balance warning /
  usage screen) — schemas weren't confirmed at integration time.
- No call site yet: `DermIQClient` is a ready-to-call service on `AppState`,
  not yet invoked from `ScanView` or the Match/Progress screens. Wire it once
  you've decided where the cloud result should surface (e.g. real heatmap
  masks in place of `ZoneHeatmapView`'s heuristic, or skin age on the
  Dashboard).
