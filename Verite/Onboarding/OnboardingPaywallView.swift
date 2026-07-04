import SwiftUI

/// Soft paywall: clear free-vs-Pro value, a free trial, honest pricing, Restore,
/// and a real skip to a limited free experience (no dark patterns). Purchases are
/// feature-flagged OFF until Milestone 12, so both paths currently continue into
/// the app — StoreKit wiring replaces the CTA there.
struct OnboardingPaywallView: View {
    let onContinue: () -> Void
    let onSkip: () -> Void

    @Environment(AppState.self) private var appState
    @Environment(PurchaseManager.self) private var purchases

    private var purchasesEnabled: Bool { appState.featureFlags.purchasesEnabled }

    private let features: [(String, LocalizedStringKey)] = [
        ("infinity", "paywall.feature.unlimited"),
        ("clock.arrow.circlepath", "paywall.feature.history"),
        ("rectangle.on.rectangle.angled", "paywall.feature.dupes"),
        ("chart.line.uptrend.xyaxis", "paywall.feature.progress"),
        ("square.and.arrow.up", "paywall.feature.share"),
    ]

    var body: some View {
        ZStack {
            GradientMeshBackground()
            VStack(spacing: 0) {
                ScrollView {
                    VStack(spacing: 18) {
                        VStack(spacing: 10) {
                            Image(systemName: "seal.fill")
                                .font(.system(size: 44))
                                .foregroundStyle(Theme.signature)
                                .blueGlow()
                            Text("paywall.title")
                                .font(Typography.display(30))
                                .foregroundStyle(Theme.textPrimary)
                                .multilineTextAlignment(.center)
                            Text("paywall.subtitle")
                                .font(.subheadline)
                                .foregroundStyle(Theme.textSecondary)
                                .multilineTextAlignment(.center)
                        }
                        .padding(.top, 24)

                        GlassCard {
                            VStack(alignment: .leading, spacing: 14) {
                                ForEach(features, id: \.0) { feature in
                                    HStack(spacing: 12) {
                                        Image(systemName: feature.0)
                                            .foregroundStyle(Theme.primary)
                                            .frame(width: 26)
                                        Text(feature.1)
                                            .font(.subheadline)
                                            .foregroundStyle(Theme.textPrimary)
                                    }
                                }
                            }
                        }

                        Text("paywall.pricing")
                            .font(.footnote)
                            .foregroundStyle(Theme.textSecondary)
                            .multilineTextAlignment(.center)

                        Button("paywall.restore") {
                            Task { await purchases.restore(); if purchases.isPro { onContinue() } }
                        }
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(Theme.primary)
                    }
                    .padding(24)
                }
                .scrollIndicators(.hidden)

                VStack(spacing: 6) {
                    PrimaryButton(titleKey: "paywall.trial", systemImage: "sparkles",
                                  isEnabled: !purchases.isPurchasing) {
                        startTrial()
                    }
                    SecondaryButton(titleKey: "paywall.skip", action: onSkip)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 20)
            }
        }
    }

    /// With purchases enabled, attempt the real purchase; either way continue into
    /// the app (a soft paywall never traps the user).
    private func startTrial() {
        guard purchasesEnabled, let product = purchases.products.first else {
            onContinue()
            return
        }
        Task {
            _ = await purchases.purchase(product)
            onContinue()
        }
    }
}
