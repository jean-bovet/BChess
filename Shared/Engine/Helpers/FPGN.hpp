//
//  FPGN.hpp
//  BChess
//
//  Created by Jean Bovet on 12/14/17.
//  Copyright © 2017 Jean Bovet. All rights reserved.
//

#pragma once

#include <stdio.h>
#include <string>

#include "ChessGame.hpp"
#include "ChessBoard.hpp"

// This class knows how to parse PGN
// https://en.wikipedia.org/wiki/Portable_Game_Notation
class FPGN {
public:
    FPGN(std::string pgn = "") {
        FPGN::pgn = pgn;
    }
    
    ChessGame & getGame() {
        return game;
    }
    
    const char character(int offset = 0) {
        int desiredCursor = cursor + offset;
        if (desiredCursor >= 0 && desiredCursor < pgn.length()) {
            return pgn[desiredCursor];
        } else {
            return 0;
        }
    }
    
    bool hasMoreCharacters() {
        return cursor < pgn.length();
    }

    bool parseTag(bool lookahead = false);
    bool parseMoveText();

    bool parseVariation();

    bool parseMoveNumber(unsigned &moveNumber, bool &isMoveForBlack);
    bool parsePiece(Piece &p);
    bool parseMove(Move &move);
    bool parseMoveAnnotation();

    bool parseTerminationMarker();
    bool parseComment(std::string & comment);
    
    void eatWhiteSpaces();

    // Utilities
    
    enum class SANType {
        tight, // Ne6
        medium, // Nde6
        full, // Nd4e6
        uci // d4e6
    };

    static std::string to_string(Move move, SANType sanType = SANType::full);
    
    static bool setGame(std::string pgn, ChessGame &game);
    
    static bool setGames(std::string pgn, std::vector<ChessGame> & games);
    
    enum class Formatting {
        storage, // default mode, to be exported or stored outside this program
        line, // for displaying the line of game, without numbering the moves. For example: "Na3 Bxc4 e5+"
        history, // for displaying the history of the game, with new lines every two ply.
    };
    
    static std::string getGames(std::vector<ChessGame> & games);
    
    // fromIndex: the index from which to start building the PGN. Used to display a line from a game during analysis,
    //            which means we only want to display the game after the current move (to show the thinking of the computer).
    //            This parameter takes effect only if the Formatting is set to line
    // toIndex: the index at which to stop building the PGN.
    static std::string getGame(ChessGame game, Formatting formatting = FPGN::Formatting::storage, int fromIndex = 0, int toIndex = INT_MAX);
    
private:
    std::string pgn = "";
    unsigned cursor = 0;
    ChessGame game;

    static bool setGame(std::string pgn, ChessGame &game, unsigned & cursor);

};
