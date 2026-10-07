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

    /// One card of the form: a serif header above rows on a walnut card, divided by hairlines.
    private func card<Rows: View>(_ title: LocalizedStringKey, @ViewBuilder rows: () -> Rows) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(.subheadline, design: .serif, weight: .semibold))
                .foregroundStyle(Walnut.textSecondary)
                .accessibilityAddTraits(.isHeader)
                .padding(.horizontal, 14)
            VStack(spacing: 0) {
                Group(subviews: rows()) { subviews in
                    ForEach(subviews.indices, id: \.self) { index in
                        if index > 0 {
                            Walnut.cardBorder.frame(height: 1)
                        }
                        subviews[index]
                    }
                }
            }
            .walnutCard(radius: 16)
        }
    }

    private func label(_ title: LocalizedStringKey, _ hint: LocalizedStringKey) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.system(.callout, design: .serif, weight: .semibold))
                .foregroundStyle(Walnut.textPrimary)
            Text(hint)
                .font(.caption)
                .foregroundStyle(Walnut.textSecondary)
        }
    }

    private func toggle(_ title: LocalizedStringKey, _ hint: LocalizedStringKey, isOn: Binding<Bool>) -> some View {
        Toggle(isOn: isOn) {
            label(title, hint)
        }
        .tint(Walnut.accent)
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 20) {
            card("Board") {
                toggle("Show coordinates", "Files and ranks on the walnut frame", isOn: $showCoordinates)
                toggle("Show legal moves", "Dots and rings when a piece is selected", isOn: $showLegalMoves)
                toggle("Highlight the last move", "Tints the two squares of the move just played", isOn: $highlightLastMove)
            }
            card("Engine") {
                #if os(macOS)
                // The iPhone never shows the statistics, so the switch is the Mac's only
                toggle("Show engine statistics", "Depth, nodes and speed under the engine card", isOn: $showStatistics)
                #endif
                toggle("Use Transposition Table (Beta)", "Remembers positions the engine has searched", isOn: $ttTable)
            }
            card("Appearance") {
                VStack(alignment: .leading, spacing: 10) {
                    label("Theme", "Follow the system, or always light or dark")
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

/// A segmented control in the walnut palette: the chosen segment is the honey pill.
private struct WalnutSegmented<Option: Hashable & Identifiable>: View {
    @Binding var selection: Option
    let options: [Option]
    let title: (Option) -> String

    var body: some View {
        HStack(spacing: 2) {
            ForEach(options) { option in
                let isSelected = option == selection
                Button {
                    selection = option
                } label: {
                    Text(title(option))
                        .font(.system(.callout, design: .serif, weight: .semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .frame(maxWidth: .infinity, minHeight: 32)
                        .foregroundStyle(isSelected ? Walnut.pillText : Walnut.textPrimary)
                        .background(isSelected ? Walnut.pillBackground : .clear, in: RoundedRectangle(cornerRadius: 8))
                        .contentShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }
        .padding(3)
        .background(Walnut.background, in: RoundedRectangle(cornerRadius: 11))
        .overlay(RoundedRectangle(cornerRadius: 11).strokeBorder(Walnut.cardBorder))
    }
}

#if DEBUG
#Preview("Settings") {
    PreviewScenarios.settings.view()
}
#endif
