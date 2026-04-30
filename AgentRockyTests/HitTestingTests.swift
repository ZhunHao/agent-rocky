import Testing
import AppKit
@testable import AgentRocky

@MainActor
struct HitTestingTests {

    /// 4×4 image: opaque red square at NS y in [2, 4) (top half), transparent elsewhere.
    /// Built via NSBitmapImageRep so we get exactly 4x4 pixels regardless of display scale.
    private func makeFixtureImage() -> NSImage {
        let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: 4, pixelsHigh: 4,
            bitsPerSample: 8, samplesPerPixel: 4,
            hasAlpha: true, isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 16, bitsPerPixel: 32
        )!
        // Bitmap rep has top-left origin. Fill rows 0 and 1 (which correspond to
        // NSImage NS y in [2, 4) — the top half of a bottom-origin 4-row image).
        let data = rep.bitmapData!
        for row in 0..<4 {
            for col in 0..<4 {
                let offset = row * 16 + col * 4
                if row < 2 {
                    // Opaque red
                    data[offset]     = 255  // R
                    data[offset + 1] = 0    // G
                    data[offset + 2] = 0    // B
                    data[offset + 3] = 255  // A
                } else {
                    // Transparent
                    data[offset]     = 0
                    data[offset + 1] = 0
                    data[offset + 2] = 0
                    data[offset + 3] = 0
                }
            }
        }
        let img = NSImage(size: NSSize(width: 4, height: 4))
        img.addRepresentation(rep)
        return img
    }

    @Test("Opaque pixel returns true")
    func opaque_pixel_returns_true() {
        let img = makeFixtureImage()
        #expect(HitTesting.isOpaque(at: NSPoint(x: 0.5, y: 3.5), in: img, threshold: 0.1))
    }

    @Test("Transparent pixel returns false")
    func transparent_pixel_returns_false() {
        let img = makeFixtureImage()
        #expect(!HitTesting.isOpaque(at: NSPoint(x: 3, y: 0), in: img, threshold: 0.1))
    }

    @Test("Out-of-bounds returns false")
    func out_of_bounds_returns_false() {
        let img = makeFixtureImage()
        #expect(!HitTesting.isOpaque(at: NSPoint(x: 100, y: 100), in: img, threshold: 0.1))
        #expect(!HitTesting.isOpaque(at: NSPoint(x: -1, y: 0), in: img, threshold: 0.1))
    }
}
