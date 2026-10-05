//
//  LabelsView.swift
//  BChess
//
//  Created by Jean Bovet on 1/12/21.
//  Copyright © 2021 Jean Bovet. All rights reserved.
//

import SwiftUI

struct LabelsView: View {
    let session: GameSession

    func actualIndex(_ index: Int) -> Int {
        if session.gameState.rotated {
            return 7 - index
        } else {
            return index
        }
    }
    
    var body: some View {
        GeometryReader { geometry in
            let minSize: CGFloat = min(geometry.size.width, geometry.size.height)
            let xOffset: CGFloat = (geometry.size.width - minSize) / 2
            let yOffset: CGFloat = (geometry.size.height - minSize) / 2
            let squareSize: CGFloat = minSize / 8
            
            ForEach(0...7, id:\.self) { index in
                let ai = actualIndex(index)
                let x = xOffset - 0.1 * squareSize - squareSize
                let y = yOffset + CGFloat(index) * squareSize
                Text("\(8 - ai)")
                    .font(.title2)
                    .frame(width: squareSize, height: squareSize, alignment: .trailing)
                    .offset(x: x, y: y)
            }
            
            ForEach(Array(["a", "b", "c", "d", "e", "f", "g", "h"].enumerated()), id:\.offset) { index, value in
                let x = xOffset + CGFloat(actualIndex(index)) * squareSize
                let y = yOffset + CGFloat(numberOfSquares) * squareSize + 0.1 * squareSize
                Text("\(value)")
                    .font(.title2)
                    .frame(width: squareSize, height: squareSize, alignment: .top)
                    .offset(x: x, y: y)
            }
        }
    }
}

#Preview("White at the bottom") {
    let session = GameSession()
    ZStack {
        BoardView(session: session)
        LabelsView(session: session)
    }
}

#Preview("Rotated") {
    let session = GameSession(state: GameState(pgn: "*", rotated: true))
    ZStack {
        BoardView(session: session)
        LabelsView(session: session)
    }
}
