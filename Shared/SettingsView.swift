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

    private var content: some View {
        VStack(alignment: .leading, spacing: 20) {
            WalnutSection("Board") {
                WalnutToggleRow("Show coordinates", "Files and ranks on the walnut frame", isOn: $showCoordinates)
                WalnutToggleRow("Show legal moves", "Dots and rings when a piece is selected", isOn: $showLegalMoves)
                WalnutToggleRow("Highlight the last move", "Tints the two squares of the move just played", isOn: $highlightLastMove)
            }
            WalnutSection("Engine") {
                #if os(macOS)
                // The iPhone never shows the statistics, so the switch is the Mac's only
                WalnutToggleRow("Show engine statistics", "Depth, nodes and speed under the engine card", isOn: $showStatistics)
                #endif
                WalnutToggleRow("Use Transposition Table (Beta)", "Remembers positions the engine has searched", isOn: $ttTable)
            }
            WalnutSection("Appearance") {
                VStack(alignment: .leading, spacing: 10) {
                    WalnutRowLabel("Theme", "Follow the system, or always light or dark")
                    WalnutSegmented(selection: $theme, options: AppTheme.allCases, title: \.title)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
            }
        }
        .padding(16)
    }

    var body: some View {
        #if os(iOS)
        ScrollView {
            content
        }
        .background(Walnut.background.ignoresSafeArea())
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Walnut.background, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("Settings")
                    .font(.system(.headline, design: .serif, weight: .semibold))
                    .foregroundStyle(Walnut.textPrimary)
            }
        }
        #else
        content
            .frame(width: 460)
            .fixedSize(horizontal: false, vertical: true)
            .background(Walnut.background)
        #endif
    }
}

#if DEBUG
#Preview("Settings") {
    PreviewScenarios.settings.view()
}
#endif
