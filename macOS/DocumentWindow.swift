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
            .containerBackground(Walnut.background, for: .window)
            .background(WindowTitle(title: GameText.title(white: session.gameState.white, black: session.gameState.black),
                                    subtitle: session.openingName ?? ""))
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

/// Shows the players as the window title and the opening as its subtitle. A document window's controller
/// writes the file name into the title when the document opens, saves or is renamed, which wins over
/// `navigationTitle`, so this sets the window's title itself and puts it back whenever it is replaced.
/// The file name stays in the title bar's document menu.
private struct WindowTitle: NSViewRepresentable {
    let title: String
    let subtitle: String

    func makeNSView(context: Context) -> TitleView {
        TitleView()
    }

    func updateNSView(_ view: TitleView, context: Context) {
        view.set(title: title, subtitle: subtitle)
    }

    final class TitleView: NSView {
        private var title = ""
        private var subtitle = ""
        private var observation: NSKeyValueObservation?

        func set(title: String, subtitle: String) {
            self.title = title
            self.subtitle = subtitle
            apply()
        }

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            observation = window?.observe(\.title) { [weak self] _, _ in
                Task { @MainActor in
                    self?.apply()
                }
            }
            apply()
        }

        private func apply() {
            guard let window, window.title != title || window.subtitle != subtitle else {
                return
            }
            window.title = title
            window.subtitle = subtitle
        }
    }
}

#Preview("Document window") {
    DocumentWindow(document: .constant(ChessDocument()))
}
