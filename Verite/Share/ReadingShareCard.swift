import SwiftUI

/// The shareable "Vérité Reading" — a story-sized (9:16) porcelain card with
/// the overall score in serif, all seven metrics, and a verified-scan seal.
/// This is the app's viral artifact: the same editorial layout the user first
/// saw as an illustration in onboarding, now filled with THEIR real result.
/// Rendered fully on-device (ImageRenderer); nothing leaves the phone unless
/// the user explicitly shares it.
struct ReadingShareCard: View {
    let analysis: DermiqAnalysis
    let date: Date
    /// Optional first name from the profile ("ANNA'S READING").
    var displayName: String? = nil

    /// Fixed story aspect (9:16). Rendered at scale 3 → 1080×1920.
    static let size = CGSize(width: 360, height: 640)

    var body: some View {
        ZStack {
            // The Lumière dawn field, simplified for a static render.
            RampStage.porcelain
            RadialGradient(colors: [RampStage.dawnPeach.opacity(0.9), .clear],
                           center: UnitPoint(x: 0.2, y: 0.05), startRadius: 0, endRadius: 320)
            RadialGradient(colors: [RampStage.dawnLilac.opacity(0.9), .clear],
                           center: UnitPoint(x: 0.9, y: 0.25), startRadius: 0, endRadius: 300)
            RadialGradient(colors: [RampStage.dawnSky.opacity(0.9), .clear],
                           center: UnitPoint(x: 0.5, y: 1.05), startRadius: 0, endRadius: 380)

            VStack(spacing: 0) {
                header
                Spacer()
                scoreBlock
                Spacer()
                metricList
                Spacer()
                seal
            }
            .padding(28)
        }
        .frame(width: Self.size.width, height: Self.size.height)
    }

    private var header: some View {
        VStack(spacing: 6) {
            Text(verbatim: "VÉRITÉ")
                .font(VType.micro).tracking(6)
                .foregroundStyle(RampStage.accentDeep)
            Text(verbatim: displayName.map { "\($0.uppercased())'S READING" } ?? "SKIN READING")
                .font(VType.micro).tracking(3)
                .foregroundStyle(RampStage.textTertiary)
        }
    }

    private var scoreBlock: some View {
        VStack(spacing: 4) {
            Text(verbatim: "\(analysis.overall)")
                .font(RampStage.serif(110))
                .foregroundStyle(RampStage.ink)
            Text(verbatim: "/ 100 · HONEST SCORE")
                .font(VType.micro).tracking(3)
                .foregroundStyle(RampStage.textSecondary)
        }
    }

    private var metricList: some View {
        VStack(spacing: 12) {
            ForEach(analysis.subScores) { score in
                HStack(spacing: 12) {
                    Text(score.category.displayName)
                        .font(VType.caption)
                        .foregroundStyle(RampStage.textSecondary)
                        .frame(width: 84, alignment: .leading)
                    ZStack(alignment: .leading) {
                        Capsule().fill(RampStage.hair.opacity(0.55))
                        Capsule()
                            .fill(RampStage.accent)
                            .frame(width: 160 * CGFloat(score.value) / 100)
                    }
                    .frame(width: 160, height: 5)
                    Text(verbatim: "\(score.value)")
                        .font(VType.captionBold)
                        .foregroundStyle(RampStage.accentDeep)
                        .monospacedDigit()
                        .frame(width: 28, alignment: .trailing)
                }
            }
        }
        .padding(20)
        .background(Color.white.opacity(0.62), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(RampStage.hairline, lineWidth: 1)
        )
    }

    private var seal: some View {
        VStack(spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(RampStage.accentDeep)
                Text(verbatim: "VERIFIED SCAN · NO FILTER")
                    .font(VType.micro).tracking(2)
                    .foregroundStyle(RampStage.textSecondary)
            }
            Text(date.formatted(date: .abbreviated, time: .omitted))
                .font(VType.micro)
                .foregroundStyle(RampStage.textTertiary)
        }
    }
}
