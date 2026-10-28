import AppKit
import Foundation
import SwiftUI
import Testing
@testable import BChess

/// Both Mac gallery suites in one serialized parent: the tests mount AppKit windows and share the scratch
/// preference suites while they suspend in readiness and settle waits, and main-actor isolation alone lets
/// asynchronous tests interleave.
@MainActor @Suite(.serialized)
enum MacGallerySuites {}

extension MacGallerySuites {

    /// The scenario list feeds the Mac renderer (`MacSnapshotGalleryTests`); these run in every mac test run.
    @MainActor @Suite struct MacGalleryScenarioTests {

        @Test("every scenario has a name, a group and a unique slug")
        func slugsAreUnique() {
            var seen = Set<String>()
            for scenario in MacGalleryScenarios.all {
                #expect(!scenario.name.isEmpty)
                #expect(!scenario.group.isEmpty, "\(scenario.name)")
                #expect(!scenario.slug.isEmpty, "\(scenario.name)")
                #expect(seen.insert(scenario.slug).inserted, "duplicate slug \(scenario.slug)")
            }
            #expect(MacGalleryScenarios.all.count == 6)
        }

        @Test("the ONLY filter matches names or slugs, comma-separated, case-insensitive; empty means all")
        func onlyFilter() {
            #expect(MacGalleryScenarios.matching("").count == MacGalleryScenarios.all.count)
            #expect(MacGalleryScenarios.matching("Settings window").map(\.slug) == ["settings-window"])
            #expect(MacGalleryScenarios.matching("new-game-sheet").count == 3)
            #expect(MacGalleryScenarios.matching("nothing").isEmpty)
        }

        @Test("every scenario builds a view")
        func everyScenarioBuilds() throws {
            for scenario in MacGalleryScenarios.all {
                _ = try scenario.view()
            }
        }

        @Test("the middlegame fixture parses and has white to move after sixteen moves each")
        func middlegameParses() {
            #expect(FEngine().loadAllGames(GalleryScenarios.Fixture.middlegame))
            let session = GameSession(state: GameState(pgn: GalleryScenarios.Fixture.middlegame))
            #expect(session.game.rows.count == 16)
            #expect(session.isWhiteToMove)
        }

        @Test("a sheet scenario's suite holds its seeded choice, read back through the production reader")
        func seededSuitesHoldTheirChoice() {
            #expect(NewGame(remembered: MacGalleryScenarios.sheetClubSuite) == MacGalleryScenarios.clubChoice)
            #expect(NewGame(remembered: MacGalleryScenarios.sheetFriendSuite) == MacGalleryScenarios.friendChoice)
            #expect(NewGame(remembered: MacGalleryScenarios.sheetMaximumSuite) == MacGalleryScenarios.maximumChoice)
            #expect(MacGalleryScenarios.friendChoice.firstName == "Anna" && MacGalleryScenarios.friendChoice.secondName == "Jean")
            #expect(MacGalleryScenarios.maximumChoice.thinkingTime == 10)
        }

        // MARK: The renderer

        /// The capture fails by name on a 1x display by design, so its tests are skipped by name there.
        nonisolated static let retina = NSScreen.main?.backingScaleFactor == 2

        @Test("the document window mounts off screen with the players as its title and a toolbar")
        func documentWindowMountsWithThePlayersAsTitle() async throws {
            let scenario = MacGalleryScenarios.documentWindowEngineOn
            let window = try MacRenderer.mount(scenario, appearance: .light)
            defer { MacRenderer.close(window) }
            try await MacRenderer.waitUntilReady(window, scenario)
            #expect(window.title == GameText.title(white: .defaultWhite, black: .defaultBlack))
            #expect((window.toolbar?.items.count ?? 0) >= 4)
            // Never ordered on screen (the window reports itself visible so that a sheet attaches)
            #expect(!window.occlusionState.contains(.visible))
        }

        @Test("the new game scenario's sheet attaches to the window")
        func newGameSheetAttaches() async throws {
            let scenario = MacGalleryScenarios.documentWindowNewGameSheet
            let window = try MacRenderer.mount(scenario, appearance: .light)
            defer { MacRenderer.close(window) }
            try await MacRenderer.waitUntilReady(window, scenario, timeout: .seconds(10))
            #expect(window.attachedSheet != nil)
        }

        @Test("the manifest the snapshot test writes records the mounted frame: the whole window, or the content plus the title bar")
        func manifestSizeIsTheMountedFrame() throws {
            let settings = MacGalleryScenarios.settingsWindow
            let window = try MacRenderer.mount(settings, appearance: .light)
            defer { MacRenderer.close(window) }
            let mounted = Self.sizeString(window.frame.size)
            #expect(window.frame.width == 460 && window.frame.height > 100)

            // A rendered scenario: the frame it was captured at
            // (a frame that is not what a probe would measure, so only the captured one can produce this string)
            let rendered = try Self.manifest(rendered: [settings.slug: CGSize(width: 1234, height: 567)])
            #expect(rendered[settings.slug]?["size"] as? String == "1234x567")
            #expect(rendered[MacGalleryScenarios.documentWindowEngineOn.slug]?["size"] as? String == "1440x900")
            // An unrendered one (a partial run): measured on a probe window, the same frame
            let measured = try Self.manifest(rendered: [:])
            #expect(measured[settings.slug]?["size"] as? String == mounted)
            // A whole-window scenario: the frame it asks for
            for slug in [MacGalleryScenarios.documentWindowVariations.slug, MacGalleryScenarios.documentWindowEngineOn.slug] {
                #expect(measured[slug]?["size"] as? String == "1440x900", "\(slug)")
            }
            #expect(measured.count == MacGalleryScenarios.all.count)
            #expect(measured.values.allSatisfy { $0["platform"] as? String == "mac" })
        }

        private static func sizeString(_ size: CGSize) -> String {
            "\(Int(size.width))x\(Int(size.height))"
        }

        /// The entries `MacSnapshotGalleryTests` would write, decoded, by slug.
        private static func manifest(rendered: [String: CGSize]) throws -> [String: [String: Any]] {
            let data = try MacSnapshotGalleryTests.manifestData(rendered: rendered)
            let entries = try #require(JSONSerialization.jsonObject(with: data) as? [[String: Any]])
            return Dictionary(uniqueKeysWithValues: entries.compactMap { entry in (entry["slug"] as? String).map { ($0, entry) } })
        }

        // MARK: What the sheet shows and writes

        /// Mounts the scenario, waits for its sheet, and returns the choice that sheet holds and where it remembers one.
        private func mountedSheet(_ scenario: MacGalleryScenario, probe: NewGameSheetProbe) async throws -> (choice: NewGame, defaults: UserDefaults) {
            probe.reset()
            let window = try MacRenderer.mount(scenario, appearance: .light)
            defer { MacRenderer.close(window) }
            try await MacRenderer.waitUntilReady(window, scenario)
            MacRenderer.settle(window)
            return (try #require(probe.choice, "\(scenario.name): the sheet never reported"), try #require(probe.defaults))
        }

        @Test("each sheet scenario's mounted sheet holds its own seeded choice")
        func sheetShowsTheSeededChoice() async throws {
            let club = try await mountedSheet(MacGalleryScenarios.documentWindowNewGameSheet, probe: MacGalleryScenarios.clubProbe)
            #expect(club.choice == MacGalleryScenarios.clubChoice)
            #expect(club.choice.opponent == .club && !club.choice.showsThinkingTime && !club.choice.isFriend)
            #expect(club.defaults === MacGalleryScenarios.sheetClubSuite)

            let friend = try await mountedSheet(MacGalleryScenarios.documentWindowNewGameSheetFriend, probe: MacGalleryScenarios.friendProbe)
            #expect(friend.choice == MacGalleryScenarios.friendChoice)
            #expect(friend.choice.opponent == .friend && friend.choice.isFriend)
            #expect(friend.choice.firstName == "Anna" && friend.choice.secondName == "Jean")
            #expect(friend.defaults === MacGalleryScenarios.sheetFriendSuite)

            let maximum = try await mountedSheet(MacGalleryScenarios.documentWindowNewGameSheetMaximum, probe: MacGalleryScenarios.maximumProbe)
            #expect(maximum.choice == MacGalleryScenarios.maximumChoice)
            #expect(maximum.choice.opponent == .maximum && maximum.choice.showsThinkingTime && maximum.choice.thinkingTime == 10)
            #expect(maximum.defaults === MacGalleryScenarios.sheetMaximumSuite)
        }

        @Test("Start Game remembers the choice in the window's suite, and the app's preferences keep what they held")
        func startGameWritesTheInjectedSuite() async throws {
            var choice = NewGame()
            choice.opponent = .maximum
            choice.firstName = "Probe Name"
            choice.thinkingTime = 30
            let suiteName = "BChessMacGallery.probe"
            let suite = MacGalleryScenarios.newGameSuite("probe", seeded: choice)
            defer { suite.removePersistentDomain(forName: suiteName) }
            let probe = NewGameSheetProbe()
            let scenario = MacGalleryScenario(name: "Probe", group: "Mac", size: MacGalleryScenarios.windowFrame,
                                              title: MacGalleryScenarios.defaultTitle, waitsForSheet: true) {
                AnyView(MacGalleryScenarios.newGameWindow(suite).environment(\.newGameSheetProbe, probe))
            }
            // The sheet shows the suite's choice (30 s at Maximum), not the app's
            let remembered = try await mountedSheetKeepingWindow(scenario, probe: probe) {
                #expect(probe.choice == choice)
                #expect(probe.choice?.thinkingTime == 30 && probe.choice?.showsThinkingTime == true)
                #expect(probe.defaults === suite)

                // The app's own preferences are never written by the test: whatever the failing case would write is put back
                let standard = UserDefaults.standard
                let saved = AppSettings.newGameKeys.map { ($0, standard.object(forKey: $0)) }
                defer { for (key, value) in saved { if let value { standard.set(value, forKey: key) } else { standard.removeObject(forKey: key) } } }
                // A different choice, so that a write to the wrong store cannot be mistaken for the seed
                suite.removePersistentDomain(forName: suiteName)
                probe.start?()
                #expect(standard.string(forKey: AppSettings.newGameNameKey) != "Probe Name")
                return NewGame(remembered: suite)
            }
            #expect(remembered == choice)
        }

        /// Mounts the scenario, waits for its sheet and runs `body` with the window while it is mounted.
        private func mountedSheetKeepingWindow<T>(_ scenario: MacGalleryScenario, probe: NewGameSheetProbe,
                                                  body: () throws -> T) async throws -> T {
            let window = try MacRenderer.mount(scenario, appearance: .light)
            defer { MacRenderer.close(window) }
            try await MacRenderer.waitUntilReady(window, scenario)
            MacRenderer.settle(window)
            return try body()
        }

        @Test("a frame scenario's capture is exactly 2880 x 1800 pixels",
              .enabled(if: MacGalleryScenarioTests.retina, "needs a Retina display"))
        func frameCaptureIs2880x1800() async throws {
            let png = try await MacRenderer.render(MacGalleryScenarios.documentWindowVariations, appearance: .light).png
            let rep = try #require(NSBitmapImageRep(data: png))
            #expect(rep.pixelsWide == 2880)
            #expect(rep.pixelsHigh == 1800)
        }

        @Test("the sheet is composited inside its own frame, and nowhere else",
              .enabled(if: MacGalleryScenarioTests.retina, "needs a Retina display"))
        func sheetIsCompositedInsideItsFrame() async throws {
            let scenario = MacGalleryScenarios.documentWindowNewGameSheet
            let window = try MacRenderer.mount(scenario, appearance: .light)
            defer { MacRenderer.close(window) }
            try await MacRenderer.waitUntilReady(window, scenario)
            try await Task.sleep(for: scenario.settle)
            MacRenderer.settle(window)
            let sheet = try #require(window.attachedSheet)

            let alone = try MacRenderer.draw(window).image
            let composite = try MacRenderer.capture(window)
            #expect(alone.width == composite.width && alone.height == composite.height)

            // The sheet's frame in the parent's image: pixels, origin top left
            let scale = MacRenderer.scale
            let left = Int(((sheet.frame.minX - window.frame.minX) * scale).rounded())
            let right = Int(((sheet.frame.maxX - window.frame.minX) * scale).rounded())
            let top = Int(((window.frame.maxY - sheet.frame.maxY) * scale).rounded())
            let bottom = Int(((window.frame.maxY - sheet.frame.minY) * scale).rounded())
            let a = try Self.pixels(alone), b = try Self.pixels(composite)
            var inside = 0, differingInside = 0, differingOutside = 0
            for y in 0..<alone.height {
                for x in 0..<alone.width {
                    let i = (y * alone.width + x) * 4
                    let differs = a[i] != b[i] || a[i + 1] != b[i + 1] || a[i + 2] != b[i + 2] || a[i + 3] != b[i + 3]
                    // One pixel of slack on each side for the rounding of the offset
                    let isInside = x >= left - 1 && x < right + 1 && y >= top - 1 && y < bottom + 1
                    if isInside { inside += 1 }
                    if differs { if isInside { differingInside += 1 } else { differingOutside += 1 } }
                }
            }
            #expect(differingOutside == 0, "\(differingOutside) pixels differ outside the sheet's frame")
            #expect(inside > 0 && differingInside * 2 > inside, "\(differingInside) of \(inside) pixels differ inside the sheet's frame")
        }

        private static func pixels(_ image: CGImage) throws -> [UInt8] {
            var bytes = [UInt8](repeating: 0, count: image.width * image.height * 4)
            let context = try #require(CGContext(data: &bytes, width: image.width, height: image.height, bitsPerComponent: 8,
                                                 bytesPerRow: image.width * 4, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                                 bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
            context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
            return bytes
        }
    }
}
