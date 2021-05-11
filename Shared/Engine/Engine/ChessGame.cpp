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
#include <math.h>

ChessGame::ChessGame() {
    history = NEW_HISTORY;
    reset();
}

void ChessGame::reset() {
    root.clear();
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
    root.visit(0, moveIndexes, [&all](auto & node) {
        all.push_back(node.move);
    });
    return all;
}

// move: the move to perform
// replace: true to replace any variations by this move only,
//          false to add as a new variation if the move does not exist already
void ChessGame::move(Move move, std::string comment, bool replace) {
    assert(MOVE_ISVALID(move));
    
    // Lookup the node representing the last move by `moveIndexes`
    root.lookupNode(0, moveIndexes.moveCursor, moveIndexes, [&move, &comment, replace, this](auto & node) {
        bool found = false;
        if (replace) {
            // Clear all the variations so this move
            // becomes the only one available.
            node.variations.clear();
        } else {
            // First try to match the move with an existing move for that node.
            // This happens, for example, when a PGN has been loaded and
            // the player is playing a series of move that correspond to that PGN.
            for (int index=0; index<node.variations.size(); index++) {
                if (node.variations[index].move == move) {
                    moveIndexes.add(index);
                    found = true;
                    break;
                }
            }
        }
        
        // If the move is not found in any variations of this node, this mean
        // this is a new variation (either main variation if no variation exists yet).
        if (!found || replace) {
            MoveNode newNode = MoveNode();
            newNode.moveNumber = ceil(moveIndexes.moveCursor / 2) + 1;
            newNode.comment = comment;
            newNode.move = move;
            node.variations.push_back(newNode);
            
            // Insert the index of that new variation to the current move indexes
            moveIndexes.add((int)node.variations.size() - 1);
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
        ChessGame::move(move, "", false);
    }
}

bool ChessGame::canUndoMove() {
    return moveIndexes.moveCursor > 0;
}

bool ChessGame::canRedoMove() {
    return moveIndexes.moveCursor < moveIndexes.moves.size();
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
