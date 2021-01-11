//
//  PiecesView.swift
//  BChess
//
//  Created by Jean Bovet on 1/10/21.
//  Copyright © 2021 Jean Bovet. All rights reserved.
//

import SwiftUI

struct PiecesView: View {
    
    @Binding var document: BChessUIDocument

    func processTap(_ rank: Int, _ file: Int) {
        if let move = document.selection.possibleMove(rank, file) {
            withAnimation {
                Actions(document: $document).playMove(move: move)
            }
            withAnimation {
                Actions(document: $document).enginePlay()
            }
        } else {
            document.selection = SelectionState(position: Position(rank: rank, file: file),
                                                possibleMoves: document.engine.moves(at: UInt(rank), file: UInt(file)))
        }
    }

    func board(withPieces pieces: [Piece]) -> [Square] {
        var squares = [Square]()
        for rank in 0...7 {
            for file in 0...7 {
                let piece = pieces.piece(atRank: rank, file: file)
                let square = Square(rank: rank, file: file, piece: piece)
                squares.append(square)
            }
        }
        return squares
    }
    
    var body: some View {
        GeometryReader { geometry in
            let minSize: CGFloat = min(geometry.size.width, geometry.size.height)
            let xOffset: CGFloat = (geometry.size.width - minSize) / 2
            let yOffset: CGFloat = (geometry.size.height - minSize) / 2
            let squareSize: CGFloat = minSize / 8
            let b: [Square] = board(withPieces: document.pieces)
            ForEach(b) { square in
                let r: Int = square.rank
                let f: Int = square.file
                let x: CGFloat = CGFloat(f) * squareSize + xOffset
                let y: CGFloat = CGFloat(7 - r) * squareSize + yOffset
                SquareView(piece: square.piece)
                    .frame(width: squareSize, height: squareSize)
                    .offset(x: x,
                            y: y)
                    .onTapGesture {
                        processTap(r, f)
                    }
            }
        }
    }
}

struct PiecesView_Previews: PreviewProvider {
    static var previews: some View {
        let doc = BChessUIDocument()
        PiecesView(document: .constant(doc))
    }
}
