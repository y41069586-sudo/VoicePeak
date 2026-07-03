import SwiftUI
import UIKit

/// Shown right after a capture. Honest by construction:
/// • baseline → your Day-0 estimates, labeled as a starting point;
/// • follow-up → change vs your own baseline, but only as a *verdict* once
///   confidence clears the threshold; otherwise a "not enough data yet" state;
/// • no face → a kind retry, nothing saved.
struct ScanResultView: View {
    let image: UIImage?
    let analysis: ScanAnalysis
    let isBaseline: Bool
    let captureQuality: Double
    let scans: [Scan]
    let onDone: () -> Void

    private var confidence: Double { BaselineTracker.confidence(scans) }
    private var reliable: Bool { BaselineTracker.hasReliableVerdict(scans) }
    private var isFollowUp: Bool {
        !isBaseline && BaselineTracker.fullScans(scans).count >= AnalysisConfidence.minScansForChange
    }

    var body: some View {
        ZStack {
            GradientMeshBackground()
            VStack(spacing: 0) {
                ScrollView {
                    VStack(spacing: 16) {
                        header
                        if !analysis.faceFound {
                            noFaceCard
                        } else if isFollowUp {
                            if reliable { changeCard } else { notEnoughCard }
                            ConfidenceMeter(value: confidence)
                            readingsCard(title: "result.readings")
                        } else {
                            baselineCard
                            readingsCard(title: "result.readings")
                        }
                        DisclaimerBanner(style: .short)
                    }
                    .padding(20)
                }
                .scrollIndicators(.hidden)

                PrimaryButton(titleKey: "common.done", action: onDone)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
            }
        }
    }

    // MARK: Header

    private var header: some View {
        VStack(spacing: 14) {
            if let image {
                Image(uiImage: image)
                    .resizable().scaledToFill()
                    .frame(width: 130, height: 165)
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(Theme.strokeSubtle, lineWidth: 1))
                    .blueGlow(Theme.accent, radius: 20, opacity: 0.3)
            }
            Image(systemName: analysis.faceFound ? "checkmark.seal.fill" : "exclamationmark.triangle.fill")
                .font(.title2)
                .foregroundStyle(analysis.faceFound ? Theme.success : Theme.warning)
            Text(titleKey)
                .font(Typography.display(26))
                .foregroundStyle(Theme.textPrimary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 12)
    }

    private var titleKey: LocalizedStringKey {
        if !analysis.faceFound { return "result.noFace.title" }
        if isBaseline { return "scan.captured.baseline" }
        return isFollowUp && reliable ? "result.title.change" : "scan.captured.saved"
    }

    // MARK: Cards

    private var baselineCard: some View {
        GlassCard {
            Text("result.baselineNote")
                .font(.subheadline)
                .foregroundStyle(Theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var changeCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("result.title.change")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.textSecondary)
                ForEach(BaselineTracker.changes(scans)) { change in
                    AttributeChangeRow(change: change)
                }
            }
        }
    }

    private var notEnoughCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: "hourglass")
                    Text("result.notEnough.title").font(.headline)
                }
                .foregroundStyle(Theme.textPrimary)
                Text("result.notEnough.body")
                    .font(.subheadline)
                    .foregroundStyle(Theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var noFaceCard: some View {
        GlassCard {
            Text("result.noFace.body")
                .font(.subheadline)
                .foregroundStyle(Theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func readingsCard(title: LocalizedStringKey) -> some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.textSecondary)
                ForEach(SkinAttribute.allCases) { attribute in
                    ScoreBar(labelKey: attribute.localizationKey,
                             value: analysis.attributes[attribute] ?? 0,
                             tone: .info)
                }
                Text("result.estimatesNote")
                    .font(.caption2)
                    .foregroundStyle(Theme.textSecondary)
            }
        }
    }
}

/// One attribute's change: name + directional magnitude, color-coded for honesty
/// (green = improvement, red = regression, grey = little change).
struct AttributeChangeRow: View {
    let change: AttributeChange

    var body: some View {
        HStack {
            Text(change.attribute.localizationKey)
                .font(.subheadline)
                .foregroundStyle(Theme.textPrimary)
            Spacer()
            HStack(spacing: 4) {
                Image(systemName: iconName).font(.caption2.weight(.bold))
                Text(change.magnitude.formatted(.percent.precision(.fractionLength(0))))
                    .font(Typography.number(14))
            }
            .foregroundStyle(color)
        }
        .accessibilityElement(children: .combine)
    }

    private var iconName: String {
        guard change.isMeaningful else { return "minus" }
        return change.delta < 0 ? "arrow.down" : "arrow.up"
    }

    private var color: Color {
        guard change.isMeaningful else { return Theme.textSecondary }
        return change.isImprovement ? Theme.success : Theme.danger
    }
}

/// Confidence bar with an honest caption when the read isn't trustworthy yet.
struct ConfidenceMeter: View {
    let value: Double

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 8) {
                ScoreBar(labelKey: "result.confidence",
                         value: value,
                         tone: value >= AnalysisConfidence.significanceThreshold ? .success : .warning)
                if value < AnalysisConfidence.significanceThreshold {
                    Text("result.confidence.low")
                        .font(.caption2)
                        .foregroundStyle(Theme.textSecondary)
                }
            }
        }
    }
}
