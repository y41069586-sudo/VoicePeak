# Vérité — App Store Review Checklist

Each item from the brief (§11) mapped to its implementation, with reviewer notes.
Ship-blockers are marked ⚠️ where a human step remains before submission.

## Reviewer quick-start
- **No account required.** Launch → onboarding → the app is fully usable.
- **Free tier is fully functional offline.** StoreKit, Supabase, and Affiliate
  modules are feature-flagged **OFF** (`FeatureFlags`), so review needs no
  sandbox account, no server, and no purchase.
- **Reach every feature:** Scan tab (camera) → Products tab (search/barcode →
  product analysis → "See how it fits your skin" = Honest Match → "Start a
  half-face test") → Today (active test, savings, share) → Routine → Progress →
  Settings (language ×5, data export/delete, legal, reminders).
- **No medical claims anywhere;** a "not medical advice" disclaimer is on every
  analysis surface and in Settings → Legal.

## Checklist

| # | Requirement | Implementation |
|---|---|---|
| 1 | Honest, specific, localized permission strings | `NSCameraUsageDescription` in `Info.plist`, localized ×5 in `Resources/InfoPlist.xcstrings`. No photo-library permission (not used). |
| 2 | Privacy manifest | `Resources/PrivacyInfo.xcprivacy` — no tracking, no collected data types; UserDefaults required-reason `CA92.1`. |
| 3 | App Privacy nutrition label | Local-first → **Data Not Collected**. Photos are not collected/transmitted. Fill the App Store Connect label accordingly. ⚠️ (ASC form is a human step.) |
| 4 | No medical/diagnostic claims; persistent disclaimer | `DisclaimerBanner` (short) on every analysis surface (scan result, match, test, baseline reveal, dashboard); full text in Settings → Legal (`disclaimer.full`), localized ×5. Copy says "estimates," "what happened on your skin," never "works"/diagnosis. |
| 5 | No attractiveness rating | Only change-vs-own-baseline (`BaselineTracker`, `HalfFaceTestScoring`). No absolute/beauty/ranking score exists in the data model or UI. |
| 6 | No scraped copyrighted imagery | Product imagery is open-licensed **Open Beauty Facts** only (`ImageCache`/`RemoteImage`); starter catalog is INCI-only, no bundled brand images. |
| 7 | In-app account deletion (if accounts exist) | No accounts in the shipping build (backend OFF). When enabled, the backend module must delete server rows; delete-all already wipes local data. ⚠️ (only relevant once backend is on.) |
| 8 | Data export + delete-all (local) | Settings → Data & privacy: `DataExporter` (JSON, numbers + routine, **never photos**) and a delete-all that wipes SwiftData + thumbnails + reminders. |
| 9 | Sign in with Apple offered if any third-party auth | No third-party auth in the shipping build. The Supabase module (M12, OFF) must offer Sign in with Apple if it adds email auth. ⚠️ |
| 10 | Restore Purchases; no external purchase links | Paywall shows Restore; pricing routes to App Store settings; no external purchase CTAs. Real StoreKit is M12. |
| 11 | Minimum functionality / not a thin wrapper (4.2) | On-device camera + Vision + classical-CV analysis, INCI engine, half-face test, routine, progress charts — all work offline. |
| 12 | No private APIs | Only public AVFoundation, Vision, CoreImage, SwiftData, SwiftUI, Charts, UserNotifications, StoreKit (later). |
| 13 | Accessibility ×5 | System text styles for body (Dynamic Type); VoiceOver labels/values on data + controls; Reduce Motion honored (`Motion`/`GradientMeshBackground`/animations); contrast tuned for the white-blue palette. Verify with VoiceOver in each language. |
| 14 | Graceful permission denial + Settings deep-link | `CameraPrimingView` (pre-prompt) + `CameraDeniedView` with `CameraPermission.openSettings()`. No dead-ends/crashes. |
| 15 | Accurate metadata & no deceptive onboarding/paywall | Onboarding has a Skip path throughout; paywall is skippable to a real free tier; no fake "after," no forced trial. ⚠️ (App Store screenshots/metadata are a human step.) |
| 16 | Age rating; EU compliance (GDPR + Impressum) | Not directed to under-16 (privacy policy). `legal/IMPRESSUM.md` + localized in-app Impressum (TMG §5). ⚠️ (set age rating + fill operator details in ASC.) |

## Remaining human steps before submission
1. Fill App Store Connect **App Privacy** as Data Not Collected (item 3).
2. Replace bracketed operator/contact fields in the localized legal text +
   `legal/*.md`, and have a lawyer review (items 7, 16).
3. Add App Store screenshots/metadata (item 15).
4. Bundle the display font + confirm its SIL OFL license (see `docs/SETUP.md`).
5. If enabling M12 modules: add StoreKit products, Sign in with Apple, and
   server-side account deletion (items 7, 9, 10).
