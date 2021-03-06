//
//  ActionsToolbar.swift
//  BChess
//
//  Created by Jean Bovet on 1/12/21.
//  Copyright © 2021 Jean Bovet. All rights reserved.
//

import SwiftUI

struct ShowHideInfoButton: View {
    @Binding var document: ChessDocument
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
    @Binding var document: ChessDocument
    var body: some View {
        Button(action: { Actions(document: $document).rotateBoard() }) {
            Label("Rotate Board", systemImage: "arrow.up.arrow.down.circle")
        }
    }
}

struct UndoMoveButton: View {
    @Binding var document: ChessDocument
    var body: some View {
        Button(action: { Actions(document: $document).undoMove() }) {
            Label("Undo Move", systemImage: "arrow.uturn.backward.square")
        }.disabled(!document.engine.canUndoMove())
    }
}

struct RedoMoveButton: View {
    @Binding var document: ChessDocument
    var body: some View {
        Button(action: { Actions(document: $document).redoMove() }) {
            Label("Redo Move", systemImage: "arrow.uturn.forward.square")
        }.disabled(!document.engine.canRedoMove())
    }
}

struct CopyButton: View {
    @Binding var document: ChessDocument
    var body: some View {
        Button(action: { Actions(document: $document).copyFEN() }) {
            Label("Copy", systemImage: "doc.on.doc")
        }
    }
}

struct PasteButton: View {
    @Binding var document: ChessDocument
    var body: some View {
        Button(action: { Actions(document: $document).pasteGame() }) {
            Label("Paste", systemImage: "arrow.down.circle")
        }
    }
}

struct LevelPicker: View {
    @Binding var document: ChessDocument
    var body: some View {
        Picker(selection: $document.level, label: Text("Level")) {
            Text("2 seconds").tag(0)
            Text("5 seconds").tag(1)
            Text("10 seconds").tag(2)
            Text("15 seconds").tag(3)
        }
    }
}

struct NewGameMenu: View {
    @Binding var document: ChessDocument
    
    var body: some View {
        Section {
            Button(action: { Actions(document: $document).newGame(playAgainst: .black) }) {
                Label("New Game as White", systemImage: "plus.circle")
            }

            Button(action: { Actions(document: $document).newGame(playAgainst: .white ) }) {
                Label("New Game as Black", systemImage: "plus.circle.fill")
            }
            
            Button(action: { Actions(document: $document).newGame(playAgainst: .human ) }) {
                Label("New Game Human vs Human", systemImage: "plus.circle")
            }
            
            Divider()
            
            Button(action: { Actions(document: $document).enginePlay() }) {
                Label("Computer to Play", systemImage: "play.fill")
            }
        }
    }
}

struct ActionsToolbar: ToolbarContent {

    @Binding var document: ChessDocument
    @Binding var showInfo: Bool
    
    var body: some ToolbarContent {
        #if os(macOS)
        ToolbarItemGroup(placement: .automatic) {
            ShowHideInfoButton(document: $document, showInfo: $showInfo)
            
            RotateBoard(document: $document)
            
            UndoMoveButton(document: $document)
            RedoMoveButton(document: $document)
            
            CopyButton(document: $document)
            PasteButton(document: $document)

            LevelPicker(document: $document)
            
            Menu {
                NewGameMenu(document: $document)
            }
            label: {
                Label("Actions", systemImage: "ellipsis.circle")
            }
        }
        #else
        ToolbarItemGroup(placement: .automatic) {
            Menu {
                NewGameMenu(document: $document)
                RotateBoard(document: $document)
            }
            label: {
                Label("Actions", systemImage: "ellipsis.circle")
            }
        }
        ToolbarItemGroup(placement: .bottomBar) {
            ShowHideInfoButton(document: $document, showInfo: $showInfo)
            Spacer()
            
            UndoMoveButton(document: $document)
            Spacer()
            
            RedoMoveButton(document: $document)
            Spacer()

            Menu {
                CopyButton(document: $document)
                PasteButton(document: $document)
            }
            label: {
                Label("Copy", systemImage: "doc.on.doc")
            }

            Spacer()
            
            Menu {
                LevelPicker(document: $document)
            }
            label: {
                Label("Level", systemImage: "hourglass")
            }
        }
        #endif
        
    }
}
