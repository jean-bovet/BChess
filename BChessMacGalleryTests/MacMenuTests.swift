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
}
