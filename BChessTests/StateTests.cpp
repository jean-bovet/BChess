//
//  FTests.hpp
//  BChess
//
//  Created by Jean Bovet on 12/2/17.
//  Copyright © 2017 Jean Bovet. All rights reserved.
//

#include <gtest/gtest.h>

#include "ChessState.hpp"
#include "FPGN.hpp"

// The legal move that the UCI text spells on this board
static Move uciMove(ChessBoard &board, std::string uci) {
    Move move = FPGN::uciMove(board, uci);
    EXPECT_TRUE(MOVE_ISVALID(move)) << uci;
    return move;
}

TEST(State, InitialState) {
    ChessBoard board;
    ChessState state;
    state.set(board);
    
    auto p = state.getState();
    ASSERT_EQ(p, "R100N110B120Q130K140B250N260R270P101P211P321P431P541P651P761P871p106p216p326p436p546p656p766p876r107n117b127q137k147b257n267r277");
}

TEST(State, WithMoves) {
    ChessBoard board;
    ChessState state;
    state.set(board);
    
    ASSERT_EQ(state.getState(), "R100N110B120Q130K140B250N260R270P101P211P321P431P541P651P761P871p106p216p326p436p546p656p766p876r107n117b127q137k147b257n267r277");
    
    board.move(uciMove(board, "e2e4"));
    state.update(board);
    ASSERT_EQ(state.getState(), "R100N110B120Q130K140B250N260R270P101P211P321P431P651P761P871P543p106p216p326p436p546p656p766p876r107n117b127q137k147b257n267r277");
    
    board.move(uciMove(board, "e7e5"));
    state.update(board);
    ASSERT_EQ(state.getState(), "R100N110B120Q130K140B250N260R270P101P211P321P431P651P761P871P543p544p106p216p326p436p656p766p876r107n117b127q137k147b257n267r277");
    
    board.move(uciMove(board, "g1f3"));
    state.update(board);
    ASSERT_EQ(state.getState(), "R100N110B120Q130K140B250R270P101P211P321P431P651P761P871N252P543p544p106p216p326p436p656p766p876r107n117b127q137k147b257n267r277");
    
    board.move(uciMove(board, "g8f6"));
    state.update(board);
    ASSERT_EQ(state.getState(), "R100N110B120Q130K140B250R270P101P211P321P431P651P761P871N252P543p544n255p106p216p326p436p656p766p876r107n117b127q137k147b257r277");
    
    board.move(uciMove(board, "f1e2"));
    state.update(board);
    ASSERT_EQ(state.getState(), "R100N110B120Q130K140R270P101P211P321P431B241P651P761P871N252P543p544n255p106p216p326p436p656p766p876r107n117b127q137k147b257r277");
    
    board.move(uciMove(board, "f8e7"));
    state.update(board);
    ASSERT_EQ(state.getState(), "R100N110B120Q130K140R270P101P211P321P431B241P651P761P871N252P543p544n255p106p216p326p436b246p656p766p876r107n117b127q137k147r277");
    
    // White castle 0-0
    board.move(uciMove(board, "e1g1"));
    state.update(board);
    ASSERT_EQ(state.getState(), "R100N110B120Q130R250K160P101P211P321P431B241P651P761P871N252P543p544n255p106p216p326p436b246p656p766p876r107n117b127q137k147r277");
    
    // Black night capture pawn f6xe4
    board.move(uciMove(board, "f6e4"));
    state.update(board);
    ASSERT_EQ(state.getState(), "R100N110B120Q130R250K160P101P211P321P431B241P651P761P871N252n243p544p106p216p326p436b246p656p766p876r107n117b127q137k147r277");
}

