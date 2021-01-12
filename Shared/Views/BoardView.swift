//
//  BoardView.swift
//  BChess
//
//  Created by Jean Bovet on 1/10/21.
//  Copyright © 2021 Jean Bovet. All rights reserved.
//

import SwiftUI

struct BoardView: View {
    
    @Binding var document: BChessUIDocument

    func backgroundColor(rank: Int, file: Int) -> Color {
        if rank % 2 == 0 {
            return file % 2 == 0 ? .gray : .white
        } else {
            return file % 2 == 0 ? .white : .gray
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            ForEach((0...7).reversed(), id: \.self) { rank in
                HStack(spacing: 0) {
                    ForEach((0...7), id: \.self) { file in
                        let r = rank.actual(document.playAgainst)
                        let f = file.actual(document.playAgainst)
                        Rectangle()
                            .fill(backgroundColor(rank: r, file: f))
                            .modifier(LastMoveModifier(rank: r, file: f, lastMove: document.lastMove))
                            .modifier(SelectionModifier(rank: r, file: f, selection: document.selection))
                    }
                }
            }
        }
        .aspectRatio(1.0, contentMode: .fit)
    }
}

struct BoardView_Previews: PreviewProvider {
    static var previews: some View {
        let doc = BChessUIDocument()
        BoardView(document: .constant(doc))
    }
}
