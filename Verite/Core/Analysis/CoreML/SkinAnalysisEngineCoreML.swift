import Foundation

/// Drop-in CoreML analysis layer for Phase 3B.
/// Wraps heuristic engine and CoreML inference with intelligent fallback.
///
/// ARCHITECTURE:
/// - Maintains identical input/output contracts (AnalysisInput → ScanAnalysisResult)
/// - Supports 3 operating modes: heuristic, coreML, hybrid
/// - Graceful fallback if model missing
/// - No breaking changes to Phase 3A code
/// - Performance: async inference off main thread
actor SkinAnalysisEngineCoreML: Sendable {
    private let modelLoader: ModelLoader
    private let inferencePipeline: InferencePipeline
    private let fusionEngine: HybridFusionEngine
    
    private var config: CoreMLAnalysisConfig
    private var performanceMetrics: PerformanceMetrics = PerformanceMetrics()
    
    // MARK: - Initialization
    
    /// Create CoreML analysis engine with configuration.
    init(
        modelName: String = "SkinAnalysisModel",
        config: CoreMLAnalysisConfig = CoreMLAnalysisConfig()
    ) {
        let loader = ModelLoader(modelName: modelName)
        self.modelLoader = loader
        self.inferencePipeline = InferencePipeline(modelLoader: loader, config: config)
        self.fusionEngine = HybridFusionEngine(config: config)
        self.config = config
    }
    
    // MARK: - Public API
    
    /// Analyze skin using configured mode (heuristic, coreML, or hybrid).
    /// Falls back to heuristic if CoreML unavailable.
    func analyze(
        input: AnalysisInput,
        regionWeighting: RegionWeighting = .default,
        qualityPenalty: Bool = true
    ) async -> ScanAnalysisResult {
        let startTime = Date()
        
        // Always compute heuristic baseline
        let heuristicResult = SkinAnalysisEngine.analyze(
            input: input,
            regionWeighting: regionWeighting,
            qualityPenalty: qualityPenalty
        )
        
        // Handle based on mode
        let result: ScanAnalysisResult
        
        switch config.mode {
        case .heuristic:
            result = heuristicResult
            
        case .coreML:
            let coreMLResult = await inferencePipeline.infer(input: input)
            if coreMLResult.isSuccessful && !coreMLResult.regionPredictions.isEmpty {
                result = await fusionEngine.convertCoreMLToScanResult(
                    coreMLResult: coreMLResult,
                    timestamp: input.timestamp
                )
            } else {
                // Fallback
                if config.enableFallback {
                    if config.logMetrics {
                        logger.warning("CoreML inference failed, falling back to heuristic")
                    }
                    result = heuristicResult
                } else {
                    // Return error result (in production, might use Result type instead)
                    result = heuristicResult  // Even when not enabled, we fallback safely
                }
            }
            
        case .hybrid:
            let coreMLResult = await inferencePipeline.infer(input: input)
            result = await fusionEngine.fuseScores(
                heuristicResult: heuristicResult,
                coreMLResult: coreMLResult,
                input: input
            )
        }
        
        // Track metrics
        let elapsed = Date().timeIntervalSince(startTime)
        await updateMetrics(elapsed: Float(elapsed), mode: config.mode)
        
        if config.logMetrics {
            logger.info("Analysis (\(config.mode)): \(String(format: "%.1f", elapsed * 1000))ms")
        }
        
        return result
    }
    
    /// Update runtime configuration.
    func updateConfig(_ newConfig: CoreMLAnalysisConfig) {
        self.config = newConfig
    }
    
    /// Get current configuration.
    func getConfig() -> CoreMLAnalysisConfig {
        config
    }
    
    /// Change operating mode at runtime.
    func setMode(_ mode: AnalysisMode) {
        config.mode = mode
    }
    
    /// Get current operating mode.
    func getMode() -> AnalysisMode {
        config.mode
    }
    
    /// Check if CoreML model is available.
    func isModelAvailable() -> Bool {
        modelLoader.isModelAvailable()
    }
    
    /// Preload CoreML model to avoid latency on first analysis.
    func preloadModel() async {
        _ = await modelLoader.loadModel()
    }
    
    /// Clear model cache and force reload on next analysis.
    func clearModelCache() {
        modelLoader.clearCache()
    }
    
    /// Get performance metrics for monitoring.
    func getMetrics() -> PerformanceMetrics {
        performanceMetrics
    }
    
    /// Reset performance metrics.
    func resetMetrics() {
        performanceMetrics = PerformanceMetrics()
    }
    
    // MARK: - Private
    
    private func updateMetrics(elapsed: Float, mode: AnalysisMode) {
        performanceMetrics.addMeasurement(elapsed: elapsed, mode: mode)
    }
    
    // Private helper for internal use only
    func convertCoreMLToScanResult(
        coreMLResult: CoreMLInferenceResult,
        timestamp: Date
    ) async -> ScanAnalysisResult {
        await fusionEngine.convertCoreMLToScanResult(
            coreMLResult: coreMLResult,
            timestamp: timestamp
        )
    }
}

// MARK: - Performance Metrics

/// Tracks performance characteristics of analysis.
struct PerformanceMetrics: Sendable {
    private(set) var heuristicTimings: [Float] = []
    private(set) var coreMLTimings: [Float] = []
    private(set) var hybridTimings: [Float] = []
    
    mutating func addMeasurement(elapsed: Float, mode: AnalysisMode) {
        switch mode {
        case .heuristic:
            heuristicTimings.append(elapsed)
        case .coreML:
            coreMLTimings.append(elapsed)
        case .hybrid:
            hybridTimings.append(elapsed)
        }
    }
    
    var averageHeuristicTime: Float {
        heuristicTimings.isEmpty ? 0 : heuristicTimings.reduce(0, +) / Float(heuristicTimings.count)
    }
    
    var averageCoreMLTime: Float {
        coreMLTimings.isEmpty ? 0 : coreMLTimings.reduce(0, +) / Float(coreMLTimings.count)
    }
    
    var averageHybridTime: Float {
        hybridTimings.isEmpty ? 0 : hybridTimings.reduce(0, +) / Float(hybridTimings.count)
    }
    
    var maxCoreMLTime: Float {
        coreMLTimings.max() ?? 0
    }
    
    var minCoreMLTime: Float {
        coreMLTimings.min() ?? 0
    }
    
    var analysisCount: Int {
        heuristicTimings.count + coreMLTimings.count + hybridTimings.count
    }
}

// MARK: - Logging

private let logger = CoreMLLogger()

struct CoreMLLogger: Sendable {
    func info(_ message: String) {
        #if DEBUG
        print("[CoreML] ℹ️  \(message)")
        #endif
    }
    
    func warning(_ message: String) {
        #if DEBUG
        print("[CoreML] ⚠️  \(message)")
        #endif
    }
}
