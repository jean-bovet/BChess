//
//  ChessOpenings.cpp
//  BChess
//
//  Created by Jean Bovet on 12/29/17.
//  Copyright © 2017 Jean Bovet. All rights reserved.
//

#include "ChessOpenings.hpp"
#include "FPGN.hpp"
#include "FUtility.hpp"

ChessOpenings::ChessOpenings() {
}

bool ChessOpenings::load(std::string pgn) {
    games.clear();
    return FPGN::setGames(pgn, games);
}

bool ChessOpenings::lookup(std::vector<Move> moves, OpeningCallback callback) {
    return lookupAll(moves, [&callback](std::vector<OpeningMove> moves) {
        callback(moves[0]);
    });
}

bool openingMoveComparison(ChessOpenings::OpeningMove i, ChessOpenings::OpeningMove j) {
    return i.score > j.score;
}

bool ChessOpenings::lookupAll(std::vector<Move> moves, OpeningsCallback callback) {
    std::vector<OpeningMove> possibleMoves;
    for (int gIndex=0; gIndex<games.size(); gIndex++) {
        auto & game = games[gIndex];
        game.getRoot().matches(0, moves, [&game, &callback, &possibleMoves](auto &node) {
            auto opening = OpeningMove();
            opening.move = node.move;
            opening.name = game.tags["Name"];
            opening.score = 0;
            auto scoreString = game.tags["Score"];
            if (scoreString.length() > 0) {
                opening.score = integer(scoreString);
            }
            for (int vindex=0; vindex<node.variations.size(); vindex++) {
                opening.nextMoves.push_back(node.variations[vindex].move);
            }
            possibleMoves.push_back(opening);
        });
    }
    
    if (possibleMoves.empty()) {
        return false;
    } else {
        // Sort and return the move that corresponds to the opening
        // with the highest SCORE
        std::sort(possibleMoves.begin(), possibleMoves.end(), openingMoveComparison);
        callback(possibleMoves);
        return true;
    }
}

bool ChessOpenings::best(std::vector<Move> moves, OpeningCallback callback) {
    bool bestFound = false;
    bool result = lookup(moves, [&](OpeningMove opening) {
        // Check if the opening book has some more moves for that particular node
        if (opening.nextMoves.empty()) {
            bestFound = false;
        } else {
            // Always pick the main line variation for the opening
            auto bestOpening = OpeningMove();
            bestOpening.move = opening.nextMoves[0];
            bestOpening.name = opening.name;
            bestOpening.score = opening.score;
            callback(bestOpening);
            bestFound = true;
        }
    });
    
    return result && bestFound;
}
