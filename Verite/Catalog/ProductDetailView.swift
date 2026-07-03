import SwiftUI

/// Full ingredient breakdown for one product (§5.5). Leads with an honest
/// heads-up when there's real risk, then key actives, then the classified INCI
/// list with plain-language explanations. The skin-match verdict arrives in M5.
struct ProductDetailView: View {
    let product: Product

    private var profile: ProductProfile { IngredientEngine.profile(for: product) }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                header
                if profile.isEmpty {
                    emptyIngredients
                } else {
                    riskSummary
                    if !profile.actives.isEmpty { activesCard }
                    ingredientList
                }
                DisclaimerBanner(style: .short)
                Text("product.matchFooter")
                    .font(.footnote)
                    .foregroundStyle(Theme.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.top, 2)
            }
            .padding(20)
        }
        .scrollIndicators(.hidden)
        .navigationTitle(Text(verbatim: product.name))
        .navigationBarTitleDisplayMode(.inline)
        .background(GradientMeshBackground())
    }

    // MARK: Header

    private var header: some View {
        GlassCard {
            HStack(spacing: 14) {
                RemoteImage(urlString: product.imageURLString) {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Theme.bgElevated)
                        .overlay(Image(systemName: "sparkles").foregroundStyle(Theme.textSecondary))
                }
                .frame(width: 72, height: 72)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                VStack(alignment: .leading, spacing: 4) {
                    if !product.brand.isEmpty {
                        Text(verbatim: product.brand)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Theme.textSecondary)
                    }
                    Text(verbatim: product.name)
                        .font(.headline)
                        .foregroundStyle(Theme.textPrimary)
                    PillTag(titleKey: product.source.localizationKey, tone: .neutral)
                        .padding(.top, 2)
                }
                Spacer(minLength: 0)
            }
        }
    }

    // MARK: Risk-first summary

    private var riskSummary: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 10) {
                if profile.riskFlags.isEmpty {
                    Label("product.risk.none", systemImage: "checkmark.shield")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.success)
                } else {
                    Label("product.section.risk", systemImage: "exclamationmark.triangle")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.warning)
                    Text("product.risk.intro")
                        .font(.footnote)
                        .foregroundStyle(Theme.textSecondary)
                    FlowFlags(flags: profile.riskFlags)
                }
            }
        }
    }

    private var activesCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 8) {
                Text("product.section.actives")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.textSecondary)
                ForEach(profile.actives) { ingredient in
                    Text(verbatim: ingredient.name)
                        .font(.subheadline)
                        .foregroundStyle(Theme.textPrimary)
                }
            }
        }
    }

    private var ingredientList: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 14) {
                Text("product.section.ingredients")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.textSecondary)
                ForEach(profile.ingredients) { ingredient in
                    IngredientRow(ingredient: ingredient)
                }
                if profile.hasUnknowns {
                    Text("product.ingredients.unknownNote")
                        .font(.caption2)
                        .foregroundStyle(Theme.textSecondary)
                }
            }
        }
    }

    private var emptyIngredients: some View {
        GlassCard {
            Text("product.ingredients.none")
                .font(.subheadline)
                .foregroundStyle(Theme.textSecondary)
        }
    }
}

/// One classified ingredient: name, class chips, plain-language explanation.
private struct IngredientRow: View {
    let ingredient: ClassifiedIngredient

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Text(verbatim: ingredient.name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.textPrimary)
                Spacer(minLength: 4)
                if let comedogenic = ingredient.comedogenic, comedogenic >= 3 {
                    Text(verbatim: "\(comedogenic)/5")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(Theme.warning)
                }
            }
            if ingredient.isKnown {
                FlowFlags(flags: ingredient.classes)
                Text(ingredient.explanationKey)
                    .font(.caption)
                    .foregroundStyle(Theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Text("product.ingredient.unknown")
                    .font(.caption)
                    .foregroundStyle(Theme.textSecondary)
            }
        }
        .padding(.vertical, 2)
    }
}

/// Wrapping row of class chips (uses each class's semantic tone).
private struct FlowFlags: View {
    let flags: [IngredientClass]

    var body: some View {
        FlexWrap(spacing: 6, lineSpacing: 6) {
            ForEach(flags, id: \.self) { flag in
                PillTag(titleKey: flag.localizationKey, tone: flag.tone)
            }
        }
    }
}
