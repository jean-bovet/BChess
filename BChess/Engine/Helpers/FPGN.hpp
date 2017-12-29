//
//  FPGN.hpp
//  BChess
//
//  Created by Jean Bovet on 12/14/17.
//  Copyright © 2017 Jean Bovet. All rights reserved.
//

#pragma once

// https://en.wikipedia.org/wiki/Portable_Game_Notation

#include <stdio.h>
#include <string>

#include "ChessGame.hpp"
#include "ChessBoard.hpp"

class FPGN {
public:
    enum class SANType {
        tight, // Ne6
        medium, // Nde6
        full, // Nd4e6
        uci // d4e6
    };
    
    static std::string to_string(Move move, SANType sanType = SANType::full);
    
    static Move parseMove(std::string pgn, unsigned &cursor, ChessGame &game, bool &end);
    static bool parseMoveText(std::string pgn, unsigned &cursor, ChessGame &game, bool &end);
    
    static bool setGame(std::string pgn, ChessGame &game);
    
    enum class Formatting {
        storage, // default mode, to be exported or stored outside this program
        line, // for displaying the line of game, without numbering the moves. For example: "Na3 Bxc4 e5+"
        history, // for displaying the history of the game, with new lines every two ply.
    };
    
    // compact: true to return a compact form of PGN for display in the UI. For example: "Na3 Bxc4 e5+"
    // fromIndex: the index from which to start building the PGN. Used to display a line from a game.
    static std::string getGame(ChessGame game, Formatting formatting = FPGN::Formatting::storage, int fromIndex = 0);
};
