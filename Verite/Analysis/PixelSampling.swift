import CoreGraphics

/// A small RGBA8 pixel grid read from a region of a captured image. Kept tiny
/// (downscaled) so per-attribute metrics run in well under a frame budget.
struct PixelBuffer: Sendable {
    let pixels: [UInt8]   // RGBA8, row-major, premultiplied-last
    let width: Int
    let height: Int
    var count: Int { width * height }

    @inline(__always)
    func rgb(_ x: Int, _ y: Int) -> (r: Double, g: Double, b: Double) {
        let i = (y * width + x) * 4
        return (Double(pixels[i]), Double(pixels[i + 1]), Double(pixels[i + 2]))
    }
}

/// Image cropping + pixel readout helpers. All CPU-only, no GPU/CoreImage
/// dependency, so they run happily on a background task.
enum Sampling {

    /// Convert a Vision bounding box (normalized, bottom-left origin) to a pixel
    /// rect in the image's top-left coordinate space.
    static func pixelRect(fromVision box: CGRect, imageWidth w: Int, imageHeight h: Int) -> CGRect {
        let width = box.width * CGFloat(w)
        let height = box.height * CGFloat(h)
        let x = box.minX * CGFloat(w)
        let yTop = (1 - box.maxY) * CGFloat(h) // flip Y
        return CGRect(x: x, y: yTop, width: width, height: height)
    }

    /// A region's pixel rect within a face rect, from fractional coordinates.
    static func regionRect(in faceRect: CGRect,
                           _ f: (x0: Double, y0: Double, x1: Double, y1: Double)) -> CGRect {
        CGRect(
            x: faceRect.minX + f.x0 * faceRect.width,
            y: faceRect.minY + f.y0 * faceRect.height,
            width: (f.x1 - f.x0) * faceRect.width,
            height: (f.y1 - f.y0) * faceRect.height
        )
    }

    /// Crop `cgImage` to `rect` (clamped to bounds), downscale so the longest side
    /// is ≤ `maxDim`, and read the pixels. Returns nil if the region is degenerate.
    static func readPixels(_ cgImage: CGImage, rect: CGRect, maxDim: Int = 96) -> PixelBuffer? {
        let bounds = CGRect(x: 0, y: 0, width: cgImage.width, height: cgImage.height)
        let clamped = rect.integral.intersection(bounds)
        guard clamped.width >= 4, clamped.height >= 4,
              let crop = cgImage.cropping(to: clamped) else { return nil }
        return read(crop, maxDim: maxDim)
    }

    /// Read a whole CGImage into a bounded PixelBuffer.
    static func read(_ cgImage: CGImage, maxDim: Int = 96) -> PixelBuffer? {
        let w0 = cgImage.width, h0 = cgImage.height
        guard w0 > 0, h0 > 0 else { return nil }
        let scale = min(1.0, Double(maxDim) / Double(max(w0, h0)))
        let w = max(1, Int(Double(w0) * scale))
        let h = max(1, Int(Double(h0) * scale))

        let bytesPerRow = w * 4
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        // Let the context own its buffer, then copy out — an inout Swift array
        // pointer would only be valid for the duration of the init call.
        guard let ctx = CGContext(
            data: nil,
            width: w, height: h,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ), let raw = ctx.data else { return nil }

        ctx.interpolationQuality = .medium
        ctx.draw(cgImage, in: CGRect(x: 0, y: 0, width: w, height: h))

        let count = w * h * 4
        let ptr = raw.bindMemory(to: UInt8.self, capacity: count)
        let pixels = Array(UnsafeBufferPointer(start: ptr, count: count))
        return PixelBuffer(pixels: pixels, width: w, height: h)
    }
}
