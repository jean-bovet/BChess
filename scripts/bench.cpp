// Developer tool: a fixed-depth search benchmark for Shared/Engine, built and run by scripts/bench.sh.
// It is not part of the app and not part of the engine, so it may use Apple headers (behind __APPLE__).
//
// Environment: DEPTH (default 6), TT=0|1 (transposition-table cut-offs, default 0).
//
// Prints one "pos" line per position (index, nodes, score, best move), then "signature" (a hash over
// every position's tuple, and the total nodes) and "cost" (retired instructions, cycles, CPU time and
// the maximum resident size of the whole run). The "pos" and "signature" lines do not depend on load;
// "cost" lines are for scripts/bench.sh to compare.

#include <cstdio>
#include <cstdlib>
#include <ctime>
#include <string>
#include <vector>
#include <sys/resource.h>

#ifdef __APPLE__
#include <libproc.h>
#include <unistd.h>
#endif

#include "ChessEngine.hpp"
#include "FFEN.hpp"
#include "FPGN.hpp"
#include "FUtility.hpp"

namespace {

struct Position {
    const char *name;
    const char *fen;
    // UCI moves played from the start position through ChessGame, so that the search gets a real history.
    const char *game;
};

// A 130-ply game of mostly quiet random moves (a fixed-seed generator), so that the history holds 131
// positions when the search starts.
const char *LongGame =
    "c2c3 b7b5 g1f3 h7h6 b2b4 c8b7 e2e4 g7g5 h2h3 b8c6 h3h4 e7e6 d1a4 c6e7 d2d3 d8b8 g2g3 f7f6 a2a3 e8d8 "
    "a4a6 h8h7 c1e3 h7f7 a6a5 e7c6 f3e5 f6f5 e1d1 f7g7 a5a6 d8c8 h4h5 c6d4 a6c6 d4c2 e5g4 d7d6 c6a6 c2e1 "
    "a3a4 d6d5 h1h4 d5d4 f1h3 g7h7 a6b6 g8e7 d1c1 a7a5 h3f1 e1f3 h4h1 c7c6 e3d2 e6e5 b6a7 h7f7 c1c2 f7h7 "
    "h1g1 h7g7 d2e3 e7g6 f1h3 b8c7 b1d2 g7e7 a1e1 e7g7 c2b3 g7h7 a7b6 c6c5 b6d6 g6h4 d6g6 h4g2 g1f1 h7g7 "
    "e1b1 c8d7 f1d1 f3h4 g6e6 d7d8 e6d7 g7d7 d1e1 a8a7 b1d1 f5f4 f2f3 f8e7 e1g1 b7a8 b3a2 c5c4 d2f1 e7c5 "
    "f1d2 c5d6 d1f1 d7g7 f1d1 h4f5 d1c1 c7d7 a2a3 d7c6 e3f2 g2h4 c1c2 d8e7 g1h1 c6c7 g4e3 a8c6 d2b1 c6d7 "
    "h1f1 g5g4 e3d5 e7e6 a3a2 g7e7 d5e3 a7a6 b1a3 c7a7";

const Position Positions[] = {
    {"start", "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1", nullptr},
    {"kiwipete", "r3k2r/p1ppqpb1/bn2pnp1/3PN3/1p2P3/2N2Q1p/PPPBBPPP/R3K2R w KQkq - 0 1", nullptr},
    {"pos3", "8/2p5/3p4/KP5r/1R3p1k/8/4P1P1/8 w - - 0 1", nullptr},
    {"pos4", "r3k2r/Pppp1ppp/1b3nbN/nP6/BBP1P3/q4N2/Pp1P2PP/R2Q1RK1 w kq - 0 1", nullptr},
    {"pos5", "rnbq1k1r/pp1Pbppp/2p5/8/2B5/8/PPP1NnPP/RNBQK2R w KQ - 1 8", nullptr},
    {"pos6", "r4rk1/1pp1qppp/p1np1n2/2b1p1B1/2B1P1b1/P1NP1N2/1PP1QPPP/R4RK1 w - - 0 10", nullptr},
    {"italian", "r1bqkb1r/pppp1ppp/2n2n2/4p3/2B1P3/5N2/PPPP1PPP/RNBQK2R w KQkq - 4 4", nullptr},
    {"endgame", "8/pp3k2/2p2p2/3p4/3P1P2/2P3K1/PP6/8 w - - 0 1", nullptr},
    {"history", nullptr, LongGame},
};

struct Cost {
    uint64_t instructions = 0;
    uint64_t cycles = 0;
    double cpuMilli = 0;
};

Cost now() {
    Cost cost;
    struct timespec ts;
    clock_gettime(CLOCK_PROCESS_CPUTIME_ID, &ts);
    cost.cpuMilli = ts.tv_sec * 1000.0 + ts.tv_nsec / 1e6;
#ifdef __APPLE__
    struct rusage_info_v4 info;
    if (proc_pid_rusage(getpid(), RUSAGE_INFO_V4, (rusage_info_t *)&info) == 0) {
        cost.instructions = info.ri_instructions;
        cost.cycles = info.ri_cycles;
    }
#endif
    return cost;
}

}

int main() {
    const char *depthText = getenv("DEPTH");
    const char *ttText = getenv("TT");
    int depth = depthText ? atoi(depthText) : 6;
    bool tt = ttText && atoi(ttText) != 0;

    ChessEngine::initialize();

    uint64_t signature = 1469598103934665603ULL; // FNV-1a
    auto mix = [&signature](uint64_t value) {
        for (int shift = 0; shift < 64; shift += 8) {
            signature ^= (value >> shift) & 0xff;
            signature *= 1099511628211ULL;
        }
    };

    int64_t totalNodes = 0;
    int index = 0;
    Cost total;
    for (auto &position : Positions) {
        // A fresh engine for every position: no table, history or killers carried over
        ChessEngine engine;
        if (position.fen) {
            if (!engine.setFEN(position.fen)) {
                printf("%s: FEN rejected\n", position.name);
                return 1;
            }
        } else {
            std::vector<std::string> moves;
            split4(position.game, moves);
            for (auto &uci : moves) {
                if (!engine.move(uci)) {
                    printf("%s: move %s rejected\n", position.name, uci.c_str());
                    return 1;
                }
            }
        }
        auto &game = engine.game();
        ChessBoard board = game.board;
        HistoryPtr history = std::make_shared<std::vector<BoardHash>>(*game.history);

        ChessEvaluation result;
        Cost before = now();
        engine.iterativeSearch.start();
        engine.searchBestMove(board, history, depth, tt, [&result](ChessEvaluation info, bool finished) {
            if (finished) result = info;
        });
        Cost after = now();

        Move best = result.line.bestMove();
        std::string bestText = MOVE_ISVALID(best) ? FPGN::to_string(best, FPGN::SANType::uci) : "none";
        printf("pos %d %-9s nodes %-9lld score %-7d best %s\n", index, position.name, (long long)result.nodes, result.value, bestText.c_str());
        printf("cost %d %-9s instructions %llu\n", index, position.name, (unsigned long long)(after.instructions - before.instructions));

        mix(index);
        mix((uint64_t)result.nodes);
        mix((uint64_t)(int64_t)result.value);
        for (char c : bestText) mix((uint64_t)c);
        totalNodes += result.nodes;
        total.instructions += after.instructions - before.instructions;
        total.cycles += after.cycles - before.cycles;
        total.cpuMilli += after.cpuMilli - before.cpuMilli;
        index++;
    }

    struct rusage usage;
    getrusage(RUSAGE_SELF, &usage);
#ifdef __APPLE__
    double maxRSSMB = usage.ru_maxrss / (1024.0 * 1024.0); // bytes on macOS
#else
    double maxRSSMB = usage.ru_maxrss / 1024.0; // kilobytes elsewhere
#endif
    printf("signature %016llx nodes %lld depth %d tt %d\n", (unsigned long long)signature, (long long)totalNodes, depth, tt ? 1 : 0);
    printf("cost total instructions %llu cycles %llu cpu_ms %.0f max_rss_mb %.1f\n",
           (unsigned long long)total.instructions, (unsigned long long)total.cycles, total.cpuMilli, maxRSSMB);
    return 0;
}
