import AppKit
import Foundation
import Testing
@testable import BChess

extension MacGallerySuites {

    /// Renders every `MacGalleryScenarios.all` entry in light and dark, and prints the files `scripts/snapshot-mac.sh`
    /// decodes: `<slug>.png`, `<slug>.dark.png` and `manifest.json`, each as `mac-gallery-file <name> <base64 chunk>`
    /// lines of 64 KiB. The host is the sandboxed, team-signed Mac app, and macOS keeps other processes out of its
    /// container, so no file is written. Skipped when BCHESS_MAC_SNAPSHOT is absent, so a normal test run renders nothing.
    /// `$BCHESS_SNAPSHOT_ONLY` (comma-separated substrings of names or slugs) renders a subset.
    @MainActor @Suite struct MacSnapshotGalleryTests {
        @Test("render every Mac scenario in light and dark",
              .enabled(if: ProcessInfo.processInfo.environment["BCHESS_MAC_SNAPSHOT"] != nil,
                       "set BCHESS_MAC_SNAPSHOT (TEST_RUNNER_BCHESS_MAC_SNAPSHOT on the xcodebuild command line) to render the Mac gallery"))
        func renderEveryMacScenarioInLightAndDark() async throws {
            let slugs = MacGalleryScenarios.all.map(\.slug)
            #expect(Set(slugs).count == slugs.count, "two scenarios share a slug")

            let filter = ProcessInfo.processInfo.environment["BCHESS_SNAPSHOT_ONLY"] ?? ""
            let scenarios = MacGalleryScenarios.matching(filter)
            try #require(!scenarios.isEmpty, "no scenario matches \(filter)")

            try await Self.closeTheHostsWindows()

            let clock = ContinuousClock()
            var rendered = 0
            var frames: [String: CGSize] = [:]
            for scenario in scenarios {
                let started = clock.now
                for appearance in MacAppearance.allCases {
                    let result = try await MacRenderer.render(scenario, appearance: appearance)
                    Self.emit(result.png, as: scenario.slug + (appearance == .dark ? ".dark.png" : ".png"))
                    frames[scenario.slug] = result.frame
                }
                print("gallery: \(scenario.slug) \(clock.now - started)")
                rendered += 1
            }

            Self.emit(try Self.manifestData(rendered: frames), as: "manifest.json")
            print("gallery: \(rendered) scenario(s)")
        }

        /// The manifest always lists every scenario, so a partial run still knows the whole gallery. `rendered` holds the
        /// frame each rendered scenario was captured at (its slug); the others are measured on a window that is mounted
        /// and closed again.
        static func manifestData(rendered: [String: CGSize]) throws -> Data {
            let entries = try MacGalleryScenarios.all.map { scenario in
                let size = try rendered[scenario.slug] ?? scenario.size.points(for: scenario.view())
                return GalleryManifestEntry(name: scenario.name, group: scenario.group, slug: scenario.slug,
                                            size: "\(Int(size.width))x\(Int(size.height))", platform: "mac")
            }
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            return try encoder.encode(entries)
        }

        /// The host is the real app: it opens an untitled game window with the players sheet when it launches, and the
        /// launch cannot be vetoed (APP-9). The windows are closed before the first capture, and again while the
        /// launch's own may still arrive.
        static func closeTheHostsWindows() async throws {
            for _ in 0..<10 {
                for window in NSApp.windows where !(window is OffscreenWindow) {
                    if let sheet = window.attachedSheet { window.endSheet(sheet) }
                    window.close()
                }
                try await Task.sleep(for: .milliseconds(200))
            }
        }

        /// `mac-gallery-file <name> <base64 chunk>` lines of 64 KiB, which the script joins and decodes.
        static func emit(_ data: Data, as name: String) {
            let base64 = data.base64EncodedString()
            var start = base64.startIndex
            while start < base64.endIndex {
                let end = base64.index(start, offsetBy: 65_536, limitedBy: base64.endIndex) ?? base64.endIndex
                print("mac-gallery-file \(name) \(base64[start..<end])")
                start = end
            }
        }
    }
}
