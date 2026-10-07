//
//  SettingsView.swift
//  BChess (macOS)
//
//  Created by Jean Bovet on 4/17/21.
//  Copyright © 2021 Jean Bovet. All rights reserved.
//

import SwiftUI

/// The settings form: the Settings window on the Mac, a sheet from the More menu on iPhone.
struct SettingsView: View {
    @AppStorage(AppSettings.showCoordinatesKey) private var showCoordinates = AppSettings.showCoordinatesDefault
    @AppStorage(AppSettings.showLegalMovesKey) private var showLegalMoves = AppSettings.showLegalMovesDefault
    @AppStorage(AppSettings.highlightLastMoveKey) private var highlightLastMove = AppSettings.highlightLastMoveDefault
    @AppStorage(AppSettings.themeKey) private var theme = AppTheme.default

    @AppStorage("useTranspositionTable") private var ttTable = false

    @AppStorage("showEngineStatistics") private var showStatistics = false

    private func toggle(_ title: LocalizedStringKey, _ hint: LocalizedStringKey, isOn: Binding<Bool>) -> some View {
        Toggle(isOn: isOn) {
            Text(title)
            Text(hint)
        }
    }

    var body: some View {
        Form {
            Section("Board") {
                toggle("Show coordinates", "Files and ranks on the walnut frame", isOn: $showCoordinates)
                toggle("Show legal moves", "Dots and rings when a piece is selected", isOn: $showLegalMoves)
                toggle("Highlight the last move", "Tints the two squares of the move just played", isOn: $highlightLastMove)
            }
            Section("Engine") {
                #if os(macOS)
                // The iPhone never shows the statistics, so the switch is the Mac's only
                toggle("Show engine statistics", "Depth, nodes and speed under the engine card", isOn: $showStatistics)
                #endif
                toggle("Use Transposition Table (Beta)", "Remembers positions the engine has searched", isOn: $ttTable)
            }
            Section("Appearance") {
                Picker(selection: $theme) {
                    ForEach(AppTheme.allCases) { theme in
                        Text(theme.title).tag(theme)
                    }
                } label: {
                    Text("Theme")
                    Text("Follow the system, or always light or dark")
                }
                .pickerStyle(.segmented)
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .background(Walnut.background)
        #if os(macOS)
        .frame(width: 460)
        .fixedSize(horizontal: false, vertical: true)
        #endif
    }
}

#Preview("Light") {
    SettingsView()
}

#Preview("Dark") {
    SettingsView()
        .preferredColorScheme(.dark)
}
