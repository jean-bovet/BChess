//
//  GameCommands.swift
//  BChess (macOS)
//
//  The Game menu and the Edit items that copy and paste games, for the focused game window.
//

import SwiftUI

extension FocusedValues {
    /// The session of the focused game window; nil while its players sheet is up.
    @Entry var gameSession: GameSession?
    @Entry var showPlayers: Binding<Bool>?
}

struct GameCommands: Commands {
    @FocusedValue(\.gameSession) private var session
    @FocusedValue(\.showPlayers) private var showPlayers
    @AppStorage("showEngine") private var showEngine = false

    /// A text field is being edited: the standard editing actions go to it.
    private var isEditingText: Bool {
        NSApp.keyWindow?.firstResponder is NSText
    }

    private func forward(_ selector: Selector) {
        NSApp.sendAction(selector, to: nil, from: nil)
    }

    private func go(_ direction: Direction) {
        withAnimation { session?.move(to: direction) }
    }

    var body: some Commands {
        CommandMenu("Game") {
            Button("New Game") {
                NSDocumentController.shared.newDocument(nil)
            }
            .disabled(session == nil)

            Button("Players & Level\u{2026}") {
                showPlayers?.wrappedValue = true
            }
            .disabled(session == nil)

            Button("Flip Board") {
                session?.rotate()
            }
            .keyboardShortcut("r")
            .disabled(session == nil)

            if let session, session.games.count > 1 {
                Picker("Game", selection: Binding(get: { session.currentGameIndex }, set: { session.selectGame($0) })) {
                    ForEach(session.games, id: \.self) { game in
                        Text(game.name).tag(Int(game.index))
                    }
                }
            }

            Divider()

            Button("Back") { go(.backward) }
                .keyboardShortcut(.leftArrow, modifiers: [])
                .disabled(!(session?.canMove(to: .backward) ?? false))
            Button("Forward") { go(.forward) }
                .keyboardShortcut(.rightArrow, modifiers: [])
                .disabled(!(session?.canMove(to: .forward) ?? false))
            Button("Start of Game") { go(.start) }
                .keyboardShortcut(.leftArrow, modifiers: .command)
                .disabled(!(session?.canMove(to: .start) ?? false))
            Button("End of Game") { go(.end) }
                .keyboardShortcut(.rightArrow, modifiers: .command)
                .disabled(!(session?.canMove(to: .end) ?? false))

            Divider()

            Toggle("Show Engine", isOn: $showEngine)
                .keyboardShortcut("e")
                .disabled(session == nil)
            Toggle("Analyze Game", isOn: Binding(get: { session?.mode.value == .analyze },
                                                 set: { _ in withAnimation { session?.toggleAnalyze() } }))
                .disabled(session == nil)
            Toggle("Practice Openings", isOn: Binding(get: { session?.mode.value == .train },
                                                      set: { _ in withAnimation { session?.toggleTrain() } }))
                .disabled(session == nil)
        }

        CommandGroup(replacing: .pasteboard) {
            Button("Cut") { forward(#selector(NSText.cut(_:))) }
                .keyboardShortcut("x")
            Button("Copy Game") {
                if isEditingText {
                    forward(#selector(NSText.copy(_:)))
                } else if let session {
                    Pasteboard.set(session.pgnCurrentGame)
                }
            }
            .keyboardShortcut("c")
            Button("Copy Position") {
                if let session {
                    Pasteboard.set(session.fen)
                }
            }
            .keyboardShortcut("c", modifiers: [.command, .option])
            .disabled(session == nil)
            Button("Paste Game or Position") {
                if isEditingText {
                    forward(#selector(NSText.paste(_:)))
                } else if let session, let text = Pasteboard.string {
                    _ = session.paste(text)
                }
            }
            .keyboardShortcut("v")
            Button("Select All") { forward(#selector(NSText.selectAll(_:))) }
                .keyboardShortcut("a")
        }
    }
}
