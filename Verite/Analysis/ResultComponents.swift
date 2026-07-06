import SwiftUI

struct SkinScoreOrb: View {
    let score: Int
    @State private var drawAmount: Double = 0.0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            // Glow behind the orb
            Circle()
                .fill(Theme.accent.opacity(0.08))
                .frame(width: 140, height: 140)
                .blueGlow(Theme.accent, radius: 24, opacity: 0.3)

            Circle()
                .stroke(VColor.strokeSubtle, lineWidth: 6)
                .frame(width: 148, height: 148)

            Circle()
                .trim(from: 0.0, to: drawAmount)
                .stroke(
                    Theme.signature,
                    style: StrokeStyle(lineWidth: 6, lineCap: .round)
                )
                .frame(width: 148, height: 148)
                .rotationEffect(.degrees(-90))

            VStack(spacing: 0) {
                Text("\(score)")
                    .font(VType.hero(60))
                    .foregroundStyle(VColor.textPrimary)
                    .monospacedDigit()
                Text("skin score")
                    .vEyebrow()
                    .foregroundStyle(VColor.textTertiary)
            }
        }
        .onAppear {
            if reduceMotion {
                drawAmount = Double(score) / 100.0
            } else {
                withAnimation(.easeOut(duration: 1.1)) {
                    drawAmount = Double(score) / 100.0
                }
            }
        }
    }
}

struct SkinAttributeCard: View {
    let display: MockAttributeDisplay

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: display.iconName)
                    .foregroundStyle(Theme.primary)
                    .font(.footnote)
                Text(display.label)
                    .font(VType.body)
                    .foregroundStyle(VColor.textSecondary)
                Spacer()
                Text(display.adjective)
                    .font(VType.captionBold)
                    .foregroundStyle(VColor.textPrimary)
            }

            // Fill bar (thin horizontal line)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(VColor.bgElevated)
                    Capsule()
                        .fill(Theme.signature)
                        .frame(width: geo.size.width * CGFloat(display.value))
                }
            }
            .frame(height: 5)
        }
        .padding(14)
        .background(VColor.bgSurface)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(VColor.strokeSubtle, lineWidth: 1)
        )
    }
}

struct HeatmapOverlay: View {
    let regions: [MockHeatmapRegion]
    @State private var selectedRegion: MockHeatmapRegion?

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "sparkles")
                    .foregroundStyle(Theme.accent)
                Text("Regional Face Analysis")
                    .font(VType.title)
                    .foregroundStyle(VColor.textPrimary)
                Spacer()
            }

            ZStack {
                // Main Face shape background
                Ellipse()
                    .fill(VColor.bgElevated)
                    .frame(width: 180, height: 240)
                    .overlay(
                        Ellipse()
                            .stroke(VColor.strokeBright, lineWidth: 1.5)
                    )

                // Forehead zone (top arc/ellipse)
                Ellipse()
                    .fill(zoneColor(for: .forehead))
                    .frame(width: 130, height: 50)
                    .offset(y: -75)
                    .onTapGesture { selectRegion(.forehead) }

                // Nose zone (center thin pill)
                Capsule()
                    .fill(zoneColor(for: .nose))
                    .frame(width: 32, height: 75)
                    .offset(y: -10)
                    .onTapGesture { selectRegion(.nose) }

                // Left cheek (left circle)
                Circle()
                    .fill(zoneColor(for: .leftCheek))
                    .frame(width: 50, height: 50)
                    .offset(x: -50, y: 15)
                    .onTapGesture { selectRegion(.leftCheek) }

                // Right cheek (right circle)
                Circle()
                    .fill(zoneColor(for: .rightCheek))
                    .frame(width: 50, height: 50)
                    .offset(x: 50, y: 15)
                    .onTapGesture { selectRegion(.rightCheek) }

                // Chin zone (bottom circle)
                Circle()
                    .fill(zoneColor(for: .chin))
                    .frame(width: 45, height: 45)
                    .offset(y: 80)
                    .onTapGesture { selectRegion(.chin) }
            }
            .frame(height: 260)
            .padding(.vertical, 8)

            if let selectedRegion {
                RegionDetailBubble(region: selectedRegion) {
                    self.selectedRegion = nil
                }
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
            } else {
                Text("Tap any zone for a detailed regional reading")
                    .font(VType.caption)
                    .foregroundStyle(VColor.textTertiary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(16)
        .background(VColor.bgSurface)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(VColor.strokeSubtle, lineWidth: 1)
        )
    }

    private func zoneColor(for r: FaceRegion) -> RadialGradient {
        let color = regions.first(where: { $0.id == r })?.color ?? Theme.success
        return RadialGradient(
            colors: [color.opacity(0.40), color.opacity(0.04)],
            center: .center,
            startRadius: 0,
            endRadius: 40
        )
    }

    private func selectRegion(_ id: FaceRegion) {
        Haptics.fire(.selection)
        withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
            selectedRegion = regions.first(where: { $0.id == id })
        }
    }
}

struct RegionDetailBubble: View {
    let region: MockHeatmapRegion
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(region.color)
                .frame(width: 8, height: 8)

            VStack(alignment: .leading, spacing: 2) {
                Text(region.name)
                    .font(VType.bodyMedium.weight(.semibold))
                    .foregroundStyle(VColor.textPrimary)
                Text("Status: \(region.statusLabel)")
                    .font(VType.caption)
                    .foregroundStyle(VColor.textSecondary)
            }
            Spacer()

            Button(action: onDismiss) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(VColor.textTertiary)
                    .font(.title3)
            }
        }
        .padding(12)
        .background(VColor.bgElevated)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(VColor.strokeBright, lineWidth: 1)
        )
    }
}

struct RecommendationCard: View {
    let rec: MockRecommendation
    let onAdd: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: rec.icon)
                    .foregroundStyle(Theme.primary)
                    .font(.title3)
                    .padding(8)
                    .background(Theme.primary.opacity(0.1), in: Circle())

                VStack(alignment: .leading, spacing: 4) {
                    Text(rec.title)
                        .font(VType.bodyMedium.weight(.semibold))
                        .foregroundStyle(VColor.textPrimary)
                    Text(rec.description)
                        .font(VType.caption)
                        .foregroundStyle(VColor.textSecondary)
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            if let cta = rec.cta, let onAdd {
                Button(action: onAdd) {
                    HStack {
                        Spacer()
                        Text(cta)
                            .font(VType.captionBold)
                            .foregroundStyle(.white)
                        Image(systemName: "plus")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(.white)
                        Spacer()
                    }
                    .frame(height: 38)
                    .background(VColor.heroGradient, in: Capsule())
                }
                .buttonStyle(PressableStyle())
            }
        }
        .padding(14)
        .background(VColor.bgSurface)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(VColor.strokeSubtle, lineWidth: 1)
        )
    }
}

struct WhatChangedCard: View {
    let changes: [AttributeChange]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "arrow.up.right.and.arrow.down.left.rectangle")
                    .foregroundStyle(Theme.accent)
                Text("Changes Since Last Scan")
                    .font(VType.title)
                    .foregroundStyle(VColor.textPrimary)
            }

            if changes.isEmpty {
                Text("No significant changes recorded yet. Keep consistency up!")
                    .font(VType.body)
                    .foregroundStyle(VColor.textSecondary)
            } else {
                ForEach(changes) { change in
                    HStack {
                        Text(change.attribute.localizationKey)
                            .font(VType.body)
                            .foregroundStyle(VColor.textPrimary)
                        Spacer()
                        HStack(spacing: 4) {
                            Image(systemName: iconName(for: change))
                                .font(.caption2.weight(.bold))
                            Text(change.magnitude.formatted(.percent.precision(.fractionLength(0))))
                                .font(VType.bodyMedium)
                        }
                        .foregroundStyle(color(for: change))
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .padding(16)
        .background(VColor.bgSurface)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(VColor.strokeSubtle, lineWidth: 1)
        )
    }

    private func iconName(for change: AttributeChange) -> String {
        guard change.isMeaningful else { return "minus" }
        return change.delta < 0 ? "arrow.down" : "arrow.up"
    }

    private func color(for change: AttributeChange) -> Color {
        guard change.isMeaningful else { return VColor.textSecondary }
        return change.isImprovement ? Theme.success : Theme.danger
    }
}
