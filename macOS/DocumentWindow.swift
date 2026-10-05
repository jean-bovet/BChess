//
//  DocumentWindow.swift
//  BChess
//
//  Hosts a `GameSession` for a `ChessDocument` and keeps the two in sync.
//

import SwiftUI

/// Creates the session on first use: SwiftUI re-initializes the view for every change of the document,
/// and a session owns an engine, so it must not be built in `init`.
@MainActor
private final class SessionBox {
    private let initialState: GameState
    private(set) lazy var session = GameSession(state: initialState)

    init(state: GameState) {
        initialState = state
    }
}

struct DocumentWindow: View {
    @Binding var document: ChessDocument
    /// A new, untitled document: it offers the players sheet once.
    let isNew: Bool
    @State private var box: SessionBox
    @State private var showPlayers = false
    @State private var offeredPlayers = false
    @AppStorage("showEngine") private var showEngine = false

    init(document: Binding<ChessDocument>, isNew: Bool = false) {
        _document = document
        self.isNew = isNew
        _box = State(initialValue: SessionBox(state: document.wrappedValue.state))
    }

    var body: some View {
        let session = box.session
        ContentView(session: session)
            .navigationTitle(GameText.title(white: session.gameState.white, black: session.gameState.black))
            .navigationSubtitle(session.openingName ?? "")
            .toolbar {
                ToolbarItemGroup {
                    Button("New Game", systemImage: "plus.circle") {
                        NSDocumentController.shared.newDocument(nil)
                    }
                    Button("Flip Board", systemImage: "arrow.triangle.2.circlepath.circle") {
                        session.rotate()
                    }
                    NavigationButtons(session: session)
                    Toggle(isOn: $showEngine) {
                        Label("Show Engine", systemImage: "gauge")
                    }
                    .toggleStyle(.button)
                }
            }
            .sheet(isPresented: $showPlayers) {
                NewGameView(session: session)
            }
            // The Game menu acts on the focused window, and is off while the sheet takes the keys
            .focusedSceneValue(\.gameSession, showPlayers ? nil : session)
            .focusedSceneValue(\.showPlayers, $showPlayers)
            .onAppear {
                if isNew && !offeredPlayers && document.state == .newGame {
                    offeredPlayers = true
                    showPlayers = true
                }
            }
            // Only persisted changes (moves, new game, paste, players, rotation) dirty the document.
            // Selection, navigation, analysis and engine information never do.
            .onChange(of: session.gameState) { _, newState in
                if document.state != newState {
                    document.state = newState
                }
            }
            // Any external change to the value reaches the session: Edit ▸ Undo and Redo, File ▸ Revert.
            // Both directions compare values, so the two observers cannot loop.
            .onChange(of: document.state) { _, newState in
                if newState != session.gameState {
                    session.load(newState)
                }
            }
    }
}

#Preview {
    DocumentWindow(document: .constant(ChessDocument()))
}
