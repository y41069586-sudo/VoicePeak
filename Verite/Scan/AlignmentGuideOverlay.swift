import SwiftUI

/// The AR alignment guide drawn over the live preview: a face oval that turns
/// from cyan/indigo to signature gradient when framing is standardized, with a focus vignette
/// and a live guidance capsule.
struct AlignmentGuideOverlay: View {
    let quality: CaptureQuality
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var ringColor: Color {
        if quality.isStandardized {
            return Theme.success
        } else if quality.faceDetected {
            return Theme.primary
        } else {
            return Theme.accent
        }
    }

    var body: some View {
        GeometryReader { geo in
            let ovalWidth = geo.size.width * 0.70
            let ovalHeight = geo.size.height * 0.46

            ZStack {
                // Focus vignette (darkens the edges of the camera feed agressively).
                RadialGradient(
                    colors: [.clear, Color.black.opacity(0.72)],
                    center: .center,
                    startRadius: ovalWidth * 0.32,
                    endRadius: geo.size.height * 0.58
                )
                .ignoresSafeArea()

                // Face oval alignment rings
                TimelineView(.animation(paused: reduceMotion || !quality.isStandardized)) { timeline in
                    let pulse = pulseScale(at: timeline.date)
                    ZStack {
                        // Outer Halo Glow
                        Ellipse()
                            .stroke(ringColor, lineWidth: 8)
                            .blur(radius: 12)
                            .opacity(quality.isStandardized ? 0.65 : (quality.faceDetected ? 0.45 : 0.22))
                            .frame(width: ovalWidth, height: ovalHeight)

                        // Inner stroke ring
                        if quality.isStandardized {
                            Ellipse()
                                .stroke(Theme.signature, style: StrokeStyle(lineWidth: 3.5))
                                .frame(width: ovalWidth, height: ovalHeight)
                                .shadow(color: Theme.success.opacity(0.4), radius: 10)
                        } else {
                            Ellipse()
                                .stroke(ringColor, style: StrokeStyle(lineWidth: 2.5, dash: quality.faceDetected ? [] : [8, 6]))
                                .frame(width: ovalWidth, height: ovalHeight)
                                .shadow(color: ringColor.opacity(0.25), radius: 6)
                        }
                    }
                    .scaleEffect(pulse)
                    .position(x: geo.size.width / 2, y: geo.size.height * 0.44)
                }

                // Guidance capsule near the top.
                VStack {
                    guidanceCapsule
                        .padding(.top, 16)
                    Spacer()
                }

                // Emotional hint text at the lower-middle section (visible when no face detected)
                if !quality.faceDetected {
                    VStack {
                        Spacer()
                        Text("Natural light works best")
                            .font(VType.captionBold)
                            .foregroundStyle(.white.opacity(0.65))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 6)
                            .background(Color.black.opacity(0.3), in: Capsule())
                            .padding(.bottom, 120)
                    }
                }
            }
        }
        .allowsHitTesting(false)
    }

    private var guidanceCapsule: some View {
        HStack(spacing: 8) {
            Image(systemName: quality.isStandardized ? "checkmark.circle.fill" : "viewfinder")
                .font(.footnote)
                .foregroundStyle(quality.isStandardized ? Theme.success : Theme.accent)
            Text(quality.guidanceKey)
                .font(VType.bodyMedium.weight(.semibold))
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay(Capsule().strokeBorder(ringColor.opacity(0.4), lineWidth: 1))
    }

    private func pulseScale(at date: Date) -> CGFloat {
        guard !reduceMotion, quality.isStandardized else { return 1 }
        let t = date.timeIntervalSinceReferenceDate
        return 1 + 0.022 * CGFloat(sin(t * 2.5))
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
                .foregroundStyle(ok ? Theme.success : Theme.accent)
            Text(titleKey)
        }
        .font(VType.captionBold)
        .foregroundStyle(ok ? VColor.textPrimary : VColor.textSecondary)
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay(Capsule().strokeBorder((ok ? Theme.success : VColor.strokeSubtle).opacity(0.4), lineWidth: 1))
    }
}
