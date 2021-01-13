//
//  ContentView.swift
//  Shared
//
//  Created by Jean Bovet on 1/7/21.
//  Copyright © 2021 Jean Bovet. All rights reserved.
//

import SwiftUI

struct ContentView: View {
    @Binding var document: BChessUIDocument
            
    @State private var showInfo: Bool = false
    
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
            ActionsToolbar(document: $document, showInfo: $showInfo)
        }

    }
}

struct ContentView_Previews: PreviewProvider {
    
    static var previews: some View {
        Group {
            let doc = BChessUIDocument()
            ContentView(document: .constant(doc))
        }
        Group {
            let doc = BChessUIDocument(playAgainst: .white)
            ContentView(document: .constant(doc))
        }
    }
}
