//
//  FPGN.cpp
//  BChess
//
//  Created by Jean Bovet on 12/14/17.
//  Copyright © 2017 Jean Bovet. All rights reserved.
//

#include "FPGN.hpp"
#include "FFEN.hpp"
#include "FUtility.hpp"

#include "ChessBoard.hpp"
#include "ChessMoveGenerator.hpp"

#include <cassert>
#include <iostream>
#include <vector>

static void eatWhiteSpace(std::string pgn, unsigned &cursor) {
    while (pgn[cursor] == ' ') {
        cursor++;
    }
}

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
    while (cursor < pgn.length() && pgn[cursor] != '.') {
        cursor++;
    }
    cursor++;
    return true;
}

static bool parseString(std::string pgn, unsigned &cursor, std::string string) {
    for (int index=0; index<string.length(); index++) {
        if (cursor < pgn.length()) {
            if (string[index] == pgn[cursor]) {
                cursor++;
            } else {
                return false;
            }
        } else {
            return false;
        }
    }
    return true;
}

static bool parseQuotedString(std::string pgn, unsigned &cursor, std::string &string) {
    if (pgn[cursor] != '"') {
        return false;
    }
    cursor++;
    
    while (cursor < pgn.length() && pgn[cursor] != '"') {
        string += pgn[cursor];
        cursor++;
    }
    cursor++; // go after the endCharacter
    return true;
}

static std::string pgnPiece(Piece piece) {
    switch (piece) {
        case PAWN:
            return "";
            
        case KING:
            return "K";
            
        case QUEEN:
            return "Q";
            
        case ROOK:
            return "R";
            
        case BISHOP:
            return "B";
            
        case KNIGHT:
            return "N";
            
        default:
            return "?";
    }
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

static std::vector<Move> getMatchingMoves(ChessBoard board, Square to, Piece movingPiece, Piece promotedPiece, File fromFile, Rank fromRank) {
    ChessMoveGenerator generator;
    auto moveList = generator.generateMoves(board);
    std::vector<Move> matchingMoves;
    for (int index=0; index<moveList.count; index++) {
        auto m = moveList.moves[index];
        if (MOVE_TO(m) != to) {
            continue;
        }
        
        if (MOVE_PIECE(m) != movingPiece) {
            continue;
        }

        if (MOVE_PROMOTION_PIECE(m) != promotedPiece) {
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
    
    return matchingMoves;
}

static bool IsCastlingKingSide(Move move) {
    if (MOVE_COLOR(move) == WHITE) {
        return MOVE_FROM(move) == e1 && MOVE_TO(move) == g1;
    } else {
        return MOVE_FROM(move) == e8 && MOVE_TO(move) == g8;
    }
}

static bool IsCastlingQueenSide(Move move) {
    if (MOVE_COLOR(move) == WHITE) {
        return MOVE_FROM(move) == e1 && MOVE_TO(move) == c1;
    } else {
        return MOVE_FROM(move) == e8 && MOVE_TO(move) == c8;
    }
}

std::string FPGN::to_string(Move move, SANType sanType) {
    auto piece = MOVE_PIECE(move);
    auto fromSquare = SquareNames[MOVE_FROM(move)];
    auto toSquare = SquareNames[MOVE_TO(move)];
    auto promotionPiece = MOVE_PROMOTION_PIECE(move);
    
    // UCI requires a very simple representation
    if (sanType == SANType::uci) {
        return fromSquare+toSquare;
    }
    
    // Non-UCI mode is a bit more complex
    std::string pgn = "";

    if (IsCastlingKingSide(move)) {
        pgn += "O-O";
    } else if (IsCastlingQueenSide(move)) {
        pgn += "O-O-O";
    } else {
        auto isCapture = MOVE_IS_CAPTURE(move);
        
        auto fromFile = FileFrom(MOVE_FROM(move));
        auto fileName = FileNames[fromFile];

        switch (sanType) {
            case SANType::tight:
                if (isCapture) {
                    if (piece == PAWN) {
                        // cxe4
                        pgn += fileName;
                        pgn += "x";
                        pgn += toSquare;
                    } else {
                        // Nxe4
                        pgn += pgnPiece(piece);
                        pgn += "x";
                        pgn += toSquare;
                    }
                } else {
                    pgn += pgnPiece(piece);
                    pgn += toSquare;
                }
                break;
                
            case SANType::full:
                pgn += pgnPiece(piece);
                pgn += fromSquare;
                if (isCapture) {
                    pgn += "x";
                }
                pgn += toSquare;
                break;
                
            case SANType::medium: {
                pgn += pgnPiece(piece);
                pgn += fileName;
                if (isCapture) {
                    pgn += "x";
                }
                pgn += toSquare;
                break;
            }
                
            case SANType::uci:
                // Handled above
                break;
        }
    }
    
    if (promotionPiece > PAWN) {
        pgn += "=";
        pgn += pgnPiece(promotionPiece);
    }
    
    return pgn;
}

Move FPGN::parseMove(std::string pgn, unsigned &cursor, FGame &game, bool &end) {
    eatWhiteSpace(pgn, cursor);
    
    Piece movingPiece = parsePiece(pgn, cursor);
    
    File fromFile = FileUndefined;
    Rank fromRank = RankUndefined;

    File toFile = FileUndefined;
    Rank toRank = RankUndefined;

    bool capture = false;
    
    if (isRank(pgn[cursor]) && isFile(pgn[cursor+1]) && isRank(pgn[cursor+2])) {
        // R6e4
        fromRank = getRank(pgn[cursor++]);
        toFile = getFile(pgn[cursor++]);
        toRank = getRank(pgn[cursor++]);
    } else if (isFile(pgn[cursor]) && isFile(pgn[cursor+1]) && isRank(pgn[cursor+2])) {
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
        if (game.board.color == WHITE) {
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
        if (game.board.color == WHITE) {
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
        game.outcome = FGame::Outcome::white_wins;
        end = true;
    } else if (pgn[cursor] == '0' && pgn[cursor+1] == '-' && pgn[cursor+2] == '1') {
        // Termination marker: black wins
        cursor+=3;
        game.outcome = FGame::Outcome::black_wins;
        end = true;
    } else if (pgn[cursor] == '1' && pgn[cursor+1] == '/' && pgn[cursor+2] == '2' && pgn[cursor+3] == '-' && pgn[cursor+4] == '1' && pgn[cursor+5] == '/' && pgn[cursor+6] == '2') {
        // Termination marker: draw
        cursor+=7;
        game.outcome = FGame::Outcome::draw;
        end = true;
    } else if (pgn[cursor] == '*') {
        // Termination marker: game in progress or result unknown
        cursor++;
        game.outcome = FGame::Outcome::in_progress;
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
    assert(toRank != RankUndefined);
    
    Square to = SquareFrom(toFile, toRank);
    
    // Now the original square can be not fully defined...
    auto matchingMoves = getMatchingMoves(game.board, to, movingPiece, (Piece)0, fromFile, fromRank);
    
    // After matching, one and only one move should be found
    if (matchingMoves.size() == 1) {
        return matchingMoves.front();
    } else {
        return 0;
    }
}

bool FPGN::parseMoveText(std::string pgn, unsigned &cursor, FGame &game, bool &end) {
    // Indication of a move, for example:
    // 1. e4 e5
    assert(parseMoveNumber(pgn, cursor));
    
    Move whiteMove = parseMove(pgn, cursor, game, end);
    if (end) {
        return true;
    }
    if (!MOVE_ISVALID(whiteMove)) {
        return false;
    }
    
    game.move(whiteMove);
    
//    std::cout << MOVE_DESCRIPTION(whiteMove) << std::endl;
//    game.board.print();
    
    // Did we reach the end now?
    if (cursor >= pgn.length()) {
        end = true;
        return true;
    }
    
    if (!isSpaceOrNewLine(pgn[cursor++])) {
        // Missing white space or new line
        return false;
    }
    
    Move blackMove = parseMove(pgn, cursor, game, end);
    if (end) {
        return true;
    }
    if (!MOVE_ISVALID(blackMove)) {
        return false;
    }
    
    game.move(blackMove);
//    std::cout << MOVE_DESCRIPTION(blackMove) << std::endl;
//    game.board.print();
    
    return true;
}

bool FPGN::setGame(std::string pgn, FGame &game) {
    game.reset();
    
    unsigned cursor = 0;
    bool end = false;
    while (cursor < pgn.length() && !end) {
        auto c = pgn[cursor];
        if (c == '[') {
            // Indication for a tag
            cursor++; // go after the [

            if (parseString(pgn, cursor, "FEN")) {
                eatWhiteSpace(pgn, cursor);
                std::string fen;
                assert(parseQuotedString(pgn, cursor, fen));
                assert(game.setFEN(fen));
            } else {
                std::string comment = "";
                assert(parseUntil(pgn, cursor, comment, ']'));
            }
        } else if (c == '{') {
            // Indication for a comment
            cursor++; // go after the [
            std::string comment = "";
            assert(parseUntil(pgn, cursor, comment, '}'));
        } else if (c >= '0' && c <= '9') {
            if (!parseMoveText(pgn, cursor, game, end)) {
                return false;
            }
        } else {
            // Any other character, such as white space or new line are ignored
            cursor++;
        }
    }
    
    return true;
}

std::string FPGN::getGame(FGame game, bool newLineAfterEachFullMove, bool compact, int fromIndex) {
    // Game used to compute the optimum PGN representation for each move
    ChessBoard outputBoard;
    FFEN::setFEN(game.initialFEN, outputBoard);
    
    std::string pgn;
    unsigned fullMoveIndex = 0;
    for (int index=0; index<game.moveCursor; index++) {
        auto move = game.moves[index];
        auto piece = MOVE_PIECE(move);

        if (index == fromIndex) {
            pgn = "";
        }
        
        SANType sanType = SANType::full;
        auto matchingMoves = getMatchingMoves(outputBoard, MOVE_TO(move), piece, MOVE_PROMOTION_PIECE(move), FileUndefined, RankUndefined);
        if (matchingMoves.size() == 1) {
            // Only one matching move, we can use the shortest form for PGN
            // For example: Ne3
            sanType = SANType::tight;
        } else {
            matchingMoves = getMatchingMoves(outputBoard, MOVE_TO(move), piece, MOVE_PROMOTION_PIECE(move), FileFrom(MOVE_FROM(move)), RankUndefined);
            if (matchingMoves.size() == 1) {
                // Use the File to specify the move. For example: Nge3
                sanType = SANType::medium;
            } else {
                matchingMoves = getMatchingMoves(outputBoard, MOVE_TO(move), piece, MOVE_PROMOTION_PIECE(move), FileFrom(MOVE_FROM(move)), RankFrom(MOVE_FROM(move)));
                if (matchingMoves.size() == 1) {
                    sanType = SANType::full;
                } else {
                    assert(false); // Should not happen
                }
            }
        }
        
        if (index % 2 == 0) {
            fullMoveIndex++;
            if (newLineAfterEachFullMove) {
                pgn += "\n";
            }
            if (!compact) {
                pgn += std::to_string(fullMoveIndex) + ". ";
            }
        }
                
        pgn += to_string(move, sanType);

        outputBoard.move(move);
        
        // Determine if the position is check or mate
        if (outputBoard.isCheck(outputBoard.color)) {
            ChessMoveGenerator generator;
            auto moveList = generator.generateMoves(outputBoard);
            if (moveList.count == 0) {
                pgn += "#";
            } else {
                pgn += "+";
            }
        }
        
        pgn += " ";
    }
    
    if (compact) {
        return pgn;
    }
        
    switch (game.outcome) {
        case FGame::Outcome::black_wins:
            pgn += "0-1";
            break;
            
        case FGame::Outcome::white_wins:
            pgn += "1-0";
            break;
            
        case FGame::Outcome::draw:
            pgn += "1/2-1/2";
            break;
            
        case FGame::Outcome::in_progress:
            pgn += "*";
            break;
    }
    
    // Now let's add the tag pairs
    // https://en.wikipedia.org/wiki/Portable_Game_Notation
    if (game.initialFEN != StartFEN) {
        // [FEN "rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq - 0 1"]
        // [SetUp "1"]
        std::string tags = "[FEN \"" + game.initialFEN + "\"]\n";
        tags += "Setup \"1\"\n";
        
        pgn = tags + pgn;
    }
    
    return pgn;
}

