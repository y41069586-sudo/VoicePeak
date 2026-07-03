import SwiftUI

/// The AR alignment guide drawn over the live preview: a face oval that turns
/// from cyan to green when framing is standardized, a focus vignette, and a live
/// guidance capsule. Purely decorative for touch — capture controls sit above it.
struct AlignmentGuideOverlay: View {
    let quality: CaptureQuality
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var ringColor: Color { quality.isStandardized ? Theme.success : Theme.accent }

    var body: some View {
        GeometryReader { geo in
            let ovalWidth = geo.size.width * 0.70
            let ovalHeight = geo.size.height * 0.46

            ZStack {
                // Focus vignette (darkens the edges, draws the eye to the face).
                RadialGradient(
                    colors: [.clear, Theme.bgBase.opacity(0.55)],
                    center: .center,
                    startRadius: ovalWidth * 0.35,
                    endRadius: geo.size.height * 0.62
                )
                .ignoresSafeArea()

                // Face oval.
                TimelineView(.animation(paused: reduceMotion || !quality.isStandardized)) { timeline in
                    let pulse = pulseScale(at: timeline.date)
                    Ellipse()
                        .stroke(ringColor, style: StrokeStyle(lineWidth: 3, dash: quality.faceDetected ? [] : [10, 8]))
                        .frame(width: ovalWidth, height: ovalHeight)
                        .scaleEffect(pulse)
                        .shadow(color: ringColor.opacity(0.6), radius: 16)
                        .position(x: geo.size.width / 2, y: geo.size.height * 0.44)
                }

                // Guidance capsule near the top.
                VStack {
                    guidanceCapsule
                        .padding(.top, 12)
                    Spacer()
                }
            }
        }
        .allowsHitTesting(false)
    }

    private var guidanceCapsule: some View {
        HStack(spacing: 7) {
            Image(systemName: quality.isStandardized ? "checkmark.circle.fill" : "viewfinder")
                .font(.subheadline)
            Text(quality.guidanceKey)
                .font(.subheadline.weight(.semibold))
        }
        .foregroundStyle(quality.isStandardized ? Theme.success : Theme.textPrimary)
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay(Capsule().strokeBorder(ringColor.opacity(0.4), lineWidth: 1))
    }

    private func pulseScale(at date: Date) -> CGFloat {
        guard !reduceMotion, quality.isStandardized else { return 1 }
        let t = date.timeIntervalSinceReferenceDate
        return 1 + 0.02 * CGFloat(sin(t * 2.4))
    }
}

/// A pass/fail chip for one standardization gate (distance, lighting).
struct GateChip: View {
    let titleKey: LocalizedStringKey
    let ok: Bool
    let systemImage: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: ok ? "checkmark.circle.fill" : systemImage)
            Text(titleKey)
        }
        .font(.footnote.weight(.semibold))
        .foregroundStyle(ok ? Theme.success : Theme.textSecondary)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay(Capsule().strokeBorder((ok ? Theme.success : Theme.strokeSubtle).opacity(0.5), lineWidth: 1))
    }
}
