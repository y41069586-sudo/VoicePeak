import SwiftUI

// ============================================================
// MARK: — What's already on your shelf
// ============================================================

/// Brand multi-select. The user picks the products they already own so the
/// routine can work with their shelf instead of asking them to rebuy it.
///
/// USE OF THE MARKS. The logos identify the brands and nothing else. This is
/// referential use: we are naming things the user owns, in a question about
/// the user. Three constraints follow from that, and they are the reason the
/// screen looks the way it does — do not undo them while editing:
///
///  1. Never frame the brands as partners, sponsors, featured or supported.
///     The heading asks what is on the USER's shelf; it makes no claim about
///     our business relationships, because there are none. Words to keep out
///     of this file: "Partners", "Featured brands", "Our brands", "Works
///     with", "Official".
///  2. Every brand gets the identical container — same tile, same box, same
///     spacing, our palette around it. Nothing is elevated, ordered by
///     prominence, or given a badge.
///  3. The disclaimer at the bottom stays, and the same line belongs in the
///     App Store description.
///
/// LAYOUT. A shelf list, not the circular grid this pattern usually gets.
/// Circles are the worst container for a wordmark — "LA ROCHE-POSAY" is five
/// times wider than it is tall and has to shrink to illegibility to fit one,
/// while "NIVEA" sits in a disc and looks native. A landscape box gives every
/// mark the same honest room, and a single column means a long name never
/// truncates.
///
/// The box is 84x44 because the marks demanded it. At 56x40 the two widest
/// wordmarks came out 9-10pt tall — Bioderma's "LABORATOIRE DERMATOLOGIQUE"
/// line rendered around 2pt, which is not small, it is absent. These lockups
/// are 5:1; a box narrow enough to feel tidy makes half of them unreadable.
///
/// ASSETS. Each brand loads `logoAsset` through `RampPhoto.load` — drop
/// `BrandCeraVe.png` and friends into `Verite/Resources/Photos/`. Until a file
/// exists the row shows a monogram in OUR typeface on OUR ground, never an
/// approximation of the brand's own colour-and-lettering. Transparent PNG at
/// roughly 3x the 56x40pt box (≈168x120px) is the safe format for this loose-
/// file path; the box fits by aspect, so wordmarks and discs both land.
///
/// Most of these marks are only published as SVG. Two ways round that, both
/// cheaper than running a converter: Wikimedia renders any SVG to PNG at a
/// width you name —
/// `commons.wikimedia.org/wiki/Special:FilePath/<File>.svg?width=512` — and
/// Xcode has accepted SVG directly in an ASSET CATALOG since Xcode 12 (Single
/// Scale + Preserve Vector Data, back to iOS 13). `RampPhoto.load` checks the
/// asset catalog first, so an SVG imported there wins over any loose file.
///
/// One asset choice is not cosmetic: for NIVEA, prefer the plain WORDMARK file
/// over the blue-disc lockup. Beiersdorf holds a registered abstract colour
/// mark on NIVEA blue (Pantone 280C) — Unilever's cancellation action failed,
/// BGH 9 July 2015, I ZB 65/13 "Nivea-Blau", and the mark still stands. The
/// wordmark engages one right; the disc engages two.
struct RampBrandScreen: View {
    @Binding var selected: Set<String>
    let onAdvance: () -> Void

    @State private var query = ""

    struct Brand: Identifiable, Hashable {
        let id: String
        let name: String
        /// Filename in Resources/Photos, without extension.
        let logoAsset: String
        /// Fallback initials, shown until the logo file lands.
        let monogram: String
        /// Per-mark nudge so twelve logos of wildly different proportions
        /// carry the same visual WEIGHT down the column.
        ///
        /// Fitting each file into one box is not enough. Bioderma is nearly
        /// 5:1 and NIVEA is square, so a shared box renders the disc three
        /// times taller than the wordmark and the rows stop looking like a
        /// set. Optical balance is about how much ink a mark puts on the
        /// page, which no automatic fit can measure — dense, compact marks
        /// want a value below 1, thin extended wordmarks above it.
        ///
        /// Measured against the real files rather than guessed: every
        /// wordmark here is 2.3:1 or wider, so all of them hit the WIDTH cap
        /// and their scale does nothing. Only a compact mark — the NIVEA disc
        /// is the one in this set — is height-limited, and that is where the
        /// value bites. So leave this at 1.0 for wordmarks; reach for it when
        /// a round or square mark reads too heavy. Nudge in steps of 0.05.
        var opticalScale: CGFloat = 1.0
    }

    static let brands: [Brand] = [
        Brand(id: "cerave",        name: "CeraVe",         logoAsset: "BrandCeraVe",       monogram: "CV"),
        Brand(id: "larocheposay",  name: "La Roche-Posay", logoAsset: "BrandLaRochePosay", monogram: "LRP"),
        Brand(id: "theordinary",   name: "The Ordinary",   logoAsset: "BrandTheOrdinary",  monogram: "TO"),
        Brand(id: "cetaphil",      name: "Cetaphil",       logoAsset: "BrandCetaphil",     monogram: "CE"),
        Brand(id: "neutrogena",    name: "Neutrogena",     logoAsset: "BrandNeutrogena",   monogram: "NG"),
        // The one compact mark in the set, so the only one the scale moves.
        // A filled disc reads heavier than type at equal size — 0.9 lands it
        // just under the wordmarks' cap height instead of matching it.
        Brand(id: "nivea",         name: "NIVEA",          logoAsset: "BrandNivea",        monogram: "NV",
              opticalScale: 0.90),
        Brand(id: "eucerin",       name: "Eucerin",        logoAsset: "BrandEucerin",      monogram: "EU"),
        Brand(id: "bioderma",      name: "Bioderma",       logoAsset: "BrandBioderma",     monogram: "BD"),
        Brand(id: "avene",         name: "Avène",          logoAsset: "BrandAvene",        monogram: "AV"),
        Brand(id: "vichy",         name: "Vichy",          logoAsset: "BrandVichy",        monogram: "VI"),
        Brand(id: "paulaschoice",  name: "Paula's Choice", logoAsset: "BrandPaulasChoice", monogram: "PC"),
        Brand(id: "cosrx",         name: "COSRX",          logoAsset: "BrandCosrx",        monogram: "CX"),
    ]

    private var matches: [Brand] {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return Self.brands }
        return Self.brands.filter { $0.name.localizedCaseInsensitiveContains(trimmed) }
    }

    var body: some View {
        GeometryReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    Spacer(minLength: RampStage.headerClearance)

                    Text("YOUR LIFE · FIVE OF SIX")
                        .font(VType.micro).tracking(3)
                        .foregroundStyle(RampStage.accentDeep)
                        .padding(.horizontal, VSpace.lg)
                        .padding(.bottom, VSpace.sm)

                    Text("What's already\non your shelf?")
                        .font(RampStage.serif(28))
                        .foregroundStyle(RampStage.ink)
                        .lineSpacing(2)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, VSpace.lg)

                    Text("Pick everything you use. Your plan is built around what you already own instead of asking you to rebuy it.")
                        .font(VType.body)
                        .foregroundStyle(RampStage.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, VSpace.lg)
                        .padding(.top, VSpace.xs)

                    searchField
                        .padding(.horizontal, VSpace.lg)
                        .padding(.top, VSpace.lg)

                    LazyVStack(spacing: 10) {
                        ForEach(matches) { brand in
                            row(brand)
                        }
                    }
                    .padding(.horizontal, VSpace.lg)
                    .padding(.top, VSpace.md)

                    if matches.isEmpty {
                        Text("No match — you can add it later in Settings.")
                            .font(VType.caption)
                            .foregroundStyle(RampStage.textSecondary)
                            .padding(.horizontal, VSpace.lg)
                            .padding(.top, VSpace.sm)
                    }

                    Text("Using something that isn't listed? Add it any time from Settings — your plan can reference far more than this.")
                        .font(VType.caption)
                        .foregroundStyle(RampStage.textTertiary)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, VSpace.lg)
                        .padding(.top, VSpace.md)

                    Spacer(minLength: VSpace.lg)

                    disclaimer
                        .padding(.horizontal, VSpace.lg)
                        .padding(.bottom, VSpace.md)

                    // Continue is never disabled here — picking nothing IS a
                    // valid answer ("none of these are on my shelf"), so a
                    // separate "I'm not sure" button used to sit below this
                    // one doing the exact same thing Continue already does
                    // with an empty selection. One control, one meaning.
                    RampPrimaryButton(title: "Continue") { onAdvance() }
                        .padding(.horizontal, VSpace.lg)

                    Spacer().frame(height: VSpace.xl)
                }
                .frame(minHeight: proxy.size.height, alignment: .leading)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
    }

    // MARK: Rows

    private func row(_ brand: Brand) -> some View {
        let isOn = selected.contains(brand.id)
        return Button {
            Haptics.fire(.selection)
            withAnimation(VMotion.snappy) {
                if isOn { selected.remove(brand.id) } else { selected.insert(brand.id) }
            }
        } label: {
            HStack(spacing: 14) {
                RampBrandMark(brand: brand)
                    .frame(width: 84, height: 44)

                // Verbatim: proper names are never localised or restyled.
                Text(verbatim: brand.name)
                    .font(VType.bodyLarge.weight(.semibold))
                    .foregroundStyle(RampStage.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)

                Spacer(minLength: 8)

                addTag(isOn)
            }
            .padding(.horizontal, 14)
            .frame(maxWidth: .infinity, minHeight: 66)
            // The card stays white in BOTH states — eleven of the twelve logo
            // files are opaque white plates, so a tinted card would frame
            // every one of them in a visible white rectangle. Selection is
            // the ring plus the "Added" tag, not a fill. (The unselected edge
            // is a hairline rather than a shadow, matching every other
            // answer tile in the flow — see `RampOptionCard`.)
            .background(RampStage.card, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(isOn ? RampStage.accentEdge : RampStage.hair,
                              lineWidth: isOn ? 2 : 1))
        }
        .buttonStyle(PressableStyle())
        .accessibilityAddTraits(isOn ? [.isButton, .isSelected] : .isButton)
    }

    private func addTag(_ isOn: Bool) -> some View {
        Text(isOn ? "Added" : "Add")
            .font(.system(size: 13, weight: .bold, design: .rounded))
            .foregroundStyle(isOn ? RampStage.accentDeep : RampStage.textTertiary)
            .padding(.horizontal, isOn ? 10 : 0)
            .padding(.vertical, isOn ? 5 : 0)
            .background(isOn ? RampStage.accentSoft : Color.clear,
                        in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private var disclaimer: some View {
        Text("SkinFix is not affiliated with, sponsored by or endorsed by any brand listed. Brand names and logos are shown only so you can identify the products you use, and remain the property of their respective owners.")
            .font(VType.micro)
            .foregroundStyle(RampStage.textTertiary)
            .fixedSize(horizontal: false, vertical: true)
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
}

// ============================================================
// MARK: — The mark itself
// ============================================================

/// The supplied logo, fitted inside a neutral box — or, until the file
/// exists, a monogram in our own type on our own ground.
///
/// `scaledToFit`, drawn straight onto the row with no plate or outline of its
/// own: the logos arrive at wildly different aspect ratios, and a fitted frame
/// gives each the same room without cropping any of them or inventing a
/// background colour for someone else's mark.
///
/// Eleven of the twelve files are opaque white-background assets rather than
/// cut-outs, and they are left that way on purpose. Against a white row they
/// are indistinguishable from cut-outs, and keying dark type off white leaves
/// halos on the anti-aliased edges — worse than the plate it removes.
///
/// The condition that buys: THE ROW MUST STAY WHITE IN EVERY STATE. That is
/// why selection is a border and a check rather than a tint. Fill the card and
/// eleven logos frame themselves in white rectangles. A design that wants a
/// coloured card has to cut the assets out first, not the other way round.
private struct RampBrandMark: View {
    let brand: RampBrandScreen.Brand

    var body: some View {
        ZStack {
            #if canImport(UIKit)
            if let image = RampPhoto.load(brand.logoAsset) {
                // Capped on BOTH axes, with height the tighter of the two.
                // Fitting to the box alone would let a square mark stand 28pt
                // tall beside a 9pt wordmark; holding height near the cap
                // pulls every row onto the same optical line.
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: 72 * brand.opticalScale,
                           maxHeight: 32 * brand.opticalScale)
            } else {
                monogram
            }
            #else
            monogram
            #endif
        }
        // The name is already read out by the row; the mark is decoration.
        .accessibilityHidden(true)
    }

    private var monogram: some View {
        Text(verbatim: brand.monogram)
            .font(.system(size: 15, weight: .bold, design: .rounded))
            .foregroundStyle(RampStage.accentDeep)
            .minimumScaleFactor(0.7)
            .lineLimit(1)
            .padding(.horizontal, 4)
    }
}
