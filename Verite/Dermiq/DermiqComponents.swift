import SwiftUI

// ============================================================
// MARK: — Score ring gauge
// ============================================================

/// Ring gauge that fills to `progress` (0...1) with the accent gradient.
struct DQScoreRing: View {
    let progress: Double
    var lineWidth: CGFloat = 10

    var body: some View {
        ZStack {
            Circle()
                .stroke(DQColor.surfaceElevated, lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    AngularGradient(
                        colors: [DQColor.accent, DQColor.accentBright],
                        center: .center,
                        startAngle: .degrees(-90),
                        endAngle: .degrees(270)
                    ),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .shadow(color: DQColor.accent.opacity(0.5), radius: 8)
        }
    }
}

// ============================================================
// MARK: — Count-up score numeral
// ============================================================

/// Huge numeral that counts 0 → target on an ease-out curve with light haptic
/// ticks. Monospaced digits — zero layout jitter.
struct DQCountUpScore: View {
    let target: Int
    var size: CGFloat = 96
    var play: Bool = true
    var onFinished: (() -> Void)? = nil

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var value = 0

    var body: some View {
        // Before the count-up plays (e.g. under the paywall blur) the numeral
        // silhouette shows the real value — unreadable but the right shape.
        Text(verbatim: "\(play ? value : target)")
            .font(DQFont.score(size))
            .foregroundStyle(DQColor.textPrimary)
            .contentTransition(.numericText(value: Double(value)))
            .task(id: play) {
                guard play else { return }
                if reduceMotion {
                    value = target
                    onFinished?()
                    return
                }
                value = 0
                let total = max(target, 1)
                for current in 1...total {
                    guard !Task.isCancelled else { return }
                    // Ease-out: early increments fly, the last ones land slowly.
                    let progress = Double(current) / Double(total)
                    let delay = 8 + pow(progress, 3) * 55 // ms per step
                    try? await Task.sleep(for: .milliseconds(UInt64(delay)))
                    withAnimation(.linear(duration: 0.03)) { value = current }
                    if current % 7 == 0 || current == total {
                        Haptics.fire(.tick)
                    }
                }
                onFinished?()
            }
    }
}

// ============================================================
// MARK: — Sub-score card
// ============================================================

/// Compact category card: label, mono value, mini-bar (+ optional delta arrow).
struct DQSubScoreCard: View {
    let score: DermiqSubScore
    var delta: Int? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(score.category.displayName)
                    .font(DQFont.caption)
                    .foregroundStyle(DQColor.textSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Spacer(minLength: 4)
                if let delta, delta != 0 {
                    HStack(spacing: 2) {
                        Image(systemName: delta > 0 ? "arrow.up" : "arrow.down")
                            .font(.system(size: 9, weight: .bold))
                        Text(verbatim: "\(abs(delta))")
                            .font(DQFont.mono(11, weight: .semibold))
                    }
                    .foregroundStyle(delta > 0 ? DQColor.deltaUp : DQColor.deltaDown)
                }
            }
            Text(verbatim: "\(score.value)")
                .font(DQFont.mono(22, weight: .semibold))
                .foregroundStyle(DQColor.textPrimary)
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(DQColor.surfaceElevated)
                    Capsule()
                        .fill(DQColor.accentGradient)
                        .frame(width: proxy.size.width * Double(score.value) / 100)
                }
            }
            .frame(height: 4)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(DQColor.surface, in: RoundedRectangle(cornerRadius: DQRadius.card, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: DQRadius.card, style: .continuous)
                .strokeBorder(DQColor.stroke, lineWidth: 1)
        )
    }
}

// ============================================================
// MARK: — Day tile (14-day grid)
// ============================================================

struct DQDayTile: View {
    let day: Int
    let state: TileState
    var isRescanTile = false

    enum TileState { case completed, today, upcoming, missed }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(background)
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(state == .today ? DQColor.accent : DQColor.stroke,
                              lineWidth: state == .today ? 1.5 : 1)
            if isRescanTile && state != .completed {
                Image(systemName: "lock.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(state == .today ? DQColor.textPrimary : DQColor.textSecondary)
            } else if state == .completed {
                Image(systemName: "checkmark")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(DQColor.textPrimary)
            } else {
                Text(verbatim: "\(day)")
                    .font(DQFont.mono(13, weight: .semibold))
                    .foregroundStyle(state == .today ? DQColor.textPrimary : DQColor.textSecondary)
            }
        }
        .frame(height: 44)
        .animation(VMotion.snappy, value: state == .completed)
    }

    private var background: AnyShapeStyle {
        switch state {
        case .completed: return AnyShapeStyle(DQColor.accentGradient)
        case .today:     return AnyShapeStyle(DQColor.surfaceElevated)
        case .upcoming, .missed: return AnyShapeStyle(DQColor.surface)
        }
    }
}

// ============================================================
// MARK: — Scan portal (Screen 1 centerpiece)
// ============================================================

/// Circular scan portal: slowly rotating accent-gradient ring with a soft bloom.
struct DQScanPortal: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var rotating = false

    var body: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [DQColor.accent.opacity(0.16), .clear],
                        center: .center, startRadius: 10, endRadius: 130
                    )
                )
            Circle()
                .stroke(
                    AngularGradient(
                        colors: [DQColor.accent, DQColor.accentBright,
                                 DQColor.accent.opacity(0.15), DQColor.accent],
                        center: .center
                    ),
                    style: StrokeStyle(lineWidth: 3, lineCap: .round)
                )
                .rotationEffect(.degrees(rotating ? 360 : 0))
                .animation(
                    reduceMotion ? nil : .linear(duration: 9).repeatForever(autoreverses: false),
                    value: rotating
                )
                .padding(28)
            Circle()
                .stroke(DQColor.stroke, lineWidth: 1)
                .padding(46)
            Image(systemName: "faceid")
                .font(.system(size: 44, weight: .ultraLight))
                .foregroundStyle(DQColor.accentBright)
        }
        .onAppear { rotating = true }
    }
}

// ============================================================
// MARK: — Small shared bits
// ============================================================

/// Date + overall score chip for the scan-history strip.
struct DQHistoryChip: View {
    let date: Date
    let overall: Int

    var body: some View {
        VStack(spacing: 3) {
            Text(verbatim: "\(overall)")
                .font(DQFont.mono(17, weight: .semibold))
                .foregroundStyle(DQColor.textPrimary)
            Text(date, format: .dateTime.day().month(.abbreviated))
                .font(DQFont.micro)
                .foregroundStyle(DQColor.textSecondary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(DQColor.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(DQColor.stroke, lineWidth: 1)
        )
    }
}
