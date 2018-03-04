//
//  ChessState.cpp
//  BChess
//
//  Created by Jean Bovet on 3/3/18.
//  Copyright © 2018 Jean Bovet. All rights reserved.
//

#include "ChessState.hpp"

void ChessState::set(ChessBoard board) {
    for (Rank r=0; r<8; r++) {
        for (File f=0; f<8; f++) {
            BoardSquare boardSquare = board.get(f, r);

            PieceInstance pieceInstance;
            if (boardSquare.empty) {
                pieceInstance.empty = true;
            } else {
                auto p = pieceToChar(boardSquare.piece, boardSquare.color == WHITE);
                auto count = ++pieceCount[p];
                
                pieceInstance.p = p;
                pieceInstance.count = count;
                pieceInstance.empty = false;
            }
            
            squareContent[SquareFrom(f, r)] = pieceInstance;
        }
    }
}

void ChessState::update(ChessBoard board) {
    // Remove pieces that are no longer in the same position on the board
    std::map<char, PieceInstance> removedPieces;
    for (Rank r=0; r<8; r++) {
        for (File f=0; f<8; f++) {
            Square square = SquareFrom(f, r);
            PieceInstance & instance = squareContent[square];
            
            BoardSquare boardSquare = board.get(f, r);
            if (boardSquare.empty) {
                if (!instance.empty) {
                    removedPieces[instance.p] = instance;
                    instance.empty = true;
                }
            } else {
                auto p = pieceToChar(boardSquare.piece, boardSquare.color == WHITE);
                if ((!instance.empty && instance.p != p)) {
                    removedPieces[instance.p] = instance;
                    instance.empty = true;
                }
            }
        }
    }
    
    // Put back pieces that are on other position on the board
    for (Rank r=0; r<8; r++) {
        for (File f=0; f<8; f++) {
            Square square = SquareFrom(f, r);
            PieceInstance & instance = squareContent[square];
            
            BoardSquare boardSquare = board.get(f, r);
            if (!boardSquare.empty) {
                auto p = pieceToChar(boardSquare.piece, boardSquare.color == WHITE);
                if ((!instance.empty && instance.p != p) || instance.empty) {
                    if (removedPieces.count(p) == 0) {
                        // This is a new piece
                        auto count = ++pieceCount[p];

                        instance.p = p;
                        instance.count = count;
                        instance.empty = false;
                    } else {
                        // The piece has moved
                        instance = removedPieces[p];
                        instance.empty = false;
                    }
                }
            }
        }
    }
}

std::string ChessState::getState() {
    std::string state;
    for (Rank r=0; r<8; r++) {
        for (File f=0; f<8; f++) {
            PieceInstance instance = squareContent[SquareFrom(f, r)];
            if (instance.empty) continue;
            
            state.append(std::string(1, instance.p));
            state.append(std::to_string(instance.count));
            state.append(std::to_string(f));
            state.append(std::to_string(r));
        }
    }
    return state;
}
