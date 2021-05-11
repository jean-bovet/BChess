//
//  ContentView.swift
//  Shared
//
//  Created by Jean Bovet on 1/7/21.
//  Copyright © 2021 Jean Bovet. All rights reserved.
//

import SwiftUI

struct ContentView: View {
    @Binding var document: ChessDocument
            
    @State private var showInfo = true
    
    @State private var showNewGameSheet = false
    @State private var newGameSheetEditMode = false

    var body: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading) {
                ColorInformationView(document: $document, isWhite: document.rotated ? true: false)
                ZStack {
                    BoardView(document: $document)
                        .if(document.mode.value == .analyze) {
                            $0.border(Color.yellow, width: 4)
                        }
                        .if(document.mode.value == .train) {
                            $0.border(Color.green, width: 4)
                        }
                    LabelsView(document: $document)
                    PiecesView(document: $document)
                }
                .padding()
                .padding(.bottom, 20) // Because the labels are "leaking" a bit below the board space itself
                ColorInformationView(document: $document, isWhite: document.rotated ? false: true)
            }
            
            if (showInfo) {
                VStack(alignment: .leading) {
                    if (document.mode.value != .play) {
                        AnalyzeActionsView(document: $document)
                    }
                    
                    InformationView(document: document)
                }
                .frame(minWidth: 350, idealWidth: 350, maxWidth: 350, alignment: .leading)
            }
        }
        .padding()
        .toolbar {
            ActionsToolbar(document: $document,
                           showInfo: $showInfo,
                           showNewGameSheet: $showNewGameSheet,
                           newGameSheetEditMode: $newGameSheetEditMode)
        }
        .sheet(isPresented: $showNewGameSheet) {
            #if os(macOS)
            NewGameView(document: $document, editMode: newGameSheetEditMode)
            #else
            NewGameView_iOS(document: $document, editMode: newGameSheetEditMode)
            #endif
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    
    static var previews: some View {
        Group {
            let doc = ChessDocument(mode: GameMode(value: .analyze))
            ContentView(document: .constant(doc))
        }
        Group {
            let doc = ChessDocument(mode: GameMode(value: .train))
            ContentView(document: .constant(doc))
        }
        Group {
            let doc = ChessDocument(rotated: true)
            ContentView(document: .constant(doc))
        }
    }
}
