//
//  FGame.hpp
//  BChess
//
//  Created by Jean Bovet on 12/14/17.
//  Copyright © 2017 Jean Bovet. All rights reserved.
//

#pragma once

#include "ChessBoard.hpp"
#include "MoveList.hpp"
#include "GameHistory.hpp"

#include <vector>
#include <map>

class ChessGame {
public:
    enum class Outcome {
        white_wins, black_wins, draw, in_progress
    };

    // This structure identifies the current moves of the game,
    // taking into account the exact variation taken when appropriate.
    struct MoveIndexes {
        // Current move path identifier
        // [0, 0, 1] means there are 3 moves, the first 2 in the main line
        // and the third one using the first variation.
        std::vector<int> moves;
        
        // The current index in the index of moves above
        int moveCursor = 0;
        
        void add(int move) {
            if (moveCursor < moves.size()) {
                moves[moveCursor] = move;
            } else {
                moves.push_back(move);
            }
            moveCursor++;
        }
        
        void reset() {
            moveCursor = 0;
            moves.clear();
        }
    };

    // This structure represents a particular move in the tree of moves
    // that a game represents. A node has a move associated with it, including
    // the next move node (or move nodes if there is more than one variation).
    struct MoveNode {
        // Unique ID for this move node, used to identify uniquely this node
        // across any variations. For example, this is used to indicate
        // which move node is the current one in the game.
        unsigned int uuid;
        
        // The full move number
        unsigned moveNumber;
        
        // The move itself
        Move move;

        // The comment associated with the move
        std::string comment;
                
        // List representing the next node following this one.
        // In other words, this list contains the moves that can be
        // played against this node's move, including any variation.
        // Note: the main line is always at index 0.
        std::vector<MoveNode> variations;
        
        typedef std::function<void(MoveNode &node)> NodeCallback;

        // Find the node that represents the move at `atIndex`. Note that `atIndex==0` represents
        // the "root" node, which is not a move. The first move is actually at `atIndex==1`.
        // cursor: the cursor used to keep track of the current index while recursively looking up
        void lookupNode(int cursor, int atIndex, MoveIndexes indexes, NodeCallback callback) {
            if (cursor == atIndex) {
                callback(*this);
            } else if (cursor < indexes.moveCursor) {
                int varIndex = indexes.moves[cursor];
                assert(varIndex < variations.size());
                variations[varIndex].lookupNode(cursor+1, atIndex, indexes, callback);
            }
        }
        
        void visit(int cursor, MoveIndexes indexes, NodeCallback callback) {
            if (cursor < indexes.moveCursor) {
                int varIndex = indexes.moves[cursor];
                callback(variations[varIndex]);
                variations[varIndex].visit(cursor+1, indexes, callback);
            }
        }
        
        // This function takes an array of moves and returns true if and only if
        // all the moves match at least one variation starting with this node.
        bool matches(int cursor, std::vector<Move> moves, NodeCallback callback) {
            if (cursor < moves.size()) {
                for (int vindex=0; vindex<variations.size(); vindex++) {
                    if (variations[vindex].move == moves[cursor]) {
                        return variations[vindex].matches(cursor+1, moves, callback);
                    }
                }
                return false;
            } else {
                callback(*this);
                return true;
            }
        }

        void clear() {
            variations.clear();
        }
    };
    
    ChessGame();
    
    // The initial representation of the game in FEN.
    std::string initialFEN;
    
    ChessBoard board;
    
    HistoryPtr history;
        
    MoveIndexes getMoveIndexes() {
        return moveIndexes;
    }
    
    void setMoveIndexes(MoveIndexes indexes) {
        moveIndexes = indexes;
                
        // Always replay the moves to update the internal
        // board state when the move indexes change,
        // because that means we are starting at another
        // location in the tree of moves.
        // TODO: consider never doing that and replaying the game only when needed?
        replayMoves();
    }
    
    int getNumberOfMoves() {
        return moveIndexes.moveCursor;
    }
    
    Move getMoveAtIndex(int indexMove) {
        Move move = INVALID_MOVE;
        // Note: use indexMove+1 because the node at index 0 is the root node
        // which does not represent the first move (the first move is attached
        // to the root node in the variations list).
        root.lookupNode(0, indexMove+1, moveIndexes, [&move](auto & node) {
            move = node.move;
        });
        return move;
    }
    
    unsigned int getCurrentMoveUUID() {
        unsigned int uuid = 0;
        root.lookupNode(0, moveIndexes.moveCursor, moveIndexes, [&uuid](auto & node) {
            uuid = node.uuid;
        });
        return uuid;
    }
    
    MoveNode getRoot() {
        return root;
    }
    
    Outcome outcome = Outcome::in_progress;
    
    std::map<std::string, std::string> tags;
    
    void reset();
    
    bool setFEN(std::string fen);
    std::string getFEN();
    
    BoardSquare getPieceAt(File file, Rank rank);
    
    std::vector<Move> movesAt(File file, Rank rank);
    std::vector<Move> allMoves();

    void move(Move move, std::string comment, bool replace);
    void move(std::string from, std::string to);
    
    bool canUndoMove();
    bool canRedoMove();
    
    void undoMove();
    void redoMove();

    std::string getState();
    
private:
    MoveNode root;
    MoveIndexes moveIndexes;

    // Unique ID for each generated move.
    // Simply incrementing this variable
    // is sufficient.
    unsigned int moveUUID;

    unsigned int nextMoveUUID() {
        if (moveUUID < UINT_MAX) {
            moveUUID++;
        } else {
            moveUUID = 0;
        }
        return moveUUID;
    }
    
    void replayMoves();
};

