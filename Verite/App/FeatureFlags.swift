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

    /// Native rating ask on the onboarding social-proof screen. OFF — the
    /// hook is built, intended for later versions once ratings justify it.
    var onboardingRatingAskEnabled: Bool

    /// "Sign in with Apple" on the sign-in screen. OFF by default: the button
    /// needs the `com.apple.developer.applesignin` entitlement, which requires
    /// the capability enabled on the App ID in the developer portal. Turn ON
    /// (and re-add CODE_SIGN_ENTITLEMENTS in project.yml) once that's done.
    /// When both this and Google are OFF, the sign-in step is skipped entirely.
    var appleSignInEnabled: Bool

    /// "Continue with Google" on the sign-in screen. OFF until the
    /// GoogleSignIn SDK + OAuth client ID are configured — a visible but
    /// non-functional button is an App Review 2.1 rejection.
    var googleSignInEnabled: Bool

    init(
        affiliateEnabled: Bool = false,
        backendEnabled: Bool = true,
        purchasesEnabled: Bool = false,
        communityEnabled: Bool = false,
        onboardingRatingAskEnabled: Bool = false,
        appleSignInEnabled: Bool = true,
        googleSignInEnabled: Bool = false
    ) {
        self.affiliateEnabled = affiliateEnabled
        self.backendEnabled = backendEnabled
        self.purchasesEnabled = purchasesEnabled
        self.communityEnabled = communityEnabled
        self.onboardingRatingAskEnabled = onboardingRatingAskEnabled
        self.appleSignInEnabled = appleSignInEnabled
        self.googleSignInEnabled = googleSignInEnabled
    }

    /// Production defaults — everything optional stays off.
    static let `default` = FeatureFlags()
}
