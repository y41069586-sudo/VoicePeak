import Foundation

/// Extended per-region metrics beyond the base `RegionMetrics`.
/// Added as a separate struct so the core pipeline stays unchanged and
/// these new attributes are computed only where the relevant region
/// (under-eye for dark circles; cheeks for glow; composite for barrier)
/// is available.
///
/// All values are 0…1 estimates from classical image heuristics.
/// Higher = more of the signal (more dark-circle appearance, more glow, etc.).
struct ExtendedRegionMetrics: Sendable {
    /// Under-eye region only. Low luma + blue-green channel dominance
    /// (shadowing + venous hue) mapped to 0…1.
    var darkCircles: Double = 0

    /// Composite glow signal: high radiance + smooth texture + low redness
    /// → naturally luminous appearance. 0 = dull, 1 = visibly radiant.
    var glow: Double = 0

    /// Heuristic barrier health estimate: low redness + low sensitivity proxy
    /// (redness unevenness across regions) + adequate hydration proxy.
    /// 0 = compromised-looking barrier, 1 = healthy-looking barrier.
    var barrierScore: Double = 0
}

/// Computes extended metrics from base `RegionMetrics` already produced by
/// `SkinMetrics`, plus an optional under-eye `PixelBuffer` for dark-circle analysis.
enum ExtendedSkinMetrics {

    /// Compute glow from existing region metrics.
    /// Call per-region after `SkinMetrics.metrics(for:)`.
    static func glow(from m: RegionMetrics) -> Double {
        // Glow = bright + smooth + not red. Each factor penalises the glow score.
        let radiance = m.radiance           // 0=dark, 1=bright
        let smoothness = 1.0 - m.texture   // 0=rough, 1=smooth
        let calm = 1.0 - m.redness         // 0=red, 1=calm
        return (radiance * smoothness * calm).clamped01
    }

    /// Compute barrier score from multiple face regions.
    /// `rednessMean` and `rednessSD` should come from the full set of sampled regions.
    static func barrierScore(rednessMean: Double,
                             rednessSD: Double,
                             hydrationProxy: Double) -> Double {
        // Compromised barriers show elevated, uneven redness and poor hydration.
        let stabilityScore = (1.0 - (rednessMean * 0.5 + rednessSD * 0.5)).clamped01
        let hydrationFactor = hydrationProxy.clamped01
        return (0.55 * stabilityScore + 0.45 * hydrationFactor).clamped01
    }

    /// Compute dark-circle appearance from an under-eye `PixelBuffer`.
    /// The key signals are:
    ///   - Sub-average luma (shadowing / hollowness)
    ///   - Slight blue-green dominance over red (venous tone)
    static func darkCircles(buffer: PixelBuffer) -> Double {
        let w = buffer.width, h = buffer.height
        guard w >= 2, h >= 2 else { return 0 }

        var sumLuma = 0.0
        var sumBlueDominance = 0.0
        let n = max(1, buffer.count)

        for y in 0..<h {
            for x in 0..<w {
                let (r, g, b) = buffer.rgb(x, y)
                let luma = 0.299 * r + 0.587 * g + 0.114 * b
                sumLuma += luma
                // Blue-green dominance over red: positive means cooler/darker hue.
                let blueGreenAvg = (g + b) / 2
                sumBlueDominance += max(0, blueGreenAvg - r)
            }
        }

        let meanLuma = sumLuma / Double(n) / 255.0       // 0…1
        let meanBGDom = sumBlueDominance / Double(n) / 255.0

        // Dark circles: low luma AND slight blue/green dominance.
        // Scale so that 50 % luma → 0, 20 % luma → 1.
        let lumaSignal = (1.0 - (meanLuma / 0.50)).clamped01
        let hueSignal = (meanBGDom * 5.0).clamped01   // small values, amplify

        return (0.65 * lumaSignal + 0.35 * hueSignal).clamped01
    }

    /// Compute all extended metrics for a full-face region set, plus
    /// an optional under-eye pixel buffer.
    static func compute(
        regions: [FaceRegion: RegionMetrics],
        underEyeBuffer: PixelBuffer?
    ) -> ExtendedRegionMetrics {
        var ext = ExtendedRegionMetrics()

        // Glow: average of cheeks (most visible glow region).
        let glowSamples = [FaceRegion.leftCheek, .rightCheek, .forehead].compactMap { regions[$0] }
        if !glowSamples.isEmpty {
            ext.glow = (glowSamples.map { glow(from: $0) }.reduce(0, +) / Double(glowSamples.count)).clamped01
        }

        // Barrier: use redness mean + SD across all available regions.
        let rednessValues = regions.values.map(\.redness)
        if !rednessValues.isEmpty {
            let mean = rednessValues.reduce(0, +) / Double(rednessValues.count)
            let variance = rednessValues.reduce(0) { $0 + ($1 - mean) * ($1 - mean) } / Double(rednessValues.count)
            let sd = sqrt(variance)
            let hydProxy = regions[.leftCheek].map { 0.6 * $0.radiance + 0.4 * (1 - $0.texture) }
                        ?? regions[.rightCheek].map { 0.6 * $0.radiance + 0.4 * (1 - $0.texture) }
                        ?? 0.5
            ext.barrierScore = barrierScore(rednessMean: mean, rednessSD: sd, hydrationProxy: hydProxy)
        }

        // Dark circles: from dedicated under-eye buffer if provided.
        if let buf = underEyeBuffer {
            ext.darkCircles = darkCircles(buffer: buf)
        }

        return ext
    }
}
