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
        } else {
            library = .documents
        }
    }
    #endif

    var body: some Scene {
        #if os(macOS)
        DocumentGroup(newDocument: ChessDocument()) { file in
            DocumentWindow(document: file.$document)
        }
        Settings {
            SettingsView()
        }
        #else
        WindowGroup {
            GameRootView(library: library)
        }
        #endif
    }
}
