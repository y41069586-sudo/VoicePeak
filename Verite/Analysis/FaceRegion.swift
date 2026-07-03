import CoreGraphics

/// The face regions the analysis engine samples. Region rectangles are defined as
/// fractions of the detected face bounding box — a documented v1 heuristic that
/// deliberately avoids the eyes/brows. (Vision landmarks refine the left/right
/// midline used by the half-face test; see `SkinAnalysisCore`.)
enum FaceRegion: String, CaseIterable, Sendable {
    case forehead
    case leftCheek
    case rightCheek
    case nose
    case chin

    /// Which half of the face this region belongs to (for the half-face test).
    var half: FaceSide {
        switch self {
        case .leftCheek: return .left
        case .rightCheek: return .right
        default: return .full
        }
    }

    /// Fractional rect within the face box, top-left origin: (x0, y0, x1, y1).
    /// Tuned to sit on skin and skip the eye band (~0.30–0.42).
    var fractionalRect: (x0: Double, y0: Double, x1: Double, y1: Double) {
        switch self {
        case .forehead:   return (0.28, 0.06, 0.72, 0.22)
        case .leftCheek:  return (0.12, 0.44, 0.36, 0.68)
        case .rightCheek: return (0.64, 0.44, 0.88, 0.68)
        case .nose:       return (0.43, 0.32, 0.57, 0.60)
        case .chin:       return (0.36, 0.80, 0.64, 0.95)
        }
    }
}
