//
//  ContentView.swift
//  Shared
//
//  Created by Jean Bovet on 1/7/21.
//  Copyright © 2021 Jean Bovet. All rights reserved.
//

import SwiftUI

struct RankView: View {
    
    let rank: Int
    let pieces: [Piece]

    func backgroundColor(file: Int) -> Color {
        if rank % 2 == 0 {
            return file % 2 == 0 ? .gray : .white
        } else {
            return file % 2 == 0 ? .white : .gray
        }
    }
    
    func pieceImage(at file: Int) -> Image? {
        return pieces.filter { $0.rank == rank && $0.file == file }.first?.image
    }
    
    var body: some View {
        HStack(spacing: 0) {
            ForEach((0...7), id: \.self) { file in
                if let image = pieceImage(at: file) {
                    Rectangle()
                        .fill(backgroundColor(file: file))
                        .overlay(image.resizable())
                } else {
                    Rectangle()
                        .fill(backgroundColor(file: file))
                }
            }
        }
    }
}

struct ContentView: View {
    @Binding var document: BChessUIDocument
    
    let rows = [0, 1, 2, 3, 4, 5, 6, 7]
    let columns = [0, 1, 2, 3, 4, 5, 6, 7]
        
    var body: some View {
        VStack(spacing: 0) {
            ForEach((0...7).reversed(), id: \.self) { rank in
                RankView(rank: rank, pieces: document.pieces)
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
