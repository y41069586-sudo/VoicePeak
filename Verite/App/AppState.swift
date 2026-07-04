import SwiftUI

/// Global, observable app state injected into the environment. Kept deliberately
/// small — persistent data lives in SwiftData; this holds transient UI/session state.
@Observable
final class AppState {
    /// Currently selected main tab (Home, Analyzer, Routine, or Progress).
    var selectedTab: AppTab = .home

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

/// The four core destinations. Premium, analyzer-first experience.
enum AppTab: String, CaseIterable, Identifiable {
    case home, analyzer, routine, progress
    var id: String { rawValue }

    var titleKey: LocalizedStringKey { "\(rawValue)" }

    var systemImage: String {
        switch self {
        case .home:     return "house.fill"
        case .analyzer: return "camera.viewfinder"
        case .routine:  return "checklist"
        case .progress: return "chart.line.uptrend.xyaxis"
        }
    }
}
