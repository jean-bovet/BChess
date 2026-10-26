//
//  GalleryPixels.swift
//  BChessGalleryTests
//
//  A small pixel oracle for the layout tests: where a flat colour lands in a capture. The oracles use the
//  resolved Walnut fills (the board frame, the cards), which no shadow (a blended black) or coordinate glyph matches.
//

import SwiftUI
import UIKit

enum GalleryPixels {
    /// The colour a Walnut fill resolves to in the appearance of the capture.
    static func resolved(_ color: Color, style: UIUserInterfaceStyle) -> UIColor {
        UIColor(color).resolvedColor(with: UITraitCollection(userInterfaceStyle: style))
    }

    /// The bounding box, in points, of the solid areas of `image` within `tolerance` of `color` (per channel),
    /// searched only in `region` (points); nil when none. Only a solid square of `block` points counts, so the
    /// strokes of text drawn in a like colour (the frame's brown is also the ink) never match.
    static func boundingBox(of color: UIColor, in image: UIImage, region: CGRect, tolerance: CGFloat = 2.0 / 255,
                            block: CGFloat = 3) -> CGRect? {
        guard let cgImage = image.cgImage else { return nil }
        let width = cgImage.width
        let height = cgImage.height
        let scale = image.scale
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        let drawn = pixels.withUnsafeMutableBytes { buffer -> Bool in
            guard let context = CGContext(data: buffer.baseAddress, width: width, height: height, bitsPerComponent: 8,
                                          bytesPerRow: width * 4, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                          bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return false }
            context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
            return true
        }
        guard drawn else { return nil }

        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        color.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        let target = [red, green, blue].map { $0 * 255 }
        let slack = tolerance * 255 + 0.5

        let x0 = max(0, Int((region.minX * scale).rounded(.down)))
        let x1 = min(width, Int((region.maxX * scale).rounded(.up)))
        let y0 = max(0, Int((region.minY * scale).rounded(.down)))
        let y1 = min(height, Int((region.maxY * scale).rounded(.up)))
        guard x0 < x1, y0 < y1 else { return nil }

        // A summed-area table over the region's matches, so a solid square is one lookup
        let side = max(1, Int((block * scale).rounded(.up)))
        let w = x1 - x0, h = y1 - y0
        var sums = [Int32](repeating: 0, count: (w + 1) * (h + 1))
        for y in 0..<h {
            var row: Int32 = 0
            for x in 0..<w {
                let offset = ((y0 + y) * width + x0 + x) * 4
                if pixels[offset + 3] == 255,
                   abs(CGFloat(pixels[offset]) - target[0]) <= slack,
                   abs(CGFloat(pixels[offset + 1]) - target[1]) <= slack,
                   abs(CGFloat(pixels[offset + 2]) - target[2]) <= slack {
                    row += 1
                }
                sums[(y + 1) * (w + 1) + x + 1] = sums[y * (w + 1) + x + 1] + row
            }
        }
        guard w >= side, h >= side else { return nil }
        var minX = Int.max, minY = Int.max, maxX = -1, maxY = -1
        for y in 0...(h - side) {
            for x in 0...(w - side) {
                let count = sums[(y + side) * (w + 1) + x + side] - sums[y * (w + 1) + x + side]
                    - sums[(y + side) * (w + 1) + x] + sums[y * (w + 1) + x]
                guard Int(count) == side * side else { continue }
                minX = min(minX, x); maxX = max(maxX, x + side - 1)
                minY = min(minY, y); maxY = max(maxY, y + side - 1)
            }
        }
        guard maxX >= 0 else { return nil }
        return CGRect(x: CGFloat(x0 + minX) / scale, y: CGFloat(y0 + minY) / scale,
                      width: CGFloat(maxX - minX + 1) / scale, height: CGFloat(maxY - minY + 1) / scale)
    }
}
