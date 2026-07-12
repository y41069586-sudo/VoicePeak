import AVFoundation
import UIKit

// ============================================================
// MARK: — Glow-Up Reel composer (on-device video export)
// ============================================================
//
// Renders the user's scan photos into a 9:16 H.264 video, entirely on-device:
// intro photo → crossfaded timeline → finale with the score counting up →
// brand outro. ~6–12 s at 30 fps. Frames are drawn with UIKit/CoreGraphics
// straight into the AVAssetWriter's pixel-buffer pool — no intermediate
// UIImage per frame, so exports finish in a few seconds.

/// One scan as reel input. `@unchecked Sendable`: the only non-Sendable member
/// is `image`, and we only ever READ it (immutable UIImage) across the export
/// task boundary — safe to hand to the detached composer.
struct ReelFrame: @unchecked Sendable {
    let image: UIImage
    let dayLabel: String   // "DAY 1"
    let score: Int
}

enum ReelError: Error { case setup, render }

enum GlowUpReelComposer {
    static let size = CGSize(width: 1080, height: 1920)
    static let fps: Int32 = 30

    // MARK: Public entry

    /// Composes the reel and returns the temporary .mp4 URL.
    /// `progress` is called on arbitrary threads with 0…1.
    static func compose(
        frames: [ReelFrame],
        progress: @escaping @Sendable (Double) -> Void
    ) async throws -> URL {
        guard frames.count >= 2 else { throw ReelError.setup }

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("verite-glowup-\(UUID().uuidString).mp4")

        let writer = try AVAssetWriter(outputURL: url, fileType: .mp4)
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: Int(size.width),
            AVVideoHeightKey: Int(size.height),
        ])
        input.expectsMediaDataInRealTime = false
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: input,
            sourcePixelBufferAttributes: [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
                kCVPixelBufferWidthKey as String: Int(size.width),
                kCVPixelBufferHeightKey as String: Int(size.height),
            ]
        )
        guard writer.canAdd(input) else { throw ReelError.setup }
        writer.add(input)
        guard writer.startWriting() else { throw ReelError.setup }
        writer.startSession(atSourceTime: .zero)

        let segments = timeline(for: frames)
        let totalFrames = segments.reduce(0) { $0 + $1.frameCount }
        var written: Int64 = 0

        for segment in segments {
            for local in 0..<segment.frameCount {
                try Task.checkCancellation()
                while !input.isReadyForMoreMediaData {
                    try await Task.sleep(nanoseconds: 8_000_000)
                }
                guard let pool = adaptor.pixelBufferPool else { throw ReelError.render }
                var pixelBuffer: CVPixelBuffer?
                CVPixelBufferPoolCreatePixelBuffer(nil, pool, &pixelBuffer)
                guard let buffer = pixelBuffer else { throw ReelError.render }

                render(into: buffer) {
                    draw(segment: segment, local: local)
                }
                guard adaptor.append(buffer, withPresentationTime:
                    CMTime(value: written, timescale: fps)) else { throw ReelError.render }
                written += 1
                progress(Double(written) / Double(totalFrames))
            }
        }

        input.markAsFinished()
        await writer.finishWriting()
        guard writer.status == .completed else { throw ReelError.render }
        return url
    }

    // MARK: Timeline

    private enum Segment {
        case intro(ReelFrame)
        case photo(ReelFrame, previous: ReelFrame)
        case finale(ReelFrame, previous: ReelFrame, fromScore: Int)
        case outro(fromScore: Int, toScore: Int)

        var frameCount: Int {
            switch self {
            case .intro: return 54    // 1.8 s
            case .photo: return 24    // 0.8 s
            case .finale: return 84   // 2.8 s (count-up lives here)
            case .outro: return 48    // 1.6 s
            }
        }
    }

    private static func timeline(for frames: [ReelFrame]) -> [Segment] {
        var segments: [Segment] = [.intro(frames[0])]
        if frames.count > 2 {
            for i in 1..<(frames.count - 1) {
                segments.append(.photo(frames[i], previous: frames[i - 1]))
            }
        }
        let last = frames[frames.count - 1]
        let prev = frames[frames.count - 2]
        segments.append(.finale(last, previous: prev, fromScore: frames[0].score))
        segments.append(.outro(fromScore: frames[0].score, toScore: last.score))
        return segments
    }

    // MARK: Frame rendering

    private static func render(into buffer: CVPixelBuffer, drawContent: () -> Void) {
        CVPixelBufferLockBaseAddress(buffer, [])
        defer { CVPixelBufferUnlockBaseAddress(buffer, []) }
        guard let base = CVPixelBufferGetBaseAddress(buffer),
              let space = CGColorSpace(name: CGColorSpace.sRGB),
              let ctx = CGContext(
                data: base,
                width: Int(size.width), height: Int(size.height),
                bitsPerComponent: 8,
                bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
                space: space,
                bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue
                    | CGBitmapInfo.byteOrder32Little.rawValue
              )
        else { return }
        // Flip into UIKit's top-left coordinate space.
        ctx.translateBy(x: 0, y: size.height)
        ctx.scaleBy(x: 1, y: -1)
        UIGraphicsPushContext(ctx)
        drawContent()
        UIGraphicsPopContext()
    }

    private static func draw(segment: Segment, local: Int) {
        let n = CGFloat(segment.frameCount)
        let t = CGFloat(local) / max(n - 1, 1)     // 0…1 within the segment

        switch segment {
        case .intro(let frame):
            drawPhoto(frame.image, zoom: 1.0 + 0.06 * easeInOut(t), alpha: 1)
            drawScrim()
            drawBrandTag()
            drawDayAndScore(frame, appear: min(1, t * 3))

        case .photo(let frame, let previous):
            let fade = min(1, CGFloat(local) / 8)
            if fade < 1 { drawPhoto(previous.image, zoom: 1.06, alpha: 1) }
            drawPhoto(frame.image, zoom: 1.02 + 0.04 * t, alpha: fade)
            drawScrim()
            drawBrandTag()
            drawDayAndScore(frame, appear: 1)

        case .finale(let frame, let previous, let fromScore):
            let fade = min(1, CGFloat(local) / 8)
            if fade < 1 { drawPhoto(previous.image, zoom: 1.06, alpha: 1) }
            drawPhoto(frame.image, zoom: 1.02 + 0.05 * t, alpha: fade)
            drawScrim(strength: 1.25)
            drawBrandTag()

            // Score races up over ~1.5 s after the crossfade settles.
            let countT = clamp01((CGFloat(local) - 12) / 45)
            let eased = 1 - pow(1 - countT, 2.6)
            let value = fromScore + Int((CGFloat(frame.score - fromScore) * eased).rounded())
            drawFinaleScore(value: value, dayLabel: frame.dayLabel,
                            delta: frame.score - fromScore, showDelta: countT >= 1)

        case .outro(let fromScore, let toScore):
            drawOutro(appear: easeInOut(min(1, t * 2.2)), from: fromScore, to: toScore)
        }
    }

    // MARK: Drawing pieces

    private static func drawPhoto(_ image: UIImage, zoom: CGFloat, alpha: CGFloat) {
        UIColor.black.setFill()
        UIRectFill(CGRect(origin: .zero, size: size))
        let img = image.size
        guard img.width > 0, img.height > 0 else { return }
        let scale = max(size.width / img.width, size.height / img.height) * zoom
        let w = img.width * scale, h = img.height * scale
        image.draw(in: CGRect(x: (size.width - w) / 2, y: (size.height - h) / 2,
                              width: w, height: h),
                   blendMode: .normal, alpha: alpha)
    }

    /// Legibility gradient over the lower third (and a whisper up top).
    private static func drawScrim(strength: CGFloat = 1.0) {
        guard let ctx = UIGraphicsGetCurrentContext(),
              let space = CGColorSpace(name: CGColorSpace.sRGB) else { return }
        let colors = [
            UIColor.black.withAlphaComponent(0).cgColor,
            UIColor.black.withAlphaComponent(0.55 * strength).cgColor,
            UIColor.black.withAlphaComponent(0.85 * strength).cgColor,
        ] as CFArray
        if let gradient = CGGradient(colorsSpace: space, colors: colors,
                                     locations: [0.55, 0.82, 1.0]) {
            ctx.drawLinearGradient(gradient,
                                   start: CGPoint(x: 0, y: 0),
                                   end: CGPoint(x: 0, y: size.height),
                                   options: [])
        }
        // Top whisper for the brand tag.
        let top = [
            UIColor.black.withAlphaComponent(0.35).cgColor,
            UIColor.black.withAlphaComponent(0).cgColor,
        ] as CFArray
        if let gradient = CGGradient(colorsSpace: space, colors: top, locations: [0, 0.14]) {
            ctx.drawLinearGradient(gradient,
                                   start: CGPoint(x: 0, y: 0),
                                   end: CGPoint(x: 0, y: size.height),
                                   options: [])
        }
    }

    private static func drawBrandTag() {
        draw(text: "VÉRITÉ", font: rounded(38, .heavy), color: .white.withAlphaComponent(0.8),
             at: CGPoint(x: 64, y: 92), tracking: 7)
    }

    private static func drawDayAndScore(_ frame: ReelFrame, appear: CGFloat) {
        let a = clamp01(appear)
        draw(text: frame.dayLabel, font: rounded(92, .heavy),
             color: .white.withAlphaComponent(a),
             at: CGPoint(x: 64, y: 1650))
        draw(text: "SCORE", font: rounded(30, .bold),
             color: .white.withAlphaComponent(0.65 * a),
             at: CGPoint(x: size.width - 64, y: 1650), rightAligned: true, tracking: 4)
        draw(text: "\(frame.score)", font: rounded(92, .heavy),
             color: .white.withAlphaComponent(a),
             at: CGPoint(x: size.width - 64, y: 1692), rightAligned: true)
    }

    private static func drawFinaleScore(value: Int, dayLabel: String, delta: Int, showDelta: Bool) {
        draw(text: dayLabel, font: rounded(64, .heavy),
             color: .white.withAlphaComponent(0.9),
             at: CGPoint(x: size.width / 2, y: 1420), centered: true)
        draw(text: "SCORE", font: rounded(34, .bold),
             color: .white.withAlphaComponent(0.65),
             at: CGPoint(x: size.width / 2, y: 1520), centered: true, tracking: 6)
        draw(text: "\(value)", font: rounded(190, .heavy),
             color: .white,
             at: CGPoint(x: size.width / 2, y: 1560), centered: true)
        if showDelta, delta != 0 {
            let sign = delta > 0 ? "+" : ""
            let color = delta > 0
                ? UIColor(red: 0.12, green: 0.62, blue: 0.42, alpha: 1)  // deltaUp
                : UIColor(red: 0.87, green: 0.36, blue: 0.31, alpha: 1)
            draw(text: "\(sign)\(delta) IN 14 DAYS", font: rounded(46, .heavy),
                 color: color, at: CGPoint(x: size.width / 2, y: 1790),
                 centered: true, tracking: 2)
        }
    }

    private static func drawOutro(appear: CGFloat, from: Int, to: Int) {
        UIColor(red: 0.055, green: 0.078, blue: 0.11, alpha: 1).setFill()  // 0E141C
        UIRectFill(CGRect(origin: .zero, size: size))
        let a = clamp01(appear)
        draw(text: "Vérité", font: rounded(150, .heavy),
             color: .white.withAlphaComponent(a),
             at: CGPoint(x: size.width / 2, y: 800), centered: true)
        if to != from {
            draw(text: "\(from) → \(to)", font: rounded(72, .heavy),
                 color: UIColor(red: 0.31, green: 0.56, blue: 0.97, alpha: a),  // accent-bright
                 at: CGPoint(x: size.width / 2, y: 1010), centered: true)
        }
        draw(text: "The 14-day glow-up.", font: rounded(52, .semibold),
             color: .white.withAlphaComponent(0.85 * a),
             at: CGPoint(x: size.width / 2, y: 1130), centered: true)
        draw(text: "Scan yours.", font: rounded(44, .bold),
             color: UIColor(red: 0.31, green: 0.56, blue: 0.97, alpha: a),
             at: CGPoint(x: size.width / 2, y: 1230), centered: true)
    }

    // MARK: Text + math helpers

    private static func draw(
        text: String, font: UIFont, color: UIColor, at point: CGPoint,
        centered: Bool = false, rightAligned: Bool = false, tracking: CGFloat = 0
    ) {
        var attributes: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color]
        if tracking != 0 { attributes[.kern] = tracking }
        let string = NSAttributedString(string: text, attributes: attributes)
        let bounds = string.size()
        var origin = point
        if centered { origin.x -= bounds.width / 2 }
        if rightAligned { origin.x -= bounds.width }
        string.draw(at: origin)
    }

    private static func rounded(_ size: CGFloat, _ weight: UIFont.Weight) -> UIFont {
        let base = UIFont.monospacedDigitSystemFont(ofSize: size, weight: weight)
        guard let descriptor = base.fontDescriptor.withDesign(.rounded) else { return base }
        return UIFont(descriptor: descriptor, size: size)
    }

    private static func easeInOut(_ t: CGFloat) -> CGFloat {
        t < 0.5 ? 2 * t * t : 1 - pow(-2 * t + 2, 2) / 2
    }

    private static func clamp01(_ v: CGFloat) -> CGFloat { min(max(v, 0), 1) }
}
