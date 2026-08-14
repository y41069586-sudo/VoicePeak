import SwiftUI

// ============================================================
// MARK: — What's already on your shelf
// ============================================================

/// Brand multi-select, as TEXT chips in our own typeface — never logos.
///
/// The app this screen was benchmarked against shows a grid of brand logos.
/// We deliberately do not, and the reason is a German case with exactly this
/// fact pattern: BGH I ZR 33/10 ("GROSSE INSPEKTION FÜR ALLE"), where an
/// independent garage was allowed to use the VW WORD mark to say what it
/// serviced, and forbidden from using the VW LOGO — because the word mark
/// conveyed the same information, so the logo was more than was *necessary*.
/// §23 MarkenG and Art. 14 EUTMR both hang on that necessity, and a naked
/// logo grid is also the standard visual grammar of a partners page, which
/// is the "impression of a commercial connection" Gillette (C-228/03) calls
/// dishonest practice. Apple resolves complaints under guideline 5.2.1 by
/// asking for written authorisation from the rights holder; we would have
/// none. Naming a brand is fine. Wearing its logo is not.
///
/// Three rules for anyone editing this screen:
///
///  1. Text only, one uniform tile style, OUR palette and typeface. Do not
///     reconstruct a brand's colour-and-lettering combination — that
///     approximates the figurative mark, and some of those colours (Nivea
///     blue) are separately protected.
///  2. Never the words "Partners", "Featured brands", "Our brands". The
///     question is about the user's bathroom shelf, not about our business
///     relationships — and the heading is what decides which of those a
///     reader sees.
///  3. The disclaimer at the bottom stays.
///
/// The text version is also the better product. Eight logos silently cap the
/// perceived catalogue at eight; a search field over the full list and a
/// "+ N more" line says "we have everything you own", which is the thing the
/// screen is actually selling.
struct RampBrandScreen: View {
    @Binding var selected: Set<String>
    let onAdvance: () -> Void
    let onSkip: () -> Void

    @State private var query = ""

    /// Names only — a plain factual reference to products the user may own.
    /// Ordered by how likely they are to be recognised on a drugstore shelf.
    static let brands: [String] = [
        "CeraVe", "La Roche-Posay", "The Ordinary", "Cetaphil",
        "Neutrogena", "Nivea", "Eucerin", "Bioderma",
        "Avène", "Vichy", "Paula's Choice", "Garnier",
        "Balea", "Sebamed", "Weleda", "Dr. Hauschka",
        "Kiehl's", "Clinique", "Differin", "Benzac",
        "Skin1004", "COSRX", "Beauty of Joseon", "Some By Mi",
    ]

    private var matches: [String] {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return Self.brands }
        return Self.brands.filter { $0.localizedCaseInsensitiveContains(trimmed) }
    }

    var body: some View {
        GeometryReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    Spacer(minLength: VSpace.xxl)

                    Text("YOUR LIFE · FOUR OF FOUR")
                        .font(VType.micro).tracking(3)
                        .foregroundStyle(RampStage.accentDeep)
                        .padding(.horizontal, VSpace.lg)
                        .padding(.bottom, VSpace.sm)

                    Text("What's already\non your shelf?")
                        .font(RampStage.serif(25))
                        .foregroundStyle(RampStage.ink)
                        .lineSpacing(2)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, VSpace.lg)

                    Text("So your plan works with what you own instead of asking you to rebuy it.")
                        .font(VType.body)
                        .foregroundStyle(RampStage.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, VSpace.lg)
                        .padding(.top, VSpace.xs)

                    searchField
                        .padding(.horizontal, VSpace.lg)
                        .padding(.top, VSpace.lg)

                    chips
                        .padding(.horizontal, VSpace.lg)
                        .padding(.top, VSpace.md)

                    if matches.isEmpty {
                        Text("No match — you can add it later in Settings.")
                            .font(VType.caption)
                            .foregroundStyle(RampStage.textSecondary)
                            .padding(.horizontal, VSpace.lg)
                            .padding(.top, VSpace.sm)
                    }

                    // Says "we have everything you own" far better than a wall
                    // of logos, which caps the perceived catalogue at its size.
                    Text("Your plan can reference thousands more — this is just the quick list.")
                        .font(VType.caption)
                        .foregroundStyle(RampStage.textTertiary)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, VSpace.lg)
                        .padding(.top, VSpace.md)

                    Spacer(minLength: VSpace.xl)

                    Text("Not affiliated with, sponsored by or endorsed by any brand shown. All trademarks are the property of their respective owners.")
                        .font(VType.micro)
                        .foregroundStyle(RampStage.textTertiary)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, VSpace.lg)
                        .padding(.bottom, VSpace.md)

                    RampPrimaryButton(title: "Continue") { onAdvance() }
                        .padding(.horizontal, VSpace.lg)

                    Button {
                        Haptics.fire(.selection)
                        onSkip()
                    } label: {
                        Text("I'm not sure")
                            .font(VType.body)
                            .foregroundStyle(RampStage.textSecondary)
                            .frame(maxWidth: .infinity, minHeight: 44)
                            .contentShape(Rectangle())
                    }
                    .padding(.top, VSpace.xs)

                    Spacer().frame(height: VSpace.xl)
                }
                .frame(minHeight: proxy.size.height, alignment: .leading)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
    }

    private var searchField: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(RampStage.textSecondary)
            TextField("Search brands", text: $query)
                .font(VType.bodyLarge)
                .foregroundStyle(RampStage.ink)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.words)
            if !query.isEmpty {
                Button {
                    query = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 15))
                        .foregroundStyle(RampStage.textTertiary)
                }
                .accessibilityLabel("Clear search")
            }
        }
        .padding(.horizontal, 16)
        .frame(height: 50)
        .background(RampStage.card, in: Capsule())
        .overlay(Capsule().strokeBorder(RampStage.hairline, lineWidth: 1))
    }

    /// A flowing wrap — chips size to their own text, which a LazyVGrid cannot
    /// do. `Layout` handles it without measuring hacks.
    private var chips: some View {
        RampFlowLayout(spacing: 8, lineSpacing: 8) {
            ForEach(matches, id: \.self) { brand in
                chip(brand)
            }
        }
    }

    private func chip(_ brand: String) -> some View {
        let isOn = selected.contains(brand)
        return Button {
            Haptics.fire(.selection)
            withAnimation(VMotion.snappy) {
                if isOn { selected.remove(brand) } else { selected.insert(brand) }
            }
        } label: {
            HStack(spacing: 6) {
                if isOn {
                    Image(systemName: "checkmark")
                        .font(.system(size: 11, weight: .bold))
                }
                // Verbatim: these are proper names, never localised.
                Text(verbatim: brand)
                    .font(VType.bodyLarge.weight(.medium))
            }
            .foregroundStyle(isOn ? RampStage.accentDeep : RampStage.ink)
            .padding(.horizontal, 16)
            .frame(height: 44)
            .background(isOn ? RampStage.accentSoft : RampStage.card, in: Capsule())
            .overlay(Capsule().strokeBorder(isOn ? RampStage.accentEdge : RampStage.hairline,
                                            lineWidth: isOn ? 1.5 : 1))
        }
        .buttonStyle(PressableStyle())
    }
}

// ============================================================
// MARK: — Flow layout
// ============================================================

/// Left-aligned wrapping row layout. Chips are as wide as their own text, so
/// a grid with fixed columns would leave ragged gaps around short names like
/// "Nivea" next to long ones like "Beauty of Joseon".
struct RampFlowLayout: Layout {
    var spacing: CGFloat = 8
    var lineSpacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, lineHeight: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x > 0, x + size.width > maxWidth {
                x = 0
                y += lineHeight + lineSpacing
                lineHeight = 0
            }
            x += size.width + spacing
            lineHeight = max(lineHeight, size.height)
        }
        return CGSize(width: maxWidth == .infinity ? x : maxWidth, height: y + lineHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize,
                       subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, lineHeight: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x > bounds.minX, x + size.width > bounds.maxX {
                x = bounds.minX
                y += lineHeight + lineSpacing
                lineHeight = 0
            }
            view.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            lineHeight = max(lineHeight, size.height)
        }
    }
}
