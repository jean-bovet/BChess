//
//  ChessEngine.h
//  BChess
//
//  Created by Jean Bovet on 12/23/17.
//  Copyright © 2017 Jean Bovet. All rights reserved.
//

#pragma once

#include <mutex>

#include "Types.hpp"

#include "FFEN.hpp"
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
#include <functional>
#include <vector>

typedef MinMaxSearch ChessMinMaxSearch;

class ChessEngine {
public:
    ChessOpenings openings;
    
    std::vector<ChessGame> games;
    unsigned gameIndex = 0;
    
    ChessGame & game() {
        return games[gameIndex];
    }
    
    IterativeDeepening iterativeSearch;
    
    typedef std::function<void(ChessEvaluation, bool)> SearchCallback;
    
public:
    
    // hashMegabytes: the size of the transposition table, which is allocated by the first search
    explicit ChessEngine(size_t hashMegabytes = 16) : iterativeSearch(hashMegabytes) {
        games.push_back(ChessGame());
    }
    
    // Rewrites global tables, so it runs once even when several engines or tests call it concurrently.
    static void initialize() {
        static std::once_flag once;
        std::call_once(once, [] {
            ChessMoveGenerator::initialize();
            ChessBoardHash::initialize();
        });
    }
    
    bool loadOpening(std::string pgn) {
        return openings.load(pgn);
    }
    
    // Replaces all the games, or leaves them untouched when the PGN does not parse or holds no game.
    bool loadAllGames(std::string pgn) {
        std::vector<ChessGame> parsed;
        if (!FPGN::setGames(pgn, parsed) || parsed.empty()) {
            return false;
        }
        games.swap(parsed);
        gameIndex = 0;
        return true;
    }
    
    bool setFEN(std::string fen) {
        return game().setFEN(fen);
    }
    
    std::string getFEN() {
        return game().getFEN();
    }
    
    bool setPGN(std::string pgn) {
        return FPGN::setGame(pgn, game());
    }
    
    std::string getPGN(bool currentGame = true) {
        if (currentGame) {
            return FPGN::getGame(game());
        } else {
            return FPGN::getGames(games);
        }
    }
    
    ChessGame::MoveNode getRootMoveNode() {
        return game().getRoot();
    }
    
    std::string getPieceAt(File file, Rank rank) {
        BoardSquare square = game().getPieceAt(file, rank);
        if (square.empty) {
            return "";
        } else {
            char p = pieceToChar(square.piece, square.color == WHITE);
            return std::string(1, p);
        }
    }
    
    std::vector<Move> getMovesAt(File file, Rank rank) {
        return game().movesAt(file, rank);
    }
    
    void move(Move move, std::string comment, bool replace) {
        game().move(move, comment, replace);
    }
    
    bool move(std::string uciMove) {
        return game().move(uciMove);
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
        return game().board.color == WHITE;
    }
    
    // Why nothing can be played from the current position, or none. Earlier positions of a finished game can
    // be played from, which starts a variation; the final position of a game with a result cannot, and
    // neither can a position that is drawn by repetition.
    enum class GameEnd {
        none,
        checkmate,
        stalemate,
        repetition,
        finished // a declared result at the end of the line
    };
    
    GameEnd gameEnd() {
        auto & g = game();
        if (ChessMoveGenerator::generateMoves(g.board).count == 0) {
            return g.board.isCheck(g.board.color) ? GameEnd::checkmate : GameEnd::stalemate;
        }
        // A position that already occurred three times is drawn: a search finds no move in it
        if (ChessEvaluater::isDraw(g.board, g.history)) {
            return GameEnd::repetition;
        }
        if (g.getNumberOfMoves() < g.getLineLength() || g.outcome == ChessGame::Outcome::in_progress) {
            return GameEnd::none;
        }
        return GameEnd::finished;
    }
    
    // Whether a move can be played from the current position.
    bool canPlay() {
        return gameEnd() == GameEnd::none;
    }
    
    // Returns true if the current moves are following a valid opening line as defined
    // by the openings loaded with loadOpening()
    bool isValidOpeningMoves(std::string &name) {
        name = "";
        if (game().getNumberOfMoves() > 0) {
            bool result = openings.lookup(game().allMoves(), [&](auto opening) {
                name = opening.name;
            });
            return result;
        } else {
            return false;
        }
    }
    
    bool lookupOpeningMove(ChessEvaluation & evaluation) {
        if (game().initialFEN != StartFEN) {
            // The openings are lines from the standard start position: a game that started from
            // another position would be offered moves that are not legal in it.
            return false;
        }
        bool result = openings.best(game().allMoves(), [&evaluation](auto opening) {
            evaluation.line.push(opening.move);
        });
        return result;
    }

    // Searches the given position, not game(): the caller passes a snapshot, because the history is
    // modified during the search. Call iterativeSearch.start() first.
    void searchBestMove(ChessBoard board, HistoryPtr history, int maxDepth, bool transpositionTable, SearchCallback callback) {
        iterativeSearch.minMaxSearch.config.transpositionTable = transpositionTable;
        ChessEvaluation info = iterativeSearch.search(board, history, maxDepth, [&](ChessEvaluation info) {
            if (!iterativeSearch.cancelled()) {
                callback(info, false);
            }
        });
        if (!iterativeSearch.cancelled()) {
            callback(info, true);
        }
    }
    
    std::string getState() {
        return game().getState();
    }
};
