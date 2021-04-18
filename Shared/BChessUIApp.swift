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
    var body: some Scene {
        DocumentGroup(newDocument: ChessDocument()) { file in            
            ContentView(document: file.$document)
        }
        #if os(macOS)
        Settings {
            SettingsView()
        }
        #endif
    }
}
