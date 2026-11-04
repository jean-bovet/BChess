//
//  MacMenuTests.swift
//  BChessMacGalleryTests
//
//  The Mac menu bar of the running (hosted) app: the Game menu and the Edit items that `GameCommands` replaces. The gallery
//  renders windows, never the menu bar, so this is where a translation of a menu item is read through the production
//  path. In a run under another language (`BCHESS_EXPECT_LANGUAGE`) the titles must also differ from the English keys.
//

import AppKit
import Foundation
import Testing
@testable import BChess

@MainActor
struct MacMenuTests {

    private static let gameKeys = ["New Game", "Players…", "Flip Board", "Back", "Forward", "Start of Game", "End of Game",
                                   "Show Engine", "Analyze Game", "Practice Openings"]
    private static let editKeys = ["Cut", "Copy Game", "Copy Position", "Paste Game or Position", "Select All"]

    private static func title(_ key: String) -> String {
        String(localized: String.LocalizationValue(key))
    }

    private func submenu(containing key: String) throws -> NSMenu {
        let main = try #require(NSApp.mainMenu, "the app has no main menu")
        let title = Self.title(key)
        return try #require(main.items.compactMap(\.submenu).first { $0.items.contains { $0.title == title } },
                            "no menu holds \"\(title)\"")
    }

    private func titles(_ menu: NSMenu) -> [String] {
        menu.items.filter { !$0.isSeparatorItem }.map(\.title)
    }

    @Test func gameMenuHoldsTheLocalizedItems() throws {
        let main = try #require(NSApp.mainMenu)
        let game = try #require(main.items.first { $0.title == Self.title("Game") }?.submenu, "no Game menu in \(main.items.map(\.title))")
        #expect(titles(game) == Self.gameKeys.map(Self.title))
    }

    @Test func editMenuHoldsTheReplacedItems() throws {
        let edit = try submenu(containing: "Copy Game")
        let present = Set(titles(edit))
        for key in Self.editKeys {
            #expect(present.contains(Self.title(key)), "Edit lacks \"\(Self.title(key))\"")
        }
    }

    /// Under another language the titles are not the English keys: a translation reached the menu.
    @Test(.enabled(if: ProcessInfo.processInfo.environment["BCHESS_EXPECT_LANGUAGE"].map { $0 != "en" } ?? false))
    func titlesAreTranslated() throws {
        let game = try #require(NSApp.mainMenu?.items.first { $0.title == Self.title("Game") }?.submenu)
        let shown = titles(game)
        for key in Self.gameKeys where key != "Players…" {
            #expect(!shown.contains(key), "\"\(key)\" is still English in the Game menu")
        }
        let edit = try submenu(containing: "Copy Game")
        let editShown = titles(edit)
        for key in Self.editKeys {
            #expect(!editShown.contains(key), "\"\(key)\" is still English in the Edit menu")
        }
    }

    // MARK: About

    private func aboutWindows() -> [NSWindow] {
        let title = Self.title("About BChess")
        return NSApp.windows.filter { $0.title == title && $0.isVisible }
    }

    private func waitFor(_ condition: () -> Bool) async -> Bool {
        for _ in 0..<100 {
            if condition() { return true }
            try? await Task.sleep(for: .milliseconds(50))
        }
        return condition()
    }

    /// The Mac path: the app menu's item, `GameCommands`, the `Window` scene hosting `AboutView`; one window however often fired.
    @Test(.timeLimit(.minutes(1)))
    func aboutItemOpensOneWindowHostingAboutView() async throws {
        let main = try #require(NSApp.mainMenu, "the app has no main menu")
        let title = Self.title("About BChess")
        let holders = main.items.compactMap(\.submenu).filter { $0.items.contains { $0.title == title } }
        #expect(holders.count == 1, "\"\(title)\" is in \(holders.count) menus")
        let appMenu = try #require(holders.first)
        let windowMenu = try #require(NSApp.windowsMenu, "no Window menu")
        #expect(!windowMenu.items.contains { $0.title == title })
        let index = try #require(appMenu.items.firstIndex { $0.title == title })

        appMenu.performActionForItem(at: index)
        let opened = await waitFor { !aboutWindows().isEmpty }
        #expect(opened, "the About window did not open")
        appMenu.performActionForItem(at: index)
        try? await Task.sleep(for: .milliseconds(300))
        let windows = aboutWindows()
        #expect(windows.count == 1)

        let window = try #require(windows.first)
        defer { window.close() }
        // The window hosts the production AboutView (SwiftUI exposes no text to accessibility in the hosted, unfocused
        // app, so the notices are covered by ThirdPartyNoticesTests and the About gallery scenarios)
        let hosted = [window.contentView.map { String(reflecting: type(of: $0)) },
                      window.contentViewController.map { String(reflecting: type(of: $0)) }].compactMap { $0 }
        #expect(hosted.contains { $0.contains("AboutView") }, "the window hosts \(hosted)")
    }

    /// The production loader reads the notices from the real app bundle (the unit tests read a copy bundled in their own target).
    @Test func appBundleCarriesTheNotices() {
        let text = ThirdPartyNotices.text
        #expect(text.contains("Colin M.L. Burnett"))
        #expect(text.contains("Pradyumna Kannan"))
        #expect(text.contains("EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE."))
        #expect(text.contains("3. This notice may not be removed or altered from any source distribution."))
    }
}
