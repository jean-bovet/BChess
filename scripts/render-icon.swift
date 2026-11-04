// Renders the app icon: a carved walnut knight on a board of two real veneers, in every PNG of AppIcon.appiconset.
//   swiftc -O scripts/render-icon.swift -o /tmp/render-icon && /tmp/render-icon [repository root] [output folder]
// Needs macOS (AppKit renders the SVG) and ImageMagick 7 (`magick`, on PATH) for the masks, the board and the Mac cut.
// Inputs, all in the repository (checked against their pinned SHA-1, see Art/icon/SOURCES.txt):
//   Art/pieces/Chess_ndt45.svg   the knight (Wikimedia Commons, Cburnett, BSD)
//   Art/icon/okoume_veneer.jpg   light squares   (Poly Haven, CC0)
//   Art/icon/teak_veneer.jpg     dark squares    (Poly Haven, CC0)
// Writes the five kinds of file the catalog names: AppIcon-iOS-1024.png (opaque), AppIcon-Dark.png, AppIcon-Tinted.png
// (grayscale) and AppIcon-mac-{16,32,64,128,256,512,1024}.png (rounded square with its shadow).
// Method (planning/LEGAL-1-piece-artwork.md, the icon step): the knight's outline and its inner lines become two masks;
// the masks become a height field (a bevel plus a soft dome, grooves cut by the inner lines); that is lit by one light
// as walnut with a warm rim light, over the board, with a cast shadow. The same height field is lit three times: a light
// look, a night look (board turned down, knight lifted) and a tinted look (converted to gray).
import AppKit
import CryptoKit
import simd

let N = 1024

func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data((message + "\n").utf8))
    exit(1)
}

// MARK: Process helpers

@discardableResult
func magick(_ args: [String]) -> String {
    let p = Process()
    p.executableURL = URL(fileURLWithPath: "/usr/bin/env")
    p.arguments = ["magick"] + args
    let out = Pipe()
    p.standardOutput = out
    do { try p.run() } catch { fail("cannot run magick: \(error)") }
    let data = out.fileHandleForReading.readDataToEndOfFile()
    p.waitUntilExit()
    guard p.terminationStatus == 0 else { fail("magick \(args.joined(separator: " ")) failed") }
    return String(decoding: data, as: UTF8.self)
}

func sha1(_ url: URL) -> String {
    guard let data = try? Data(contentsOf: url) else { fail("cannot read \(url.lastPathComponent)") }
    return Insecure.SHA1.hash(data: data).map { String(format: "%02x", $0) }.joined()
}

// MARK: Arguments and inputs

let root = URL(fileURLWithPath: CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : FileManager.default.currentDirectoryPath)
let outDir = URL(fileURLWithPath: CommandLine.arguments.count > 2
                 ? CommandLine.arguments[2] : root.appendingPathComponent("Shared/Assets.xcassets/AppIcon.appiconset").path)
let work = FileManager.default.temporaryDirectory.appendingPathComponent("render-icon-\(getpid())")
try? FileManager.default.createDirectory(at: work, withIntermediateDirectories: true)
defer { if ProcessInfo.processInfo.environment["RENDER_ICON_KEEP"] == nil { try? FileManager.default.removeItem(at: work) } }
func w(_ name: String) -> String { work.appendingPathComponent(name).path }

let knightSVG = root.appendingPathComponent("Art/pieces/Chess_ndt45.svg")
let lightTexture = root.appendingPathComponent("Art/icon/okoume_veneer.jpg")
let darkTexture = root.appendingPathComponent("Art/icon/teak_veneer.jpg")
for (url, pinned) in [(knightSVG, "3c79cbbda76bcf1d4e4062cef6dd3b58a250a562"),
                      (lightTexture, "985e78b7ef27af48c0285216c415d893a693fe9a"),
                      (darkTexture, "0d8a1c8f5419140fd39435abb772b1b771eb9f44")] {
    let digest = sha1(url)
    guard digest == pinned else { fail("\(url.lastPathComponent): SHA-1 \(digest) differs from the pinned \(pinned)") }
}

// MARK: Masks (the black knight, drawn 1:1 on a 1024 canvas)

guard let image = NSImage(contentsOf: knightSVG) else { fail("cannot decode the knight SVG") }
guard let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: N, pixelsHigh: N, bitsPerSample: 8, samplesPerPixel: 4,
                                 hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)
else { fail("cannot make a bitmap") }
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
image.draw(in: NSRect(x: 0, y: 0, width: N, height: N))
NSGraphicsContext.restoreGraphicsState()
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: w("knight.png")))

// The silhouette (alpha at 50 %), trimmed, 560 px wide; the inner lines (luminance over 55 % on black) with the same crop.
let trim = magick([w("knight.png"), "-alpha", "extract", "-threshold", "50%", "-trim", "-format", "%wx%h%O", "info:"])
magick([w("knight.png"), "-alpha", "extract", "-threshold", "50%", "-crop", trim, "+repage", "-resize", "560x", w("sk.png")])
magick([w("knight.png"), "-background", "black", "-alpha", "remove", "-alpha", "off", "-colorspace", "Gray",
        "-threshold", "55%", "-crop", trim, "+repage", "-resize", "560x", w("dk.png")])
// The knight sits at +232+153 on the canvas; the base is three stacked bars, the grooves two thin ones.
magick(["-size", "1024x1024", "xc:black", w("sk.png"), "-geometry", "+232+153", "-composite", "-fill", "white",
        "-draw", "roundrectangle 262,708 762,756 14,14", "-draw", "roundrectangle 232,764 792,812 16,16",
        "-draw", "roundrectangle 202,820 822,878 18,18", w("silh.png")])
magick(["-size", "1024x1024", "xc:black", w("dk.png"), "-geometry", "+232+153", "-composite", "-fill", "white",
        "-draw", "rectangle 262,756 762,764", "-draw", "rectangle 232,812 792,820", w("det.png")])

// MARK: Board: the centre of each veneer, scaled so its mean colour is the target, laid out as a 2 x 2 checker

func veneer(_ source: URL, _ target: SIMD3<Double>, _ out: String) {
    let crop = ["-gravity", "center", "-crop", "1536x1536+0+0", "+repage", "-resize", "1024x"]
    let base = w("veneer-base.png")
    magick([source.path] + crop + [base])
    let mean = magick([base, "-format", "%[fx:mean.r] %[fx:mean.g] %[fx:mean.b]", "info:"])
        .split(separator: " ").compactMap { Double($0) }
    guard mean.count == 3 else { fail("cannot measure \(source.lastPathComponent)") }
    magick([base, "-channel", "R", "-evaluate", "multiply", "\(target.x / mean[0])",
            "-channel", "G", "-evaluate", "multiply", "\(target.y / mean[1])",
            "-channel", "B", "-evaluate", "multiply", "\(target.z / mean[2])", "+channel", out])
}
veneer(lightTexture, SIMD3(0.92, 0.77, 0.585), w("light.png"))
veneer(darkTexture, SIMD3(0.565, 0.305, 0.146), w("dark.png"))
// Top-left and bottom-right squares come from the light veneer, the other two from the dark one, each at its own place.
magick([w("light.png"),
        "(", w("dark.png"), "-crop", "512x512+512+0", "+repage", ")", "-geometry", "+512+0", "-composite",
        "(", w("dark.png"), "-crop", "512x512+0+512", "+repage", ")", "-geometry", "+0+512", "-composite", w("board.png")])

// MARK: Pixels

func loadGray(_ path: String) -> [Float] {
    guard let s = CGImageSourceCreateWithURL(URL(fileURLWithPath: path) as CFURL, nil),
          let i = CGImageSourceCreateImageAtIndex(s, 0, nil) else { fail("cannot read \(path)") }
    var b = [UInt8](repeating: 0, count: N * N)
    let c = CGContext(data: &b, width: N, height: N, bitsPerComponent: 8, bytesPerRow: N, space: CGColorSpaceCreateDeviceGray(), bitmapInfo: 0)!
    c.draw(i, in: CGRect(x: 0, y: 0, width: N, height: N))
    return b.map { Float($0) / 255 }
}

func loadRGB(_ path: String) -> [UInt8] {
    guard let s = CGImageSourceCreateWithURL(URL(fileURLWithPath: path) as CFURL, nil),
          let i = CGImageSourceCreateImageAtIndex(s, 0, nil) else { fail("cannot read \(path)") }
    var b = [UInt8](repeating: 0, count: N * N * 4)
    let c = CGContext(data: &b, width: N, height: N, bitsPerComponent: 8, bytesPerRow: N * 4, space: CGColorSpaceCreateDeviceRGB(),
                      bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
    c.draw(i, in: CGRect(x: 0, y: 0, width: N, height: N))
    return b
}

func writePNG(_ px: inout [UInt8], _ path: String) {
    let cg = CGContext(data: &px, width: N, height: N, bitsPerComponent: 8, bytesPerRow: N * 4, space: CGColorSpaceCreateDeviceRGB(),
                       bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
    let d = CGImageDestinationCreateWithURL(URL(fileURLWithPath: path) as CFURL, "public.png" as CFString, 1, nil)!
    CGImageDestinationAddImage(d, cg.makeImage()!, nil)
    CGImageDestinationFinalize(d)
}

/// Box blur three times, a close match for a Gaussian.
func box(_ a: [Float], _ r: Int) -> [Float] {
    var o = a, t = a
    let wd = Float(2 * r + 1)
    for y in 0..<N {
        var s: Float = 0
        for k in -r...r { s += a[y * N + min(max(k, 0), N - 1)] }
        for x in 0..<N { t[y * N + x] = s / wd; s += a[y * N + min(x + r + 1, N - 1)] - a[y * N + max(x - r, 0)] }
    }
    for x in 0..<N {
        var s: Float = 0
        for k in -r...r { s += t[min(max(k, 0), N - 1) * N + x] }
        for y in 0..<N { o[y * N + x] = s / wd; s += t[min(y + r + 1, N - 1) * N + x] - t[max(y - r, 0) * N + x] }
    }
    return o
}
func blur(_ a: [Float], _ r: Int) -> [Float] { box(box(box(a, r), r), r) }

// Value noise for the knight's own walnut grain (the board's grain is the photographed veneer).
func h2(_ x: Int, _ y: Int, _ s: Int) -> Float {
    var h = UInt32(truncatingIfNeeded: x &* 374761393 &+ y &* 668265263 &+ s &* 1274126177)
    h = (h ^ (h >> 13)) &* 1274126177
    h ^= h >> 16
    return Float(h & 0xffff) / 65535
}
func vn(_ x: Float, _ y: Float, _ s: Int) -> Float {
    let xi = Int(floor(x)), yi = Int(floor(y))
    var fx = x - Float(xi), fy = y - Float(yi)
    fx = fx * fx * (3 - 2 * fx)
    fy = fy * fy * (3 - 2 * fy)
    let a = h2(xi, yi, s), b = h2(xi + 1, yi, s), c = h2(xi, yi + 1, s), d = h2(xi + 1, yi + 1, s)
    return (a + (b - a) * fx) * (1 - fy) + (c + (d - c) * fx) * fy
}
func fbm(_ x: Float, _ y: Float, _ s: Int) -> Float {
    var t: Float = 0, a: Float = 0.5, f: Float = 1
    for o in 0..<5 { t += a * vn(x * f, y * f, s + o); a *= 0.5; f *= 2 }
    return t
}
/// Grain runs along x. Returns 0...1: growth rings plus fine fibres.
func wood(_ xx: Float, _ yy: Float, _ s: Int) -> Float {
    let warp = fbm(xx * 0.0009, yy * 0.0035, s)
    let rings = 0.5 + 0.5 * sin(yy * 0.10 + warp * 7)
    let fibre = fbm(xx * 0.012, yy * 0.55, s + 9)
    let pore = fbm(xx * 0.03, yy * 1.1, s + 21)
    return min(max(0.30 * rings + 0.42 * fibre + 0.28 * pore, 0), 1)
}
func mix(_ a: SIMD3<Float>, _ b: SIMD3<Float>, _ t: Float) -> SIMD3<Float> { a + (b - a) * t }

// MARK: The carved knight

let silh = loadGray(w("silh.png")), det = loadGray(w("det.png"))
let board = loadRGB(w("board.png"))
let bev = blur(silh, 7), dome = blur(silh, 32), gro = blur(det, 3), sh = blur(silh, 22), ct = blur(silh, 6)
var hgt = [Float](repeating: 0, count: N * N)
for i in 0..<N * N {
    let b = min(max((bev[i] - 0.05) / 0.9, 0), 1)
    hgt[i] = (b * b * (3 - 2 * b)) * 1.0 + dome[i] * 0.7 - gro[i] * 0.34 * silh[i]
}
hgt = box(hgt, 1)

let walnut = (SIMD3<Float>(0.20, 0.115, 0.07), SIMD3<Float>(0.04, 0.022, 0.014))
let L = simd_normalize(SIMD3<Float>(-0.55, -0.62, 0.58)), V = SIMD3<Float>(0, 0, 1)
let H = simd_normalize(L + V)

/// How the same carving is lit: the board is multiplied by `boardGain`, the walnut by `lift`, the rim light by `rimGain`
/// (and tinted `rimColor`). The light look changes nothing.
struct Look {
    var boardGain = SIMD3<Float>(1, 1, 1)
    var lift = SIMD3<Float>(1, 1, 1)
    var rimGain: Float = 1
    var rimColor = SIMD3<Float>(0.95, 0.74, 0.46)
}
let lightLook = Look()
let nightLook = Look(boardGain: SIMD3(0.20, 0.25, 0.46), lift: SIMD3(2.4, 2.3, 2.6), rimGain: 1.5, rimColor: SIMD3(0.86, 0.80, 0.70))
let tintedLook = Look(boardGain: SIMD3(0.10, 0.10, 0.10), lift: SIMD3(2.6, 2.6, 2.6), rimGain: 1.6, rimColor: SIMD3(0.95, 0.95, 0.95))

func render(_ look: Look) -> [UInt8] {
    var px = [UInt8](repeating: 255, count: N * N * 4)
    for y in 0..<N {
        for x in 0..<N {
            let i = y * N + x, fx = Float(x), fy = Float(y)
            var bc = SIMD3<Float>(Float(board[i * 4]) / 255, Float(board[i * 4 + 1]) / 255, Float(board[i * 4 + 2]) / 255) * look.boardGain
            // a fine joint between the squares
            let e = min(abs(fx - 512), abs(fy - 512))
            if e < 1.5 { bc *= 0.72 }
            // cast shadow, offset down-right, and contact shadow
            let sx = min(max(x - 16, 0), N - 1), sy = min(max(y - 22, 0), N - 1)
            bc *= 1 - 0.62 * sh[sy * N + sx]
            bc *= 1 - 0.35 * ct[min(max(y - 5, 0), N - 1) * N + min(max(x - 4, 0), N - 1)]
            var c = bc
            if silh[i] > 0.004 {
                let dx = hgt[y * N + min(x + 1, N - 1)] - hgt[y * N + max(x - 1, 0)]
                let dy = hgt[min(y + 1, N - 1) * N + x] - hgt[max(y - 1, 0) * N + x]
                let n = simd_normalize(SIMD3<Float>(-dx * 30, -dy * 30, 1))
                let g = wood(fy * 0.8 + 90, fx * 0.8, 77)
                var al = mix(walnut.1, walnut.0, pow(g, 1.3))
                let d = max(simd_dot(n, L), 0), s = pow(max(simd_dot(n, H), 0), 34)
                let edge = max(1 - n.z, 0)
                al = al * look.lift * (0.30 + 1.15 * d)
                let rim = look.rimColor * look.rimGain * (0.5 * s + 1.2 * pow(edge, 1.6) * max(simd_dot(n, L), 0))
                c = bc + (al + rim - bc) * min(max(silh[i], 0), 1)
            }
            let vx = (fx - 512) / 724, vy = (fy - 512) / 724
            c *= 1 - 0.22 * (vx * vx + vy * vy)
            for k in 0..<3 { px[i * 4 + k] = UInt8(min(max(c[k], 0), 1) * 255) }
        }
    }
    return px
}

var lightPx = render(lightLook), nightPx = render(nightLook), tintedPx = render(tintedLook)
writePNG(&lightPx, w("light-art.png"))
writePNG(&nightPx, w("night-art.png"))
writePNG(&tintedPx, w("tinted-art.png"))

// MARK: Files

try? FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)
func out(_ name: String) -> String { outDir.appendingPathComponent(name).path }

// iOS: square corners and no alpha channel, as Apple requires; the system rounds them.
magick([w("light-art.png"), "-alpha", "off", "-depth", "8", "-strip", out("AppIcon-iOS-1024.png")])
magick([w("night-art.png"), "-alpha", "off", "-depth", "8", "-strip", out("AppIcon-Dark.png")])
magick([w("tinted-art.png"), "-alpha", "off", "-colorspace", "Gray", "-depth", "8", "-strip", out("AppIcon-Tinted.png")])

// Mac: the art at 824 px on a 1024 canvas (100 px inset), cut to a rounded square of radius 185.4 px (drawn at 4x for a
// smooth edge), with two black shadows measured on the earlier Mac icon: ambient (12 %, sigma 9) and a drop shadow (22 %,
// sigma 8, 12 px down).
magick(["-size", "3296x3296", "xc:black", "-fill", "white", "-draw", "roundrectangle 0,0 3295,3295 741.6,741.6",
        "-filter", "Lanczos", "-resize", "824x824", w("mask.png")])
magick([w("light-art.png"), "-colorspace", "sRGB", "-resize", "824x824", w("mask.png"), "-alpha", "off", "-compose", "CopyOpacity", "-composite",
        "-colorspace", "sRGB", w("cut.png")])
magick(["-size", "1024x1024", "xc:none", w("cut.png"), "-geometry", "+100+100", "-composite", w("cut-1024.png")])
func shadow(_ opacity: Double, _ sigma: Double, _ dy: Int, _ name: String) {
    magick([w("cut-1024.png"), "-alpha", "extract", "-background", "black", "-alpha", "shape",
            "-channel", "A", "-evaluate", "multiply", "\(opacity)", "+channel", "-roll", "+0+\(dy)",
            "-blur", "0x\(sigma)", "-colorspace", "sRGB", w(name)])
}
shadow(0.12, 9, 0, "shadow-a.png")
shadow(0.22, 8, 12, "shadow-b.png")
magick([w("shadow-a.png"), w("shadow-b.png"), "-compose", "Over", "-composite", w("shadows.png")])
// The art is the base and the shadows go under it, so the result keeps the art's colour.
magick([w("cut-1024.png"), w("shadows.png"), "-compose", "DstOver", "-composite", "-depth", "8", "-strip", w("mac-1024.png")])
for size in [16, 32, 64, 128, 256, 512, 1024] {
    if size == 1024 {
        try? FileManager.default.removeItem(atPath: out("AppIcon-mac-1024.png"))
        try? FileManager.default.copyItem(atPath: w("mac-1024.png"), toPath: out("AppIcon-mac-1024.png"))
    } else {
        magick([w("mac-1024.png"), "-filter", "Lanczos", "-resize", "\(size)x\(size)", "-strip", out("AppIcon-mac-\(size).png")])
    }
}
print("wrote the icon to \(outDir.lastPathComponent)")
