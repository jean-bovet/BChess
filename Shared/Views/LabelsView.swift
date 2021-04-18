//
//  LabelsView.swift
//  BChess
//
//  Created by Jean Bovet on 1/12/21.
//  Copyright © 2021 Jean Bovet. All rights reserved.
//

import SwiftUI

struct LabelsView: View {
    @Binding var document: ChessDocument

    func actualIndex(_ index: Int) -> Int {
        if document.rotated {
            return index
        } else {
            return 7 - index
        }
    }
    
    var body: some View {
        GeometryReader { geometry in
            let minSize: CGFloat = min(geometry.size.width, geometry.size.height)
            let xOffset: CGFloat = (geometry.size.width - minSize) / 2
            let yOffset: CGFloat = (geometry.size.height - minSize) / 2
            let squareSize: CGFloat = minSize / (8 + 1)
            
            ForEach(0...7, id:\.self) { index in
                let ai = actualIndex(index)
                let x = xOffset
                let y = yOffset + CGFloat(index) * squareSize
                Text("\(8 - ai)")
                    .font(.title)
                    .frame(width: squareSize, height: squareSize)
                    .offset(x: x, y: y)
            }
            
            ForEach(Array(["a", "b", "c", "d", "e", "f", "g", "h"].enumerated()), id:\.offset) { index, value in
                let x = xOffset + CGFloat(actualIndex(index)) * squareSize + squareSize
                let y = yOffset + CGFloat(numberOfSquares) * squareSize
                Text("\(value)")
                    .font(.title)
                    .frame(width: squareSize, height: squareSize)
                    .offset(x: x, y: y)
            }
        }
    }
}

struct LabelsView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            let doc = ChessDocument(playAgainst: .black)
            ZStack {
                BoardView(document: .constant(doc))
                LabelsView(document: .constant(doc))
            }
        }
        Group {
            let doc = ChessDocument(playAgainst: .white)
            ZStack {
                BoardView(document: .constant(doc))
                LabelsView(document: .constant(doc))
            }
        }
    }
}
