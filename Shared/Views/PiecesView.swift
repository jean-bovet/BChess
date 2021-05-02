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
    
    @State private var isPromotionViewShown = false
    @State private var promotion = Promotion(move: FEngineMove(), isWhite: true)
    
    // This state is used as a workaround to
    // detect when the animation of the piece after
    // a move is completed so the computer can start thinking.
    // This is to avoid the computer replying at the same time as the animation is
    // ongoing after the human (or computer) has played.
    @State private var pieceAnimationValue = 0.0

    func processTap(_ rank: Int, _ file: Int) {
        if let move = document.selection.possibleMove(rank, file) {
            if move.isPromotion {
                promotion = Promotion(move: move, isWhite: document.engine.isWhite())
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
            playMove(move: move)
            
            // Set the final value to detect when the animation ends
            // (see below in onAnimationCompleted)
            pieceAnimationValue = 1.0
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
    
    func triggerEngineEvaluationIfSuitable() {
        // Don't play the engine while the user is analyzing the board
        guard document.state == .play else {
            return
        }
        
        // Only play the computer if the current color matches
        // a player who is a computer.
        guard document.engine.isWhite() && document.whitePlayer.computer || !document.engine.isWhite() && document.blackPlayer.computer else {
            return
        }

        // Ensure the engine internal state allows it to play
        guard document.engine.canPlay() else {
            return
        }
                
        // Trigger the engine evaluation
        document.engine.evaluate { (info, completed) in
            DispatchQueue.main.async {
                if completed {
                    withAnimation {
                        playMove(info: info)
                        
                        // Set the final value to detect when the animation ends
                        // (see below in onAnimationCompleted)
                        pieceAnimationValue = 1.0
                    }
                } else {
                    self.document.info = info
                }
            }
        }
    }

    func playMove(move: FEngineMove) {
        document.selection = Selection.empty()
        document.lastMove = nil
        document.applyEngineSettings()
        document.engine.move(move.rawMoveValue)
        document.pgn = document.engine.pgn()
    }
    
    func playMove(info: FEngineInfo) {
        document.selection = Selection.empty()
        document.lastMove = info.bestEngineMove
        document.info = info
        document.applyEngineSettings()
        document.engine.move(info.bestMove)
        document.pgn = document.engine.pgn()
    }
        
    var body: some View {
        GeometryReader { geometry in
            let minSize: CGFloat = min(geometry.size.width, geometry.size.height)
            let squareSize: CGFloat = minSize / CGFloat(numberOfSquares)
            let xOffset: CGFloat = (geometry.size.width - minSize) / 2
            let yOffset: CGFloat = (geometry.size.height - minSize) / 2
            let b: [Square] = board(withPieces: document.pieces)
            ForEach(b) { square in
                let x = CGFloat(square.file.actual(rotated: document.rotated)) * squareSize + xOffset
                let y = CGFloat(7 - square.rank.actual(rotated: document.rotated)) * squareSize + yOffset
                SquareView(piece: square.piece)
                    .frame(width: squareSize, height: squareSize)
                    .offset(x: x,
                            y: y)
                    .onTapGesture {
                        processTap(square.rank, square.file)
                    }
            }
        }
        .onAppear() {
            // Start to play after this view appear which takes care of starting
            // the engine when the document is first opened
            triggerEngineEvaluationIfSuitable()
        }
        .onChange(of: document.engineShouldMove, perform: { value in
            // Start to play after a change in this state, which is usually
            // triggered after a new game is selected
            triggerEngineEvaluationIfSuitable()
        })
        .onAnimationCompleted(for: pieceAnimationValue) {
            // Animation has completed, reset the value
            pieceAnimationValue = 0
            // And trigger the engine evaluation if suitable
            triggerEngineEvaluationIfSuitable()
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
            let doc = ChessDocument(rotated: true)
            ZStack {
                BoardView(document: .constant(doc))
                PiecesView(document: .constant(doc))
            }
        }
    }
}
