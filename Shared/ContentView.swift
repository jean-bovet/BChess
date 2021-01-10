//
//  ContentView.swift
//  Shared
//
//  Created by Jean Bovet on 1/7/21.
//  Copyright © 2021 Jean Bovet. All rights reserved.
//

import SwiftUI

extension View {
    @ViewBuilder
    func `if`<Content: View>(_ condition: Bool, content: (Self) -> Content) -> some View {
        if condition {
            content(self)
        }
        else {
            self
        }
    }
}

struct Position {
    let rank: Int
    let file: Int
    
    static func empty() -> Position {
        return Position(rank: -1, file: -1)
    }
}
    
struct LastMoveModifier: ViewModifier {
    let rank: Int
    let file: Int
    let lastMove: FEngineMove?
    
    func isLastMoveStart(_ rank: Int, _ file: Int) -> Bool {
        if let move = lastMove {
            return move.fromRank == rank && move.fromFile == file
        } else {
            return false
        }
    }

    func isLastMoveEnd(_ rank: Int, _ file: Int) -> Bool {
        if let move = lastMove {
            return move.toRank == rank && move.toFile == file
        } else {
            return false
        }
    }


    func body(content: Content) -> some View {
        return content
            .if(isLastMoveStart(rank, file)) { view in
                view.border(Color.orange.opacity(0.8), width: 3)
            }
            .if(isLastMoveEnd(rank, file)) { view in
                view.border(Color.orange.opacity(0.8), width: 5)
            }
    }
}

struct ContentView: View {
    @Binding var document: BChessUIDocument
    @State private var selection = Position.empty()
    @State private var possibleMoves = [FEngineMove]()
    @State private var lastMove: FEngineMove?

    func backgroundColor(rank: Int, file: Int) -> Color {
        if rank % 2 == 0 {
            return file % 2 == 0 ? .gray : .white
        } else {
            return file % 2 == 0 ? .white : .gray
        }
    }
    
    func selected(rank: Int, file: Int) -> Bool {
        return selection.rank == rank && selection.file == file
    }
    
    func isPossibleMove(_ rank: Int, _ file: Int) -> Bool {
        return possibleMove(rank, file) != nil
    }
    
    func possibleMove(_ rank: Int, _ file: Int) -> FEngineMove? {
        return possibleMoves.filter { $0.fromFile == file && $0.fromRank == rank || $0.toFile == file && $0.toRank == rank }.first
    }
    
    func pieceImage(atRank rank: Int, file: Int) -> Image? {
        return document.pieces.filter { $0.rank == rank && $0.file == file }.first?.image
    }

    func processTap(_ rank: Int, _ file: Int) {
        if let move = possibleMove(rank, file) {
            document.engine.move(move.rawMoveValue)
            document.engine.evaluate { (info, completed) in
                DispatchQueue.main.async {
                    if completed {
                        self.document.engine.move(info.bestMove)
                        
                        // TODO: refactor?
                        let move = FEngineMove()
                        move.fromFile = info.fromFile
                        move.fromRank = info.fromRank
                        move.toFile = info.toFile
                        move.toRank = info.toRank
                        move.rawMoveValue = info.bestMove
                        self.lastMove = move
                    }
//                    self.infoChanged?(info)
                }
            }
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            ForEach((0...7).reversed(), id: \.self) { rank in
                HStack(spacing: 0) {
                    ForEach((0...7), id: \.self) { file in
                        if let image = pieceImage(atRank: rank, file: file) {
                            Rectangle()
                                .fill(backgroundColor(rank: rank, file: file))
                                .overlay(image.resizable())
                                .if(selected(rank: rank, file: file) || isPossibleMove(rank, file)) { view in
                                    view.overlay(Color.yellow.opacity(0.8))
                                }
                                .modifier(LastMoveModifier(rank: rank, file: file, lastMove: lastMove))
                                .onTapGesture {
                                    selection = Position(rank: rank, file: file)
                                    possibleMoves = document.engine.moves(at: UInt(rank), file: UInt(file))
                                }
                        } else {
                            Rectangle()
                                .fill(backgroundColor(rank: rank, file: file))
                                .if(isPossibleMove(rank, file)) { view in
                                    view.overlay(Color.yellow.opacity(0.8))
                                }
                                .modifier(LastMoveModifier(rank: rank, file: file, lastMove: lastMove))
                                .onTapGesture {
                                    withAnimation {
                                        processTap(rank, file)
                                        selection = Position.empty()
                                        possibleMoves.removeAll()
                                    }
                                }
                        }
                    }
                }
            }
        }
        .aspectRatio(1.0, contentMode: .fit)
        .padding()
    }
}

struct Piece {
    let name: String
    let file: UInt
    let rank: UInt
    let image: Image
}

struct PiecesFactory {
    
    let pieceImageNames = [
        "p" : "pawn_b",
        "P" : "pawn_w",
        "n" : "knight_b",
        "N" : "knight_w",
        "b" : "bishop_b",
        "B" : "bishop_w",
        "r" : "rook_b",
        "R" : "rook_w",
        "q" : "queen_b",
        "Q" : "queen_w",
        "k" : "king_b",
        "K" : "king_w",
        ]
    
    func pieces(forState state: String) -> [Piece] {
        var pieces = [Piece]()
        var cursor = state.startIndex
        while cursor < state.endIndex {
            let nextCursor = state.index(cursor, offsetBy: 4)
            let token = state[cursor..<nextCursor]
            pieces.append(piece(forToken: String(token)))
            cursor = nextCursor
        }
        return pieces
    }
    
    func piece(forToken token: String) -> Piece {
        let pieceName = String(token.prefix(2))
        let pieceFile = UInt(String(token[token.index(token.startIndex, offsetBy: 2)]))!
        let pieceRank = UInt(String(token[token.index(token.startIndex, offsetBy: 3)]))!
        
        let pieceImageName = String(pieceName.prefix(1))
        let pieceImage = Image(pieceImageNames[pieceImageName]!)
        return Piece(name: pieceName, file: pieceFile, rank: pieceRank, image: pieceImage)
    }
                    
}

struct ContentView_Previews: PreviewProvider {
    
    static var previews: some View {
        Group {
            ContentView(document: .constant(BChessUIDocument()))
        }
    }
}
