import SwiftUI

/// Global, observable app state injected into the environment. Kept deliberately
/// small — persistent data lives in SwiftData; this holds transient UI/session state.
@Observable
@MainActor
final class AppState {
    /// Currently selected main tab.
    var selectedTab: AppTab = .home

    // MARK: Guided flow coordination (scan → match → prove)

    /// Set when the user enters the scan as step 1 of the guided flow. `ScanView`
    /// reads it to carry them straight into product selection after a successful
    /// scan, instead of dropping back to the dashboard.
    var continueFlowAfterScan = false

    /// Drives the product-selection → match → test leg presented over the scanner.
    /// `ScanView` owns the cover; setting this `false` (e.g. when a test starts)
    /// tears the whole flow down and returns to the dashboard.
    var flowSelectingProduct = false

    /// Language override chosen in Settings (nil = follow the system locale).
    /// Persisted separately via `@AppStorage("languageOverride")` in Settings.
    var languageOverride: String?

    let featureFlags: FeatureFlags

    /// Optional backend. Defaults to `LocalOnlyBackend` — the app is fully
    /// functional offline; switches to Supabase only when the flag is on *and*
    /// config is present. Face photos never touch it.
    let backend: BackendService

    /// Optional affiliate enrichment. OFF by default → `DisabledAffiliate`.
    let affiliate: AffiliateService

    init(featureFlags: FeatureFlags = .default) {
        self.featureFlags = featureFlags
        self.backend = (featureFlags.backendEnabled && BackendConfig.shared.isConfigured)
            ? SupabaseBackend()
            : LocalOnlyBackend()
        self.affiliate = (featureFlags.affiliateEnabled && AffiliateConfig.shared.isConfigured)
            ? ConfiguredAffiliateProvider(config: .shared)
            : DisabledAffiliate()
    }
}

/// The four primary destinations.
enum AppTab: String, CaseIterable, Identifiable {
    case home, analyze, routine, progress
    var id: String { rawValue }

    var titleKey: LocalizedStringKey {
        switch self {
        case .home:     return "tab.today"
        case .analyze:  return "tab.scan"
        case .routine:  return "tab.routine"
        case .progress: return "tab.progress"
        }
    }

    var systemImage: String {
        switch self {
        case .home:     return "house.fill"
        case .analyze:  return "camera.viewfinder"
        case .routine:  return "checklist"
        case .progress: return "chart.line.uptrend.xyaxis"
        }
    }
}
