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
        VStack(alignment: .leading) {
            if (showInfo) {
                TopInformationView(document: document)
            }
            
            ZStack {
                BoardView(document: $document)
                    .if(document.analyzing) {
                        $0.border(Color.yellow, width: 4)
                    }
                LabelsView(document: $document)
                PiecesView(document: $document)
            }.padding()

            if (showInfo) {
                BottomInformationView(document: document)
                    .padding(.top)
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
            let doc = ChessDocument()
            ContentView(document: .constant(doc))
        }
        Group {
            let doc = ChessDocument(rotated: true)
            ContentView(document: .constant(doc))
        }
    }
}
