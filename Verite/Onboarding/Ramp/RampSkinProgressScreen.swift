import SwiftUI

// ============================================================
// MARK: — Skin Progress (14-day transformation preview)
// ============================================================

/// Shows the user what 14 days with SkinFix looks like: a visual
/// transformation with emoji-accented metrics.
struct RampSkinProgressScreen: View {
    let answers: RampQuizAnswers
    let onAdvance: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var metricsVisible = false

    var body: some View {
        GeometryReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    Spacer(minLength: RampStage.headerClearance)

                    // Headline
                    Text("14 days with SkinFix")
                        .font(RampStage.serif(26, weight: .semibold))
                        .foregroundStyle(RampStage.ink)
                        .lineSpacing(2)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, VSpace.lg)

                    // Subtext
                    Text("Here's what real results look like.")
                        .font(VType.body)
                        .foregroundStyle(RampStage.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, VSpace.lg)
                        .padding(.top, VSpace.xs)

                    // Visual transformation
                    transformationCard
                        .padding(.horizontal, VSpace.lg)
                        .padding(.top, VSpace.lg)

                    // Metrics
                    metricsGrid
                        .padding(.horizontal, VSpace.lg)
                        .padding(.top, VSpace.lg)

                    // CTA
                    Spacer(minLength: VSpace.lg)
                    RampPrimaryButton(title: "See the tiers") { onAdvance() }
                        .padding(.horizontal, VSpace.lg)
                    Spacer().frame(height: VSpace.xxl)
                }
                .frame(minHeight: proxy.size.height, alignment: .leading)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
        .task { await choreograph() }
    }

    private var transformationCard: some View {
        VStack(spacing: 0) {
            GeometryReader { geo in
                ZStack {
                    // Before state (left)
                    VStack(alignment: .center, spacing: VSpace.sm) {
                        Circle()
                            .fill(
                                LinearGradient(
                                    gradient: Gradient(stops: [
                                        .init(color: Color(hex: "#E8A89A"), location: 0),
                                        .init(color: Color(hex: "#D4957F"), location: 1)
                                    ]),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .overlay(
                                Image(systemName: "sparkles")
                                    .font(.system(size: 48))
                                    .foregroundStyle(.white)
                                    .opacity(0.6)
                            )
                            .frame(width: 80, height: 80)

                        Text("Before")
                            .font(VType.caption)
                            .foregroundStyle(RampStage.textTertiary)
                    }
                    .frame(width: geo.size.width / 2)
                    .position(x: geo.size.width / 4, y: geo.size.height / 2)

                    // Arrow
                    HStack(spacing: 0) {
                        Image(systemName: "arrow.right")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(RampStage.accentEdge)
                    }
                    .position(x: geo.size.width / 2, y: geo.size.height / 2)

                    // After state (right)
                    VStack(alignment: .center, spacing: VSpace.sm) {
                        Circle()
                            .fill(
                                LinearGradient(
                                    gradient: Gradient(stops: [
                                        .init(color: Color(hex: "#F4D4B8"), location: 0),
                                        .init(color: Color(hex: "#E8C9AB"), location: 1)
                                    ]),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .overlay(
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 48))
                                    .foregroundStyle(Color(hex: "#52C41A"))
                            )
                            .frame(width: 80, height: 80)

                        Text("After")
                            .font(VType.caption)
                            .foregroundStyle(RampStage.textTertiary)
                    }
                    .frame(width: geo.size.width / 2)
                    .position(x: geo.size.width * 0.75, y: geo.size.height / 2)
                }
            }
            .frame(height: 140)

            Divider()
                .padding(.vertical, VSpace.md)

            // Key message
            VStack(alignment: .center, spacing: VSpace.xs) {
                Text("Most people see improvement in 2–3 weeks.")
                    .font(VType.body)
                    .foregroundStyle(RampStage.ink)
                    .lineLimit(nil)

                Text("Some by day five.")
                    .font(VType.bodyLarge.weight(.semibold))
                    .foregroundStyle(RampStage.accentEdge)
            }
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.vertical, VSpace.md)
        }
        .padding(VSpace.md)
        .background(RampStage.accentSoft)
        .cornerRadius(16)
    }

    private var metricsGrid: some View {
        VStack(spacing: RampStage.tileGap) {
            HStack(spacing: RampStage.tileGap) {
                metricCard(emoji: "🔴", label: "Redness", benefit: "↓ 40%")
                metricCard(emoji: "✨", label: "Clarity", benefit: "↑ 60%")
            }
            .frame(maxWidth: .infinity)

            HStack(spacing: RampStage.tileGap) {
                metricCard(emoji: "🎯", label: "Texture", benefit: "↑ 35%")
                metricCard(emoji: "💧", label: "Hydration", benefit: "↑ 45%")
            }
            .frame(maxWidth: .infinity)
        }
        .opacity(metricsVisible ? 1 : 0)
        .offset(y: metricsVisible ? 0 : 8)
    }

    private func metricCard(emoji: String, label: String, benefit: String) -> some View {
        VStack(alignment: .leading, spacing: VSpace.xs) {
            HStack(spacing: VSpace.xs) {
                Text(emoji)
                    .font(.system(size: 20))
                Text(label)
                    .font(VType.bodySmall.weight(.medium))
                    .foregroundStyle(RampStage.textSecondary)
            }
            Text(benefit)
                .font(.system(size: 16, weight: .semibold, design: .rounded).monospacedDigit())
                .foregroundStyle(RampStage.accentEdge)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(VSpace.md)
        .background(RampStage.hair.opacity(0.04))
        .cornerRadius(12)
    }

    private func choreograph() async {
        if reduceMotion {
            metricsVisible = true
            return
        }

        try? await Task.sleep(for: .milliseconds(300))
        guard !Task.isCancelled else { return }

        withAnimation(.easeOut(duration: 0.6)) {
            metricsVisible = true
        }
    }
}

// ============================================================
// MARK: — Product Tiers
// ============================================================

/// Three product tiers: what you get and at what price. Each tier
/// shows included items and clear call-to-action.
struct RampProductTiersScreen: View {
    let answers: RampQuizAnswers
    let onAdvance: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var tiersVisible = [false, false, false]

    var body: some View {
        GeometryReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    Spacer(minLength: RampStage.headerClearance)

                    // Headline
                    Text("Choose your plan")
                        .font(RampStage.serif(26, weight: .semibold))
                        .foregroundStyle(RampStage.ink)
                        .lineSpacing(2)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, VSpace.lg)

                    // Subtext
                    Text("All plans include a full 14-day guarantee.")
                        .font(VType.body)
                        .foregroundStyle(RampStage.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, VSpace.lg)
                        .padding(.top, VSpace.xs)

                    // Tiers
                    VStack(spacing: RampStage.tileGap) {
                        tierCard(
                            index: 0,
                            emoji: "🧴",
                            name: "Starter",
                            price: "€29",
                            period: "/month",
                            items: [
                                "Gentle cleanser",
                                "Hydrating serum",
                                "Daily moisturizer"
                            ]
                        )

                        tierCard(
                            index: 1,
                            emoji: "✨",
                            name: "Clarity",
                            price: "€59",
                            period: "/month",
                            items: [
                                "Everything in Starter",
                                "Targeted acne treatment",
                                "Weekly mask",
                                "Priority support"
                            ],
                            highlight: true
                        )

                        tierCard(
                            index: 2,
                            emoji: "👑",
                            name: "Complete",
                            price: "€89",
                            period: "/month",
                            items: [
                                "Everything in Clarity",
                                "SPF protection",
                                "Eye care serum",
                                "Personalized routine",
                                "Direct dermatologist access"
                            ]
                        )
                    }
                    .padding(.horizontal, VSpace.lg)
                    .padding(.top, VSpace.lg)

                    // CTA
                    Spacer(minLength: VSpace.lg)
                    RampPrimaryButton(title: "Continue") { onAdvance() }
                        .padding(.horizontal, VSpace.lg)
                    Spacer().frame(height: VSpace.xxl)
                }
                .frame(minHeight: proxy.size.height, alignment: .leading)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
        .task { await choreograph() }
    }

    private func tierCard(
        index: Int,
        emoji: String,
        name: String,
        price: String,
        period: String,
        items: [String],
        highlight: Bool = false
    ) -> some View {
        VStack(alignment: .leading, spacing: VSpace.md) {
            // Header
            HStack(spacing: VSpace.sm) {
                Text(emoji)
                    .font(.system(size: 20))
                VStack(alignment: .leading, spacing: 0) {
                    Text(name)
                        .font(VType.bodyLarge.weight(.semibold))
                        .foregroundStyle(RampStage.ink)
                    HStack(spacing: 0) {
                        Text(price)
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundStyle(RampStage.accentEdge)
                        Text(period)
                            .font(VType.caption)
                            .foregroundStyle(RampStage.textSecondary)
                    }
                }
                Spacer()
            }

            Divider()
                .padding(.vertical, VSpace.sm)

            // Items
            VStack(alignment: .leading, spacing: VSpace.sm) {
                ForEach(items, id: \.self) { item in
                    HStack(spacing: VSpace.sm) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(RampStage.accentEdge)
                        Text(item)
                            .font(VType.bodySmall)
                            .foregroundStyle(RampStage.ink)
                        Spacer()
                    }
                }
            }
        }
        .padding(VSpace.md)
        .background(highlight ? RampStage.accentSoft : RampStage.hair.opacity(0.02))
        .borderOrOutline(highlight: highlight)
        .cornerRadius(16)
        .opacity(tiersVisible[index] ? 1 : 0)
        .offset(y: tiersVisible[index] ? 0 : 12)
    }

    private func choreograph() async {
        if reduceMotion {
            tiersVisible = [true, true, true]
            return
        }

        let staggerDelay: UInt64 = 120
        for (index, _) in tiersVisible.enumerated() {
            try? await Task.sleep(for: .milliseconds(staggerDelay * UInt64(index)))
            guard !Task.isCancelled else { return }
            withAnimation(.easeOut(duration: 0.5)) {
                tiersVisible[index] = true
            }
        }
    }
}

// MARK: — Helper extensions

extension View {
    fileprivate func borderOrOutline(highlight: Bool) -> some View {
        if highlight {
            return AnyView(
                self.overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(RampStage.accentEdge, lineWidth: 2)
                )
            )
        } else {
            return AnyView(self)
        }
    }
}

extension Color {
    fileprivate init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        let rgb = Int(hex, radix: 16) ?? 0
        let r = Double((rgb >> 16) & 0xFF) / 255.0
        let g = Double((rgb >> 8) & 0xFF) / 255.0
        let b = Double(rgb & 0xFF) / 255.0
        self.init(red: r, green: g, blue: b)
    }
}
