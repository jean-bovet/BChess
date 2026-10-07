//
//  AppThemeTests.swift
//  BChessTests
//
//  The theme setting and what it asks of SwiftUI.
//

import SwiftUI
import Testing

struct AppThemeTests {

    @Test func mapsToTheColorScheme() {
        #expect(AppTheme.system.colorScheme == nil)
        #expect(AppTheme.light.colorScheme == .light)
        #expect(AppTheme.dark.colorScheme == .dark)
    }

    @Test func storedValuesAreStable() {
        #expect(AppTheme.allCases.map(\.rawValue) == ["system", "light", "dark"])
        #expect(AppTheme.allCases.map(\.title) == ["System", "Light", "Dark"])
    }

    @Test func defaultsKeepTodaysBehavior() {
        #expect(AppSettings.showCoordinatesDefault)
        #expect(AppSettings.showLegalMovesDefault)
        #expect(AppSettings.highlightLastMoveDefault)
        #expect(AppTheme.default == .system)
    }

    @Test func trainModeKeepsItsTintWhenTheLastMoveIsNotHighlighted() {
        #expect(AppSettings.showsLastMoveTint(mode: .play, highlightLastMove: true))
        #expect(!AppSettings.showsLastMoveTint(mode: .play, highlightLastMove: false))
        #expect(!AppSettings.showsLastMoveTint(mode: .analyze, highlightLastMove: false))
        #expect(AppSettings.showsLastMoveTint(mode: .train, highlightLastMove: false))
        #expect(AppSettings.showsLastMoveTint(mode: .train, highlightLastMove: true))
    }
}
