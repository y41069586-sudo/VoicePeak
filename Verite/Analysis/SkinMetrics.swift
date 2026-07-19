import Foundation

/// Raw, per-region skin metrics from a `PixelBuffer`. Every value is normalized to
/// 0...1 and is an **estimate** produced by classical CV heuristics — not a
/// clinical measurement. Higher = "more of this signal" (more redness, more shine,
/// rougher texture, more visible pores, more spots; radiance is brightness).
struct RegionMetrics: Sendable {
    var redness: Double = 0
    var shine: Double = 0
    var texture: Double = 0
    var pores: Double = 0
    var spots: Double = 0
    var radiance: Double = 0
    var meanLuma: Double = 0 // 0...1, used for lighting normalization
}

/// Heuristic calibration. These constants map raw pixel statistics into 0...1.
/// Their absolute values matter less than their *consistency* across scans —
/// change-vs-baseline is what Glowé reports, and the same pipeline runs each time.
private enum Calib {
    static let rednessDivisor = 34.0     // raw red-dominance (0...255) → 0...1
    static let shineLuma = 208.0         // luma above this + low saturation = specular shine
    static let shineSaturation = 0.20
    static let textureDivisor = 26.0     // mean |Laplacian| → 0...1
    static let poreThreshold = 20.0      // |Laplacian| above this counts as a micro-edge
    static let poreScale = 3.2
    static let spotScale = 5.0
}

enum SkinMetrics {

    /// Compute all region metrics in a single pass (+ one Laplacian pass).
    static func metrics(for buffer: PixelBuffer) -> RegionMetrics {
        let w = buffer.width, h = buffer.height
        let n = max(1, buffer.count)

        var luma = [Double](repeating: 0, count: w * h)
        var sumRedDominance = 0.0
        var shineCount = 0
        var sumLuma = 0.0

        for y in 0..<h {
            for x in 0..<w {
                let (r, g, b) = buffer.rgb(x, y)
                let l = 0.299 * r + 0.587 * g + 0.114 * b
                luma[y * w + x] = l
                sumLuma += l

                sumRedDominance += max(0, r - (g + b) / 2)

                let maxC = max(r, max(g, b))
                let minC = min(r, min(g, b))
                let saturation = maxC > 0 ? (maxC - minC) / maxC : 0
                if l >= Calib.shineLuma && saturation <= Calib.shineSaturation { shineCount += 1 }
            }
        }

        let meanLuma = sumLuma / Double(n)

        // Laplacian pass over interior pixels → texture (mean magnitude) + pores
        // (fraction of strong micro-edges) + spots (reddish-dark outliers).
        var lapSum = 0.0
        var lapCount = 0
        var poreHits = 0
        var spotHits = 0
        if w >= 3 && h >= 3 {
            for y in 1..<(h - 1) {
                for x in 1..<(w - 1) {
                    let c = luma[y * w + x]
                    let lap = abs(4 * c
                                  - luma[y * w + (x - 1)]
                                  - luma[y * w + (x + 1)]
                                  - luma[(y - 1) * w + x]
                                  - luma[(y + 1) * w + x])
                    lapSum += lap
                    lapCount += 1
                    if lap >= Calib.poreThreshold { poreHits += 1 }

                    let (r, g, b) = buffer.rgb(x, y)
                    let redDominance = max(0, r - (g + b) / 2)
                    if redDominance > Calib.rednessDivisor && c < meanLuma * 0.92 { spotHits += 1 }
                }
            }
        }

        var m = RegionMetrics()
        m.meanLuma = (meanLuma / 255).clamped01
        m.redness = ((sumRedDominance / Double(n)) / Calib.rednessDivisor).clamped01
        m.shine = (Double(shineCount) / Double(n)).clamped01
        m.radiance = m.meanLuma
        if lapCount > 0 {
            // Normalize texture by brightness so dim captures don't read as smooth.
            let meanLap = lapSum / Double(lapCount)
            let lightingNorm = max(0.4, m.meanLuma)
            m.texture = ((meanLap / Calib.textureDivisor) / lightingNorm).clamped01
            m.pores = ((Double(poreHits) / Double(lapCount)) * Calib.poreScale).clamped01
            m.spots = ((Double(spotHits) / Double(lapCount)) * Calib.spotScale).clamped01
        }
        return m
    }
}
