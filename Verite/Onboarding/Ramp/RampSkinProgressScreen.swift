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

    /// The two states, as photographs rather than icons.
    ///
    /// Icons were the first draft and they argued nothing: a sparkle beside a
    /// tick is a claim written in symbols, and the reader has to take it on
    /// trust. Real macro skin — inflamed on the left, calm on the right — is
    /// the same claim made in the only evidence that counts on a screen about
    /// skin. Circles rather than squares so the crop reads as a sample of skin
    /// rather than a before/after ad, and big enough that the texture is
    /// legible at arm's length; at 80pt the lesions were mush.
    private var transformationCard: some View {
        VStack(spacing: 0) {
            HStack(spacing: VSpace.md) {
                progressState(photo: "ProgressBefore",
                              label: "Before",
                              ringed: false)

                Image(systemName: "arrow.right")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(RampStage.accentEdge)
                    // The labels sit under the circles, so centring the arrow
                    // on the whole stack would float it low. Nudged up onto
                    // the circles' own centre line.
                    .padding(.bottom, 22)

                progressState(photo: "ProgressAfter",
                              label: "After",
                              ringed: true)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, VSpace.xs)

            Divider()
                .padding(.vertical, VSpace.md)

            // Key message
            VStack(alignment: .center, spacing: VSpace.xs) {
                Text("Most people see improvement in 2–3 weeks.")
                    .font(VType.body)
                    .foregroundStyle(RampStage.ink)
                    .multilineTextAlignment(.center)
                    .lineLimit(nil)

                Text("Some by day five.")
                    .font(VType.bodyLarge.weight(.semibold))
                    .foregroundStyle(RampStage.accentEdge)
            }
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.bottom, VSpace.sm)
        }
        .padding(VSpace.md)
        .background(RampStage.accentSoft)
        .cornerRadius(16)
        .accessibilityElement()
        .accessibilityLabel("Before and after: inflamed skin on the left, calm skin on the right.")
    }

    /// One circle plus its caption. `ringed` marks the outcome side with an
    /// accent ring — the only styling difference between the two, so the eye
    /// knows which way the arrow points without reading the labels.
    private func progressState(photo: String, label: String, ringed: Bool) -> some View {
        VStack(spacing: VSpace.sm) {
            skinCircle(photo)
                .frame(width: Self.circleSize, height: Self.circleSize)
                .clipShape(Circle())
                .overlay {
                    Circle()
                        .strokeBorder(ringed ? RampStage.accentEdge : Color.white.opacity(0.75),
                                      lineWidth: ringed ? 2.5 : 2)
                }
                .shadow(color: RampStage.ink.opacity(0.12), radius: 10, y: 4)

            Text(LocalizedStringKey(label))
                .font(VType.caption)
                .foregroundStyle(RampStage.textTertiary)
        }
    }

    /// The photo if it shipped, a quiet gradient if it did not — the screen
    /// must never show tofu or an empty ring just because an asset is missing.
    @ViewBuilder
    private func skinCircle(_ name: String) -> some View {
        #if canImport(UIKit)
        if let image = RampPhoto.load(name) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
        } else {
            RampStage.accent
        }
        #else
        RampStage.accent
        #endif
    }

    /// 124, not 80. The photographs are macro crops — at 80pt the individual
    /// lesions blurred into a pink wash and the two circles read as two
    /// swatches of colour rather than as two states of skin.
    private static let circleSize: CGFloat = 124

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
