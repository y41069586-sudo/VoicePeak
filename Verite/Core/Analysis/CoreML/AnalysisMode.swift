import Foundation

/// Operating mode for skin analysis engine.
/// Allows runtime switching between heuristic, CoreML, and hybrid modes.
enum AnalysisMode: String, Codable, Sendable {
    /// Pure heuristic analysis (Phase 3A).
    case heuristic
    
    /// CoreML model inference only.
    case coreML
    
    /// Weighted fusion of heuristic and CoreML (default, recommended).
    case hybrid
}

/// Configuration for CoreML analysis.
struct CoreMLAnalysisConfig: Sendable {
    /// Current operating mode (default: .hybrid for CI safety).
    /// Hybrid mode runs heuristic baseline always, so app works with or without CoreML model.
    var mode: AnalysisMode = .hybrid

    /// Weight for CoreML predictions in hybrid mode (0–1).
    /// 1.0 = full ML, 0.0 = full heuristic.
    /// In CI without model, automatically falls back to full heuristic (0.0).
    var mlWeight: Float = 0.7

    /// Weight for heuristic fallback in hybrid mode (0–1).
    /// Auto-computed: fallbackWeight = 1.0 - mlWeight.
    var fallbackWeight: Float { 1.0 - mlWeight }

    /// Minimum confidence threshold for using ML prediction.
    /// Below this, fallback to heuristic.
    var confidenceThreshold: Float = 0.5

    /// Enable automatic fallback if model missing.
    /// Required for CI deployment (model is optional).
    var enableFallback: Bool = true

    /// Log inference metrics for debugging.
    var logMetrics: Bool = false
}
