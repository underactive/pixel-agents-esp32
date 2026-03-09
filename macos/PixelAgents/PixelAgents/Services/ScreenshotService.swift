import Foundation
import AppKit
import UniformTypeIdentifiers

/// Captures screenshots from the ESP32 over serial.
/// Screenshot protocol uses distinct sync bytes (0xBB 0x66) and RLE-encoded RGB565 pixel data.
enum ScreenshotService {

    private static let timeoutSec: TimeInterval = 15.0

    /// Capture a screenshot from the device and save as PNG.
    /// Returns the saved file URL on success.
    static func capture(via serial: SerialTransport) -> URL? {
        // Send screenshot request
        let msg = ProtocolBuilder.screenshotRequest()
        guard serial.send(msg) else { return nil }

        let deadline = Date().addingTimeInterval(timeoutSec)

        // Scan for screenshot sync bytes (0xBB 0x66)
        guard waitForSync(serial: serial, deadline: deadline) else { return nil }

        // Read 10-byte header
        guard let headerData = serial.readExact(count: 10, deadline: deadline) else { return nil }

        let widthHi = UInt16(headerData[0]) << 8
        let widthLo = UInt16(headerData[1])
        let width = Int(widthHi | widthLo)

        let heightHi = UInt16(headerData[2]) << 8
        let heightLo = UInt16(headerData[3])
        let height = Int(heightHi | heightLo)

        let tp3 = UInt32(headerData[4]) << 24
        let tp2 = UInt32(headerData[5]) << 16
        let tp1 = UInt32(headerData[6]) << 8
        let tp0 = UInt32(headerData[7])
        let totalPixels = Int(tp3 | tp2 | tp1 | tp0)

        guard width > 0, width < 1024, height > 0, height < 1024,
              totalPixels == width * height else { return nil }

        // Read RLE data
        var pixels: [(UInt8, UInt8, UInt8)] = []
        pixels.reserveCapacity(totalPixels)

        while pixels.count < totalPixels {
            if Date() > deadline { break }

            guard let entry = serial.readExact(count: 4, deadline: deadline) else { break }

            let runCount = Int(UInt16(entry[0]) << 8 | UInt16(entry[1]))
            if runCount == 0 { break } // end marker

            let pixel = UInt16(entry[2]) << 8 | UInt16(entry[3])
            let rgb = rgb565ToRGB888(pixel)

            for _ in 0..<runCount {
                pixels.append(rgb)
            }
        }

        // Pad with black if needed
        while pixels.count < totalPixels {
            pixels.append((0, 0, 0))
        }

        // Create image and save
        guard let image = createImage(width: width, height: height, pixels: pixels) else { return nil }
        return saveImage(image, width: width, height: height)
    }

    // MARK: - Private

    private static func waitForSync(serial: SerialTransport, deadline: Date) -> Bool {
        var foundFirst = false

        while Date() < deadline {
            guard let byte = serial.readExact(count: 1, deadline: deadline) else { return false }

            if !foundFirst {
                if byte[0] == ProtocolBuilder.screenshotSync1 {
                    foundFirst = true
                }
            } else {
                if byte[0] == ProtocolBuilder.screenshotSync2 {
                    return true
                }
                foundFirst = false
            }
        }
        return false
    }

    private static func rgb565ToRGB888(_ pixel: UInt16) -> (UInt8, UInt8, UInt8) {
        var r = UInt8(((pixel >> 11) & 0x1F) << 3)
        var g = UInt8(((pixel >> 5) & 0x3F) << 2)
        var b = UInt8((pixel & 0x1F) << 3)
        r |= r >> 5
        g |= g >> 6
        b |= b >> 5
        return (r, g, b)
    }

    private static func createImage(width: Int, height: Int, pixels: [(UInt8, UInt8, UInt8)]) -> CGImage? {
        var rgba = Data(capacity: width * height * 4)
        for (r, g, b) in pixels {
            rgba.append(r)
            rgba.append(g)
            rgba.append(b)
            rgba.append(255) // alpha
        }

        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let provider = CGDataProvider(data: rgba as CFData) else { return nil }

        return CGImage(
            width: width,
            height: height,
            bitsPerComponent: 8,
            bitsPerPixel: 32,
            bytesPerRow: width * 4,
            space: colorSpace,
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
            provider: provider,
            decode: nil,
            shouldInterpolate: false,
            intent: .defaultIntent
        )
    }

    private static func saveImage(_ image: CGImage, width: Int, height: Int) -> URL? {
        let picturesDir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Pictures/PixelAgents")
        try? FileManager.default.createDirectory(at: picturesDir, withIntermediateDirectories: true)

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        let filename = "screenshot-\(formatter.string(from: Date())).png"
        let url = picturesDir.appendingPathComponent(filename)

        guard let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)
        else { return nil }

        CGImageDestinationAddImage(dest, image, nil)
        guard CGImageDestinationFinalize(dest) else { return nil }

        return url
    }
}
