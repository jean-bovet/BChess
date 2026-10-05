#include <cstdio>
#include <chrono>
#include "ChessEngine.hpp"
#include "FFEN.hpp"

static uint64_t perft(ChessBoard &board, int depth) {
    MoveList moves = ChessMoveGenerator::generateMoves(board);
    if (depth == 1) return moves.count;
    uint64_t n = 0;
    for (int i = 0; i < moves.count; i++) {
        ChessBoard next = board;
        next.move(moves.moves[i]);
        n += perft(next, depth - 1);
    }
    return n;
}

struct Case { const char *name; const char *fen; std::vector<uint64_t> expected; };

int main() {
    ChessEngine::initialize();
    std::vector<Case> cases = {
        {"start", "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1", {20, 400, 8902, 197281, 4865609}},
        {"kiwipete", "r3k2r/p1ppqpb1/bn2pnp1/3PN3/1p2P3/2N2Q1p/PPPBBPPP/R3K2R w KQkq - 0 1", {48, 2039, 97862, 4085603}},
        {"pos3", "8/2p5/3p4/KP5r/1R3p1k/8/4P1P1/8 w - - 0 1", {14, 191, 2812, 43238, 674624}},
        {"pos4", "r3k2r/Pppp1ppp/1b3nbN/nP6/BBP1P3/q4N2/Pp1P2PP/R2Q1RK1 w kq - 0 1", {6, 264, 9467, 422333}},
        {"pos5", "rnbq1k1r/pp1Pbppp/2p5/8/2B5/8/PPP1NnPP/RNBQK2R w KQ - 1 8", {44, 1486, 62379, 2103487}},
        {"pos6", "r4rk1/1pp1qppp/p1np1n2/2b1p1B1/2B1P1b1/P1NP1N2/1PP1QPPP/R4RK1 w - - 0 10", {46, 2079, 89890, 3894594}},
    };
    int failures = 0;
    for (auto &c : cases) {
        ChessBoard board;
        if (!FFEN::setFEN(c.fen, board)) { printf("%s: FEN rejected\n", c.name); failures++; continue; }
        for (size_t d = 0; d < c.expected.size(); d++) {
            auto t0 = std::chrono::steady_clock::now();
            uint64_t n = perft(board, (int)d + 1);
            double ms = std::chrono::duration<double, std::milli>(std::chrono::steady_clock::now() - t0).count();
            bool ok = n == c.expected[d];
            if (!ok) failures++;
            printf("%-9s d%zu %10llu expected %10llu %s  (%.0f ms, %.1f Mnps)\n", c.name, d + 1, (unsigned long long)n,
                   (unsigned long long)c.expected[d], ok ? "OK" : "MISMATCH", ms, ms > 0 ? n / ms / 1000 : 0);
            if (!ok) break;
        }
    }
    printf("failures: %d\n", failures);
    return failures;
}
