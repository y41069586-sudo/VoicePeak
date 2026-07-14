import SwiftUI

/// Soft paywall (SCREENS_SPEC A15): clear free-vs-Pro value led by the half-face
/// proof benefit — the thing that makes Glowé different — a plan selector, a free
/// trial, honest pricing, Restore, and a real skip to the free experience (no dark
/// patterns). Purchases are feature-flagged OFF until Milestone 12, so both paths
/// continue into the app; the StoreKit wiring lights up the CTA when enabled.
struct OnboardingPaywallView: View {
    let onContinue: () -> Void
    let onSkip: () -> Void

    @Environment(AppState.self) private var appState
    @Environment(PurchaseManager.self) private var purchases
    @State private var plan: Plan = .yearly

    enum Plan: CaseIterable { case yearly, monthly }

    private var purchasesEnabled: Bool { appState.featureFlags.purchasesEnabled }

    // Half-face proof leads — it's the honesty differentiator.
    private let features: [(String, LocalizedStringKey)] = [
        ("flask", "paywall.feature.halfface"),
        ("clock.arrow.circlepath", "paywall.feature.history"),
        ("infinity", "paywall.feature.unlimited"),
        ("rectangle.on.rectangle.angled", "paywall.feature.dupes"),
        ("chart.line.uptrend.xyaxis", "paywall.feature.progress"),
        ("square.and.arrow.up", "paywall.feature.share"),
    ]

    var body: some View {
        ZStack {
            VBackground()
            VStack(spacing: 0) {
                ScrollView {
                    VStack(spacing: VSpace.lg) {
                        header
                        featureCard
                        planSelector
                        Text("paywall.pricing")
                            .font(VType.caption)
                            .foregroundStyle(VColor.textSecondary)
                            .multilineTextAlignment(.center)
                        Button("paywall.restore") {
                            Task { await purchases.restore(); if purchases.isPro { onContinue() } }
                        }
                        .font(VType.captionBold)
                        .foregroundStyle(VColor.primary)
                    }
                    .padding(VSpace.lg)
                }
                .scrollIndicators(.hidden)

                VStack(spacing: VSpace.xs) {
                    PrimaryButton(titleKey: "paywall.trial", systemImage: "sparkles",
                                  isEnabled: !purchases.isPurchasing) {
                        startTrial()
                    }
                    SecondaryButton(titleKey: "paywall.skip", action: onSkip)
                }
                .padding(.horizontal, VSpace.lg)
                .padding(.bottom, VSpace.lg)
            }
        }
    }

    private var header: some View {
        VStack(spacing: VSpace.sm) {
            Image(systemName: "seal.fill")
                .font(.system(size: 44))
                .foregroundStyle(VColor.primary)
                .vGlow(VColor.primary, radius: 18, opacity: 0.25)
            Text("paywall.title")
                .font(VType.heroTitle)
                .foregroundStyle(VColor.textPrimary)
                .multilineTextAlignment(.center)
            Text("paywall.subtitle")
                .font(VType.body)
                .foregroundStyle(VColor.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, VSpace.xl)
    }

    private var featureCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: VSpace.md) {
                ForEach(Array(features.enumerated()), id: \.offset) { index, feature in
                    HStack(spacing: VSpace.sm) {
                        Image(systemName: feature.0)
                            .foregroundStyle(index == 0 ? VColor.primary : VColor.accent)
                            .frame(width: 26)
                        Text(feature.1)
                            .font(index == 0 ? VType.bodyMedium : VType.body)
                            .foregroundStyle(VColor.textPrimary)
                        Spacer(minLength: 0)
                    }
                }
            }
        }
    }

    // MARK: Plan selector

    private var planSelector: some View {
        HStack(spacing: VSpace.sm) {
            planCard(.yearly, titleKey: "paywall.plan.yearly", priceKey: "paywall.plan.yearly.price",
                     badgeKey: "paywall.plan.yearly.badge")
            planCard(.monthly, titleKey: "paywall.plan.monthly", priceKey: "paywall.plan.monthly.price")
        }
    }

    private func planCard(_ value: Plan, titleKey: LocalizedStringKey, priceKey: LocalizedStringKey,
                          badgeKey: LocalizedStringKey? = nil) -> some View {
        let selected = plan == value
        return Button {
            Haptics.fire(.selection)
            plan = value
        } label: {
            VStack(alignment: .leading, spacing: VSpace.xs) {
                if let badgeKey {
                    Text(badgeKey)
                        .font(VType.micro.weight(.bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background(VColor.heroGradient, in: Capsule())
                }
                Text(titleKey).font(VType.bodyMedium).foregroundStyle(VColor.textPrimary)
                Text(priceKey).font(VType.caption).foregroundStyle(VColor.textSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(VSpace.md)
            .background(VColor.bgSurface, in: RoundedRectangle(cornerRadius: VRadius.md, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: VRadius.md, style: .continuous)
                    .strokeBorder(selected ? VColor.primary : VColor.strokeSubtle, lineWidth: selected ? 2 : 1)
            )
        }
        .buttonStyle(PressableStyle())
        .animation(VMotion.snappy, value: selected)
    }

    /// With purchases enabled, attempt the real purchase for the selected plan;
    /// either way continue into the app (a soft paywall never traps the user).
    private func startTrial() {
        guard purchasesEnabled else { onContinue(); return }
        let productID = plan == .yearly ? VeriteProducts.proYearly : VeriteProducts.proMonthly
        let product = purchases.products.first { $0.id == productID } ?? purchases.products.first
        guard let product else { onContinue(); return }
        Task {
            _ = await purchases.purchase(product)
            onContinue()
        }
    }
}
