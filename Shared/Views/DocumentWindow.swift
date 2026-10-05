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
    @State private var box: SessionBox

    init(document: Binding<ChessDocument>) {
        _document = document
        _box = State(initialValue: SessionBox(state: document.wrappedValue.state))
    }

    var body: some View {
        let session = box.session
        ContentView(session: session)
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
