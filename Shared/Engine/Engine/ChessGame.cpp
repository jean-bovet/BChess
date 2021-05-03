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
    moveIndexes.reset();
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
    return moveList.allMoves();
}

std::vector<Move> ChessGame::allMoves() {
    std::vector<Move> all;
    MoveNode currentNode = root;
    for (int index=0; index<getNumberOfMoves(); index++) {
        currentNode = currentNode.variations[0]; // return only the main variation
        all.push_back(currentNode.move);
    }
    return all;
}

void ChessGame::move(Move move) {
    assert(MOVE_ISVALID(move));
    
    // Lookup the node representing the last move by `moveIndexes`
    root.lookupNode(0, moveIndexes.moveCursor, moveIndexes, [&move, this](auto & node) {
        // First try to match the move with an existing move for that node.
        // This happens, for example, when a PGN has been loaded and
        // the player is playing a series of move that correspond to that PGN.
        bool found = false;
        for (int index=0; index<node.variations.size(); index++) {
            if (node.variations[index].move == move) {
                moveIndexes.moves.push_back(index);
                moveIndexes.moveCursor++;
                found = true;
                break;
            }
        }
        
        // If the move is not found in any variations of this node, this mean
        // this is a new variation (either main variation if no variation exists yet).
        if (!found) {
            MoveNode newNode = MoveNode();
            newNode.move = move;
            node.variations.push_back(newNode);
            
            // Insert the index of that new variation to the current move indexes
            moveIndexes.moves.push_back((int)node.variations.size() - 1);
            moveIndexes.moveCursor++;
        }
    });

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
    return moveIndexes.moveCursor > 0;
}

bool ChessGame::canRedoMove() {
    return moveIndexes.moveCursor < getNumberOfMoves();
}

void ChessGame::undoMove() {
    assert(canUndoMove());
    moveIndexes.moveCursor--;
    replayMoves();
}

void ChessGame::redoMove() {
    assert(canRedoMove());
    moveIndexes.moveCursor++;
    replayMoves();
}

void ChessGame::replayMoves() {
    board.reset();
    auto result = FFEN::setFEN(initialFEN, board);
    assert(result);
    auto moves = allMoves();
    for (int index=0; index<moves.size(); index++) {
        board.move(moves[index]);
    }
}

std::string ChessGame::getState() {
    ChessBoard replay;
    auto result = FFEN::setFEN(initialFEN, replay);
    assert(result);
    
    ChessState state;
    state.set(replay);
    
    auto moves = allMoves();
    for (int index=0; index<moves.size(); index++) {
        replay.move(moves[index]);
        state.update(replay);
    }
    
    return state.getState();
}
