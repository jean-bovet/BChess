import SwiftUI
import UIKit
import Foundation
import Testing
@testable import BChess

extension GallerySuites {

    /// Renders every `GalleryScenarios.all` entry in light and dark into `$BCHESS_SNAPSHOT_DIR` as
    /// `<slug>.png` and `<slug>.dark.png`, plus `manifest.json`, the files `scripts/preview-gallery.py`
    /// reads. Skipped when the variable is absent, so a normal test run writes nothing.
    /// `$BCHESS_SNAPSHOT_ONLY` (comma-separated substrings of names or slugs) renders a subset. Run it
    /// with `scripts/snapshot-gallery.sh`.
    @MainActor @Suite struct SnapshotGalleryTests {
        /// True on the Duo pass (`scripts/snapshot-gallery.sh --device duo`): every capture is at the display's 3x.
        static let duoPass = ProcessInfo.processInfo.environment["BCHESS_SNAPSHOT_DEVICE"] == "duo"

        /// True on the iPad pass (`scripts/snapshot-gallery.sh --device ipad`): an iPad Pro 13-inch, 1032 x 1376 pt at 2x.
        static let ipadPass = ProcessInfo.processInfo.environment["BCHESS_SNAPSHOT_DEVICE"] == "ipad"

        private static let snapshotDirectory = ProcessInfo.processInfo.environment["BCHESS_SNAPSHOT_DIR"].flatMap { $0.isEmpty ? nil : $0 }

        @Test("render every scenario in light and dark",
              .enabled(if: ProcessInfo.processInfo.environment["BCHESS_SNAPSHOT_DIR"]?.isEmpty == false,
                       "set BCHESS_SNAPSHOT_DIR (TEST_RUNNER_BCHESS_SNAPSHOT_DIR on the xcodebuild command line) to render the gallery"))
        func renderEveryScenarioInLightAndDark() async throws {
            let directory = URL(fileURLWithPath: try #require(Self.snapshotDirectory))
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

            if Self.duoPass {
                // Before the first capture: nothing is labelled "outer display" on a simulator that is not
                let problem = try Self.duoPassProblem()
                try #require(problem == nil, Comment(rawValue: problem ?? ""))
                let screen = try Self.screenSize()
                print("gallery: duo screen \(Int(screen.width)) x \(Int(screen.height)) pt")
            }

            let slugs = GalleryScenarios.all.map(\.slug)
            #expect(Set(slugs).count == slugs.count, "two scenarios share a slug")

            let filter = ProcessInfo.processInfo.environment["BCHESS_SNAPSHOT_ONLY"] ?? ""
            let scenarios = GalleryScenarios.matching(filter)
            try #require(!scenarios.isEmpty, "no scenario matches \(filter)")

            let screen = try Self.screenSize()
            let clock = ContinuousClock()
            var rendered = 0
            for scenario in scenarios {
                if let reason = scenario.skipReason(duoPass: Self.duoPass, ipadPass: Self.ipadPass) {
                    print("gallery: skipped \(scenario.slug): \(reason)")
                    continue
                }
                let started = clock.now
                for style in [UIUserInterfaceStyle.light, .dark] {
                    let png = try await Self.render(scenario, style: style)
                    let name = scenario.slug + (style == .dark ? ".dark.png" : ".png")
                    try png.write(to: directory.appendingPathComponent(name))
                }
                print("gallery: \(scenario.slug) \(clock.now - started)")
                rendered += 1
            }

            // The manifest always lists every scenario, so a partial run still knows the whole gallery.
            let manifest = GalleryScenarios.all.map {
                GalleryManifestEntry(name: $0.name, group: $0.group, slug: $0.slug,
                              size: "\(Int($0.size.points(screen: screen).width))x\(Int($0.size.points(screen: screen).height))",
                              platform: $0.size.platform(ipadPass: Self.ipadPass),
                              skipped: $0.skipReason(duoPass: Self.duoPass, ipadPass: Self.ipadPass),
                              documentCanvas: $0.documentCanvas ? true : nil, drawsNothing: $0.drawsNothing ? true : nil,
                              imagery: $0.imagery ? true : nil, duoInner: $0.size.isDuoInner ? true : nil)
            }
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            try encoder.encode(manifest).write(to: directory.appendingPathComponent("manifest.json"))
            print("gallery: \(rendered) scenario(s)")
        }

        @Test("the Duo pass needs the folded outer display",
              .enabled(if: ProcessInfo.processInfo.environment["BCHESS_SNAPSHOT_DEVICE"] == "duo",
                       "only on the Duo pass (BCHESS_SNAPSHOT_DEVICE=duo)"))
        func duoPassRequiresTheOuterDisplay() throws {
            #expect(try Self.duoPassProblem() == nil)
        }

        /// Why the Duo pass cannot run, or nil: it renders the outer display, so the simulator must be folded
        /// (a leased Duo may come back in another posture) and read compact width, like the iPhone's `.phone`.
        static func duoPassProblem() throws -> String? {
            let scene = try scene()
            let screen = scene.screen.fixedCoordinateSpace.bounds.size
            guard screen == CGSize(width: 466, height: 678), scene.traitCollection.horizontalSizeClass == .compact else {
                return "the Duo simulator is not folded: screen \(Int(screen.width)) x \(Int(screen.height))"
            }
            return nil
        }

        /// The hosting scene's screen in points, in its portrait orientation.
        static func screenSize() throws -> CGSize {
            try scene().screen.fixedCoordinateSpace.bounds.size
        }

        static func scene() throws -> UIWindowScene {
            try #require(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first, "needs the app's window scene")
        }

        /// A scenario as PNG data, at its size, size classes and the pass's scale.
        static func render(_ scenario: GalleryScenario, style: UIUserInterfaceStyle) async throws -> Data {
            let image = try await renderImage(scenario, style: style)
            return try #require(image.pngData())
        }

        static func renderImage(_ scenario: GalleryScenario, style: UIUserInterfaceStyle) async throws -> UIImage {
            let size = scenario.size.points(screen: try screenSize())
            return try await render(AnyView(try scenario.view()), name: scenario.name, size: size,
                                    sizeClasses: scenario.size.sizeClasses,
                                    scale: scenario.size.scale(duoPass: duoPass), style: style, settle: scenario.settle)
        }

        /// The primitive: any view in a window of `size` (with the size classes forced on the window and the host),
        /// captured at `scale`. The oracle tests call it with ad-hoc views and sizes.
        static func render(_ view: AnyView, name: String = "view", size: CGSize,
                           sizeClasses: (horizontal: UIUserInterfaceSizeClass, vertical: UIUserInterfaceSizeClass)? = nil,
                           scale: CGFloat = 2, style: UIUserInterfaceStyle,
                           settle: Duration = .milliseconds(400)) async throws -> UIImage {
            let host = UIHostingController(rootView: view)
            host.overrideUserInterfaceStyle = style
            host.view.backgroundColor = .systemBackground
            let window = UIWindow(windowScene: try scene())
            window.frame = CGRect(origin: .zero, size: size)
            window.overrideUserInterfaceStyle = style
            if let sizeClasses {
                // A fixed window on a phone screen reads the classes of the device it stands for
                window.traitOverrides.horizontalSizeClass = sizeClasses.horizontal
                window.traitOverrides.verticalSizeClass = sizeClasses.vertical
                host.traitOverrides.horizontalSizeClass = sizeClasses.horizontal
                host.traitOverrides.verticalSizeClass = sizeClasses.vertical
            }
            window.rootViewController = host
            defer {
                window.isHidden = true
                window.rootViewController = nil
            }
            window.makeKeyAndVisible()
            host.view.frame = window.bounds
            host.view.layoutIfNeeded()
            // Let onAppear / task / List layout settle.
            try await Task.sleep(for: settle)
            host.view.layoutIfNeeded()
            // A mount that ignored the size would be stretched into the capture: never a valid picture
            try #require(window.bounds.size == size && host.view.bounds.size == size,
                         "\(name) mounted at \(host.view.bounds.size.width) x \(host.view.bounds.size.height), not \(size.width) x \(size.height)")

            let format = UIGraphicsImageRendererFormat()
            format.scale = scale
            var drawn = false
            let image = UIGraphicsImageRenderer(size: size, format: format).image { _ in
                drawn = host.view.drawHierarchy(in: CGRect(origin: .zero, size: size), afterScreenUpdates: true)
            }
            try #require(drawn, "\(name) did not draw")
            return image
        }
    }
}
