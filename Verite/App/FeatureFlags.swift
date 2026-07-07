import SwiftUI

/// Feature flags for the optional modules. **All OFF by default** — the app is
/// 100% functional offline without any of them (see the brief §7.1/§9/§16).
///
/// Exposed as `@Observable` so a debug settings screen can toggle them at
/// runtime; production defaults come from `.default`.
@Observable
final class FeatureFlags: @unchecked Sendable {

    /// Affiliate catalog enrichment (Amazon PA-API / Awin / Impact). OFF.
    var affiliateEnabled: Bool

    /// Supabase account sync + opt-in anonymized aggregate efficacy. OFF.
    /// Face photos never leave the device regardless of this flag.
    var backendEnabled: Bool

    /// StoreKit 2 paywall + subscription entitlements. OFF until Milestone 12.
    var purchasesEnabled: Bool

    /// Community efficacy (opt-in, numbers only, no photos). OFF.
    var communityEnabled: Bool

    /// Cloud skin analysis (DermIQ). OFF. The one deliberate exception to
    /// "face photos never leave the device" — sends the captured face photo
    /// to DermIQ's API for analysis. See CloudSkin/README.md before enabling.
    var cloudSkinAnalysisEnabled: Bool

    init(
        affiliateEnabled: Bool = false,
        backendEnabled: Bool = false,
        purchasesEnabled: Bool = false,
        communityEnabled: Bool = false,
        cloudSkinAnalysisEnabled: Bool = false
    ) {
        self.affiliateEnabled = affiliateEnabled
        self.backendEnabled = backendEnabled
        self.purchasesEnabled = purchasesEnabled
        self.communityEnabled = communityEnabled
        self.cloudSkinAnalysisEnabled = cloudSkinAnalysisEnabled
    }

    /// Production defaults — everything optional stays off.
    static let `default` = FeatureFlags()
}
