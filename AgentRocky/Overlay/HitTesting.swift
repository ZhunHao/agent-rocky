import AppKit
import AVFoundation

/// Per-pixel alpha hit testing on an NSImage + frame extraction helpers.
/// Used by AppController to toggle ignoresMouseEvents on the overlay window
/// based on whether the cursor is over Rocky's actual sprite pixels.
nonisolated enum HitTesting {

    /// Returns true if the pixel at `point` (image coordinates, origin bottom-left)
    /// has alpha greater than `threshold` (0..1).
    static func isOpaque(at point: NSPoint, in image: NSImage, threshold: CGFloat = 0.1) -> Bool {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return false
        }
        let width = cgImage.width
        let height = cgImage.height
        let x = Int(point.x)
        let y = height - 1 - Int(point.y)   // CGImage origin is top-left
        guard x >= 0, x < width, y >= 0, y < height else { return false }

        var pixel: [UInt8] = [0, 0, 0, 0]
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue

        guard let ctx = CGContext(
            data: &pixel,
            width: 1,
            height: 1,
            bitsPerComponent: 8,
            bytesPerRow: 4,
            space: colorSpace,
            bitmapInfo: bitmapInfo
        ) else { return false }

        ctx.translateBy(x: -CGFloat(x), y: -CGFloat(height - 1 - y))
        ctx.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        let alpha = CGFloat(pixel[3]) / 255.0
        return alpha > threshold
    }

    /// Extract frame 1 of an asset as the static idle hit mask.
    /// We use this once at startup (cached) instead of grabbing live AVPlayer frames.
    static func extractFirstFrame(from videoURL: URL) -> NSImage? {
        let asset = AVURLAsset(url: videoURL)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        do {
            let cgImage = try generator.copyCGImage(at: .zero, actualTime: nil)
            return NSImage(cgImage: cgImage, size: .zero)
        } catch {
            return nil
        }
    }
}
