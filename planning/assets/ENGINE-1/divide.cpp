#include <cstdio>
#include <string>
#include "ChessEngine.hpp"
#include "FFEN.hpp"
#include "FPGN.hpp"
static uint64_t perft(ChessBoard &b, int d) { MoveList m = ChessMoveGenerator::generateMoves(b); if (d == 1) return m.count; uint64_t n = 0; for (int i = 0; i < m.count; i++) { ChessBoard x = b; x.move(m.moves[i]); n += perft(x, d - 1); } return n; }
static std::string uci(Move mv) {
    std::string s = FPGN::to_string(mv, FPGN::SANType::uci);
    for (auto &c : s) c = tolower(c);
    if (MOVE_PROMOTION_PIECE(mv) != PAWN && s.size() == 4) { const char *p = "pnbrqk"; s += p[MOVE_PROMOTION_PIECE(mv)]; }
    return s;
}
int main(int argc, char **argv) {
    ChessEngine::initialize();
    ChessBoard b; FFEN::setFEN(argv[1], b); int d = atoi(argv[2]);
    for (int a = 3; a < argc; a++) {  // replay a path of moves inside the engine
        MoveList m = ChessMoveGenerator::generateMoves(b); bool found = false;
        for (int i = 0; i < m.count; i++) if (uci(m.moves[i]) == argv[a]) { b.move(m.moves[i]); found = true; break; }
        if (!found) { printf("path move %s not generated\n", argv[a]); return 1; }
    }
    fprintf(stderr, "engine FEN: %s\n", FFEN::getFEN(b).c_str());
    MoveList m = ChessMoveGenerator::generateMoves(b);
    for (int i = 0; i < m.count; i++) { ChessBoard x = b; x.move(m.moves[i]); printf("%s %llu\n", uci(m.moves[i]).c_str(), (unsigned long long)(d > 1 ? perft(x, d - 1) : 1)); }
}
