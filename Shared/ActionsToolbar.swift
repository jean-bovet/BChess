//
//  ActionsToolbar.swift
//  BChess
//
//  Created by Jean Bovet on 1/12/21.
//  Copyright © 2021 Jean Bovet. All rights reserved.
//

import SwiftUI

struct NewGameButton: View {
    @Binding var showNewGameSheet: Bool
    @Binding var newGameSheetEditMode: Bool

    var body: some View {
        Button(action: {
            self.newGameSheetEditMode = false
            self.showNewGameSheet.toggle()
        }) {
            Label("New Game", systemImage: "plus.circle")
        }
    }
}

struct AnalyzeBoard: View {
    let session: GameSession
    var body: some View {
        Button(action: { withAnimation { session.toggleAnalyze() } }) {
            Label("Analyze Game", systemImage: "magnifyingglass.circle")
        }
    }
}

struct TrainButton: View {
    let session: GameSession
    var body: some View {
        Button(action: { withAnimation { session.toggleTrain() } }) {
            Label("Practice Openings", systemImage: "book")
        }
    }
}

struct EditGameButton: View {
    @Binding var showNewGameSheet: Bool
    @Binding var newGameSheetEditMode: Bool

    var body: some View {
        Button(action: {
            self.newGameSheetEditMode = true
            self.showNewGameSheet.toggle()
        }) {
            Label("Edit Game", systemImage: "pencil")
        }
    }
}

struct ShowHideInfoButton: View {
    @Binding var showInfo: Bool
    var body: some View {
        Button(action: { withAnimation { showInfo.toggle() } }) {
            if (showInfo) {
                Label("Hide Information", systemImage: "info.circle")
            } else {
                Label("Show Information", systemImage: "info.circle")
            }
        }
    }
}

struct RotateBoard: View {
    let session: GameSession
    var body: some View {
        Button(action: { session.rotate() }) {
            Label("Flip Board", systemImage: "arrow.triangle.2.circlepath.circle")
        }
    }
}

struct UndoMoveButton: View {
    let session: GameSession
    var body: some View {
        Button(action: { withAnimation { session.undo() } }) {
            Label("Undo Move", systemImage: "arrow.uturn.backward.square")
        }.disabled(!session.canMove(to: .backward))
    }
}

struct RedoMoveButton: View {
    let session: GameSession
    var body: some View {
        Button(action: { withAnimation { session.redo() } }) {
            Label("Redo Move", systemImage: "arrow.uturn.forward.square")
        }.disabled(!session.canMove(to: .forward))
    }
}

struct CopyFENButton: View {
    let session: GameSession
    var body: some View {
        Button(action: { Pasteboard.set(session.fen) }) {
            Label("Copy Position", systemImage: "doc.on.doc")
        }
    }
}

struct CopyPGNButton: View {
    let session: GameSession
    var body: some View {
        Button(action: { Pasteboard.set(session.pgnCurrentGame) }) {
            Label("Copy Game", systemImage: "doc.on.doc")
        }
    }
}

struct PasteButton: View {
    let session: GameSession
    var body: some View {
        Button(action: {
            if let text = Pasteboard.string {
                _ = session.paste(text)
            }
        }) {
            Label("Paste", systemImage: "arrow.down.circle")
        }
    }
}

struct CopyPasteMenu: View {
    let session: GameSession
    
    var body: some View {
        Section {
            CopyFENButton(session: session)
            CopyPGNButton(session: session)
            PasteButton(session: session)
        }
    }
}

struct GameSelectionMenu: View {
    let session: GameSession
        
    var body: some View {
        Picker(selection: Binding(get: { session.currentGameIndex }, set: { session.selectGame($0) }), label: Text("Games")) {
            ForEach(session.games, id:\.self) { game in
                Text(game.name).tag(Int(game.index))
            }
        }
    }
}

struct ActionsToolbar: ToolbarContent {

    let session: GameSession
    @Binding var showInfo: Bool
    @Binding var showNewGameSheet: Bool
    @Binding var newGameSheetEditMode: Bool

    var body: some ToolbarContent {
        #if os(macOS)
        ToolbarItemGroup(placement: .automatic) {
            Menu {
                NewGameButton(showNewGameSheet: $showNewGameSheet, newGameSheetEditMode: $newGameSheetEditMode)
                EditGameButton(showNewGameSheet: $showNewGameSheet, newGameSheetEditMode: $newGameSheetEditMode)

                GameSelectionMenu(session: session)
                
                Divider()
                
                AnalyzeBoard(session: session)
                TrainButton(session: session)

                Divider()

                RotateBoard(session: session)

                Divider()

                ShowHideInfoButton(showInfo: $showInfo)
            }
            label: {
                Label("Board", systemImage: "checkerboard.rectangle")
            }
            
            Menu {
                CopyPasteMenu(session: session)
            }
            label: {
                Label("Copy & Paste", systemImage: "doc.on.doc")
            }
        }
        #else
        ToolbarItemGroup(placement: .automatic) {
            Menu {
                NewGameButton(showNewGameSheet: $showNewGameSheet, newGameSheetEditMode: $newGameSheetEditMode)
                EditGameButton(showNewGameSheet: $showNewGameSheet, newGameSheetEditMode: $newGameSheetEditMode)
                RotateBoard(session: session)
            }
            label: {
                Label("Actions", systemImage: "ellipsis.circle")
            }
        }
        ToolbarItemGroup(placement: .bottomBar) {
            ShowHideInfoButton(showInfo: $showInfo)
            Spacer()
            
            UndoMoveButton(session: session)
            Spacer()
            
            RedoMoveButton(session: session)
            Spacer()

            Menu {
                CopyPasteMenu(session: session)
            }
            label: {
                Label("Copy & Paste", systemImage: "doc.on.doc")
            }
        }
        #endif
        
    }
}
