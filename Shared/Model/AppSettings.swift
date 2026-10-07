//
//  AppSettings.swift
//  BChess
//
//  The settings the user can change, stored with `@AppStorage` under the keys below. Every default keeps
//  the behavior the app had before the setting existed.
//

import SwiftUI

enum AppTheme: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    static let `default` = AppTheme.system

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system: return "System"
        case .light: return "Light"
        case .dark: return "Dark"
        }
    }

    /// What `preferredColorScheme` takes: nil follows the system.
    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

enum AppSettings {
    static let showCoordinatesKey = "showCoordinates"
    static let showLegalMovesKey = "showLegalMoves"
    static let highlightLastMoveKey = "highlightLastMove"
    static let themeKey = "appTheme"

    static let showCoordinatesDefault = true
    static let showLegalMovesDefault = true
    static let highlightLastMoveDefault = true

    /// Whether the squares of the last move are tinted. Training shows its green or red verdict on those
    /// squares whatever the setting says, because it is feedback on the move, not decoration.
    static func showsLastMoveTint(mode: GameMode.Value, highlightLastMove: Bool) -> Bool {
        mode == .train || highlightLastMove
    }
}

/// Applies the theme the user chose, app-wide: put it on the root view of every window.
private struct ThemeModifier: ViewModifier {
    @AppStorage(AppSettings.themeKey) private var theme = AppTheme.default

    func body(content: Content) -> some View {
        content.preferredColorScheme(theme.colorScheme)
    }
}

extension View {
    @MainActor
    func appTheme() -> some View {
        modifier(ThemeModifier())
    }
}
