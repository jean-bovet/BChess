//
//  FPGN.cpp
//  BChess
//
//  Created by Jean Bovet on 12/14/17.
//  Copyright © 2017 Jean Bovet. All rights reserved.
//

#include "FPGN.hpp"
#include "FBoard.hpp"
#include "FMoveGenerator.hpp"

#include <cassert>
#include <iostream>
#include <vector>

/**
 [Event "F/S Return Match"]
 [Site "Belgrade, Serbia JUG"]
 [Date "1992.11.04"]
 [Round "29"]
 [White "Fischer, Robert J."]
 [Black "Spassky, Boris V."]
 [Result "1/2-1/2"]
 
 1. e4 e5 2. Nf3 Nc6 3. Bb5 a6 {This opening is called the Ruy Lopez.}
 4. Ba4 Nf6 5. O-O Be7 6. Re1 b5 7. Bb3 d6 8. c3 O-O 9. h3 Nb8 10. d4 Nbd7
 11. c4 c6 12. cxb5 axb5 13. Nc3 Bb7 14. Bg5 b4 15. Nb1 h6 16. Bh4 c5 17. dxe5
 Nxe4 18. Bxe7 Qxe7 19. exd6 Qf6 20. Nbd2 Nxd6 21. Nc4 Nxc4 22. Bxc4 Nb6
 23. Ne5 Rae8 24. Bxf7+ Rxf7 25. Nxf7 Rxe1+ 26. Qxe1 Kxf7 27. Qe3 Qg5 28. Qxg5
 hxg5 29. b3 Ke6 30. a3 Kd6 31. axb4 cxb4 32. Ra5 Nd5 33. f3 Bc8 34. Kf2 Bf5
 35. Ra7 g6 36. Ra6+ Kc5 37. Ke1 Nf4 38. g3 Nxh3 39. Kd2 Kb5 40. Rd6 Kc5 41. Ra6
 Nf2 42. g4 Bd3 43. Re6 1/2-1/2
 */

static bool parseUntil(std::string pgn, unsigned &cursor, std::string &comment, char endCharacter) {
    while (cursor < pgn.length() && pgn[cursor] != endCharacter) {
        comment += pgn[cursor];
        cursor++;
    }
    cursor++; // go after the endCharacter
    return true;
}


// For example: "12. "
static bool parseMoveNumber(std::string pgn, unsigned &cursor) {
    while (cursor < pgn.length() && pgn[cursor] != ' ') {
        cursor++;
    }
    cursor++;
    return true;
}

static Piece parsePiece(std::string pgn, unsigned &cursor) {
    auto c = pgn[cursor];
    Piece piece;
    switch (c) {
        case 'N':
            piece = KNIGHT;
            cursor++;
            break;
            
        case 'K':
            piece = KING;
            cursor++;
            break;
            
        case 'Q':
            piece = QUEEN;
            cursor++;
            break;
            
        case 'B':
            piece = BISHOP;
            cursor++;
            break;
            
        case 'R':
            piece = ROOK;
            cursor++;
            break;
            
        case 'P':
            piece = PAWN;
            cursor++;
            break;

        default:
            // Pawn is usually omitted, so don't move the cursor
            piece = PAWN;
            break;
    }
    return piece;
}

static bool isFile(char c) {
    return c >= 'a' && c <= 'h';
}

static bool isRank(char c) {
    return c >= '1' && c <= '8';
}

static bool isSpaceOrNewLine(char c) {
    return c == ' ' || c == '\n' || c == '\r';
}

static bool isCheckOrMate(char c) {
    return c == '+' || c == '#';
}

static File getFile(char c) {
    assert(isFile(c));
    return (File)(c - 'a');
}

static Rank getRank(char c) {
    assert(isRank(c));
    return (Rank)(c - '1');
}

Move FPGN::parseMove(std::string pgn, unsigned &cursor, Board &board, bool &end) {
    Piece movingPiece = parsePiece(pgn, cursor);
    
    File fromFile = FileUndefined;
    Rank fromRank = RankUndefined;

    File toFile = FileUndefined;
    Rank toRank = RankUndefined;

    bool capture = false;
    
    if (isFile(pgn[cursor]) && isFile(pgn[cursor+1]) && isRank(pgn[cursor+2])) {
        // Nbd7
        // Rae8
        
        fromFile = getFile(pgn[cursor++]);
        toFile = getFile(pgn[cursor++]);
        toRank = getRank(pgn[cursor++]);
    } else if (isFile(pgn[cursor]) && isRank(pgn[cursor+1]) && pgn[cursor+2] == 'x' && isFile(pgn[cursor+3]) && isRank(pgn[cursor+4])) {
        // Qa6xb7#
        fromFile = getFile(pgn[cursor++]);
        fromRank = getRank(pgn[cursor++]);
        capture = true; cursor++;
        toFile = getFile(pgn[cursor++]);
        toRank = getRank(pgn[cursor++]);
    } else if (isFile(pgn[cursor]) && isRank(pgn[cursor+1]) && isFile(pgn[cursor+2]) && isRank(pgn[cursor+3])) {
        // Qa7b8
        fromFile = getFile(pgn[cursor++]);
        fromRank = getRank(pgn[cursor++]);
        toFile = getFile(pgn[cursor++]);
        toRank = getRank(pgn[cursor++]);
    } else if (isFile(pgn[cursor]) && isRank(pgn[cursor+1]) && (isSpaceOrNewLine(pgn[cursor+2]) || isCheckOrMate(pgn[cursor+2]) || cursor+2 == pgn.size())) {
        // e4
        // Ba4
        toFile = getFile(pgn[cursor++]);
        toRank = getRank(pgn[cursor++]);
    } else if (isFile(pgn[cursor]) && pgn[cursor+1] == 'x' && isFile(pgn[cursor+2]) && isRank(pgn[cursor+3])) {
        // cxb5
        // fxg1=Q+
        fromFile = getFile(pgn[cursor++]);
        capture = true; cursor++;
        toFile = getFile(pgn[cursor++]);
        toRank = getRank(pgn[cursor++]);
    } else if (pgn[cursor] == 'x' && isFile(pgn[cursor+1]) && isRank(pgn[cursor+2])) {
        // Bxf7+
        capture = true; cursor++;
        toFile = getFile(pgn[cursor++]);
        toRank = getRank(pgn[cursor++]);
    } else if (pgn[cursor] == 'O' && pgn[cursor+1] == '-' && pgn[cursor+2] == 'O' && pgn[cursor+3] == '-' && pgn[cursor+4] == 'O') {
        // O-O-O: Queen side
        movingPiece = KING;
        if (board.color == WHITE) {
            toFile = getFile('c');
            toRank = getRank('1');
        } else {
            toFile = getFile('c');
            toRank = getRank('8');
        }
        cursor+=5;
    } else if (pgn[cursor] == 'O' && pgn[cursor+1] == '-' && pgn[cursor+2] == 'O') {
        // O-O: King side
        movingPiece = KING;
        if (board.color == WHITE) {
            toFile = getFile('g');
            toRank = getRank('1');
        } else {
            toFile = getFile('g');
            toRank = getRank('8');
        }
        cursor+=3;
    } else if (pgn[cursor] == '1' && pgn[cursor+1] == '-' && pgn[cursor+2] == '0') {
        // Termination marker: white wins
        cursor+=3;
        end = true;
    } else if (pgn[cursor] == '0' && pgn[cursor+1] == '-' && pgn[cursor+2] == '1') {
        // Termination marker: black wins
        cursor+=3;
        end = true;
    } else if (pgn[cursor] == '1' && pgn[cursor+1] == '/' && pgn[cursor+2] == '2' && pgn[cursor+3] == '-' && pgn[cursor+4] == '1' && pgn[cursor+5] == '/' && pgn[cursor+6] == '2') {
        // Termination marker: draw
        cursor+=7;
        end = true;
    } else if (pgn[cursor] == '*') {
        // Termination marker: game in progress or result unknown
        cursor++;
        end = true;
    } else {
        // Invalid SAN representation
        return 0;
    }

    if (end) {
        return 0;
    }
    
    // 8.2.3.5: Check and checkmate indication characters
    if (isCheckOrMate(pgn[cursor])) {
        cursor++;
    }
    
    // The target square must be fully defined at this point
    assert(toFile != FileUndefined);
    assert(toRank != FileUndefined);
    
    Square to = SquareFrom(toFile, toRank);
    
    // Now the original square can be not fully defined...
    MoveGenerator generator;
    auto moveList = generator.generateMoves(board);
    std::vector<Move> matchingMoves;
    for (int index=0; index<moveList.moveCount; index++) {
        Move m = moveList.moves[index];
        
        if (MOVE_TO(m) != to) {
            continue;
        }
        
        if (MOVE_PIECE(m) != movingPiece) {
            continue;
        }
        
        if (fromFile != FileUndefined && FileFrom(MOVE_FROM(m)) != fromFile) {
            continue;
        }

        if (fromRank != RankUndefined && RankFrom(MOVE_FROM(m)) != fromRank) {
            continue;
        }

        matchingMoves.push_back(m);
    }
    
    // After matching, one and only one move should be found
    if (matchingMoves.size() == 1) {
        return matchingMoves.front();
    } else {
        return 0;
    }
}

bool FPGN::parseMoveText(std::string pgn, unsigned &cursor, Board &board, bool &end) {
    // Indication of a move, for example:
    // 1. e4 e5
    assert(parseMoveNumber(pgn, cursor));
    
    Move whiteMove = parseMove(pgn, cursor, board, end);
    if (end) {
        return true;
    }
    if (!MOVE_ISVALID(whiteMove)) {
        return false;
    }
    
    board.move(whiteMove);
    
//    std::cout << MOVE_DESCRIPTION(whiteMove) << std::endl;
//    board.print();
    
    if (!isSpaceOrNewLine(pgn[cursor++])) {
        // Missing white space or new line
        return false;
    }
    
    Move blackMove = parseMove(pgn, cursor, board, end);
    if (end) {
        return true;
    }
    if (!MOVE_ISVALID(blackMove)) {
        return false;
    }
    
    board.move(blackMove);
//    std::cout << MOVE_DESCRIPTION(blackMove) << std::endl;
//    board.print();
    
    return true;
}

bool FPGN::setGame(std::string pgn, FGame &game) {
    unsigned cursor = 0;
    bool end = false;
    while (cursor < pgn.length() && !end) {
        auto c = pgn[cursor];
        if (c == '[') {
            // Indication for a comment
            cursor++; // go after the [
            std::string comment = "";
            assert(parseUntil(pgn, cursor, comment, ']'));
        } else if (c == '{') {
            // Indication for a comment
            cursor++; // go after the [
            std::string comment = "";
            assert(parseUntil(pgn, cursor, comment, '}'));
        } else if (c >= '0' && c <= '9') {
            if (!parseMoveText(pgn, cursor, game.board, end)) {
                return false;
            }
        } else {
            // Any other character, such as white space or new line are ignored
            cursor++;
        }
    }
    
    return true;
}

