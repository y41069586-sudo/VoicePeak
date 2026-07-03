import Foundation

enum TestVerdict { case pending, works, noDifference }

/// One attribute's change on one side, vs *that side's* own Day-0 baseline.
struct SideChange: Identifiable {
    let attribute: SkinAttribute
    let baseline: Double
    let current: Double
    var id: String { attribute.rawValue }
    /// Positive = the skin got better (accounts for hydration being higher-is-better).
    var improvement: Double { attribute.lowerIsBetter ? (baseline - current) : (current - baseline) }
}

struct TestProgress {
    let rounds: Int
    let focus: SkinAttribute
    let treatedChanges: [SkinAttribute: SideChange]
    let controlChanges: [SkinAttribute: SideChange]
    let netEffect: Double        // treated improvement − control improvement, on the focus attribute
    let confidence: Double
    let verdict: TestVerdict

    var treatedFocus: SideChange? { treatedChanges[focus] }
    var controlFocus: SideChange? { controlChanges[focus] }
    var passed: Bool { verdict == .works }
}

/// Scores a half-face test. **Validity rule:** each side is compared to its own
/// Day-0 baseline; the verdict is the *difference* between the treated side's
/// improvement and the control side's — never a raw left-vs-right comparison.
enum HalfFaceTestScoring {
    static let minRounds = 3
    static let significance = 0.05

    static func testScans(_ test: HalfFaceTest, in scans: [Scan]) -> [Scan] {
        scans.filter { $0.testID == test.id }
    }

    static func sideScans(_ test: HalfFaceTest, side: FaceSide, in scans: [Scan]) -> [Scan] {
        testScans(test, in: scans).filter { $0.side == side }.sorted { $0.date < $1.date }
    }

    static func rounds(_ test: HalfFaceTest, in scans: [Scan]) -> Int {
        min(sideScans(test, side: test.testSide, in: scans).count,
            sideScans(test, side: test.controlSide, in: scans).count)
    }

    static func progress(for test: HalfFaceTest, scans: [Scan], product: Product?, context: SkinContext?) -> TestProgress {
        let treated = sideScans(test, side: test.testSide, in: scans)
        let control = sideScans(test, side: test.controlSide, in: scans)
        let rounds = min(treated.count, control.count)
        let focus = product.map { focusAttribute(product: $0, context: context) } ?? .redness

        let treatedChanges = changes(baseline: treated.first, latest: treated.last)
        let controlChanges = changes(baseline: control.first, latest: control.last)

        let net = (treatedChanges[focus]?.improvement ?? 0) - (controlChanges[focus]?.improvement ?? 0)

        let all = treated + control
        let avgQuality = all.isEmpty ? 0 : all.map(\.captureQuality).reduce(0, +) / Double(all.count)
        let confidence = AnalysisConfidence.value(captureQuality: avgQuality, scanCount: rounds)

        let verdict: TestVerdict
        if rounds < minRounds || confidence < AnalysisConfidence.significanceThreshold {
            verdict = .pending
        } else if net >= significance {
            verdict = .works
        } else {
            verdict = .noDifference
        }

        return TestProgress(rounds: rounds, focus: focus,
                            treatedChanges: treatedChanges, controlChanges: controlChanges,
                            netEffect: net, confidence: confidence, verdict: verdict)
    }

    private static func changes(baseline: Scan?, latest: Scan?) -> [SkinAttribute: SideChange] {
        guard let baseline, let latest else { return [:] }
        var result: [SkinAttribute: SideChange] = [:]
        for attribute in SkinAttribute.allCases {
            if let b = baseline.score(for: attribute), let c = latest.score(for: attribute) {
                result[attribute] = SideChange(attribute: attribute, baseline: b, current: c)
            }
        }
        return result
    }

    /// The attribute the test is judged on: what the product targets, preferring a
    /// concern the user actually has.
    static func focusAttribute(product: Product, context: SkinContext?) -> SkinAttribute {
        let profile = IngredientEngine.profile(for: product)
        var targeted = Set<SkinConcern>()
        for ingredient in profile.actives {
            let key = IngredientKnowledgeBase.normalizeKey(ingredient.name)
            if let helps = MatchEngine.activeBenefits[key] { targeted.formUnion(helps) }
        }
        let userConcerns = context?.concerns ?? []
        let concern = targeted.first(where: { userConcerns.contains($0) }) ?? targeted.first ?? userConcerns.first
        return attribute(for: concern)
    }

    static func attribute(for concern: SkinConcern?) -> SkinAttribute {
        switch concern {
        case .redness: return .redness
        case .sensitivity: return .sensitivity
        case .acne, .hyperpigmentation: return .blemishes
        case .texture, .aging: return .texture
        case .pores: return .pores
        case .oiliness: return .oiliness
        case .dryness, .dullness: return .hydration
        case .none: return .redness
        }
    }
}
