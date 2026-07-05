import CoreVideo
import Foundation

/// Low-level pixel analysis utilities for skin metrics.
/// All functions operate on normalized BGRA pixel buffers.
enum PixelAnalysis {
    
    // MARK: - Histogram & Distribution
    
    /// Compute histogram of luminance values.
    static func luminanceHistogram(pixelBuffer: CVPixelBuffer, bins: Int = 256) -> [Int] {
        var histogram = [Int](repeating: 0, count: bins)
        
        CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly) }
        
        guard let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer) else {
            return histogram
        }
        
        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)
        
        let buffer = baseAddress.assumingMemoryBound(to: UInt8.self)
        
        for y in 0..<height {
            for x in 0..<width {
                let offset = y * bytesPerRow + x * 4
                let b = buffer[offset]
                let g = buffer[offset + 1]
                let r = buffer[offset + 2]
                
                let luma = UInt8(0.299 * Float(r) + 0.587 * Float(g) + 0.114 * Float(b))
                histogram[Int(luma)] += 1
            }
        }
        
        return histogram
    }
    
    /// Compute luminance statistics (mean, std dev, min, max).
    static func luminanceStats(pixelBuffer: CVPixelBuffer) -> (mean: Float, stdDev: Float, min: Float, max: Float) {
        CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly) }
        
        guard let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer) else {
            return (0, 0, 0, 0)
        }
        
        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)
        let buffer = baseAddress.assumingMemoryBound(to: UInt8.self)
        
        var sum: Float = 0
        var minVal: Float = 255
        var maxVal: Float = 0
        let pixelCount = width * height
        
        for y in 0..<height {
            for x in 0..<width {
                let offset = y * bytesPerRow + x * 4
                let b = Float(buffer[offset])
                let g = Float(buffer[offset + 1])
                let r = Float(buffer[offset + 2])
                
                let luma = 0.299 * r + 0.587 * g + 0.114 * b
                sum += luma
                minVal = min(minVal, luma)
                maxVal = max(maxVal, luma)
            }
        }
        
        let mean = sum / Float(pixelCount)
        
        // Calculate standard deviation
        var sumSquaredDiff: Float = 0
        for y in 0..<height {
            for x in 0..<width {
                let offset = y * bytesPerRow + x * 4
                let b = Float(buffer[offset])
                let g = Float(buffer[offset + 1])
                let r = Float(buffer[offset + 2])
                
                let luma = 0.299 * r + 0.587 * g + 0.114 * b
                sumSquaredDiff += (luma - mean) * (luma - mean)
            }
        }
        
        let stdDev = sqrt(sumSquaredDiff / Float(pixelCount))
        
        return (mean, stdDev, minVal, maxVal)
    }
    
    // MARK: - Redness Detection
    
    /// Compute redness metric based on red channel prominence.
    /// Higher values indicate more red/pink tones.
    static func rednessMetric(pixelBuffer: CVPixelBuffer) -> Float {
        CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly) }
        
        guard let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer) else {
            return 0
        }
        
        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)
        let buffer = baseAddress.assumingMemoryBound(to: UInt8.self)
        
        var redDiff: Float = 0
        let pixelCount = width * height
        
        for y in 0..<height {
            for x in 0..<width {
                let offset = y * bytesPerRow + x * 4
                let b = Float(buffer[offset])
                let g = Float(buffer[offset + 1])
                let r = Float(buffer[offset + 2])
                
                // R - (B+G)/2 captures red excess
                redDiff += r - (b + g) / 2.0
            }
        }
        
        return redDiff / Float(pixelCount)
    }
    
    // MARK: - Oiliness/Specularity
    
    /// Detect specular highlights (bright spots indicating oil/shine).
    /// Returns percentage of pixels above brightness threshold.
    static func specularity(pixelBuffer: CVPixelBuffer, threshold: UInt8 = 200) -> Float {
        CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly) }
        
        guard let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer) else {
            return 0
        }
        
        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)
        let buffer = baseAddress.assumingMemoryBound(to: UInt8.self)
        
        var brightPixels = 0
        let pixelCount = width * height
        
        for y in 0..<height {
            for x in 0..<width {
                let offset = y * bytesPerRow + x * 4
                let b = buffer[offset]
                let g = buffer[offset + 1]
                let r = buffer[offset + 2]
                
                let luma = UInt8(0.299 * Float(r) + 0.587 * Float(g) + 0.114 * Float(b))
                if luma >= threshold {
                    brightPixels += 1
                }
            }
        }
        
        return Float(brightPixels) / Float(pixelCount)
    }
    
    // MARK: - Texture & Edge Detection
    
    /// Compute local variance (edge density) as texture metric.
    /// Higher values indicate more texture/roughness.
    static func textureVariance(pixelBuffer: CVPixelBuffer, kernelSize: Int = 5) -> Float {
        CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly) }
        
        guard let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer) else {
            return 0
        }
        
        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)
        let buffer = baseAddress.assumingMemoryBound(to: UInt8.self)
        
        let halfKernel = kernelSize / 2
        var totalVariance: Float = 0
        var sampledPixels = 0
        
        // Subsample to avoid expensive computation
        let step = max(1, kernelSize / 2)
        
        for y in halfKernel..<(height - halfKernel) {
            for x in stride(from: halfKernel, to: width - halfKernel, by: step) {
                var localSum: Float = 0
                var localCount = 0
                
                for dy in -halfKernel...halfKernel {
                    for dx in -halfKernel...halfKernel {
                        let py = y + dy
                        let px = x + dx
                        let offset = py * bytesPerRow + px * 4
                        let b = Float(buffer[offset])
                        let g = Float(buffer[offset + 1])
                        let r = Float(buffer[offset + 2])
                        
                        let luma = 0.299 * r + 0.587 * g + 0.114 * b
                        localSum += luma
                        localCount += 1
                    }
                }
                
                let localMean = localSum / Float(localCount)
                
                var localVariance: Float = 0
                for dy in -halfKernel...halfKernel {
                    for dx in -halfKernel...halfKernel {
                        let py = y + dy
                        let px = x + dx
                        let offset = py * bytesPerRow + px * 4
                        let b = Float(buffer[offset])
                        let g = Float(buffer[offset + 1])
                        let r = Float(buffer[offset + 2])
                        
                        let luma = 0.299 * r + 0.587 * g + 0.114 * b
                        localVariance += (luma - localMean) * (luma - localMean)
                    }
                }
                
                totalVariance += sqrt(localVariance / Float(localCount))
                sampledPixels += 1
            }
        }
        
        return sampledPixels > 0 ? totalVariance / Float(sampledPixels) : 0
    }
    
    // MARK: - Pore Detection
    
    /// Detect high-frequency patterns indicating pores.
    /// Uses edge detection via Sobel-like kernel.
    static func poreFrequency(pixelBuffer: CVPixelBuffer) -> Float {
        // Pore detection: high-frequency component
        // Approximate via gradient magnitude
        let baseVariance = textureVariance(pixelBuffer: pixelBuffer, kernelSize: 3)
        let smoothedVariance = textureVariance(pixelBuffer: pixelBuffer, kernelSize: 7)
        
        // High-frequency is difference between fine and coarse scales
        return max(0, baseVariance - smoothedVariance)
    }
}
