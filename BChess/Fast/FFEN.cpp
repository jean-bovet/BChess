//
//  FFEN.cpp
//  BChess
//
//  Created by Jean Bovet on 11/30/17.
//  Copyright © 2017 Jean Bovet. All rights reserved.
//

#include "FFEN.hpp"
#include "FUtility.hpp"

#include <vector>
#include <cassert>

/**
             let pieces = fields.removeFirst()
 
            var cursor = Coordinate()
            cursor.rank = Board.size - 1
 
            // 4k3/2r5/8/8/8/8/2R5/4K3 b - - 0 1
            let ranks = pieces.split(separator: "/")
            for rank in ranks {
                for p in rank {
                    if let emptySquares = Int(String(p)) {
                        for _ in 1...emptySquares {
                            self[cursor] = .None
                            cursor.file += 1
                        }
                    } else if let piece = p.piece {
                        self[cursor] = piece
                        updatePositions(piece: piece, coordinate: cursor)
                        cursor.file += 1
                    } else {
                        print("Invalid FEN entry \(p) with \(fen)")
                        cursor.file += 1
                    }
                }
                cursor.rank -= 1
                cursor.file = 0
            }
 
            let sideToMove = fields.removeFirst()
            color = (sideToMove == "w") ? .white : .black
 
            // KQkq
            let castlingAvailability = fields.removeFirst()
            castling.fen = String(castlingAvailability)
 
            // En passant
            fields.removeFirst()
 
            // Half move
            fields.removeFirst()
 
            // Full move
            let fullMove = fields.removeFirst()
            fullMoveCount = Int(fullMove)!

 */

struct Coordinate {
    int rank = 0;
    int file = 0;
};

Board FFEN::createBoard(std::string fen) {
    std::vector<std::string> words;
    split4(fen, words);
    assert(words.size() == 6);
    
    // 4k3/2r5/8/8/8/8/2R5/4K3
    auto pieces = words[0];
    std::vector<std::string> ranks;
    split4(pieces, ranks, "/");

    Board board;
    memset(board.pieces, 0, sizeof(board.pieces));
    
    Coordinate coord = { 7, 0 };
    for (std::string rank : ranks) {
        for (char p : rank) {
            auto emptySquares = p - '0';
            if (emptySquares >= 1 && emptySquares <= 8) {
                for (int i=0; i<emptySquares; i++) {
                    coord.file += 1;
                }
            } else {
                Piece::Piece piece;
                Color::Color color = Color::WHITE;
                switch (p) {
                    case 'p':
                        piece = Piece::PAWN;
                        color = Color::BLACK;
                        break;
                    case 'P':
                        piece = Piece::PAWN;
                        break;

                    case 'r':
                        piece = Piece::ROOK;
                        color = Color::BLACK;
                        break;
                    case 'R':
                        piece = Piece::ROOK;
                        break;

                    case 'b':
                        piece = Piece::BISHOP;
                        color = Color::BLACK;
                        break;
                    case 'B':
                        piece = Piece::BISHOP;
                        break;

                    case 'n':
                        piece = Piece::KNIGHT;
                        color = Color::BLACK;
                        break;
                    case 'N':
                        piece = Piece::KNIGHT;
                        break;

                    case 'q':
                        piece = Piece::QUEEN;
                        color = Color::BLACK;
                        break;
                    case 'Q':
                        piece = Piece::QUEEN;
                        break;

                    case 'k':
                        piece = Piece::KING;
                        color = Color::BLACK;
                        break;
                    case 'K':
                        piece = Piece::KING;
                        break;

                    default:
                        assert(false); // Invalid FEN entry
                        break;
                }
                board.set(piece, color, coord.file, coord.rank);
                coord.file += 1;
            }
        }
        coord.rank -= 1;
        coord.file = 0;
    }
    
    board.print();
    
    return board;
}
