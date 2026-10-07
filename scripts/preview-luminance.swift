// Prints "<mean luminance 0...1> <file>" for every PNG in the directories given as arguments.
// scripts/preview-gallery.py uses it to check that light renders are light and dark renders are dark.
import CoreGraphics
import Foundation
import ImageIO

func luminance(_ path: String) -> Double? {
    guard let source = CGImageSourceCreateWithURL(URL(fileURLWithPath: path) as CFURL, nil),
          let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else { return nil }
    let width = 40, height = 80
    var pixels = [UInt8](repeating: 0, count: width * height * 4)
    guard let context = CGContext(data: &pixels, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
                                  space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
    context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
    var sum = 0.0
    for i in stride(from: 0, to: pixels.count, by: 4) {
        sum += 0.299 * Double(pixels[i]) + 0.587 * Double(pixels[i + 1]) + 0.114 * Double(pixels[i + 2])
    }
    return sum / Double(width * height) / 255
}

for directory in CommandLine.arguments.dropFirst() {
    let files = ((try? FileManager.default.contentsOfDirectory(atPath: directory)) ?? []).filter { $0.hasSuffix(".png") }.sorted()
    for file in files {
        print(String(format: "%.6f %@", luminance(directory + "/" + file) ?? -1, file))
    }
}
