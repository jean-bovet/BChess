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

static bool isPromotion(char c) {
    return c == '=';
}

static bool parseUntil(std::string pgn, unsigned &cursor, std::string &comment, char endCharacter) {
    while (cursor < pgn.length() && pgn[cursor] != endCharacter) {
        comment += pgn[cursor];
        cursor++;
    }
    cursor++; // go after the endCharacter
    return true;
}


// For example:
// "12. "
// "1..." - to indicate a move for black
static bool parseMoveNumber(std::string pgn, unsigned &cursor, bool &isMoveForBlack) {
    // Parse the number portion of the move
    while (cursor < pgn.length() && pgn[cursor] != '.') {
        cursor++;
    }
    
    // Parse the number of dots, to determine if it is a white or black move
    unsigned numberOfDots = 0;
    while (cursor < pgn.length() && pgn[cursor] == '.') {
        cursor++;
        numberOfDots++;
    }
    
    if (numberOfDots == 1) {
        isMoveForBlack = false;
    } else if (numberOfDots == 3) {
        isMoveForBlack = true;
    } else {
        // Invalid number of dots
        return false;
    }
    
    return true;
}

static bool parseString(std::string pgn, unsigned &cursor, std::string & string) {
    if (isSpaceOrNewLine(pgn[cursor])) {
        return false;
    }
    
    while (cursor < pgn.length() && !isSpaceOrNewLine(pgn[cursor])) {
        string += pgn[cursor];
        cursor++;
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

static void eatWhiteSpace(std::string pgn, unsigned &cursor) {
    while (cursor < pgn.length() && isSpaceOrNewLine(pgn[cursor])) {
        cursor++;
    }
}

// Parse comments in the form: { this is a comment }.
// Don't do anything with the comment itself for now.
static void parseComment(std::string pgn, unsigned &cursor) {
    eatWhiteSpace(pgn, cursor);
    
    if (pgn[cursor] == '{') {
        cursor++;
        std::string comment = "";
        auto result = parseUntil(pgn, cursor, comment, '}');
        assert(result);
    }
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
    if (!MOVE_IS_CASTLING(move)) return false;
    
    if (MOVE_COLOR(move) == WHITE) {
        return MOVE_FROM(move) == e1 && MOVE_TO(move) == g1;
    } else {
        return MOVE_FROM(move) == e8 && MOVE_TO(move) == g8;
    }
}

static bool IsCastlingQueenSide(Move move) {
    if (!MOVE_IS_CASTLING(move)) return false;

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

bool FPGN::parseMove(std::string pgn, unsigned &cursor, ChessGame &game, Move &move, bool &end) {
    eatWhiteSpace(pgn, cursor);
    
    Piece movingPiece = parsePiece(pgn, cursor);
    
    File fromFile = FileUndefined;
    Rank fromRank = RankUndefined;

    File toFile = FileUndefined;
    Rank toRank = RankUndefined;
    
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
        // Qa6xb7
        fromFile = getFile(pgn[cursor++]);
        fromRank = getRank(pgn[cursor++]);
        cursor++;
        toFile = getFile(pgn[cursor++]);
        toRank = getRank(pgn[cursor++]);
    } else if (isFile(pgn[cursor]) && isRank(pgn[cursor+1]) && isFile(pgn[cursor+2]) && isRank(pgn[cursor+3])) {
        // Qa7b8
        fromFile = getFile(pgn[cursor++]);
        fromRank = getRank(pgn[cursor++]);
        toFile = getFile(pgn[cursor++]);
        toRank = getRank(pgn[cursor++]);
    } else if (isFile(pgn[cursor]) && isRank(pgn[cursor+1]) && (isSpaceOrNewLine(pgn[cursor+2]) || isCheckOrMate(pgn[cursor+2]) || isPromotion(pgn[cursor+2]) || cursor+2 == pgn.size())) {
        // e4
        // Ba4
        toFile = getFile(pgn[cursor++]);
        toRank = getRank(pgn[cursor++]);
    } else if (isFile(pgn[cursor]) && pgn[cursor+1] == 'x' && isFile(pgn[cursor+2]) && isRank(pgn[cursor+3])) {
        // cxb5
        fromFile = getFile(pgn[cursor++]);
        cursor++;
        toFile = getFile(pgn[cursor++]);
        toRank = getRank(pgn[cursor++]);
    } else if (pgn[cursor] == 'x' && isFile(pgn[cursor+1]) && isRank(pgn[cursor+2])) {
        // Bxf7
        cursor++;
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
        game.outcome = ChessGame::Outcome::white_wins;
        end = true;
    } else if (pgn[cursor] == '0' && pgn[cursor+1] == '-' && pgn[cursor+2] == '1') {
        // Termination marker: black wins
        cursor+=3;
        game.outcome = ChessGame::Outcome::black_wins;
        end = true;
    } else if (pgn[cursor] == '1' && pgn[cursor+1] == '/' && pgn[cursor+2] == '2' && pgn[cursor+3] == '-' && pgn[cursor+4] == '1' && pgn[cursor+5] == '/' && pgn[cursor+6] == '2') {
        // Termination marker: draw
        cursor+=7;
        game.outcome = ChessGame::Outcome::draw;
        end = true;
    } else if (pgn[cursor] == '*') {
        // Termination marker: game in progress or result unknown
        cursor++;
        game.outcome = ChessGame::Outcome::in_progress;
        end = true;
    } else {
        // Invalid SAN representation
        move = 0;
        return false;
    }

    if (end) {
        move = 0;
        return false;
    }
    
    // 8.2.3.5: Check and checkmate indication characters
    if (isCheckOrMate(pgn[cursor])) {
        cursor++;
    }
    
    // Handle promotion
    Piece promotedPiece = (Piece)0;
    if (isPromotion(pgn[cursor])) {
        cursor++;
        promotedPiece = parsePiece(pgn, cursor);
    }
    
    // The target square must be fully defined at this point
    assert(toFile != FileUndefined);
    assert(toRank != RankUndefined);
    
    Square to = SquareFrom(toFile, toRank);
    
    // Now the original square can be fully defined...
    auto matchingMoves = getMatchingMoves(game.board, to, movingPiece, promotedPiece, fromFile, fromRank);
    
    // After matching, one and only one move should be found
    if (matchingMoves.size() == 1) {
        move = matchingMoves.front();
        return true;
    } else {
        move = 0;
        return false;
    }
}

/**
 Parse a movetext block as defined in the PGN specifications. Not everything is yet supported.
 [move number] [move] [comment] [move] [comment]
 
 For example:
    1. e4 e5
    2...d6
    1. e4 { comment }
 */
bool FPGN::parseMoveText(std::string pgn, unsigned &cursor, ChessGame &game, bool &end) {
    bool isMoveForBlack = false;
    auto result = parseMoveNumber(pgn, cursor, isMoveForBlack);
    if (!result) {
        return false;
    }

    Move whiteMove = 0;
    if (!parseMove(pgn, cursor, game, whiteMove, end)) {
        return false;
    }
    
    if (end) {
        return true;
    }
    if (!MOVE_ISVALID(whiteMove)) {
        return false;
    }

    //    std::cout << MOVE_DESCRIPTION(whiteMove) << std::endl;
    //    game.board.print();

    game.move(whiteMove);

    parseComment(pgn, cursor);
            
    // Did we reach the end now?
    if (cursor >= pgn.length()) {
        end = true;
        return true;
    }
        
    eatWhiteSpace(pgn, cursor);

    // Did we reach the end now?
    if (cursor >= pgn.length()) {
        end = true;
        return true;
    }

    if (pgn[cursor] == '[') {
        // Start of a new game
        end = true;
        return true;
    }
    
    Move blackMove = 0;
    if (!parseMove(pgn, cursor, game, blackMove, end)) {
        return true;
    }
    if (end) {
        return true;
    }
    if (!MOVE_ISVALID(blackMove)) {
        return false;
    }
    
    //    std::cout << MOVE_DESCRIPTION(blackMove) << std::endl;
    //    game.board.print();
    game.move(blackMove);

    parseComment(pgn, cursor);
    
    // Did we reach the end now?
    if (cursor >= pgn.length()) {
        end = true;
        return true;
    }

    return true;
}

bool FPGN::setGame(std::string pgn, ChessGame &game) {
    unsigned cursor = 0;
    return setGame(pgn, game, cursor);
}

bool FPGN::setGame(std::string pgn, ChessGame &game, unsigned & cursor) {
    game.reset();
    
    bool end = false;
    bool parsedMoveText = false;
    while (cursor < pgn.length() && !end) {
        auto c = pgn[cursor];
        if (c == '[') {
            // If we already parsed the moveText section, it means
            // we are hitting another game.
            if (parsedMoveText) {
                return true;
            }
            
            cursor++; // go after the [

            std::string tagName;
            std::string tagValue;
            auto result = parseString(pgn, cursor, tagName);
            assert(result);
            eatWhiteSpace(pgn, cursor);
            result = parseQuotedString(pgn, cursor, tagValue);
            assert(result);
            eatWhiteSpace(pgn, cursor);
            assert(pgn[cursor] == ']');
            cursor++;
            
            game.tags[tagName] = tagValue;
            
            if (tagName == "FEN") {
                result = game.setFEN(tagValue);
                assert(result);
            }
        } else if (c >= '0' && c <= '9') {
            if (!parseMoveText(pgn, cursor, game, end)) {
                return false;
            }
            parsedMoveText = true; // we are done parsing the move text section
        } else if (c == '*') {
            // The game continues (but the PGN representation stops here for that game)
            cursor++;
            return true;
        } else {
            eatWhiteSpace(pgn, cursor);
        }
    }
    
    return true;
}

bool FPGN::setGames(std::string pgn, std::vector<ChessGame> & games) {
    unsigned cursor = 0;
    while (cursor < pgn.length()) {
        ChessGame game;
        if (!setGame(pgn, game, cursor)) {
            return false;
        }
        games.push_back(game);
    }
    return true;
}

std::string FPGN::getGame(ChessGame game, Formatting formatting, int fromIndex) {
    // Game used to compute the optimum PGN representation for each move
    ChessBoard outputBoard;
    FFEN::setFEN(game.initialFEN, outputBoard);
    
    std::string pgn;
    unsigned fullMoveIndex = 0;
    for (int index=0; index<game.moveCursor && fromIndex < game.moveCursor; index++) {
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
                    // Should not happen
                    printf("Unable to find matching moves\n");
                }
            }
        }
        
        if (index % 2 == 0) {
            fullMoveIndex++;
            if (formatting != Formatting::line) {
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
    
    if (formatting == Formatting::line) {
        return pgn;
    }
        
    switch (game.outcome) {
        case ChessGame::Outcome::black_wins:
            pgn += "0-1";
            break;
            
        case ChessGame::Outcome::white_wins:
            pgn += "1-0";
            break;
            
        case ChessGame::Outcome::draw:
            pgn += "1/2-1/2";
            break;
            
        case ChessGame::Outcome::in_progress:
            pgn += "*";
            break;
    }
    
    if (formatting == Formatting::storage) {
        // Now let's add the tag pairs
        // https://en.wikipedia.org/wiki/Portable_Game_Notation
        if (game.initialFEN != StartFEN) {
            // [FEN "rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq - 0 1"]
            // [SetUp "1"]
            std::string tags = "[FEN \"" + game.initialFEN + "\"]\n";
            tags += "[Setup \"1\"]\n";
            
            pgn = tags + pgn;
        }
    }
    
    return pgn;
}

