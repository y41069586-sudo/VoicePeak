import SwiftUI
import UIKit

/// The story-sized "Verified Half-Face Reveal" card, rendered on-device to an
/// image. Credible by construction: the capture was standardized + timestamped,
/// so this shows a real, provable result — never a fabricated glow-up.
struct VerifiedShareCard: View {
    let productName: String
    let treatedSide: FaceSide
    let focus: SkinAttribute
    let treatedImprovement: Double   // positive = better
    let controlImprovement: Double
    let image: UIImage?
    let date: Date

    /// Fixed story aspect (9:16). Rendered at scale 3 → 1080×1920.
    static let size = CGSize(width: 360, height: 640)

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(hex: 0xF4F8FF), Color(hex: 0xE3ECFF)],
                           startPoint: .top, endPoint: .bottom)

            VStack(spacing: 18) {
                header
                faceSplit
                verdictBlock
                footer
            }
            .padding(22)
        }
        .frame(width: Self.size.width, height: Self.size.height)
    }

    private var header: some View {
        HStack(alignment: .center) {
            Text(Brand.name)
                .font(Typography.display(30))
                .foregroundStyle(Theme.textPrimary)
            Spacer()
            HStack(spacing: 6) {
                Image(systemName: "checkmark.seal.fill").foregroundStyle(Theme.success)
                VStack(alignment: .leading, spacing: 0) {
                    Text("share.verified").font(.caption.weight(.bold)).foregroundStyle(Theme.textPrimary)
                    Text("share.verified.sub").font(.system(size: 8)).foregroundStyle(Theme.textSecondary)
                }
            }
            .padding(.horizontal, 10).padding(.vertical, 6)
            .background(Theme.bgSurface, in: Capsule())
            .overlay(Capsule().strokeBorder(Theme.success.opacity(0.4), lineWidth: 1))
        }
    }

    private var faceSplit: some View {
        ZStack {
            if let image {
                Image(uiImage: image).resizable().scaledToFill()
            } else {
                Rectangle().fill(Theme.bgElevated)
                    .overlay(Image(systemName: "face.smiling").font(.largeTitle).foregroundStyle(Theme.textSecondary))
            }
            Rectangle().fill(.white.opacity(0.75)).frame(width: 2)
            VStack {
                Spacer()
                HStack {
                    sideLabel(treatedSide == .left ? "halfface.treated" : "halfface.control")
                    Spacer()
                    sideLabel(treatedSide == .left ? "halfface.control" : "halfface.treated")
                }
                .padding(10)
            }
        }
        .frame(height: 300)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(Theme.strokeSubtle, lineWidth: 1))
    }

    private func sideLabel(_ key: LocalizedStringKey) -> some View {
        Text(key)
            .font(.caption2.weight(.bold))
            .foregroundStyle(.white)
            .padding(.horizontal, 8).padding(.vertical, 4)
            .background(.black.opacity(0.45), in: Capsule())
    }

    private var verdictBlock: some View {
        VStack(spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: "checkmark.seal.fill").foregroundStyle(Theme.success)
                Text("halfface.verdict.works")
                    .font(Typography.display(22)).foregroundStyle(Theme.textPrimary)
            }
            Text(focus.localizationKey)
                .font(.caption.weight(.semibold)).foregroundStyle(Theme.textSecondary)
            bar(titleKey: "halfface.treated", value: treatedImprovement, color: Theme.success)
            bar(titleKey: "halfface.control", value: controlImprovement, color: Theme.textSecondary)
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .background(Theme.bgSurface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(Theme.strokeSubtle, lineWidth: 1))
    }

    private func bar(titleKey: LocalizedStringKey, value: Double, color: Color) -> some View {
        HStack(spacing: 10) {
            Text(titleKey).font(.caption).foregroundStyle(Theme.textSecondary).frame(width: 64, alignment: .leading)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Theme.strokeSubtle.opacity(0.5))
                    Capsule().fill(color).frame(width: geo.size.width * max(0, min(1, value / 0.4)))
                }
            }
            .frame(height: 8)
            Text(value.formatted(.percent.precision(.fractionLength(0))))
                .font(.caption.weight(.bold).monospacedDigit())
                .foregroundStyle(color == Theme.success ? Theme.success : Theme.textSecondary)
                .frame(width: 40, alignment: .trailing)
        }
    }

    private var footer: some View {
        VStack(spacing: 4) {
            Text(verbatim: productName)
                .font(.footnote.weight(.semibold)).foregroundStyle(Theme.textPrimary)
            Text("share.card.footer")
                .font(.caption2).foregroundStyle(Theme.textSecondary)
            Text(verbatim: date.formatted(date: .abbreviated, time: .omitted))
                .font(.system(size: 9)).foregroundStyle(Theme.textSecondary)
        }
    }
}
