#!/usr/bin/env swift
// Renders the 12 piece SVGs in Art/pieces/ to the 1024 x 1024 vector PDFs of the asset catalog.
//   swift scripts/render-pieces.swift            (from the repository root)
// Each SVG is checked against its pinned SHA-1 (planning/LEGAL-1-piece-artwork.md); the art is drawn 1:1, unscaled.
import AppKit
import CryptoKit

let root = URL(fileURLWithPath: CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : FileManager.default.currentDirectoryPath)
let canvas: CGFloat = 1024

// asset name, Commons file, SHA-1 of the current revision
let pieces: [(String, String, String)] = [
    ("king_w", "Chess_klt45", "2c7569b837971207e40f7148e2b2086aaf8e4bbd"),
    ("queen_w", "Chess_qlt45", "e638eb28ec25007b9f8fac8476bdf6ae1fc5a0ee"),
    ("rook_w", "Chess_rlt45", "126b7779885b87e87acc713474587732711bc8d3"),
    ("bishop_w", "Chess_blt45", "35dd477dc22636bfcc559a01f75b00369205ffda"),
    ("knight_w", "Chess_nlt45", "3a2253429c0e39863b3f5ecf447209dccecdc337"),
    ("pawn_w", "Chess_plt45", "09d59e2770fcee23722ac53b26e875f76d2c1eb1"),
    ("king_b", "Chess_kdt45", "b1165ef85a3df6f1af2549ab0af78ab21b540e8a"),
    ("queen_b", "Chess_qdt45", "ed72e75b7bdbf880a3c9bee053c8786cfab8bdb9"),
    ("rook_b", "Chess_rdt45", "bd0e866f1e6da8e3d6f9c0b356b60fc58391aff6"),
    ("bishop_b", "Chess_bdt45", "da6dd1b5ef629bacebbd2ce26c7d81ba8a205587"),
    ("knight_b", "Chess_ndt45", "3c79cbbda76bcf1d4e4062cef6dd3b58a250a562"),
    ("pawn_b", "Chess_pdt45", "0a6d2f3dc6327a02ca591bc489d701fbff228138"),
]

func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data((message + "\n").utf8))
    exit(1)
}

for (asset, file, sha1) in pieces {
    let svg = root.appendingPathComponent("Art/pieces/\(file).svg")
    guard let data = try? Data(contentsOf: svg) else { fail("cannot read \(svg.lastPathComponent)") }
    let digest = Insecure.SHA1.hash(data: data).map { String(format: "%02x", $0) }.joined()
    guard digest == sha1 else { fail("\(file).svg: SHA-1 \(digest) differs from the pinned \(sha1)") }
    guard let image = NSImage(contentsOf: svg) else { fail("cannot decode \(file).svg") }

    let pdf = root.appendingPathComponent("Shared/Assets.xcassets/pieces/\(asset).imageset/\(asset).pdf")
    var box = CGRect(x: 0, y: 0, width: canvas, height: canvas)
    guard let context = CGContext(pdf as CFURL, mediaBox: &box, nil) else { fail("cannot create \(pdf.lastPathComponent)") }
    context.beginPDFPage(nil)
    let graphics = NSGraphicsContext(cgContext: context, flipped: false)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = graphics
    image.draw(in: box, from: .zero, operation: .sourceOver, fraction: 1)
    NSGraphicsContext.restoreGraphicsState()
    context.endPDFPage()
    context.closePDF()
    print("\(asset).pdf")
}
