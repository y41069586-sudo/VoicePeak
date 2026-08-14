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
/// ASSETS. Each brand loads `logoAsset` through `RampPhoto.load` — drop
/// `BrandCeraVe.png` and friends into `Verite/Resources/Photos/`. Until a file
/// exists the row shows a monogram in OUR typeface on OUR ground, never an
/// approximation of the brand's own colour-and-lettering. Supply PNGs with a
/// transparent background at roughly 3x the 56x40pt box (≈168x120px); the box
/// fits them by aspect so wordmarks and discs both land correctly.
struct RampBrandScreen: View {
    @Binding var selected: Set<String>
    let onAdvance: () -> Void
    let onSkip: () -> Void

    @State private var query = ""

    struct Brand: Identifiable, Hashable {
        let id: String
        let name: String
        /// Filename in Resources/Photos, without extension.
        let logoAsset: String
        /// Fallback initials, shown until the logo file lands.
        let monogram: String
    }

    static let brands: [Brand] = [
        Brand(id: "cerave",        name: "CeraVe",         logoAsset: "BrandCeraVe",       monogram: "CV"),
        Brand(id: "larocheposay",  name: "La Roche-Posay", logoAsset: "BrandLaRochePosay", monogram: "LRP"),
        Brand(id: "theordinary",   name: "The Ordinary",   logoAsset: "BrandTheOrdinary",  monogram: "TO"),
        Brand(id: "cetaphil",      name: "Cetaphil",       logoAsset: "BrandCetaphil",     monogram: "CE"),
        Brand(id: "neutrogena",    name: "Neutrogena",     logoAsset: "BrandNeutrogena",   monogram: "NG"),
        Brand(id: "nivea",         name: "NIVEA",          logoAsset: "BrandNivea",        monogram: "NV"),
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
                    .frame(width: 56, height: 40)

                // Verbatim: proper names are never localised or restyled.
                Text(verbatim: brand.name)
                    .font(VType.bodyLarge.weight(.medium))
                    .foregroundStyle(RampStage.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)

                Spacer(minLength: 8)

                check(isOn)
            }
            .padding(.horizontal, 14)
            .frame(maxWidth: .infinity, minHeight: 66)
            .background(isOn ? RampStage.accentSoft : RampStage.card,
                        in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(isOn ? RampStage.accentEdge : RampStage.hairline,
                              lineWidth: isOn ? 1.5 : 1))
        }
        .buttonStyle(PressableStyle())
        .accessibilityAddTraits(isOn ? [.isButton, .isSelected] : .isButton)
    }

    private func check(_ isOn: Bool) -> some View {
        ZStack {
            Circle()
                .strokeBorder(isOn ? RampStage.accentEdge : RampStage.hair, lineWidth: 1.5)
                .frame(width: 22, height: 22)
            if isOn {
                Circle().fill(RampStage.accentEdge).frame(width: 22, height: 22)
                Image(systemName: "checkmark")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Color.white)
            }
        }
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
/// `scaledToFit` rather than fill, and a plain white box behind it: the logos
/// arrive at wildly different aspect ratios and most are drawn for white. This
/// gives each one the same room without cropping any of them, and without us
/// inventing a background colour for someone else's mark.
private struct RampBrandMark: View {
    let brand: RampBrandScreen.Brand

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.white)
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(RampStage.hairline, lineWidth: 1)

            #if canImport(UIKit)
            if let image = RampPhoto.load(brand.logoAsset) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .padding(6)
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
