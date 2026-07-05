import Foundation

/// Weighting model for regional skin analysis aggregation.
/// Used to compute per-attribute scores from regional measurements.
struct RegionWeighting: Sendable {
    /// Weight for forehead region.
    let forehead: Float
    
    /// Weight for left cheek region.
    let leftCheek: Float
    
    /// Weight for right cheek region.
    let rightCheek: Float
    
    /// Weight for chin region.
    let chin: Float
    
    // MARK: - Initialization
    
    init(
        forehead: Float = 0.2,
        leftCheek: Float = 0.3,
        rightCheek: Float = 0.3,
        chin: Float = 0.2
    ) {
        precondition((forehead + leftCheek + rightCheek + chin).isAlmostEqual(to: 1.0, tolerance: 0.001),
                     "Region weights must sum to 1.0")
        
        self.forehead = forehead
        self.leftCheek = leftCheek
        self.rightCheek = rightCheek
        self.chin = chin
    }
    
    /// Get weight for a specific region.
    func weight(for region: FaceRegion) -> Float {
        switch region {
        case .forehead:
            return forehead
        case .leftCheek:
            return leftCheek
        case .rightCheek:
            return rightCheek
        case .chin:
            return chin
        case .bridge:
            return 0  // Not used in standard weighting
        }
    }
    
    /// Aggregate regional scores using these weights.
    func aggregate(_ values: [FaceRegion: Float]) -> Float {
        var sum: Float = 0
        
        for region in [FaceRegion.forehead, .leftCheek, .rightCheek, .chin] {
            if let value = values[region] {
                sum += value * weight(for: region)
            }
        }
        
        return sum
    }
    
    // MARK: - Standard Presets
    
    /// Default weighting: cheeks emphasized (3 parts), forehead and chin balanced (2 parts each).
    static let `default` = RegionWeighting(
        forehead: 0.2,
        leftCheek: 0.3,
        rightCheek: 0.3,
        chin: 0.2
    )
    
    /// Cheek-focused: higher weight on cheeks for acne/oiliness analysis.
    static let cheekFocused = RegionWeighting(
        forehead: 0.15,
        leftCheek: 0.35,
        rightCheek: 0.35,
        chin: 0.15
    )
    
    /// Balanced: equal weight across all regions.
    static let balanced = RegionWeighting(
        forehead: 0.25,
        leftCheek: 0.25,
        rightCheek: 0.25,
        chin: 0.25
    )
    
    /// T-zone focused: forehead and chin emphasized.
    static let tZoneFocused = RegionWeighting(
        forehead: 0.35,
        leftCheek: 0.15,
        rightCheek: 0.15,
        chin: 0.35
    )
}

// MARK: - Float Extension

extension Float {
    fileprivate func isAlmostEqual(to other: Float, tolerance: Float) -> Bool {
        abs(self - other) <= tolerance
    }
}
