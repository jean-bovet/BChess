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
    
    let session: GameSession
    
    @State private var isPromotionViewShown = false
    @State private var promotion = Promotion(move: FEngineMove(), isWhite: true)

    func processTap(_ rank: Int, _ file: Int) {
        if let move = session.selection.possibleMove(rank, file) {
            if move.isPromotion {
                promotion = Promotion(move: move, isWhite: session.isWhiteToMove)
                isPromotionViewShown.toggle()
            } else {
                session.playHuman(move)
            }
        } else {
            session.select(rank: rank, file: file)
        }
    }

    func board(withPieces pieces: [Piece]) -> [Square] {
        var squares = [Square]()
        for rank in 0...7 {
            for file in 0...7 {
                let piece = pieces.piece(atRank: rank, file: file)
                let square = Square(position: Position(rank: rank, file: file), piece: piece)
                squares.append(square)
            }
        }
        return squares
    }
    
    func squareIdentifier(_ position: Position) -> String {
        "square-\(["a", "b", "c", "d", "e", "f", "g", "h"][position.file])\(position.rank + 1)"
    }
    
    func applyPromotion(pieceName: String) {
        promotion.move.setPromotionPiece(pieceName)
        session.playHuman(promotion.move)
    }
        
    var body: some View {
        GeometryReader { geometry in
            let minSize: CGFloat = min(geometry.size.width, geometry.size.height)
            let squareSize: CGFloat = minSize / CGFloat(numberOfSquares)
            let xOffset: CGFloat = (geometry.size.width - minSize) / 2
            let yOffset: CGFloat = (geometry.size.height - minSize) / 2
            let rotated = session.gameState.rotated
            let b: [Square] = board(withPieces: session.pieces)
            ForEach(b) { square in
                let x = CGFloat(square.position.file.actual(rotated: rotated)) * squareSize + xOffset
                let y = CGFloat(7 - square.position.rank.actual(rotated: rotated)) * squareSize + yOffset
                SquareView(piece: square.piece)
                    .frame(width: squareSize, height: squareSize)
                    .offset(x: x,
                            y: y)
                    .onTapGesture {
                        processTap(square.position.rank, square.position.file)
                    }
                    .accessibilityElement()
                    .accessibilityIdentifier(squareIdentifier(square.position))
                    .accessibilityValue(square.piece.map { String($0.name.prefix(1)) } ?? "empty")
                    .accessibilityAddTraits(.isButton)
            }
        }
        .onAppear() {
            // Start to play after this view appear which takes care of starting
            // the engine when the game is first shown
            session.requestEngineMoveIfNeeded()
        }
        .sheet(isPresented: $isPromotionViewShown) {
            PromotionView(promotion: $promotion, callback: { name in
                self.applyPromotion(pieceName: name)
            })
        }
    }
}

#Preview("White at the bottom") {
    let session = GameSession()
    ZStack {
        BoardView(session: session)
        PiecesView(session: session)
    }
}

#Preview("Rotated") {
    let session = GameSession(state: GameState(pgn: "*", rotated: true))
    ZStack {
        BoardView(session: session)
        PiecesView(session: session)
    }
}
