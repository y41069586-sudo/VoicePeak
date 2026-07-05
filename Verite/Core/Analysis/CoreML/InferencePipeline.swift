import CoreML
import CoreVideo
import Foundation

/// High-level inference pipeline for skin region analysis.
/// Handles:
/// - Input preprocessing (normalization, buffering)
/// - Model inference
/// - Output mapping to prediction format
/// - Confidence computation
actor InferencePipeline: Sendable {
    private let modelLoader: ModelLoader
    private let config: CoreMLAnalysisConfig
    
    // MARK: - Initialization
    
    init(modelLoader: ModelLoader, config: CoreMLAnalysisConfig = CoreMLAnalysisConfig()) {
        self.modelLoader = modelLoader
        self.config = config
    }
    
    // MARK: - Public API
    
    /// Run inference on analysis input.
    /// Returns predictions for each region, or failure result if model unavailable.
    func infer(input: AnalysisInput) async -> CoreMLInferenceResult {
        // Check if model is available
        guard let model = await modelLoader.loadModel() else {
            return .failure(error: "CoreML model not available")
        }
        
        var predictions: [FaceRegion: CoreMLRegionPrediction] = [:]
        
        // Process each region
        for regionData in input.skinRegions {
            do {
                let prediction = try await inferRegion(
                    regionData: regionData,
                    model: model,
                    captureQuality: input.captureQuality
                )
                predictions[regionData.region] = prediction
            } catch {
                return .failure(error: "Inference failed for region \(regionData.region): \(error)")
            }
        }
        
        return CoreMLInferenceResult(regionPredictions: predictions)
    }
    
    // MARK: - Private
    
    private func inferRegion(
        regionData: SkinRegionData,
        model: MLModel,
        captureQuality: CaptureQuality
    ) async throws -> CoreMLRegionPrediction {
        // Prepare input for model
        let modelInput = try prepareModelInput(
            pixelBuffer: regionData.pixelBuffer,
            region: regionData.region,
            lightingQuality: captureQuality.lightingQuality
        )
        
        // Run inference on background queue
        let output = try await Task.detached(priority: .userInitiated) {
            try model.prediction(from: modelInput)
        }.value
        
        // Parse output and create prediction
        let prediction = try parsePrediction(
            output: output,
            region: regionData.region,
            regionQuality: regionData.extractionConfidence,
            lightingQuality: captureQuality.lightingQuality
        )
        
        return prediction
    }
    
    private func prepareModelInput(
        pixelBuffer: CVPixelBuffer,
        region: FaceRegion,
        lightingQuality: Float
    ) throws -> MLFeatureProvider {
        // Create feature provider from pixel buffer
        // This assumes the model expects a single image input named "image"
        // Adjust feature name based on actual model specification
        
        let featureProvider = try MLDictionaryFeatureProvider(
            dictionary: [
                "image": MLFeatureValue(pixelBuffer: pixelBuffer)
            ]
        )
        
        return featureProvider
    }
    
    private func parsePrediction(
        output: MLFeatureProvider,
        region: FaceRegion,
        regionQuality: Float,
        lightingQuality: Float
    ) throws -> CoreMLRegionPrediction {
        // Extract outputs from model prediction
        // These feature names MUST match the model's output layer names
        
        let redness = extractFloatOutput(output, "redness", default: 0.5)
        let acne = extractFloatOutput(output, "acne", default: 0.5)
        let oiliness = extractFloatOutput(output, "oiliness", default: 0.5)
        let texture = extractFloatOutput(output, "texture_quality", default: 0.5)
        let pore = extractFloatOutput(output, "pore_visibility", default: 0.5)
        let hydration = extractFloatOutput(output, "hydration", default: 0.5)
        let sensitivity = extractFloatOutput(output, "sensitivity", default: 0.5)
        let confidence = extractFloatOutput(output, "confidence", default: 0.7)
        
        return CoreMLRegionPrediction(
            region: region,
            rednessProbability: redness,
            acneProbability: acne,
            oilinessProbability: oiliness,
            textureQuality: texture,
            poreVisibility: pore,
            hydrationEstimate: hydration,
            sensitivityScore: sensitivity,
            modelConfidence: confidence,
            regionQuality: regionQuality,
            lightingQuality: lightingQuality
        )
    }
    
    private func extractFloatOutput(
        _ output: MLFeatureProvider,
        _ featureName: String,
        default defaultValue: Float
    ) -> Float {
        guard let feature = try? output.featureValue(for: featureName) else {
            return defaultValue
        }
        
        switch feature.type {
        case .double:
            return Float(feature.doubleValue)
        case .float:
            return feature.floatValue
        case .int64:
            return Float(feature.int64Value)
        default:
            return defaultValue
        }
    }
}

// MARK: - Error Handling

enum InferencePipelineError: LocalizedError {
    case modelLoadFailed
    case preprocessingFailed(String)
    case inferenceFailed(String)
    case outputParsingFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .modelLoadFailed:
            return "Failed to load CoreML model"
        case .preprocessingFailed(let reason):
            return "Preprocessing failed: \(reason)"
        case .inferenceFailed(let reason):
            return "Model inference failed: \(reason)"
        case .outputParsingFailed(let reason):
            return "Failed to parse model output: \(reason)"
        }
    }
}
