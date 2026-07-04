import SwiftUI

/// Segmented progress indicator (DESIGN_SPEC §6.9): one segment per step,
/// completed = heroGradient, current = strokeBright, upcoming = strokeSubtle.
struct OnboardingProgressBar: View {
    let current: Int   // 1-based current step
    let total: Int

    var body: some View {
        HStack(spacing: VSpace.xs) {
            ForEach(0..<max(total, 1), id: \.self) { index in
                Capsule()
                    .fill(style(for: index))
                    .frame(height: 3)
            }
        }
        .animation(VMotion.standard, value: current)
        .accessibilityElement()
        .accessibilityLabel("onboarding.progress")
        .accessibilityValue(Text(verbatim: "\(current)/\(total)"))
    }

    private func style(for index: Int) -> AnyShapeStyle {
        if index < current - 1 { return AnyShapeStyle(VColor.heroGradient) } // completed
        if index == current - 1 { return AnyShapeStyle(VColor.strokeBright) } // current
        return AnyShapeStyle(VColor.strokeSubtle)                            // upcoming
    }
}

/// A tappable selection card (single- or multi-select) with a selected state.
struct OnboardingSelectCard: View {
    let titleKey: LocalizedStringKey
    var systemImage: String? = nil
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button {
            Haptics.fire(.selection)
            action()
        } label: {
            HStack(spacing: 12) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .foregroundStyle(selected ? Theme.primary : Theme.textSecondary)
                        .frame(width: 26)
                }
                Text(titleKey)
                    .font(.headline)
                    .foregroundStyle(Theme.textPrimary)
                Spacer(minLength: 8)
                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(selected ? Theme.primary : Theme.strokeSubtle)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(selected ? Theme.primary : Theme.strokeSubtle, lineWidth: selected ? 2 : 1)
            )
        }
        .buttonStyle(PressableStyle())
    }
}

/// Multi/single-select chip (A5/A6 wrapping grids). Fills with the signature
/// gradient when selected.
struct ChoiceChip: View {
    let titleKey: LocalizedStringKey
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button {
            Haptics.fire(.selection)
            action()
        } label: {
            HStack(spacing: 6) {
                if selected { Image(systemName: "checkmark").font(.caption2.weight(.bold)) }
                Text(titleKey).font(VType.bodyMedium)
            }
            .foregroundStyle(selected ? .white : VColor.textPrimary)
            .padding(.horizontal, VSpace.md)
            .padding(.vertical, 10)
            .background(selected ? AnyShapeStyle(VColor.heroGradient) : AnyShapeStyle(VColor.bgSurface), in: Capsule())
            .overlay(Capsule().strokeBorder(selected ? Color.clear : VColor.strokeSubtle, lineWidth: 1))
        }
        .buttonStyle(PressableStyle())
        .animation(VMotion.snappy, value: selected)
    }
}

/// A "building your profile" status line that ticks to a checkmark on cue (A9).
struct BuildingStatusRow: View {
    let titleKey: LocalizedStringKey
    let done: Bool

    var body: some View {
        HStack(spacing: VSpace.sm) {
            ZStack {
                Circle().stroke(VColor.strokeSubtle, lineWidth: 2).frame(width: 22, height: 22)
                if done {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(VColor.success)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            Text(titleKey)
                .font(VType.body)
                .foregroundStyle(done ? VColor.textPrimary : VColor.textSecondary)
            Spacer()
        }
        .animation(VMotion.snappy, value: done)
    }
}

/// Wrapping flow layout for chip grids (A5/A6). Left-aligned rows that wrap when
/// the next chip would overflow the proposed width.
struct FlowLayout: Layout {
    var spacing: CGFloat = VSpace.sm

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, rowHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth && x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        return CGSize(width: maxWidth.isFinite ? maxWidth : x, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) {
        var x = bounds.minX, y = bounds.minY, rowHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX && x > bounds.minX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), anchor: .topLeading, proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

/// Standard layout for a quiz step: title + subtitle + content + Continue/Skip.
struct OnboardingScaffold<Content: View>: View {
    let titleKey: LocalizedStringKey
    var subtitleKey: LocalizedStringKey? = nil
    var progress: (current: Int, total: Int)? = nil
    var continueEnabled: Bool = true
    var onContinue: () -> Void
    var onSkip: (() -> Void)? = nil
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(spacing: 0) {
            if let progress {
                OnboardingProgressBar(current: progress.current, total: progress.total)
                    .padding(.horizontal, 24).padding(.top, 12)
            }
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(titleKey)
                            .font(Typography.display(30))
                            .foregroundStyle(Theme.textPrimary)
                        if let subtitleKey {
                            Text(subtitleKey)
                                .font(.subheadline)
                                .foregroundStyle(Theme.textSecondary)
                        }
                    }
                    .padding(.top, 20)
                    content()
                }
                .padding(24)
            }
            .scrollIndicators(.hidden)

            VStack(spacing: 6) {
                PrimaryButton(titleKey: "onboarding.continue", isEnabled: continueEnabled, action: onContinue)
                if let onSkip {
                    SecondaryButton(titleKey: "onboarding.skip", action: onSkip)
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 20)
        }
    }
}
