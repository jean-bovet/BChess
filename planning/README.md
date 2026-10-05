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
