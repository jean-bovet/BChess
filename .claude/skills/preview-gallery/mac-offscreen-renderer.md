# Mac pass: render off screen with `CARenderer`

The Mac pass of the gallery renders each scenario in a real `NSWindow` that is **never ordered on screen**, and
draws the window's whole layer tree with Core Animation's own renderer (`CARenderer`) into a Metal texture at 2
pixels per point. It needs no simulator, works with the screen locked, flashes nothing, and draws what the
on-screen window shows: title bar, toolbar Liquid Glass, sidebar material and rows, `PDFView` pages, materials.
Proven in three repos, matching an on-screen capture of the same windows.

## Why not the other ways

| Way | Falls short because |
|---|---|
| ScreenCaptureKit (`SCScreenshotManager`) | The window must be on screen: it needs an unlocked session (a lock check, a failed night run), flashes every window in front of the user, and needs a Screen Recording permission. |
| `NSView.cacheDisplay(in:to:)` | Draws the view's `draw(_:)` only: no sidebar material, no toolbar glass, no `PDFView` pages; the title bar is missing. |
| `CALayer.render(in:)` | A software render of the layer tree: no materials, no glass, no Metal-backed content; blank or flat where it matters. |
| `NSHostingView` alone (no window) | No `NSToolbar` and no split view: SwiftUI's `.toolbar` and `NavigationSplitView` bridge to AppKit only through a window's hosting controller. |

## The window

- An `NSWindow` subclass that stays where it was put and never reaches the screen:
  `constrainFrameRect(_:to:)` returns the frame unchanged (AppKit otherwise pulls a titled window back on screen),
  and, to be safe, `order(_:relativeTo:)` drops everything but `.out`, and `orderFront`, `orderFrontRegardless` and
  `makeKeyAndOrderFront` do nothing. Optionally put its origin far outside every display (`-30 000, -30 000`).
- A titled screen (one with a toolbar or a split view): `contentViewController = NSHostingController(rootView:)`,
  style `[.titled, .closable, .resizable]` (plus `.fullSizeContentView` when the app uses it), and
  `controller.sizingOptions = []` so the controller does not publish its sizes to the window.
- A component: a plain `NSHostingView` with `sizingOptions = []` and `autoresizingMask = [.width, .height]` in a
  `.borderless` window. A hosting controller that drives a small window's constraints can loop ("more Update
  Constraints passes than views") and crash the host.
- A component's height: measure `view.frame(width:).fixedSize(horizontal: false, vertical: true)` in a probe
  `NSHostingView` and read `fittingSize`. Fail the scenario by name when the height is tiny (a view that fills its
  height has no ideal one: give it a fixed canvas) or above the gallery's limit (it would be clipped and still pass
  the check).
- `window.appearance = NSAppearance(named: .aqua / .darkAqua)`, `isReleasedWhenClosed = false`,
  `ignoresMouseEvents = true`, `setContentSize`. One window per render, closed in a `defer` (end an attached sheet
  first).
- SwiftUI may resize the window to its content's ideal size once it lays out, whatever size was asked. Pinning it
  back can produce a layout the app never shows (cut-off sidebar or bars): measure, and let the card be the window
  as SwiftUI sizes it.

## Readiness without a visible window

- A window that is not on screen gets **no display cycle of its own**. Load it (`_ = window.contentView`) and run
  the passes AppKit would run before showing it: `window.layoutIfNeeded()`,
  `window.contentView?.layoutSubtreeIfNeeded()`, `window.displayIfNeeded()`. That runs `onAppear` and task
  modifiers. Repeat that pass (for the window and its attached sheet) before **every** readiness poll and once more
  before the capture.
- Poll the scenario's readiness predicate every 50 ms up to a timeout that fails the scenario by name, then a short
  fixed tail (about 150–300 ms) for SwiftUI's asynchronous work (list diffing). The tail is not a readiness proxy.
- A predicate never uses `window.isVisible` or `isKeyWindow` (both stay false): test `view.window != nil`, the
  model's state, and `!view.needsDisplay` for a view that draws itself.
- State that needs a mounted window (a confirmation dialog presented as a sheet) is seeded after the first passes,
  then the predicate waits for `window.attachedSheet != nil`.

### `PDFView`

PDFKit offers no draw callback. Wait until the first `PDFView` under the content (depth-first search) has a
`document`, a `currentPage` (or the expected page index), and a `documentView` whose frame is wider and taller than
1 pt; then one more layout and display pass. A custom page overlay adds `!overlay.needsDisplay`.

## The capture

The root of the window's layer tree is the topmost superlayer of the content view's superview (the frame view),
so the title bar and toolbar are included. The skeleton below is the shared part of the three proven renderers
(errors shortened to `fail(...)`; the repo has its own error type).

```swift
import AppKit
import Metal
import QuartzCore

@MainActor
func capture(_ window: NSWindow, scale: CGFloat = 2) throws -> CGImage {
    // Retina guard: AppKit draws each layer's contents at the window's backing scale. On a 1x display a 2x card
    // would be a blurry upscale that still passes the check, so fail by name.
    guard window.backingScaleFactor == scale else { throw fail("needs a Retina (2x) display") }
    guard let content = window.contentView else { throw fail("no content") }
    let frameView = content.superview ?? content
    frameView.layoutSubtreeIfNeeded()
    frameView.displayIfNeeded()
    guard var root = frameView.layer else { throw fail("no layer") }
    while let parent = root.superlayer { root = parent }

    let width = Int((root.frame.width * scale).rounded()), height = Int((root.frame.height * scale).rounded())
    guard width > 0, height > 0, let device = MTLCreateSystemDefaultDevice(),
          let queue = device.makeCommandQueue() else { throw fail("no Metal device") }
    let descriptor = MTLTextureDescriptor.texture2DDescriptor(
        pixelFormat: .bgra8Unorm, width: width, height: height, mipmapped: false)
    descriptor.usage = [.renderTarget, .shaderRead]
    descriptor.storageMode = .shared
    guard let texture = device.makeTexture(descriptor: descriptor) else { throw fail("no texture") }

    // A new texture is undefined: clear it to transparent on the queue the renderer then uses.
    let clear = MTLRenderPassDescriptor()
    clear.colorAttachments[0].texture = texture
    clear.colorAttachments[0].loadAction = .clear
    clear.colorAttachments[0].clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 0)
    clear.colorAttachments[0].storeAction = .store
    guard let clearing = queue.makeCommandBuffer(),
          let encoder = clearing.makeRenderCommandEncoder(descriptor: clear) else { throw fail("no command buffer") }
    encoder.endEncoding()
    clearing.commit()

    let sRGB = CGColorSpace(name: CGColorSpace.sRGB)!
    let renderer = CARenderer(mtlTexture: texture,
                              options: [kCARendererColorSpace: sRGB, kCARendererMetalCommandQueue: queue])
    renderer.layer = root
    renderer.bounds = CGRect(x: 0, y: 0, width: CGFloat(width), height: CGFloat(height))

    // CARenderer maps its bounds 1:1 onto texture pixels and has no projection of its own: the 2x is a scale on the
    // root layer, for this one frame, restored before anything else runs.
    let saved = (root.transform, root.position, root.anchorPoint)
    CATransaction.begin(); CATransaction.setDisableActions(true)
    root.anchorPoint = .zero
    root.position = .zero
    root.transform = CATransform3DMakeScale(scale, scale, 1)
    CATransaction.commit()
    defer {
        CATransaction.begin(); CATransaction.setDisableActions(true)
        (root.transform, root.position, root.anchorPoint) = saved
        CATransaction.commit()
        CATransaction.flush()
    }
    CATransaction.flush()   // commit what AppKit and SwiftUI changed, and the scale

    renderer.beginFrame(atTime: CACurrentMediaTime(), timeStamp: nil)
    renderer.addUpdate(renderer.bounds)
    renderer.render()
    renderer.endFrame()
    // endFrame only submits the GPU work. Wait for it before reading back (a buffer committed after it on the same
    // queue completes after it), or renders come out blank or half drawn.
    guard let fence = queue.makeCommandBuffer() else { throw fail("no command buffer") }
    fence.commit()
    fence.waitUntilCompleted()

    var bytes = [UInt8](repeating: 0, count: width * height * 4)
    texture.getBytes(&bytes, bytesPerRow: width * 4,
                     from: MTLRegionMake2D(0, 0, width, height), mipmapLevel: 0)
    // BGRA, premultiplied, sRGB; the texture's first row is the bottom one: flip the rows.
    guard let provider = CGDataProvider(data: Data(bytes) as CFData),
          let upsideDown = CGImage(
              width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: width * 4,
              space: sRGB,
              bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedFirst.rawValue
                                       | CGBitmapInfo.byteOrder32Little.rawValue),
              provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent),
          let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                                  space: sRGB, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
    else { throw fail("readback") }
    context.translateBy(x: 0, y: CGFloat(height))
    context.scaleBy(x: 1, y: -1)
    context.draw(upsideDown, in: CGRect(x: 0, y: 0, width: width, height: height))
    guard let image = context.makeImage() else { throw fail("no image") }
    return image
}
```

The PNG: `let rep = NSBitmapImageRep(cgImage: image); rep.size = window.frame.size` (so it carries 144 dpi), then
`rep.representation(using: .png, properties: [:])`.

The four details that bite: **wait on the command buffer** before `getBytes` (blank renders otherwise); **scale the
root layer** for the one frame and restore it in `defer` (a point-sized bounds on a 2x texture draws nothing; an
unscaled tree fills a quarter of it); **flip the rows**; the window is **never ordered on screen**.

## Sheets (dialogs)

A sheet is a window of its own (`window.attachedSheet`), not part of the parent's layer tree:

1. Capture the parent as above.
2. Capture the sheet window the same way, with the **parent's picture inserted as the bottom layer** of the
   sheet's tree for that one frame: a `CALayer` with `contents = parentImage`, `contentsGravity = .resize`, its
   frame the parent's frame relative to the sheet's (screen points; when `root.isGeometryFlipped`, y is
   `sheet.frame.maxY - parent.frame.maxY`, else `parent.frame.minY - sheet.frame.minY`), inserted at index 0
   inside a `CATransaction` with actions disabled and removed (then flushed) in a `defer`. Without it the sheet's
   glass samples nothing and draws an opaque grey panel; with it, it samples the parent as on screen.
3. Composite: draw the parent image, then the sheet image at
   `((sheet.frame.minX - parent.frame.minX) * scale, (sheet.frame.minY - parent.frame.minY) * scale)` in a
   bottom-left-origin `CGContext` of the parent's size.

The layout and display passes and the readiness polls cover the attached sheet too.

## What differs from an on-screen capture (accepted)

- **Dark mode is neutral.** There is no wallpaper behind the window, so dark window backgrounds and materials are
  a neutral grey, not tinted by the desktop. Light mode looks the same as on screen.
- **Inactive selection.** The window is never key and the test host is not the active app, so a selected row and
  sidebar text show the inactive (grey) appearance, not the accent colour.
- **Retina only.** The run fails by name on a 1x display (see the guard).
- A view drawn by a `CAMetalLayer` (a live Metal canvas) is skipped by `CARenderer`. Proven in xFractal: render the same
  frame off screen through the app's own encoder at the view's drawable size, and add it for the one capture as a
  `CALayer` (`contents` = that image, `contentsGravity = .resize`, frame = the Metal layer's bounds) **inside** the
  Metal layer, so the views above it (HUD, panels) still draw on top; remove it in a `defer`.

## Tests

- Readiness: a test can mount a scenario's window without capturing (split `mount` from `render`) and assert each
  predicate, including the PDF wait and the sheet.
- No lock or session check, and no lifecycle test for one: the pass runs the same locked or unlocked. Record in
  the run report whether the screen was locked when it ran.
