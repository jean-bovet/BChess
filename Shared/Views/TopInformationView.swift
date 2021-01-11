//
//  TopInformationView.swift
//  BChess
//
//  Created by Jean Bovet on 1/10/21.
//  Copyright © 2021 Jean Bovet. All rights reserved.
//

import SwiftUI

struct TopInformationView: View {
    
    let info: FEngineInfo?
    let engine: FEngine
    
    func whoIsPlaying() -> String {
        var text = engine.isWhite() ? "White" : "Black"
        if engine.isAnalyzing() {
            text.append(" is thinking")
        } else {
            text.append("'s turn")
        }
        return text
    }
    
    var body: some View {
        VStack(alignment: .leading) {
            Text(whoIsPlaying()).bold()
            Text(engine.pgnFormattedForDisplay())
        }
    }
}
