//
//  ActionsToolbar.swift
//  BChess
//
//  Created by Jean Bovet on 1/12/21.
//  Copyright © 2021 Jean Bovet. All rights reserved.
//

import SwiftUI

struct NewGameButton: View {
    @Binding var document: ChessDocument
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
    @Binding var document: ChessDocument
    var body: some View {
        Button(action: { withAnimation { Actions(document: $document).analyze() } }) {
            Label("Analyze Game", systemImage: "magnifyingglass.circle")
        }
    }
}

struct TrainButton: View {
    @Binding var document: ChessDocument
    var body: some View {
        Button(action: { withAnimation { Actions(document: $document).train() } }) {
            Label("Practice Openings", systemImage: "book")
        }
    }
}

struct EditGameButton: View {
    @Binding var document: ChessDocument
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
            Label("Flip Board", systemImage: "arrow.triangle.2.circlepath.circle")
        }
    }
}

struct CopyFENButton: View {
    @Binding var document: ChessDocument
    var body: some View {
        Button(action: { Actions(document: $document).copyFEN() }) {
            Label("Copy Position", systemImage: "doc.on.doc")
        }
    }
}

struct CopyPGNButton: View {
    @Binding var document: ChessDocument
    var body: some View {
        Button(action: { Actions(document: $document).copyPGN() }) {
            Label("Copy Game", systemImage: "doc.on.doc")
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

struct CopyPasteMenu: View {
    @Binding var document: ChessDocument
    
    var body: some View {
        Section {
            CopyFENButton(document: $document)
            CopyPGNButton(document: $document)
            PasteButton(document: $document)
        }
    }
}

struct ActionsToolbar: ToolbarContent {

    @Binding var document: ChessDocument
    @Binding var showInfo: Bool
    @Binding var showNewGameSheet: Bool
    @Binding var newGameSheetEditMode: Bool

    var body: some ToolbarContent {
        #if os(macOS)
        ToolbarItemGroup(placement: .automatic) {
            Menu {
                NewGameButton(document: $document, showNewGameSheet: $showNewGameSheet, newGameSheetEditMode: $newGameSheetEditMode)
                EditGameButton(document: $document, showNewGameSheet: $showNewGameSheet, newGameSheetEditMode: $newGameSheetEditMode)

                Divider()
                
                AnalyzeBoard(document: $document)
                TrainButton(document: $document)

                Divider()

                RotateBoard(document: $document)

                Divider()

                ShowHideInfoButton(document: $document, showInfo: $showInfo)
            }
            label: {
                Label("Board", systemImage: "checkerboard.rectangle")
            }
            
            Menu {
                CopyPasteMenu(document: $document)
            }
            label: {
                Label("Copy & Paste", systemImage: "doc.on.doc")
            }
        }
        #else
        ToolbarItemGroup(placement: .automatic) {
            Menu {
                NewGameButton(document: $document, showNewGameSheet: $showNewGameSheet, newGameSheetEditMode: $newGameSheetEditMode)
                EditGameButton(document: $document, showNewGameSheet: $showNewGameSheet, newGameSheetEditMode: $newGameSheetEditMode)
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
                CopyPasteMenu(document: $document)
            }
            label: {
                Label("Copy & Paste", systemImage: "doc.on.doc")
            }
        }
        #endif
        
    }
}
