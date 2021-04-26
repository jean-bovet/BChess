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
            TopInformationView(document: document)
            
            ZStack {
                BoardView(document: $document)
                LabelsView(document: $document)
                PiecesView(document: $document)
            }
            
            if (showInfo) {
                BottomInformationView(document: document)
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
            NewGameView(document: $document, editMode: newGameSheetEditMode)
                .padding()
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
