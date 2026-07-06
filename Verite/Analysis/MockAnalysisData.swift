import SwiftUI

struct MockAttributeDisplay: Identifiable, Sendable {
    let id: SkinAttribute
    let label: String
    let adjective: String
    let value: Double // 0...1
    let iconName: String
}

struct MockRecommendation: Identifiable, Sendable {
    let id = UUID()
    let title: String
    let description: String
    let icon: String
    let cta: String?
}

struct MockHeatmapRegion: Identifiable, Sendable {
    let id: FaceRegion
    let name: String
    let value: Double // 0...1
    let statusLabel: String
    let color: Color
}

struct MockSkinSnapshot: Sendable {
    let score: Int
    let headline: String
    let keyInsight: String
    let attributes: [MockAttributeDisplay]
    let recommendations: [MockRecommendation]
    let heatmapRegions: [MockHeatmapRegion]

    static func generate(from analysis: ScanAnalysis) -> MockSkinSnapshot {
        // Fallback checks
        let hydration = analysis.attributes[.hydration] ?? 0.65
        let redness = analysis.attributes[.redness] ?? 0.28
        let sensitivity = analysis.attributes[.sensitivity] ?? 0.24
        let texture = analysis.attributes[.texture] ?? 0.32
        let pores = analysis.attributes[.pores] ?? 0.35
        let blemishes = analysis.attributes[.blemishes] ?? 0.18
        let oiliness = analysis.attributes[.oiliness] ?? 0.45

        // Derived skin score calculation: hydration positive, others negative
        let scoreFloat = (hydration +
                          (1.0 - redness) +
                          (1.0 - sensitivity) +
                          (1.0 - texture) +
                          (1.0 - blemishes)) / 5.0
        let finalScore = Int((scoreFloat * 40.0 + 55.0).clamped(45.0, 98.0)) // maps to a realistic premium range (55-98)

        // Adjectives for each attribute
        let hydrationAdj = hydration < 0.35 ? "Dry" : (hydration < 0.70 ? "Balanced" : "Dewy")
        let rednessAdj = redness < 0.25 ? "Calm" : (redness < 0.60 ? "Mild" : "Elevated")
        let sensitivityAdj = sensitivity < 0.30 ? "Resilient" : (sensitivity < 0.65 ? "Mild" : "Reactive")
        let textureAdj = texture < 0.30 ? "Smooth" : (texture < 0.65 ? "Moderate" : "Rough")
        let oilinessAdj = oiliness < 0.30 ? "Matte" : (oiliness < 0.70 ? "Balanced" : "Oily")

        // Deriving Barrier adjective from hydration and sensitivity
        let barrierVal = (hydration + (1.0 - sensitivity)) / 2.0
        let barrierAdj = barrierVal > 0.72 ? "Strong" : (barrierVal > 0.45 ? "Moderate" : "Compromised")

        let displays: [MockAttributeDisplay] = [
            MockAttributeDisplay(id: .hydration, label: "Hydration", adjective: hydrationAdj, value: hydration, iconName: "drop.fill"),
            MockAttributeDisplay(id: .redness, label: "Redness", adjective: rednessAdj, value: redness, iconName: "face.dashed.fill"),
            MockAttributeDisplay(id: .texture, label: "Texture", adjective: textureAdj, value: texture, iconName: "square.grid.3x3.fill"),
            MockAttributeDisplay(id: .sensitivity, label: "Sensitivity", adjective: sensitivityAdj, value: sensitivity, iconName: "shield.fill"),
            MockAttributeDisplay(id: .oiliness, label: "Oiliness", adjective: oilinessAdj, value: oiliness, iconName: "sun.max.fill"),
            MockAttributeDisplay(id: .blemishes, label: "Barrier", adjective: barrierAdj, value: barrierVal, iconName: "waveform.path.ecg")
        ]

        // 1-sentence key insight based on the weakest metric
        var insight = "Your skin barrier is resilient today. Focus on protecting hydration levels."
        if hydration < 0.40 {
            insight = "Trans-epidermal water loss is elevated. Prioritize hydration and lock it in with an emollient cream."
        } else if redness > 0.50 {
            insight = "Localized irritation is detected. Focus on soothing botanicals and avoid active acids tonight."
        } else if barrierVal < 0.50 {
            insight = "Your skin barrier shows signs of stress. Use a lipid-replenishing ceramide complex."
        } else if sensitivity > 0.50 {
            insight = "Mild micro-inflammation present. Keep your routine simple and wash with tepid water."
        } else if oiliness > 0.70 {
            insight = "Sebum activity is elevated. Balance with niacinamide and a lightweight gel hydrator."
        }

        // Headline
        var headline = "Skin is balanced."
        if redness > 0.50 || sensitivity > 0.50 {
            headline = "Sensitized & reactive."
        } else if hydration < 0.40 {
            headline = "Needs deep hydration."
        } else if barrierVal > 0.75 {
            headline = "Healthy & resilient."
        }

        // Recommendations
        var recs: [MockRecommendation] = []
        if hydration < 0.45 {
            recs.append(MockRecommendation(title: "Hydrating Serum", description: "Apply a multi-molecular hyaluronic acid to damp skin to boost core hydration.", icon: "drop.triangle.fill", cta: "Add to routine"))
        }
        if redness > 0.35 || sensitivity > 0.35 {
            recs.append(MockRecommendation(title: "Soothing Relief", description: "Use a Centella or heartleaf extract fluid to calm active capillary flushing.", icon: "leaf.fill", cta: "Add to routine"))
        }
        if barrierVal < 0.60 {
            recs.append(MockRecommendation(title: "Barrier Restoration", description: "Use a rich cream containing ceramides, cholesterol, and fatty acids to rebuild lipids.", icon: "sparkles", cta: "Add to routine"))
        }
        if recs.isEmpty {
            recs.append(MockRecommendation(title: "Daily Defense", description: "Keep protecting your barrier with a mineral broad-spectrum sunscreen.", icon: "sun.max.fill", cta: nil))
        }

        // Heatmap region analysis mapping
        let heatmapRegions: [MockHeatmapRegion] = FaceRegion.allCases.map { region in
            let regionData = analysis.regions[region.rawValue]
            // Map regional data to value 0...1
            let val: Double
            switch region {
            case .forehead:
                val = regionData?.texture ?? 0.30
            case .leftCheek, .rightCheek:
                val = regionData?.redness ?? 0.25
            case .nose:
                val = regionData?.shine ?? 0.40
            case .chin:
                val = regionData?.spots ?? 0.20
            }

            let status: String
            let color: Color
            if val < 0.30 {
                status = "Calm"
                color = Theme.success
            } else if val < 0.65 {
                status = "Moderate"
                color = Theme.warning
            } else {
                status = "Attention"
                color = Theme.danger
            }

            let displayName: String
            switch region {
            case .forehead: displayName = "Forehead Zone"
            case .leftCheek: displayName = "Left Cheek"
            case .rightCheek: displayName = "Right Cheek"
            case .nose: displayName = "Nose & T-Zone"
            case .chin: displayName = "Chin & Jawline"
            }

            return MockHeatmapRegion(id: region, name: displayName, value: val, statusLabel: status, color: color)
        }

        return MockSkinSnapshot(
            score: finalScore,
            headline: headline,
            keyInsight: insight,
            attributes: displays,
            recommendations: recs,
            heatmapRegions: heatmapRegions
        )
    }
}

extension Double {
    fileprivate func clamped(_ minVal: Double, _ maxVal: Double) -> Double {
        return Swift.max(minVal, Swift.min(maxVal, self))
    }
}
