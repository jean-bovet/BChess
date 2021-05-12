//
//  AnalyzeActionsView.swift
//  BChess
//
//  Created by Jean Bovet on 4/26/21.
//  Copyright © 2021 Jean Bovet. All rights reserved.
//

import SwiftUI

struct NavigationView: View {
    
    @Binding var document: ChessDocument
    
    var body: some View {
        HStack() {
            if document.mode.value != .play {
                Button(action: {
                    Actions(document: $document).analyzeReset()
                }) {
                    Image(systemName: "arrow.counterclockwise.circle.fill")
                }
            }
            
            Button(action: {
                Actions(document: $document).move(to: .start)
            }) {
                Image(systemName: "backward.end.fill")
            }.disabled(!document.engine.canMove(to: .start))

            Button(action: {
                Actions(document: $document).move(to: .backward)
            }) {
                Image(systemName: "arrowtriangle.backward.fill")
            }.disabled(!document.engine.canMove(to: .backward))

            Button(action: {
                Actions(document: $document).move(to: .forward)
            }) {
                Image(systemName: "arrowtriangle.forward.fill")
            }.disabled(!document.engine.canMove(to: .forward))

            Button(action: {
                Actions(document: $document).move(to: .end)
            }) {
                Image(systemName: "forward.end.fill")
            }.disabled(!document.engine.canMove(to: .end))
        }
    }
}

struct NavigationView_Previews: PreviewProvider {
    static var previews: some View {
        let doc = ChessDocument()
        NavigationView(document: .constant(doc))
    }
}
