import CoreML
import Foundation

/// Manages CoreML model loading, caching, and lifecycle.
/// Handles graceful fallback if model is unavailable.
actor ModelLoader: Sendable {
    private var loadedModel: MLModel?
    private var loadingError: Error?
    private var isLoaded = false
    
    /// Model file name (without extension).
    private let modelName: String
    
    /// Bundle containing the model.
    private let bundle: Bundle
    
    // MARK: - Initialization
    
    init(modelName: String = "SkinAnalysisModel", bundle: Bundle = .main) {
        self.modelName = modelName
        self.bundle = bundle
    }
    
    // MARK: - Public API
    
    /// Attempt to load the CoreML model.
    /// Returns the model on success, or nil with error logged on failure.
    func loadModel() async -> MLModel? {
        if isLoaded {
            if let error = loadingError {
                logger.debug("Model previously failed to load: \(error)")
            }
            return loadedModel
        }
        
        isLoaded = true
        
        do {
            let url = try modelURL()
            let model = try MLModel(contentsOf: url)
            self.loadedModel = model
            logger.info("✓ CoreML model loaded successfully")
            return model
        } catch {
            self.loadingError = error
            logger.warning("✗ Failed to load CoreML model: \(error)")
            return nil
        }
    }
    
    /// Check if model is available without loading.
    func isModelAvailable() -> Bool {
        do {
            let url = try modelURL()
            return FileManager.default.fileExists(atPath: url.path)
        } catch {
            return false
        }
    }
    
    /// Clear cached model to force reload.
    func clearCache() {
        loadedModel = nil
        loadingError = nil
        isLoaded = false
        logger.debug("Model cache cleared")
    }
    
    // MARK: - Private
    
    private func modelURL() throws -> URL {
        guard let url = bundle.url(forResource: modelName, withExtension: "mlmodelc"),
              FileManager.default.fileExists(atPath: url.path) else {
            throw ModelLoaderError.modelNotFound(modelName)
        }
        return url
    }
}

// MARK: - Error Handling

enum ModelLoaderError: LocalizedError {
    case modelNotFound(String)
    case failedToLoad(String)
    case invalidFormat
    
    var errorDescription: String? {
        switch self {
        case .modelNotFound(let name):
            return "CoreML model '\(name)' not found in bundle"
        case .failedToLoad(let reason):
            return "Failed to load CoreML model: \(reason)"
        case .invalidFormat:
            return "CoreML model format is invalid"
        }
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
    
    func debug(_ message: String) {
        #if DEBUG
        print("[CoreML] 🔧 \(message)")
        #endif
    }
}
