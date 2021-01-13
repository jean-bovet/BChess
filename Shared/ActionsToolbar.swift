//
//  ActionsToolbar.swift
//  BChess
//
//  Created by Jean Bovet on 1/12/21.
//  Copyright © 2021 Jean Bovet. All rights reserved.
//

import SwiftUI

struct ShowHideInfoButton: View {
    @Binding var document: BChessUIDocument
    @Binding var showInfo: Bool
    var body: some View {
        Button(action: { showInfo.toggle() }) {
            if (showInfo) {
                Label("Hide Information", systemImage: "info.circle")
            } else {
                Label("Show Information", systemImage: "info.circle")
            }
        }
    }
}

struct UndoMoveButton: View {
    @Binding var document: BChessUIDocument
    var body: some View {
        Button(action: { Actions(document: $document).undoMove() }) {
            Label("Undo Move", systemImage: "arrow.uturn.backward.square.fill")
        }.disabled(!document.engine.canUndoMove())
    }
}

struct RedoMoveButton: View {
    @Binding var document: BChessUIDocument
    var body: some View {
        Button(action: { Actions(document: $document).redoMove() }) {
            Label("Redo Move", systemImage: "arrow.uturn.forward.square.fill")
        }.disabled(!document.engine.canRedoMove())
    }
}

struct LevelPicker: View {
    @Binding var document: BChessUIDocument
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
    @Binding var document: BChessUIDocument
    
    var body: some View {
        Menu {
            Section {
                Button(action: { Actions(document: $document).newGame(playAgainstWhite: false ) }) {
                    Label("New Game as White", systemImage: "plus.circle.fill")
                }

                Button(action: { Actions(document: $document).newGame(playAgainstWhite: true ) }) {
                    Label("New Game as Black", systemImage: "plus.circle")
                }
            }
        }
        label: {
            Label("Actions", systemImage: "ellipsis.circle")
        }
    }
}

struct ActionsToolbar: ToolbarContent {

    @Binding var document: BChessUIDocument
    @Binding var showInfo: Bool
    
    var body: some ToolbarContent {
        #if os(macOS)
        ToolbarItemGroup(placement: .automatic) {
            ShowHideInfoButton(document: $document, showInfo: $showInfo)
            
            UndoMoveButton(document: $document)
            RedoMoveButton(document: $document)
            
            LevelPicker(document: $document)
            
            NewGameMenu(document: $document)
        }
        #else
        ToolbarItemGroup(placement: .automatic) {
            NewGameMenu(document: $document)
        }
        ToolbarItemGroup(placement: .bottomBar) {
            ShowHideInfoButton(document: $document, showInfo: $showInfo)
            Spacer()
            
            UndoMoveButton(document: $document)
            Spacer()
            
            RedoMoveButton(document: $document)
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
