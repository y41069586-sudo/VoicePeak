import SwiftUI

/// Feature flags for the optional modules. Backend, purchases and Google
/// sign-in ship ON (their services are configured); the rest stay OFF until
/// their integrations land. The app is 100% functional offline with every
/// flag off (see the brief §7.1/§9/§16).
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

    /// Native rating ask on the onboarding social-proof screen. OFF — the
    /// hook is built, intended for later versions once ratings justify it.
    var onboardingRatingAskEnabled: Bool

    // "Sign in with Apple" has no flag: the entitlement is enabled and App
    // Review 4.8 requires it whenever any third-party login (Google) is
    // offered — so the button always shows.

    /// "Continue with Google" on the sign-in screen. OFF until the
    /// GoogleSignIn SDK + OAuth client ID are configured — a visible but
    /// non-functional button is an App Review 2.1 rejection.
    var googleSignInEnabled: Bool

    init(
        affiliateEnabled: Bool = false,
        backendEnabled: Bool = true,
        purchasesEnabled: Bool = true,
        communityEnabled: Bool = false,
        onboardingRatingAskEnabled: Bool = false,
        googleSignInEnabled: Bool = true
    ) {
        self.affiliateEnabled = affiliateEnabled
        self.backendEnabled = backendEnabled
        self.purchasesEnabled = purchasesEnabled
        self.communityEnabled = communityEnabled
        self.onboardingRatingAskEnabled = onboardingRatingAskEnabled
        self.googleSignInEnabled = googleSignInEnabled
    }

    /// Production defaults — everything optional stays off.
    static let `default` = FeatureFlags()
}
