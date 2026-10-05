//
//  BoardView.swift
//  BChess
//
//  Created by Jean Bovet on 1/10/21.
//  Copyright © 2021 Jean Bovet. All rights reserved.
//

import SwiftUI

struct BoardView: View {
    
    let session: GameSession

    /// The squares keep these colors in light and dark mode
    static let lightSquare = Color.white
    static let darkSquare = Color.gray

    func backgroundColor(rank: Int, file: Int) -> Color {
        if rank % 2 == 0 {
            return file % 2 == 0 ? Self.darkSquare : Self.lightSquare
        } else {
            return file % 2 == 0 ? Self.lightSquare : Self.darkSquare
        }
    }
    
    // We draw a board that has one more rank and one more file
    // which are going to be used to display the labels
    var body: some View {
        VStack(spacing: 0) {
            ForEach((0...7).reversed(), id: \.self) { rank in
                HStack(spacing: 0) {
                    ForEach(0...7, id: \.self) { file in
                        let r = rank.actual(rotated: session.gameState.rotated)
                        let f = file.actual(rotated: session.gameState.rotated)
                        Rectangle()
                            .fill(backgroundColor(rank: r, file: f))
                            .modifier(LastMoveModifier(rank: r, file:f, session: session))
                            .modifier(SelectionModifier(rank: r, file: f, selection: session.selection))
                    }
                }
            }
        }
        .aspectRatio(1.0, contentMode: .fit)
    }
}

#Preview {
    BoardView(session: GameSession())
}
