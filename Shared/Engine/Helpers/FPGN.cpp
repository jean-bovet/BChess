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

#define PARSE_BEGIN unsigned savedCursor = cursor; eatWhiteSpaces();

#define RETURN_FAILURE_SILENT(error, silent) { \
    cursor = savedCursor; \
    if (!silent) { \
    std::cout << error << " around '" << character(-2) << character(-1) << character() << character(1) << character(2) << "' at " << __FUNCTION__ << ":" << __LINE__ << std::endl; \
    } \
    return false; }

#define RETURN_FAILURE(error) RETURN_FAILURE_SILENT(error, false)

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

static bool isDigit(char c) {
    return c >= '0' && c <= '9';
}

static File getFile(char c) {
    assert(isFile(c));
    return (File)(c - 'a');
}

static Rank getRank(char c) {
    assert(isRank(c));
    return (Rank)(c - '1');
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

static bool parseUntil(std::string pgn, unsigned &cursor, std::string &comment, char endCharacter) {
    while (cursor < pgn.length() && pgn[cursor] != endCharacter) {
        comment += pgn[cursor];
        cursor++;
    }
    cursor++; // go after the endCharacter
    return true;
}

static bool isCastlingKingSide(Move move) {
    if (!MOVE_IS_CASTLING(move)) return false;
    
    if (MOVE_COLOR(move) == WHITE) {
        return MOVE_FROM(move) == e1 && MOVE_TO(move) == g1;
    } else {
        return MOVE_FROM(move) == e8 && MOVE_TO(move) == g8;
    }
}

static bool isCastlingQueenSide(Move move) {
    if (!MOVE_IS_CASTLING(move)) return false;

    if (MOVE_COLOR(move) == WHITE) {
        return MOVE_FROM(move) == e1 && MOVE_TO(move) == c1;
    } else {
        return MOVE_FROM(move) == e8 && MOVE_TO(move) == c8;
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

    if (isCastlingKingSide(move)) {
        pgn += "O-O";
    } else if (isCastlingQueenSide(move)) {
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

// This function takes a board (which represents a particular board of a chess game)
// as well as a partial description of a move and returns all the moves that fit that description.
std::vector<Move> getMatchingMoves(ChessBoard board, Square to, Piece movingPiece, Piece promotedPiece, File fromFile, Rank fromRank) {
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

bool FPGN::parseMoveNumber(unsigned &moveNumber, bool &isMoveForBlack) {
    PARSE_BEGIN
    
    // Parse the number portion of the move
    std::string moveNumberString = "";
    while(true) {
        if (cursor >= pgn.length()) {
            RETURN_FAILURE("Unexpected end of PGN")
        }
        
        if (character() == '.') {
            // A dot means we are done with the number portion
            // Make sure the number string is not empty!
            if (moveNumberString.empty()) {
                RETURN_FAILURE("Unexpected empty moveNumber")
            }
            moveNumber = integer(moveNumberString);
            break;
        } else if (isDigit(character())) {
            moveNumberString += character();
            cursor++;
        } else {
            RETURN_FAILURE("Unexpected character")
        }
    }
        
    // Parse the number of dots, to determine if it is a white or black move
    unsigned numberOfDots = 0;
    while (hasMoreCharacters() && character() == '.') {
        cursor++;
        numberOfDots++;
    }
    
    if (numberOfDots == 1) {
        isMoveForBlack = false;
        return true;
    } else if (numberOfDots == 3) {
        isMoveForBlack = true;
        return true;
    } else {
        RETURN_FAILURE("Invalid number of dots in move number")
    }    
}

void FPGN::eatWhiteSpaces() {
    while (cursor < pgn.length() && isSpaceOrNewLine(pgn[cursor])) {
        cursor++;
    }
}

bool FPGN::parsePiece(Piece &piece) {
    auto c = pgn[cursor];
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
    
    return true;
}

bool FPGN::parseTerminationMarker() {
    PARSE_BEGIN
    
    if (pgn[cursor] == '1' && pgn[cursor+1] == '-' && pgn[cursor+2] == '0') {
        // Termination marker: white wins
        cursor+=3;
        game.outcome = ChessGame::Outcome::white_wins;
        return true;
    } else if (pgn[cursor] == '0' && pgn[cursor+1] == '-' && pgn[cursor+2] == '1') {
        // Termination marker: black wins
        cursor+=3;
        game.outcome = ChessGame::Outcome::black_wins;
        return true;
    } else if (pgn[cursor] == '1' && pgn[cursor+1] == '/' && pgn[cursor+2] == '2' && pgn[cursor+3] == '-' && pgn[cursor+4] == '1' && pgn[cursor+5] == '/' && pgn[cursor+6] == '2') {
        // Termination marker: draw
        cursor+=7;
        game.outcome = ChessGame::Outcome::draw;
        return true;
    } else if (pgn[cursor] == '*') {
        // Termination marker: game in progress or result unknown
        cursor++;
        game.outcome = ChessGame::Outcome::in_progress;
        return true;
    } else {
        RETURN_FAILURE_SILENT("Unexpected termination marker", true)
    }
}

bool FPGN::parseMove(Move &move) {
    PARSE_BEGIN
        
    Piece movingPiece;
    if (!parsePiece(movingPiece)) {
        RETURN_FAILURE("Unable to parse piece")
    }
    
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
    } else if (isFile(pgn[cursor]) && isRank(pgn[cursor+1])) {
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
    } else {
        // Invalid SAN representation
        move = 0;
        RETURN_FAILURE("Invalid SAN representation of the move")
    }

    // 8.2.3.5: Check and checkmate indication characters
    if (isCheckOrMate(pgn[cursor])) {
        cursor++;
    }
    
    // Handle promotion
    Piece promotedPiece = (Piece)0;
    if (isPromotion(pgn[cursor])) {
        cursor++;
        parsePiece(promotedPiece);
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
        if (MOVE_ISVALID(move)) {
            return true;
        } else {
            RETURN_FAILURE("Invalid matched move")
        }
    } else {
        move = 0;
        RETURN_FAILURE("No matching moves found")
    }
}

// A variation is simply an alternative line to the move that has just been played
bool FPGN::parseVariation() {
    PARSE_BEGIN
        
    if (character() != '(') {
        RETURN_FAILURE_SILENT("Unexpected start of variation", true)
    } else {
        cursor++;
    }
        
    // Remember the move indexes so we can restore it once
    // we are done parsing the variation.
    auto moveIndexes = game.getMoveIndexes();
    
    // Restore the game as it was before the last move, so we
    // apply correctly the variation.
    moveIndexes.moveCursor--;
    game.setMoveIndexes(moveIndexes);
    moveIndexes.moveCursor++;

    // Parse the variation, which consist of one or more moveText.
    // (moveText1 [moveText2]...)
    while (parseMoveText()) {
        if (!hasMoreCharacters()) {
            RETURN_FAILURE("Unexpected end of PGN while parsing a variation")
        }
        if (character() == ')') {
            break;
        }
    }
    
    eatWhiteSpaces();

    // Check we have reached the end of the variation
    if (character() != ')') {
        RETURN_FAILURE("Unexpected end of variation")
    }

    // Go past ')'
    cursor++;
    
    // Restore the move indexes as it was before the variation
    // so the internal game state is properly restored and
    // ready to consume the next moves.
    game.setMoveIndexes(moveIndexes);

    return true;
}

/**
 Parse a movetext block as defined in the PGN specifications. Not everything is yet supported.
 [move number] [move] [comment] [move] [comment]
 
 For example:
    1. e4 e5
    2...d6
    1. e4 { comment }
 */
bool FPGN::parseMoveText() {
    PARSE_BEGIN
    
    bool isMoveForBlack = false;
    unsigned moveNumber;
    if (!parseMoveNumber(moveNumber, isMoveForBlack)) {
        RETURN_FAILURE("Invalid move number")
    }

    Move whiteMove = 0;
    if (!parseMove(whiteMove)) {
        RETURN_FAILURE("Invalid move")
    }
    
    game.move(whiteMove, false);

//    if (isMoveForBlack) {
//        std::cout << "Parse black move: " << to_string(whiteMove, SANType::full) << std::endl;
//    } else {
//        std::cout << "Parse white move: " << to_string(whiteMove, SANType::full) << std::endl;
//    }
//    game.board.print();

    parseComment(); // optional
    while (parseVariation()) { } // Parse zero or more variations
        
    // Return now if the moveText was actually only for black
    if (isMoveForBlack) {
        return true;
    }

    // Return now if a termination marker is detected
    if (parseTerminationMarker()) {
        return true;
    }
    
    // Return now if the end of a variation is detected
    eatWhiteSpaces();
    if (character() == ')') {
        return true;
    }
    
    // Sometimes the move number is repeated for the black move
    if (isDigit(character())) {
        if (parseMoveNumber(moveNumber, isMoveForBlack)) {
            assert(isMoveForBlack); // it should always be for black
        } else {
            RETURN_FAILURE("Invalid black move number")
        }
    }

    // Parse the move itself
    Move blackMove = 0;
    if (!parseMove(blackMove)) {
        RETURN_FAILURE("Invalid black move")
    }
    
//    std::cout << "Parse black move: " << to_string(blackMove, SANType::full) << std::endl;
    //    game.board.print();
    game.move(blackMove, false);

    parseComment(); // optional
    while (parseVariation()) { } // Parse zero or more variations

    return true;
}

// Parse comments in the form: { this is a comment }.
// Don't do anything with the comment itself for now.
bool FPGN::parseComment() {
    PARSE_BEGIN
    
    if (character() == '{') {
        cursor++;
        std::string comment = "";
        if (!parseUntil(pgn, cursor, comment, '}')) {
            RETURN_FAILURE("Unable to parse until a specific character")
        }
                
        return true;
    } else {
        RETURN_FAILURE_SILENT("Unexpected comment starting character", true)
    }
}

bool FPGN::setGame(std::string pgn, ChessGame &game) {
    unsigned cursor = 0;
    return setGame(pgn, game, cursor);
}

bool FPGN::parseTag(bool lookahead) {
    PARSE_BEGIN
    
    // Expecting a tag opening bracket
    if (character() != '[') {
        RETURN_FAILURE_SILENT("Unexpected start TAG character", true)
    }
    
    if (lookahead) {
        cursor = savedCursor;
        return true;
    }
    
    cursor++; // go after the [

    std::string tagName;
    std::string tagValue;
    auto result = parseString(pgn, cursor, tagName);
    assert(result);
    
    eatWhiteSpaces();
    result = parseQuotedString(pgn, cursor, tagValue);
    assert(result);
    
    eatWhiteSpaces();
    if (character() != ']') {
        RETURN_FAILURE("Unexpected end TAG character")
    }
    
    cursor++;
    
    game.tags[tagName] = tagValue;
    
    if (tagName == "FEN" && !game.setFEN(tagValue)) {
        RETURN_FAILURE("Failed to set FEN to the game")
    }
    
    return true;
}

bool FPGN::setGame(std::string pgn, ChessGame &game, unsigned & cursor) {
    game.reset();
    
    auto fpgn = FPGN(pgn);
    fpgn.cursor = cursor;
    bool parsedMoveText = false;
    while (fpgn.hasMoreCharacters()) {
        fpgn.eatWhiteSpaces();

        if (fpgn.character() == '*') {
            // We have reached the end of this game
            fpgn.cursor++;
            fpgn.eatWhiteSpaces();

            game = fpgn.game;
            cursor = fpgn.cursor;
            return true;
        }

        // Check if there is tag ahead and if we have already
        // parsed at least one moveText section. If that is the case,
        // it means we are now parsing the tag section of another game.
        if (fpgn.parseTag(true) && parsedMoveText) {
            game = fpgn.game;
            cursor = fpgn.cursor;
            return true;
        }
        
        // Parse all the tags
        while (fpgn.parseTag()) {
            // no-op
        }
        
        // Parse the moveText
        if (fpgn.parseMoveText()) {
            // Remember that we parsed at least one move text section
            parsedMoveText = true;
        } else {
            return false;
        }
                
        fpgn.eatWhiteSpaces();
    }
    
    game = fpgn.game;
    cursor = fpgn.cursor;
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

// Returns a PGN representation of a particular node in the game, including all its descendant.
static void getPGN(ChessBoard board, // The chess board representation which is used to determine the actual move and state of the board
                   FPGN::Formatting formatting, // The type of desired formatting
                   ChessGame::MoveNode & node, // The current node representing the move being output
                   std::string & pgn, // The PGN being constructed
                   int moveIndex, // The current move index
                   int fromMoveIndex, // The move index at which we starts to build up the PGN
                   int fullMoveIndex, // The number of full move that have been done so far
                   bool mainLine, // True if this node/move represents the main line, false if it represents a variation
                   bool recursive, // True if this method should continue to traverse the next move and all its variation, false to just output this move and return
                   bool skip // True if the PGN output should be skipped for this method executed
) {
    auto move = node.move;
    auto piece = MOVE_PIECE(move);
    
    if (formatting == FPGN::Formatting::line && moveIndex == fromMoveIndex && !skip) {
        pgn = "";
    }
    
    FPGN::SANType sanType = FPGN::SANType::full;
    auto matchingMoves = getMatchingMoves(board, MOVE_TO(move), piece, MOVE_PROMOTION_PIECE(move), FileUndefined, RankUndefined);
    if (matchingMoves.size() == 1) {
        // Only one matching move, we can use the shortest form for PGN
        // For example: Ne3
        sanType = FPGN::SANType::tight;
    } else {
        matchingMoves = getMatchingMoves(board, MOVE_TO(move), piece, MOVE_PROMOTION_PIECE(move), FileFrom(MOVE_FROM(move)), RankUndefined);
        if (matchingMoves.size() == 1) {
            // Use the File to specify the move. For example: Nge3
            sanType = FPGN::SANType::medium;
        } else {
            matchingMoves = getMatchingMoves(board, MOVE_TO(move), piece, MOVE_PROMOTION_PIECE(move), FileFrom(MOVE_FROM(move)), RankFrom(MOVE_FROM(move)));
            if (matchingMoves.size() == 1) {
                sanType = FPGN::SANType::full;
            } else {
                // Should not happen
                printf("Unable to find matching moves\n");
            }
        }
    }
    
    if (moveIndex % 2 == 0) {
        fullMoveIndex++;
    }

    // Output the move number
    if (!skip) {
        if (mainLine) {
            // In the main line, only display the move number for white
            if (moveIndex % 2 == 0 && formatting != FPGN::Formatting::line) {
                if (pgn.size() > 0) {
                    pgn += " ";
                }
                pgn += std::to_string(fullMoveIndex) + ".";
            }
        } else {
            // We are in a variation, which means we need to display
            // the full move number and if it is white or black
            // to play. For example:
            // (1. d4)   // variation for white
            // (1... c5) // variation for black
            if (formatting != FPGN::Formatting::line) {
                pgn += std::to_string(fullMoveIndex);
            }
            if (moveIndex % 2 == 0) {
                pgn += ".";
            } else {
                pgn += "...";
            }
        }
    }
    
    // Output the actual move
    if (!skip) {
        if (pgn.size() > 0) {
            pgn += " ";
        }
        pgn += FPGN::to_string(move, sanType);
    }
    
    // Execute the move on the board
    board.move(move);

    // Determine if the position is check or mate
    if (board.isCheck(board.color) && !skip) {
        ChessMoveGenerator generator;
        auto moveList = generator.generateMoves(board);
        if (moveList.count == 0) {
            pgn += "#";
        } else {
            pgn += "+";
        }
    }

    // If we are not doing any recursive output, return now.
    if (!recursive) {
        return;
    }
    
    // Now deal with the variations
    // Note: the first variation always represents the main line
    if (node.variations.size() > 0) {
        if (node.variations.size() == 1) {
            // If there is only one variation, it is easy: it is the main line
            // so continue recursively to traverse it.
            auto & main = node.variations[0];
            getPGN(board, formatting, main, pgn, moveIndex+1, fromMoveIndex, fullMoveIndex, /*mainline*/true, /*recursive*/true, /*skip*/false);
        } else {
            // If there are more than one variation, we need to print first the main variation but for only one move
            // For example: 1. e4 e5
            auto & main = node.variations[0];
            getPGN(board, formatting, main, pgn, moveIndex+1, fromMoveIndex, fullMoveIndex, /*mainline*/true, /*recursive*/false, /*skip*/false);
            
            // And then print all the other variations in full (recursively)
            // For example: 1. e4 e5 (1... d5)
            for (int vindex=1; vindex<node.variations.size(); vindex++) {
                auto & vnode = node.variations[vindex];
                pgn += " (";
                getPGN(board, formatting, vnode, pgn, moveIndex+1, fromMoveIndex, fullMoveIndex, /*mainline*/false, /*recursive*/true, /*skip*/false);
                pgn += ")";
            }
            
            // And finally resume the main line output, recursively, but skipping this time the next move
            // because it was already output above
            // For example: 1. e4 e5 (1... d5) 2. Nf3 *
            getPGN(board, formatting, main, pgn, moveIndex+1, fromMoveIndex, fullMoveIndex, /*mainline*/true, /*recursive*/true, /*skip*/true);
        }
    }
}

std::string FPGN::getGame(ChessGame game, Formatting formatting, int fromIndex) {
    // Game used to compute the optimum PGN representation for each move
    ChessBoard outputBoard;
    FFEN::setFEN(game.initialFEN, outputBoard);
    
    std::string pgn;
    unsigned fullMoveIndex = 0;
    
    auto rootNode = game.getRoot();
    for (int vindex=0; vindex<rootNode.variations.size(); vindex++) {
        auto & node = rootNode.variations[vindex];
        if (vindex > 0) {
            pgn += " (";
        }
        getPGN(outputBoard, formatting, node, pgn, 0, fromIndex, fullMoveIndex, /*mainline*/vindex == 0, /*recursive*/true, /*skip*/false);
        if (vindex > 0) {
            pgn += ")";
        }
    }
    
    if (formatting == Formatting::line) {
        return pgn;
    }
    
    if (pgn.size() > 0) {
        pgn += " ";
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

