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

    let engine: FEngine
    let pieces: [Piece]

    func piece(atRank rank: Int, file: Int) -> Piece? {
        return pieces.filter { $0.rank == rank && $0.file == file }.first
    }

    func applyLevelSettings() {
        switch document.level {
        case 0:
            engine.thinkingTime = 2
        case 1:
            engine.thinkingTime = 5
        case 2:
            engine.thinkingTime = 10
        case 3:
            engine.thinkingTime = 15
        default:
            engine.thinkingTime = 2
        }
    }
    
    func processTap(_ rank: Int, _ file: Int) {
        if let move = document.selection.possibleMove(rank, file) {
            withAnimation {
                document.selection = SelectionState(position: Position.empty(), possibleMoves: [])
                applyLevelSettings()
                document.engine.move(move.rawMoveValue)
                document.pgn = document.engine.pgn()
                Actions(document: $document).enginePlay()
            }
        } else {
            document.selection = SelectionState(position: Position(rank: rank, file: file),
                                       possibleMoves: engine.moves(at: UInt(rank), file: UInt(file)))
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
            let b: [Square] = board(withPieces: pieces)
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
        PiecesView(document: .constant(doc), engine: doc.engine, pieces: doc.pieces)
    }
}
