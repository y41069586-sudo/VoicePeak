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
    /// Current operating mode.
    var mode: AnalysisMode = .hybrid
    
    /// Weight for CoreML predictions in hybrid mode (0–1).
    /// 1.0 = full ML, 0.0 = full heuristic.
    var mlWeight: Float = 0.7
    
    /// Weight for heuristic fallback in hybrid mode (0–1).
    /// Auto-computed: fallbackWeight = 1.0 - mlWeight.
    var fallbackWeight: Float { 1.0 - mlWeight }
    
    /// Minimum confidence threshold for using ML prediction.
    /// Below this, fallback to heuristic.
    var confidenceThreshold: Float = 0.5
    
    /// Enable automatic fallback if model missing.
    var enableFallback: Bool = true
    
    /// Log inference metrics for debugging.
    var logMetrics: Bool = false
}
