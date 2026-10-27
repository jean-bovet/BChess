//
//  BChessUIApp.swift
//  Shared
//
//  Created by Jean Bovet on 1/7/21.
//  Copyright © 2021 Jean Bovet. All rights reserved.
//

import SwiftUI

@main
struct BChessUIApp: App {
    #if os(iOS)
    private let library: GameLibrary

    init() {
        // UI tests start from an empty library of their own
        if ProcessInfo.processInfo.arguments.contains("-uiTestingFreshLibrary") {
            let directory = FileManager.default.temporaryDirectory.appendingPathComponent("UITests-\(UUID().uuidString)", isDirectory: true)
            try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            library = GameLibrary(directory: directory)
            // ... and from the engine readout off, whatever an earlier run left behind
            UserDefaults.standard.removeObject(forKey: "showEngine")
            // ... and from the New Game sheet on its first choice, Club
            for key in AppSettings.newGameKeys {
                UserDefaults.standard.removeObject(forKey: key)
            }
        } else {
            library = .documents
        }
    }
    #else
    init() {
        // AppKit shows the Open panel at launch (and on a Dock click with no window) unless this is off;
        // off, it opens a new document, the way File ▸ New and Game ▸ New Game do
        UserDefaults.standard.register(defaults: ["NSShowAppCentricOpenPanelInsteadOfUntitledFile": false])
    }
    #endif

    var body: some Scene {
        #if os(macOS)
        DocumentGroup(newDocument: ChessDocument()) { file in
            DocumentWindow(document: file.$document, isNew: file.fileURL == nil)
                .appTheme()
        }
        // A window without a remembered size: a 600 pt board and the move list beside it (the height
        // counts the title bar and toolbar, 52 pt, above the 708 pt of content)
        .defaultSize(width: 960, height: 760)
        .commands {
            GameCommands()
        }
        Settings {
            SettingsView()
                .appTheme()
        }
        #else
        WindowGroup {
            GameRootView(library: library)
                .appTheme()
        }
        #endif
    }
}
