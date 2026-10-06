#  BChess

BChess is an open-source chess app for iPhone, iPad and Mac. Its engine is written in C++ with a bitboard representation; the app is written in SwiftUI. A command-line UCI engine, `BChessUCI`, ships from the same code. The app is a work in progress: see what remains to be done below.

<p>
  <img src="markdown/ios.png" alt="BChess on iPhone with the engine readout on" width="280">
  <img src="markdown/macos.png" alt="BChess on the Mac in dark mode, with the move list beside the board" width="560">
</p>

## Features

- All the rules of chess, including castling, en passant and promotion. Checkmate, stalemate and draw by threefold repetition end the game.
- Play against the computer or a friend, or watch the computer play itself. The computer thinks for 2, 5, 10 or 15 seconds a move and plays from a small opening book.
- A simple game screen: the board, the two players, one status line and the moves. On iPhone the last moves sit in a strip under the board, and every move, with variations and comments, is one tap away. On the Mac and on iPad in landscape the full move list sits beside the board.
- An Engine button that shows who stands better, the evaluation and the best line, including on your own turn (analysis stops after 10 seconds).
- Back and forward through the game and its variations from the toolbar, or with ← → and ⌘← ⌘→ on the Mac.
- Copy a game (PGN) or a position (FEN), and paste either. On the Mac these are in the Edit menu (⌘C, ⌥⌘C, ⌘V); on iPhone and iPad in the ⋯ menu, with Share.
- On the Mac, Analyze Game and Practice Openings in the Game menu.
- Games are saved as `.bchess` files (JSON). Older `.json` games and PGN files still open; for a PGN file with several games, the Mac's Game menu picks the game.
- On the Mac each game is a document. On iPhone and iPad the app opens on the last game and keeps all games in a Games list, stored in the app's Documents folder (visible in Files), with Import, Share (standard PGN) and delete.
- Light and dark mode.

## Building

Requires Xcode 26 or later. The app targets iOS 18 and macOS 15.

The Xcode project is generated from `project.yml` with [XcodeGen](https://github.com/yonaskolb/XcodeGen); after changing `project.yml`, run `xcodegen generate` and commit the project with it.

| Scheme | What it builds | Tests |
| --- | --- | --- |
| `BChess (iOS)` | iPhone and iPad app | UI test: new game, play e4, the engine replies |
| `BChess (macOS)` | Mac app | Engine tests (GoogleTest cases run as Swift Testing cases) and app-logic tests |
| `BChessUCI` | UCI command-line engine | Covered by a test in the macOS scheme |

```
xcodebuild test -scheme "BChess (macOS)" -destination 'platform=macOS'
xcodebuild test -scheme "BChess (iOS)" -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```

Continuous integration and TestFlight builds run on Xcode Cloud, whose workflows are configured in App Store Connect.

How changes are planned and reviewed is described in `AGENTS.md` and `planning/`.

## Layout

- `Shared/Engine/`: the chess engine, in portable C++
- `Shared/Bridge/`: the Objective-C++ bridge between the engine and Swift
- `Shared/`: the game model and the SwiftUI views shared by both apps
- `iOS/`, `macOS/`: each platform's app shell
- `BChess/`: the `BChessUCI` command-line tool
- `BChessTests/`, `BChessUITests/`: tests

## How BChess was built

BChess was written by hand from 2017 to 2022, then modernized with
[Claude Code](https://claude.com/claude-code) in October 2026. The git history shows which is which:
every commit made with Claude Code carries a `Co-Authored-By: Claude` trailer.

### By hand (2017–2022, 331 commits)

- **The chess engine**, in C++: bitboards with magic move generation, legal move generation with
  castling, en passant and promotion, alpha-beta search with iterative deepening, quiescence search,
  a transposition table, an evaluation with piece-square tables, and an opening book.
- **FEN and PGN** reading and writing, including comments and variations, and PGN files with several games.
- **The UCI command-line engine**, `BChessUCI`.
- **The apps**: the first macOS UI (2017) and an iOS UI (2018), then the 2021 SwiftUI rewrite for iPhone,
  iPad and Mac, with document-based games, the move list with variations, and the Analyze Game and
  Practice Openings modes.
- **The engine tests**: GoogleTest cases for move generation, check detection, PGN, openings, hashing and search.

### With Claude Code (October 2026)

Each change was planned, reviewed by Codex and implemented following the `/develop` process
(`AGENTS.md`, `planning/`).

- **Modernization (APP-1):** builds with current Xcode for iOS 26 / macOS 26 (the project had stopped
  building); XcodeGen; Swift 6; the engine tests, which had silently stopped running, run again as
  Swift Testing cases; a thread-safe engine bridge; an iOS app that opens straight onto the board with
  a Games library; the `.bchess` file type.
- **A simpler game screen (APP-2):** one status line, a move strip, an engine readout with analysis on
  the player's turn, a Game menu and Edit-menu copy and paste on the Mac, New Game in a new window.
- **Engine fixes (ENGINE-1):** six bugs found by a perft suite and a code review, among them castling
  rights kept after a rook capture, en passant corrupting the hash, quiescence returning the wrong score,
  and an inverted bishop-pair bonus. Perft now matches all six reference positions.
- **A match-ready UCI engine and a rating (ENGINE-2):** legal move parsing, mate distance, time control,
  hardening against malformed FEN, and `scripts/elo-match.sh`; first measurement 1736 ± 40 on
  Stockfish's UCI_Elo scale (see `docs/elo.md`).
- **Shipping:** Xcode Cloud builds and TestFlight for iOS and macOS, App Store icons and metadata.
- **Tests:** from 9 Swift tests (the 88 GoogleTest cases weren't running) to 166 engine test cases and
  145 app and UCI tests.

## Attributions
- [Magic Move-Bitboard Generation in Computer Chess, Pradyumna Kannan](http://pradu.us/old/Nov27_2008/Buzz/research/magic/Bitboards.pdf)
- [Magic Move-Bitboard Generation Source Code](https://essays.jwatzman.org/essays/chess-move-generation-with-magic-bitboards.html)
- [Chess Evaluation](https://chessprogramming.wikispaces.com/Evaluation)

## What remains to be done

- Wrap saved PGN at 80 characters per line
- Copy the move history, not just a reference to it, when a game is copied (see the workaround in `FEngineInfo.mm`)
- Add the 50-move rule
- Add a heuristic that gives a bonus when the king is safely behind its row of pawns after castling
- Add more openings: the opening book names only a few lines, so most games show no opening name
- Finish the transposition table, available today as "Use Transposition Table (Beta)" in the Mac's Settings ([background](http://www.chessbin.com/post/Transposition-Table-and-Zobrist-Hashing), [more](https://chessprogramming.wikispaces.com/Transposition+Table))
- Pick a game from a multi-game PGN file on iPhone and iPad
- [Optimization](https://people.cs.clemson.edu/~dhouse/courses/405/papers/optimize.pdf)
