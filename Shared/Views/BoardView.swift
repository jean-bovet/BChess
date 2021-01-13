//
//  BoardView.swift
//  BChess
//
//  Created by Jean Bovet on 1/10/21.
//  Copyright © 2021 Jean Bovet. All rights reserved.
//

import SwiftUI

struct BoardView: View {
    
    @Binding var document: ChessDocument

    func backgroundColor(rank: Int, file: Int) -> Color {
        if rank % 2 == 0 {
            return file % 2 == 0 ? .gray : .white
        } else {
            return file % 2 == 0 ? .white : .gray
        }
    }
    
    // We draw a board that has one more rank and one more file
    // which are going to be used to display the labels
    var body: some View {
        VStack(spacing: 0) {
            ForEach((0...8).reversed(), id: \.self) { rank in
                HStack(spacing: 0) {
                    ForEach(0...8, id: \.self) { file in
                        if rank == 0 || file == 0 {
                            // Display nothing for the first rank and file
                            // as the labels will be displayed in there
                            Rectangle()
                                .fill(Color.clear)
                        } else {
                            let r = (rank - 1).actual(document.playAgainst)
                            let f = (file - 1).actual(document.playAgainst)
                            Rectangle()
                                .fill(backgroundColor(rank: r, file: f))
                                .modifier(LastMoveModifier(rank: r, file: f, lastMove: document.lastMove))
                                .modifier(SelectionModifier(rank: r, file: f, selection: document.selection))
                        }
                    }
                }
            }
        }
        .aspectRatio(1.0, contentMode: .fit)
    }
}

struct BoardView_Previews: PreviewProvider {
    static var previews: some View {
        let doc = ChessDocument()
        BoardView(document: .constant(doc))
    }
}
