//
//  FGame.cpp
//  BChess
//
//  Created by Jean Bovet on 12/14/17.
//  Copyright © 2017 Jean Bovet. All rights reserved.
//

#include "ChessGame.hpp"
#include "FFEN.hpp"
#include "ChessMoveGenerator.hpp"
#include "ChessEvaluater.hpp"
#include "ChessBoardHash.hpp"
#include "ChessState.hpp"

ChessGame::ChessGame() {
    history = NEW_HISTORY;
    reset();
}

void ChessGame::reset() {
    moveCursor = 0;
    moves.count = 0;
    history->clear();
    board.reset();
    outcome = Outcome::in_progress;
    initialFEN = StartFEN;
}

bool ChessGame::setFEN(std::string fen) {
    reset();
    if (FFEN::setFEN(fen, board)) {
        initialFEN = fen;
        return true;
    } else {
        return false;
    }
}

std::string ChessGame::getFEN() {
    return FFEN::getFEN(board);
}

BoardSquare ChessGame::getPieceAt(File file, Rank rank) {
    return board.get(file, rank);
}

std::vector<Move> ChessGame::movesAt(File file, Rank rank) {
    ChessMoveGenerator generator = ChessMoveGenerator();
    MoveList moveList = generator.generateMoves(board, board.color, ChessMoveGenerator::Mode::allMoves, SquareFrom(file, rank));
    std::vector<Move> moves;
    for (int index=0; index<moveList.count; index++) {
        auto move = moveList.moves[index];
        moves.push_back(move);
    }
    return moves;
}

void ChessGame::move(Move move) {
    assert(MOVE_ISVALID(move));
    
    if (moveCursor < moves.count) {
        // Clear the rest of the history
        moves.count = moveCursor;
        history->clear();
    }

    moves.push(move);
    moveCursor = moves.count;

    board.move(move);
    
    history->push_back(board.getHash());

    // Update the outcome after each move
    ChessMoveGenerator generator = ChessMoveGenerator();
    if (generator.generateMoves(board).count == 0) {
        if (board.isCheck(board.color)) {
            if (board.color == WHITE) {
                outcome = Outcome::black_wins;
            } else {
                outcome = Outcome::white_wins;
            }
        } else {
            outcome = Outcome::draw;
        }
    } else {
        outcome = Outcome::in_progress;
    }
}

void ChessGame::move(std::string from, std::string to) {
    auto move = board.getMove(from, to);
    if (MOVE_ISVALID(move)) {
        ChessGame::move(move);
    }
}

bool ChessGame::canUndoMove() {
    return moveCursor > 0;
}

bool ChessGame::canRedoMove() {
    return moveCursor < moves.count;
}

void ChessGame::undoMove() {
    assert(canUndoMove());
    moveCursor--;
    replayMoves();
}

void ChessGame::redoMove() {
    assert(canRedoMove());
    moveCursor++;
    replayMoves();
}

void ChessGame::replayMoves() {
    board.reset();
    auto result = FFEN::setFEN(initialFEN, board);
    assert(result);
    for (int index=0; index<moveCursor; index++) {
        board.move(moves[index]);
    }
}

std::string ChessGame::getState() {
    ChessBoard replay;
    auto result = FFEN::setFEN(initialFEN, replay);
    assert(result);
    
    ChessState state;
    state.set(replay);
    
    for (int index=0; index<moveCursor; index++) {
        replay.move(moves[index]);
        state.update(replay);
    }
    
    return state.getState();
}
