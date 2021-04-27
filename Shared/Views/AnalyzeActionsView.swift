//
//  AnalyzeActionsView.swift
//  BChess
//
//  Created by Jean Bovet on 4/26/21.
//  Copyright © 2021 Jean Bovet. All rights reserved.
//

import SwiftUI

struct AnalyzeActionsView: View {
    
    @Binding var document: ChessDocument
    
    var body: some View {
        HStack() {
            Spacer()
            Button(action: {
                Actions(document: $document).analyzeReset()
            }) {
                Image(systemName: "arrow.counterclockwise.circle.fill")
            }
            Button(action: {
                Actions(document: $document).undoMove()
            }) {
                Image(systemName: "arrowtriangle.backward.fill")
            }
            Button(action: {
                Actions(document: $document).redoMove()
            }) {
                Image(systemName: "arrowtriangle.forward.fill")
            }
            Spacer()                        
        }
    }
}

struct AnalyzeActionsView_Previews: PreviewProvider {
    static var previews: some View {
        let doc = ChessDocument()
        AnalyzeActionsView(document: .constant(doc))
    }
}
