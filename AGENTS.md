# AGENTS.md — working agreement for BChess

Process: `.claude/skills/develop/`. Plans: `planning/`.

Open-source chess app: a C++ bitboard engine with a SwiftUI front end for iOS and macOS, plus a
UCI command-line tool.

**Layout.** `Shared/Engine/` — the C++ engine (portable C++, no Apple frameworks).
`Shared/Bridge/` — Objective-C++ wrapper (`FEngine*`) that Swift sees through the bridging header.
`Shared/` — SwiftUI views and game model compiled by both apps. `iOS/` and `macOS/` — per-platform
shells and Info.plists. `BChess/` — the `BChessUCI` command-line tool. `BChessTests/` — engine
tests (GoogleTest cases plus Swift tests). `Dependencies/gtest` is vendored; do not edit.
`project.yml` — XcodeGen; never hand-edit `BChess.xcodeproj` (edit the spec, `xcodegen generate`,
commit both).

**Invariants.** A violation is always wrong:

- **I1 — Files keep opening.** Every game file an earlier BChess wrote (`.json` with the
  `GameState` shape, `.pgn`) still opens, and PGN written by BChess stays standard PGN. The one
  exception is a game whose moves are illegal chess that only an engine bug let BChess accept
  (ENGINE-1: castling after the rook was captured on its corner, or with castling rights a FEN
  claimed without king and rook in place); BChess had not shipped when that was fixed, so such
  files can exist only on the developer's own devices.
- **I2 — A search result only lands on the position it was computed for.** Once the position
  changes (move, undo, new game, paste, navigation, mode change), no callback from an earlier
  search may change the game. The main thread never waits on a search.
- **I3 — The engine stays portable.** `Shared/Engine/` compiles as plain C++ with no Apple
  headers, so it can be built and tested standalone.
- **I4 — The UCI tool keeps working.** `BChessUCI` reads stdin on its main thread; engine
  callbacks must not require the main queue to be serviced.
- **I5 — Private and offline.** No network access, analytics or accounts.

**Stack.** SwiftUI, Swift 6 language mode, Observation (`@Observable`), Swift Testing for new
tests. iOS 18 / macOS 15 minimum, built and tested with the current Xcode against the iOS 26 /
macOS 26 SDKs.

**How work is done.** Engine, bridge, model and app-logic changes go through `/develop` even
without the slash command. Docs-only changes (`planning/`, `AGENTS.md`, a skill) may land on
`main`. Landing is Jean's call. No version bumps during feature work. On Claude Code, planning runs
in a `general-purpose` subagent with `model` omitted, implementation and fix rounds in a subagent
launched with `model: "sonnet"`, and reviews in Codex (a fresh read-only `model: "opus"` subagent
when Codex is unavailable). The parent never implements.

**Done when.** The test and warning gates in `/develop` are green, including every engine
GoogleTest case actually executed.

**Tests.** New logic: a failing Swift Testing test first. Views are exempt from unit tests; every
new view gets a `#Preview`. A thread-safety fix gets a test that would fail (or hang) without it.

**Conventions.** English UI strings, code, identifiers and comments. New Swift code states
isolation (`@MainActor` / `nonisolated` / `@Sendable`). Match the surrounding style. Commit when
asked.
