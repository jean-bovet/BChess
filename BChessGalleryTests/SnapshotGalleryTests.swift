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
        private struct ManifestEntry: Encodable {
            let name: String
            let group: String
            let slug: String
            let size: String
        }

        private static let snapshotDirectory = ProcessInfo.processInfo.environment["BCHESS_SNAPSHOT_DIR"].flatMap { $0.isEmpty ? nil : $0 }

        @Test("render every scenario in light and dark",
              .enabled(if: ProcessInfo.processInfo.environment["BCHESS_SNAPSHOT_DIR"]?.isEmpty == false,
                       "set BCHESS_SNAPSHOT_DIR (TEST_RUNNER_BCHESS_SNAPSHOT_DIR on the xcodebuild command line) to render the gallery"))
        func renderEveryScenarioInLightAndDark() async throws {
            let directory = URL(fileURLWithPath: try #require(Self.snapshotDirectory))
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

            let slugs = GalleryScenarios.all.map(\.slug)
            #expect(Set(slugs).count == slugs.count, "two scenarios share a slug")

            let filter = ProcessInfo.processInfo.environment["BCHESS_SNAPSHOT_ONLY"] ?? ""
            let scenarios = GalleryScenarios.matching(filter)
            try #require(!scenarios.isEmpty, "no scenario matches \(filter)")

            let clock = ContinuousClock()
            for scenario in scenarios {
                let started = clock.now
                for style in [UIUserInterfaceStyle.light, .dark] {
                    let png = try await render(scenario, style: style)
                    let name = scenario.slug + (style == .dark ? ".dark.png" : ".png")
                    try png.write(to: directory.appendingPathComponent(name))
                }
                print("gallery: \(scenario.slug) \(clock.now - started)")
            }

            // The manifest always lists every scenario, so a partial run still knows the whole gallery.
            let manifest = GalleryScenarios.all.map {
                ManifestEntry(name: $0.name, group: $0.group, slug: $0.slug,
                              size: "\(Int($0.size.width))x\(Int($0.size.height))")
            }
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            try encoder.encode(manifest).write(to: directory.appendingPathComponent("manifest.json"))
            print("gallery: \(scenarios.count) scenario(s)")
        }

        private func render(_ scenario: GalleryScenario, style: UIUserInterfaceStyle) async throws -> Data {
            let size = scenario.size
            let host = UIHostingController(rootView: try scenario.view())
            host.overrideUserInterfaceStyle = style
            host.view.backgroundColor = .systemBackground
            let scene = try #require(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first, "needs the app's window scene")
            let window = UIWindow(windowScene: scene)
            window.frame = CGRect(origin: .zero, size: size)
            window.overrideUserInterfaceStyle = style
            window.rootViewController = host
            defer {
                window.isHidden = true
                window.rootViewController = nil
            }
            window.makeKeyAndVisible()
            host.view.frame = window.bounds
            host.view.layoutIfNeeded()
            // Let onAppear / task / List layout settle.
            try await Task.sleep(for: scenario.settle)
            host.view.layoutIfNeeded()

            let format = UIGraphicsImageRendererFormat()
            format.scale = 2
            var drawn = false
            let image = UIGraphicsImageRenderer(size: size, format: format).image { _ in
                drawn = host.view.drawHierarchy(in: CGRect(origin: .zero, size: size), afterScreenUpdates: true)
            }
            try #require(drawn, "\(scenario.name) did not draw")
            return try #require(image.pngData())
        }
    }
}
