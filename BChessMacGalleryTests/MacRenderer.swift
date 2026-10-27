//
//  MacRenderer.swift
//  BChessMacGalleryTests
//
//  Renders a Mac window off screen: a real NSWindow that is never ordered on screen (title bar, toolbar, sheet and
//  materials as the app shows them), drawn by Core Animation's own renderer (CARenderer) into a Metal texture at 2
//  pixels per point. It needs no display cycle, no unlocked session and no screen-recording permission. The recipe
//  is maestro's preview-gallery/mac-offscreen-renderer.md.
//

import AppKit
import Metal
import QuartzCore
import SwiftUI

enum MacAppearance: String, CaseIterable {
    case light
    case dark

    var name: NSAppearance.Name { self == .light ? .aqua : .darkAqua }
}

struct MacRenderError: Error, CustomStringConvertible {
    let description: String
    init(_ description: String) { self.description = description }
}

/// A window that stays where it was put and never reaches the screen, drawn as the active window (coloured traffic
/// lights, accent-coloured controls) although the test host is never the active app.
final class OffscreenWindow: NSWindow {
    override func constrainFrameRect(_ frameRect: NSRect, to screen: NSScreen?) -> NSRect { frameRect }
    override func order(_ place: NSWindow.OrderingMode, relativeTo otherWin: Int) {
        if place == .out { super.order(place, relativeTo: otherWin) }
    }
    override func orderFront(_ sender: Any?) {}
    override func orderFrontRegardless() {}
    override func makeKeyAndOrderFront(_ sender: Any?) {}
    // A sheet attaches to its parent only when AppKit takes the parent for visible; the window is never ordered on screen
    override var isVisible: Bool { true }
    override var isKeyWindow: Bool { true }
    override var isMainWindow: Bool { true }
    @objc var hasKeyAppearance: Bool { true }
    @objc var hasMainAppearance: Bool { true }
    @objc func _hasActiveAppearance() -> Bool { true }
    @objc func _hasActiveAppearanceIgnoringKeyFocus() -> Bool { true }
    @objc func _hasActiveControls() -> Bool { true }
}

extension MacWindowSize {
    static let styleMask: NSWindow.StyleMask = [.titled, .closable, .miniaturizable, .resizable]

    /// The window's frame in points, the value the mount uses and the manifest records: the given frame, or, for a
    /// window that fits its content, the frame SwiftUI gives a window of that width once it has laid the content out
    /// (measured on a window mounted and closed again: the content's ideal height plus the title bar, which
    /// `sizeThatFits` alone does not reproduce to the point).
    @MainActor
    func points<Content: View>(for view: Content) -> CGSize {
        switch self {
        case .frame(let size):
            return size
        case .fits:
            let window = MacRenderer.makeWindow(view, size: self, appearance: .light)
            defer { MacRenderer.close(window) }
            return window.frame.size
        }
    }
}

@MainActor
enum MacRenderer {
    static let offscreenOrigin = CGPoint(x: -30_000, y: -30_000)
    static let scale: CGFloat = 2

    // MARK: Mount

    /// The scenario's window with its content mounted and the first display passes run; never ordered on screen.
    static func mount(_ scenario: MacGalleryScenario, appearance: MacAppearance) throws -> OffscreenWindow {
        makeWindow(try scenario.view(), size: scenario.size, appearance: appearance)
    }

    static func makeWindow<Content: View>(_ view: Content, size: MacWindowSize, appearance: MacAppearance) -> OffscreenWindow {
        let content = view.environment(\.controlActiveState, .key)
        let window = OffscreenWindow(contentRect: .zero, styleMask: MacWindowSize.styleMask, backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.ignoresMouseEvents = true
        window.appearance = NSAppearance(named: appearance.name)
        // The toolbar and the sheet reach AppKit only through a window's hosting controller. It must not publish its
        // content's sizes to the window.
        let host = NSHostingController(rootView: content)
        host.sizingOptions = []
        window.contentViewController = host
        switch size {
        case .frame(let points):
            window.setFrame(CGRect(origin: offscreenOrigin, size: points), display: false)
        case .fits(let width):
            let fitted = host.sizeThatFits(in: CGSize(width: width, height: 10_000))
            window.setContentSize(CGSize(width: width, height: max(fitted.height, 1).rounded(.up)))
            window.setFrameOrigin(offscreenOrigin)
        }
        _ = window.contentView
        settle(window)
        return window
    }

    /// The display passes AppKit runs before showing a window (a window that is never on screen gets none of its own),
    /// for the window and its attached sheet: this is what runs `onAppear` and the tasks.
    static func settle(_ window: NSWindow) {
        // Presenting the sheet moves the window; the origin only matters to keep it far from every display
        if window is OffscreenWindow, window.frame.origin != offscreenOrigin { window.setFrameOrigin(offscreenOrigin) }
        for target in [window, window.attachedSheet].compactMap({ $0 }) {
            _ = target.contentView
            target.layoutIfNeeded()
            target.contentView?.layoutSubtreeIfNeeded()
            target.displayIfNeeded()
        }
    }

    /// Polls (50 ms, a pass before each poll) until the window shows the scenario's title and, when it has one, its
    /// sheet; fails by name after `timeout`.
    static func waitUntilReady(_ window: NSWindow, _ scenario: MacGalleryScenario, timeout: Duration = .seconds(10)) async throws {
        let clock = ContinuousClock()
        let deadline = clock.now + timeout
        while true {
            settle(window)
            let titleReady = scenario.title.map { window.title == $0 } ?? true
            let sheetReady = !scenario.waitsForSheet || window.attachedSheet != nil
            if titleReady && sheetReady { return }
            guard clock.now < deadline else {
                throw MacRenderError("\(scenario.name): not ready after \(timeout): title \"\(window.title)\" (waiting for "
                    + "\(scenario.title.map { "\"\($0)\"" } ?? "any")), sheet \(window.attachedSheet != nil ? "attached" : "missing")")
            }
            try await Task.sleep(for: .milliseconds(50))
        }
    }

    /// Ends the sheet and closes the window.
    static func close(_ window: NSWindow) {
        if let sheet = window.attachedSheet { window.endSheet(sheet) }
        window.close()
    }

    // MARK: Render

    /// One scenario in one appearance: the PNG (2 pixels per point) and the window's frame in points as mounted.
    static func render(_ scenario: MacGalleryScenario, appearance: MacAppearance) async throws -> (png: Data, frame: CGSize) {
        let window = try mount(scenario, appearance: appearance)
        defer { close(window) }
        try await waitUntilReady(window, scenario)
        try await Task.sleep(for: scenario.settle)
        settle(window)
        let frame = window.frame.size
        // A window SwiftUI resized (to its content's ideal size) would be a wrong slide: never a scaled picture
        if case .frame(let asked) = scenario.size, frame != asked {
            throw MacRenderError("\(scenario.name): mounted at \(Int(frame.width)) x \(Int(frame.height)), not \(Int(asked.width)) x \(Int(asked.height))")
        }
        let image = try capture(window)
        let (width, height) = (Int((frame.width * scale).rounded()), Int((frame.height * scale).rounded()))
        guard image.width == width, image.height == height else {
            throw MacRenderError("\(scenario.name): captured \(image.width) x \(image.height) px, not \(width) x \(height) (the window's frame x \(Int(scale)))")
        }
        return (try png(of: image, size: frame, scenario: scenario.name), frame)
    }

    static func png(of image: CGImage, size: CGSize, scenario: String) throws -> Data {
        let rep = NSBitmapImageRep(cgImage: image)
        rep.size = size
        guard let data = rep.representation(using: .png, properties: [:]) else { throw MacRenderError("\(scenario): no PNG data") }
        return data
    }

    // MARK: Capture

    private static let sRGB = CGColorSpace(name: CGColorSpace.sRGB)!

    private static func bitmap(width: Int, height: Int) -> CGContext? {
        CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0, space: sRGB,
                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
    }

    /// The window with its attached sheet composited over it, at the sheet's position.
    static func capture(_ window: NSWindow) throws -> CGImage {
        let parent = try draw(window)
        guard let sheet = window.attachedSheet else { return parent.image }
        // The sheet's glass samples what lies behind it; on screen that is the parent window. Off screen it would sample
        // nothing, so the parent's picture goes behind the sheet's layer tree for its frame.
        let drawn = try draw(sheet, behind: (parent.image, parent.frame))
        // Both frames are in screen points (origin bottom left); the sheet's offset inside the parent's image.
        let offset = CGPoint(x: (drawn.frame.minX - parent.frame.minX) * scale, y: (drawn.frame.minY - parent.frame.minY) * scale)
        guard let context = bitmap(width: parent.image.width, height: parent.image.height) else {
            throw MacRenderError("no context to composite the sheet")
        }
        context.draw(parent.image, in: CGRect(x: 0, y: 0, width: parent.image.width, height: parent.image.height))
        context.draw(drawn.image, in: CGRect(origin: offset, size: CGSize(width: drawn.image.width, height: drawn.image.height)))
        guard let composited = context.makeImage() else { throw MacRenderError("no composited image") }
        return composited
    }

    /// One window's whole layer tree (title bar, toolbar glass, materials and every view) drawn by `CARenderer` into a
    /// Metal texture at 2 pixels per point, read back upright.
    static func draw(_ window: NSWindow, behind: (image: CGImage, frame: CGRect)? = nil) throws -> (image: CGImage, frame: CGRect) {
        // AppKit draws each layer's contents at the window's backing scale: on a 1x display a 2x capture would be a
        // blurry upscale that still looks fine in the gallery, so fail by name.
        guard window.backingScaleFactor == scale else {
            throw MacRenderError("the Mac gallery needs a Retina (2x) display; this one is \(window.backingScaleFactor)x")
        }
        guard let content = window.contentView else { throw MacRenderError("window without content") }
        let frameView = content.superview ?? content
        frameView.layoutSubtreeIfNeeded()
        frameView.displayIfNeeded()
        guard var root = frameView.layer else { throw MacRenderError("the frame view has no layer") }
        while let parent = root.superlayer { root = parent }

        // What lies behind the window, as the bottom layer of its tree for this one frame; removed before anything else runs.
        var backdrop: CALayer?
        if let behind {
            let layer = CALayer()
            layer.contents = behind.image
            layer.contentsGravity = .resize
            let x = behind.frame.minX - window.frame.minX
            let y = root.isGeometryFlipped ? window.frame.maxY - behind.frame.maxY : behind.frame.minY - window.frame.minY
            layer.frame = CGRect(x: x, y: y, width: behind.frame.width, height: behind.frame.height)
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            root.insertSublayer(layer, at: 0)
            CATransaction.commit()
            backdrop = layer
        }
        defer {
            if let backdrop {
                CATransaction.begin()
                CATransaction.setDisableActions(true)
                backdrop.removeFromSuperlayer()
                CATransaction.commit()
                CATransaction.flush()
            }
        }

        let frame = root.frame
        let width = Int((frame.width * scale).rounded()), height = Int((frame.height * scale).rounded())
        guard width > 0, height > 0, let device = MTLCreateSystemDefaultDevice(), let queue = device.makeCommandQueue() else {
            throw MacRenderError("no Metal device or an empty window (\(width)x\(height))")
        }
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .bgra8Unorm, width: width, height: height, mipmapped: false)
        descriptor.usage = [.renderTarget, .shaderRead]
        descriptor.storageMode = .shared
        guard let texture = device.makeTexture(descriptor: descriptor) else { throw MacRenderError("no Metal texture") }

        // A texture starts undefined: clear it to transparent, on the queue the renderer then uses.
        let clear = MTLRenderPassDescriptor()
        clear.colorAttachments[0].texture = texture
        clear.colorAttachments[0].loadAction = .clear
        clear.colorAttachments[0].clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 0)
        clear.colorAttachments[0].storeAction = .store
        guard let clearing = queue.makeCommandBuffer(), let encoder = clearing.makeRenderCommandEncoder(descriptor: clear) else {
            throw MacRenderError("no Metal command buffer")
        }
        encoder.endEncoding()
        clearing.commit()

        let renderer = CARenderer(mtlTexture: texture, options: [kCARendererColorSpace: sRGB, kCARendererMetalCommandQueue: queue])
        renderer.layer = root
        renderer.bounds = CGRect(x: 0, y: 0, width: CGFloat(width), height: CGFloat(height))

        // CARenderer maps its bounds 1:1 onto texture pixels and has no projection of its own: the 2x is a scale on the
        // root layer, for this one frame, restored before anything else runs.
        let saved = (transform: root.transform, position: root.position, anchorPoint: root.anchorPoint)
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        root.anchorPoint = .zero
        root.position = .zero
        root.transform = CATransform3DMakeScale(scale, scale, 1)
        CATransaction.commit()
        defer {
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            root.transform = saved.transform
            root.position = saved.position
            root.anchorPoint = saved.anchorPoint
            CATransaction.commit()
            CATransaction.flush()
        }
        // Commit what AppKit and SwiftUI changed (and the scale), so the renderer sees the finished tree.
        CATransaction.flush()
        renderer.beginFrame(atTime: CACurrentMediaTime(), timeStamp: nil)
        renderer.addUpdate(renderer.bounds)
        renderer.render()
        renderer.endFrame()
        // endFrame only submits the GPU work: wait for it (a buffer on the same queue completes after it) before reading back.
        guard let fence = queue.makeCommandBuffer() else { throw MacRenderError("no Metal command buffer") }
        fence.commit()
        fence.waitUntilCompleted()

        var bytes = [UInt8](repeating: 0, count: width * height * 4)
        texture.getBytes(&bytes, bytesPerRow: width * 4, from: MTLRegionMake2D(0, 0, width, height), mipmapLevel: 0)
        // BGRA, premultiplied, sRGB; the texture's first row is the bottom one.
        guard let provider = CGDataProvider(data: Data(bytes) as CFData),
              let upsideDown = CGImage(
                  width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: width * 4, space: sRGB,
                  bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue),
                  provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent),
              let context = bitmap(width: width, height: height)
        else { throw MacRenderError("could not read the Metal texture back") }
        context.translateBy(x: 0, y: CGFloat(height))
        context.scaleBy(x: 1, y: -1)
        context.draw(upsideDown, in: CGRect(x: 0, y: 0, width: width, height: height))
        guard let image = context.makeImage() else { throw MacRenderError("no image") }
        return (image, window.frame)
    }
}
