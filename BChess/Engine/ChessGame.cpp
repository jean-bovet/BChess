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

ChessGame::ChessGame() {
    reset();
}

void ChessGame::reset() {
    moveCursor = 0;
    board.reset();
    outcome = Outcome::in_progress;
    initialFEN = StartFEN;
}

bool ChessGame::setFEN(std::string fen) {
    moveCursor = 0;
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
    ChessMoveList moveList = generator.generateMoves(board, ChessMoveGenerator::Mode::allMoves, SquareFrom(file, rank));
    std::vector<Move> moves;
    for (int index=0; index<moveList.count; index++) {
        auto move = moveList.moves[index];
        moves.push_back(move);
    }
    return moves;
}

void ChessGame::move(Move move) {
    if (moveCursor < moves.count) {
        // Clear the rest of the history
        moves.count = moveCursor;
    }

    moves.push(move);
    moveCursor = moves.count;

    board.move(move);
    
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
    assert(FFEN::setFEN(initialFEN, board));
    for (int index=0; index<moveCursor; index++) {
        board.move(moves[index]);
    }
}

void ChessGame::debugEvaluate() {
    std::cout << ChessEvaluater::evaluate(board) << std::endl;
}

