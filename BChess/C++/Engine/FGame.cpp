//
//  FGame.cpp
//  BChess
//
//  Created by Jean Bovet on 12/14/17.
//  Copyright © 2017 Jean Bovet. All rights reserved.
//

#include "FGame.hpp"
#include "FFEN.hpp"
#include "FMoveGenerator.hpp"

void FGame::setFEN(std::string fen) {
    FFEN::setFEN(fen, board);
}

std::string FGame::getFEN() {
    return FFEN::getFEN(board);
}

BoardSquare FGame::getPieceAt(File file, Rank rank) {
    return board.get(file, rank);
}

std::vector<Move> FGame::movesAt(File file, Rank rank) {
    MoveGenerator generator = MoveGenerator();
    MoveList moveList = generator.generateMoves(board, SquareFrom(file, rank));
    std::vector<Move> moves;
    for (int index=0; index<moveList.moveCount; index++) {
        moves.push_back(moveList.moves[index]);
    }
    return moves;
}

void FGame::move(Move move) {
    if (moveCursor < moves.size()) {
        // Clear the rest of the history
        moves.erase(moves.begin() + (long)moveCursor, moves.end());
    }
    
    moves.push_back(move);
    moveCursor = moves.size();

    board.move(move);
}

void FGame::move(std::string from, std::string to) {
    auto move = board.getMove(from, to);
    if (MOVE_ISVALID(move)) {
        FGame::move(move);
    }
}

bool FGame::canUndoMove() {
    return moveCursor > 0;
}

bool FGame::canRedoMove() {
    return moveCursor < moves.size();
}

void FGame::undoMove() {
    assert(canUndoMove());
    moveCursor--;
    replayMoves();
}

void FGame::redoMove() {
    assert(canRedoMove());
    moveCursor++;
    replayMoves();
}

void FGame::replayMoves() {
    board.reset();
    for (int index=0; index<moveCursor; index++) {
        board.move(moves[index]);
    }
}

