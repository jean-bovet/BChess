//
//  PiecesView.swift
//  BChess
//
//  Created by Jean Bovet on 1/10/21.
//  Copyright © 2021 Jean Bovet. All rights reserved.
//

import SwiftUI

struct Promotion {
    let move: FEngineMove
    let isWhite: Bool
}

struct PiecesView: View {
    
    @Binding var document: ChessDocument
    
    // This state is used as a workaround to
    // detect when the animation of the piece after
    // a human plays a move is completed so the computer
    // can start thinking. This is to avoid the computer
    // replying at the same time as the animation is
    // ongoing after the human has played.
    @State private var humanPieceAnimation = 0.0

    @State private var isPromotionViewShown = false
    @State private var promotion = Promotion(move: FEngineMove(), isWhite: true)
    
    func processTap(_ rank: Int, _ file: Int) {
        if let move = document.selection.possibleMove(rank, file) {
            if move.isPromotion {
                promotion = Promotion(move: move, isWhite: document.playAgainst == .black)
                isPromotionViewShown.toggle()
            } else {
                doMove(move)
            }
        } else {
            document.selection = Selection(position: Position(rank: rank, file: file),
                                           possibleMoves: document.engine.moves(at: UInt(rank), file: UInt(file)))
        }
    }

    func doMove(_ move: FEngineMove) {
        withAnimation {
            Actions(document: $document).playMove(move: move)
            
            // Set the final value to detect when the animation ends
            // (see below in onAnimationCompleted)
            humanPieceAnimation = 1.0
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
    
    func applyPromotion(pieceName: String) {
        promotion.move.setPromotionPiece(pieceName)
        doMove(promotion.move)
    }
    
    var body: some View {
        GeometryReader { geometry in
            let minSize: CGFloat = min(geometry.size.width, geometry.size.height)
            let squareSize: CGFloat = minSize / (CGFloat(numberOfSquares) + 1)
            let xOffset: CGFloat = (geometry.size.width - minSize) / 2 + squareSize
            let yOffset: CGFloat = (geometry.size.height - minSize) / 2
            let b: [Square] = board(withPieces: document.pieces)
            ForEach(b) { square in
                let x = CGFloat(square.file.actual(document.playAgainst)) * squareSize + xOffset
                let y = CGFloat(7 - square.rank.actual(document.playAgainst)) * squareSize + yOffset
                SquareView(piece: square.piece)
                    .frame(width: squareSize, height: squareSize)
                    .offset(x: x,
                            y: y)
                    .onTapGesture {
                        processTap(square.rank, square.file)
                    }
            }
        }
        .onAnimationCompleted(for: humanPieceAnimation) {
            // Animation has completed, reset the value
            humanPieceAnimation = 0
            // And trigger the computer's move
            withAnimation {
                Actions(document: $document).enginePlay()
            }
        }.sheet(isPresented: $isPromotionViewShown) {
            PromotionView(promotion: $promotion, callback: { name in
                self.applyPromotion(pieceName: name)
            })
        }
    }
}

struct PiecesView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            let doc = ChessDocument()
            ZStack {
                BoardView(document: .constant(doc))
                PiecesView(document: .constant(doc))
            }
        }
        Group {
            let doc = ChessDocument(playAgainst: .white)
            ZStack {
                BoardView(document: .constant(doc))
                PiecesView(document: .constant(doc))
            }
        }
    }
}
