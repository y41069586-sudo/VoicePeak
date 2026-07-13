import SwiftUI
import UIKit

// ============================================================
// MARK: — Results share card v2 (mirrors the live results screen)
// ============================================================
//
// What the user shares should look like what they SAW: their photo over the
// blue metric grid — Overall as the lead cell, all seven sub-scores, the
// 14-day potential line. Replaces the old porcelain "Reading" card.

struct DermiqShareCard: View {
    let analysis: DermiqAnalysis
    let photo: UIImage?
    var displayName: String? = nil

    /// Story aspect (9:16), rendered at scale 3 → 1080×1920.
    static let size = CGSize(width: 360, height: 640)

    private var projection: DermiqProjection.Projected { DermiqProjection.project(analysis) }

    var body: some View {
        ZStack {
            DQColor.background
            // Soft brand glow top-left, like the app's home.
            RadialGradient(colors: [DQColor.accentSoft.opacity(0.9), .clear],
                           center: UnitPoint(x: 0.15, y: 0.02), startRadius: 0, endRadius: 300)

            VStack(spacing: 0) {
                header
                    .padding(.top, 26)

                avatar
                    .padding(.top, 18)
                    .zIndex(1)

                grid
                    .padding(.horizontal, 22)
                    .padding(.top, -46)   // photo straddles the card, like on-screen

                potentialLine
                    .padding(.top, 12)

                Spacer(minLength: 0)

                footer
                    .padding(.bottom, 24)
            }
        }
        .frame(width: Self.size.width, height: Self.size.height)
    }

    // MARK: Pieces

    private var header: some View {
        VStack(spacing: 4) {
            Text(verbatim: Brand.name.uppercased())
                .font(DQFont.mono(11, weight: .semibold)).tracking(5)
                .foregroundStyle(DQColor.accentBright)
            Text(verbatim: displayName.map { "\($0.uppercased())'S SKIN ANALYSIS" } ?? "SKIN ANALYSIS")
                .font(DQFont.mono(9, weight: .semibold)).tracking(2.5)
                .foregroundStyle(DQColor.textSecondary)
        }
    }

    private var avatar: some View {
        Group {
            if let photo {
                Image(uiImage: photo).resizable().scaledToFill()
            } else {
                ZStack {
                    Circle().fill(DQColor.accentSoft)
                    Image(systemName: "faceid")
                        .font(.system(size: 30, weight: .light))
                        .foregroundStyle(DQColor.accentBright)
                }
            }
        }
        .frame(width: 108, height: 108)
        .clipShape(Circle())
        .overlay(Circle().strokeBorder(DQColor.surface, lineWidth: 4))
        .overlay(Circle().strokeBorder(DQColor.accentSoft, lineWidth: 4).padding(-4))
        .shadow(color: DQColor.accent.opacity(0.28), radius: 12, y: 6)
    }

    private var grid: some View {
        VStack(spacing: 10) {
            Spacer().frame(height: 52)   // room for the straddling avatar

            // Overall — the lead cell, full width.
            HStack(alignment: .firstTextBaseline) {
                Text("OVERALL")
                    .font(DQFont.mono(10, weight: .semibold)).tracking(2)
                    .foregroundStyle(DQColor.textSecondary)
                Spacer()
                Text(verbatim: "\(analysis.overall)")
                    .font(.system(size: 40, weight: .heavy, design: .rounded).monospacedDigit())
                    .foregroundStyle(DQColor.accentBright)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(DQColor.accentSoft.opacity(0.55),
                        in: RoundedRectangle(cornerRadius: 14, style: .continuous))

            // Seven sub-scores, two columns.
            let columns = [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)]
            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(analysis.subScores) { sub in
                    HStack {
                        Text(LocalizedStringKey(sub.category.displayName))
                            .font(.system(size: 11.5, weight: .semibold, design: .rounded))
                            .foregroundStyle(DQColor.textSecondary)
                            .lineLimit(1)
                        Spacer(minLength: 4)
                        Text(verbatim: "\(sub.value)")
                            .font(.system(size: 19, weight: .heavy, design: .rounded).monospacedDigit())
                            .foregroundStyle(DQColor.textPrimary)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 9)
                    .background(DQColor.surfaceElevated.opacity(0.8),
                                in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
            }
        }
        .padding(14)
        .background(DQColor.surface, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(DQColor.stroke, lineWidth: 1)
        )
        .shadow(color: DQColor.accent.opacity(0.10), radius: 16, y: 8)
    }

    private var potentialLine: some View {
        HStack(spacing: 6) {
            Image(systemName: "sparkles")
                .font(.system(size: 11, weight: .semibold))
            Text(verbatim: "14-day potential · \(projection.overall)")
                .font(.system(size: 13, weight: .bold, design: .rounded).monospacedDigit())
            Image(systemName: "arrow.up.right")
                .font(.system(size: 10, weight: .heavy))
        }
        .foregroundStyle(DQColor.accentBright)
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(DQColor.surface, in: Capsule())
        .overlay(Capsule().strokeBorder(DQColor.accentSoft, lineWidth: 1.5))
    }

    private var footer: some View {
        VStack(spacing: 3) {
            Text(verbatim: Brand.name)
                .font(.system(size: 15, weight: .heavy, design: .rounded))
                .foregroundStyle(DQColor.textPrimary)
            Text("Scan yours. 14 days to your potential.")
                .font(DQFont.micro)
                .foregroundStyle(DQColor.textSecondary)
        }
    }
}
