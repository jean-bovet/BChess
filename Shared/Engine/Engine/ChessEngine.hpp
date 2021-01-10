//
//  ChessEngine.h
//  BChess
//
//  Created by Jean Bovet on 12/23/17.
//  Copyright © 2017 Jean Bovet. All rights reserved.
//

#pragma once

#include "Types.hpp"

#include "FPGN.hpp"

#include "MinMaxSearch.hpp"
#include "IterativeDeepening.hpp"

#include "ChessGame.hpp"
#include "ChessOpenings.hpp"
#include "ChessBoard.hpp"
#include "ChessBoardHash.hpp"
#include "ChessMoveGenerator.hpp"
#include "ChessEvaluater.hpp"
#include "ChessEvaluation.hpp"

typedef MinMaxSearch ChessMinMaxSearch;

class ChessEngine {
public:
    ChessOpenings openings;
    ChessGame game;
    IterativeDeepening iterativeSearch;
    
    bool transpositionTable = true;
    
    typedef std::function<void(ChessEvaluation, bool)> SearchCallback;
    
public:
    static void initialize() {
        ChessMoveGenerator::initialize();
        ChessBoardHash::initialize();
    }
    
    bool loadOpening(std::string pgn) {
        return openings.load(pgn);
    }
    
    bool setFEN(std::string fen) {
        return game.setFEN(fen);
    }
    
    std::string getFEN() {
        return game.getFEN();
    }
    
    bool setPGN(std::string pgn) {
        return FPGN::setGame(pgn, game);
    }
    
    std::string getPGN() {
        return FPGN::getGame(game);
    }
    
    std::string getPGNForDisplay() {
        return FPGN::getGame(game, FPGN::Formatting::history);
    }
    
    std::string getPieceAt(File file, Rank rank) {
        BoardSquare square = game.getPieceAt(file, rank);
        if (square.empty) {
            return "";
        } else {
            char p = pieceToChar(square.piece, square.color == WHITE);
            return std::string(1, p);
        }
    }
    
    std::vector<Move> getMovesAt(File file, Rank rank) {
        return game.movesAt(file, rank);
    }
    
    void move(Move move) {
        game.move(move);
    }
    
    void move(std::string from, std::string to) {
        game.move(from, to);
    }
    
    bool canUndoMove() {
        return game.canUndoMove();
    }
    
    bool canRedoMove() {
        return game.canRedoMove();
    }
    
    void undoMove() {
        game.undoMove();
    }
    
    void redoMove() {
        game.redoMove();
    }
    
    void stop() {
        iterativeSearch.stop();
    }
    
    void cancel() {
        iterativeSearch.cancel();
    }
    
    bool running() {
        return iterativeSearch.running();
    }
    
    bool isWhite() {
        return game.board.color == WHITE;
    }
    
    bool canPlay() {
        return game.outcome == ChessGame::Outcome::in_progress;
    }
    
    bool lookupOpeningMove(ChessEvaluation & evaluation) {
        if (game.moves.count == 0 && game.board.fullMoveCount > 1) {
            // If the game is not at the starting position, that is,
            // there are no moves recorded yet but the fullMoveCount is greater
            // than one (meaning the game has one or more move already), don't use
            // any openings.
            return false;
        }
        bool result = openings.best(game.moves, [&evaluation](OpeningTreeNode & node) {
            evaluation.line.push(node.move);
            evaluation.opening = node.name;
        });
        return result;
    }

    void searchBestMove(int maxDepth, SearchCallback callback) {
        iterativeSearch.minMaxSearch.config.transpositionTable = transpositionTable;
        ChessEvaluation info = iterativeSearch.search(game.board, game.history, maxDepth, [&](ChessEvaluation info) {
            if (!iterativeSearch.cancelled()) {
                callback(info, false);
            }
        });
        if (!iterativeSearch.cancelled()) {
            callback(info, true);
        }
    }
    
    std::string getState() {
        return game.getState();
    }
};
