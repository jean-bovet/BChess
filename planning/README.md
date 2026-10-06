# Planning — forward-looking proposals

This folder holds **planning proposals**: work not yet closed, written for review before
implementation. Each doc states a problem (with code evidence), a design, alternatives, a test
plan, the invariants it touches (`AGENTS.md`), risks, and the **decision left open** for Jean.

Areas: `APP` (screens, game model, platform shells), `ENGINE` (C++ engine and the Objective-C++
bridge), `OPS` (project, CI, signing, distribution).

## Active

| Spec | Question | Status |
|------|----------|--------|
| [APP-1](APP-1-modernize-ios26.md) | Modernize for iOS 26 / macOS 26: XcodeGen, engine tests that run, thread-safe engine, GameState/GameSession split, iOS app shell, Swift 6, CI | Implemented on main 2026-10-05 (plan r4; Codex plan rounds 1–3, code rounds 1–3). Owed: first CI run on GitHub; Mac checks (old .json/.pgn open from Finder, Edit > Undo/Redo/Revert); iPhone checks (upgrade keeps games, Files, Share, Open in BChess) |
| [APP-2](APP-2-simple-game-screen.md) | A simpler game screen on iPhone and Mac: players as title, one status line, move strip, engine readout as a button (analysis on the player's turn), back/forward merged, Mac Game and Edit menus, New Game opens a window ([approved design](assets/APP-2-review.html)) | Implemented on main 2026-10-05 (plan r3; Codex plan rounds 1–2, code rounds 1–2). Owed: Mac checks (player-name field ←/→ and ⌘A/C/X/V, ⌘C/⌥⌘C/⌘V in the game window, arrow navigation, ⌘E, New Game window with players sheet), iPad wide layout seen running, smallest-iPhone layout, touch-and-hold Back/Forward |
| [ENGINE-1](ENGINE-1-engine-bugs-and-perft.md) | Engine bug fixes proven by perft: castling rights lost when a rook is captured, en-passant hash, castling/ep in the hash (TT and repetition), quiescence best score, bishop-pair sign, PGN round-trip of the engine's own output, `setFEN` state leak ([perft tools](assets/ENGINE-1/)) | Plan, revision 4 — Jean's go 2026-10-06 |
| [ENGINE-2](ENGINE-2-uci-and-elo.md) | A match-ready `BChessUCI` (legal UCI move parsing incl. promotion/en passant, validated transactional FEN parsing, promotion letter in `bestmove`, mate scores with distance, cumulative search statistics, clock/movetime/depth time management, clean stdout, all-or-nothing `position`, `ucinewgame`) and an Elo measurement against Stockfish `UCI_Elo` with fastchess (`scripts/elo-match.sh`, `docs/elo.md`) | Plan, revision 4 — awaiting Jean's go (Codex plan rounds 1–3 exhausted; after ENGINE-1) |
