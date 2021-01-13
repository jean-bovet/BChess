//
//  TopInformationView.swift
//  BChess
//
//  Created by Jean Bovet on 1/10/21.
//  Copyright © 2021 Jean Bovet. All rights reserved.
//

import SwiftUI

struct TopInformationView: View {
    
    let document: ChessDocument

    func whoIsPlaying() -> String {
        var text = document.engine.isWhite() ? "White" : "Black"
        if document.engine.isAnalyzing() {
            text.append(" is thinking")
        } else {
            text.append("'s turn")
        }
        return text
    }
    
    var body: some View {
        VStack(alignment: .leading) {
            Text(whoIsPlaying()).bold()
            Text(document.engine.pgnFormattedForDisplay())
        }
    }
}
