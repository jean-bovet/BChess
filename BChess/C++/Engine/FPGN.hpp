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

#include "FGame.hpp"
#include "FBoard.hpp"

class FPGN {
public:
    static Move parseMove(std::string pgn, unsigned &cursor, FGame &game, bool &end);
    static bool parseMoveText(std::string pgn, unsigned &cursor, FGame &game, bool &end);
    static bool setGame(std::string pgn, FGame &game);
    static std::string getGame(FGame game, bool newLineAfterEachFullMove = false);
};
