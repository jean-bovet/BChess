# APP-1 — Modernize BChess for iOS 26 / macOS 26

Revision 4 (2026-10-05). Codex plan-review rounds are exhausted (3 of 3). The revision-4 changes
below are not reviewed by Codex; the phase-5 implementation review covers them.

- Revision 1: initial plan.
- Revision 2: folds in Codex plan review round 1.
  - Every position-changing bridge method now invalidates the running search.
  - Callbacks are delivered under the bridge lock, which closes the window between the check and
    the callback; the guarantee each layer makes is stated in §2.3.
  - Inline searches go through the same serial queue.
  - Paste goes through a probe engine, so a failed paste leaves the game alone.
  - Three C++ bugs are fixed: `setCurrentMoveUUID` now replays the board, `loadAllGames` is atomic
    on failure, and the PGN writer emits `[SetUp "1"]`.
  - The session splits search invalidation from persisted-PGN updates, which stops navigation from
    dirtying the document.
  - An `animate` hook keeps computer-vs-computer play going.
  - Player edits invalidate the running search.
  - The unused `positionalAnalysis` knob is deleted.
  - Autosave errors are surfaced to the user.
  - The snapshot fix is checked with a Thread Sanitizer test run.
  - `GTestRunner` reuses the mechanics of `GoogleTests.mm`.
  - Rejected findings and their rationale: §3.
- Revision 3: folds in Codex plan review round 2.
  - A UCI `stop` that arrives before the search is armed is recorded for that generation and
    honored at arming. A stop never aborts depth 1, so `bestmove` is always a real move.
  - `loadAllGames` refuses a parse that yields no game.
  - Navigation now rebuilds the repetition history, and whether the engine may play is decided
    from the current position, not from the stored game result.
  - Selecting a move resolves its full path from the root, so moves on other branches can be
    selected.
  - Animation completions check the position token.
  - A failed autosave blocks switching games until the user confirms. That logic moves into a
    testable `GameShell` model.
  - A UCI subprocess test, controlled interleavings through a private test-only queue hook, and CI
    warning and gtest-count gates.
  - `Game` keeps its name and no files move.
  - The macOS undo claim is scoped down: what is guaranteed, and what is a manual check (§6).
- Revision 4: folds in Codex plan review round 3 (move path stays valid on navigation; switching
  always saves first; delete order; no TT store after a cut-short loop; test-only search checkpoint
  for TSan; a real threefold test; one partial rejection in §3).

Jean's approved scope: raise the deployment targets and fix the file types; make the engine tests
run; give iOS a normal app shell (the macOS app stays document-based); fix the engine concurrency
races and the "struct document holding a reference engine" problem; move to Swift 6, Observation and
current SwiftUI; add document, action, cancellation and UI-flow tests plus CI.

Eight steps, one commit each (§Steps). Each step leaves the tree building and its tests green. The
GoogleTest-count gate applies from step 2 on, because step 1 only reproduces today's test wiring.

---

## 1. Problem, with evidence

**Build.** `BChess.xcodeproj` is a hand-maintained pbxproj (objectVersion 48) with deployment targets
iOS 14.0/14.3, macOS 10.13/11.0/11.1 and `$(RECOMMENDED_MACOSX_DEPLOYMENT_TARGET)`. Xcode 27 rejects
all of these. With iOS 17 / macOS 14 overrides both apps build. The only warning is the deprecated
`onChange(of:perform:)` at `Shared/Views/PiecesView.swift:147`. C++ is `gnu++14` and Swift is 5.0.
`Shared/Bridge/FEngineMove.swift` imports Cocoa and belongs to no target, so it is dead code.
`Tests iOS/` and `Tests macOS/` hold only the Xcode template tests.

**Tests never run.** Only `BChess (macOS)` has a shared scheme, and its only testable is
`Tests macOS.xctest`. `BChessTests` is in no shared scheme. Even when it runs, only the 9 Swift
XCTests execute (`BChessTests/FEngineTests.swift`, `BChessTests/GamesTests.swift`). The 88
GoogleTest cases in `BChessTests/*.cpp` (8+9+3+18+8+24+8+2+2+6) are registered by
`BChessTests/Helper/GoogleTests.mm:181-190`, which waits for `NSBundleDidLoadNotification`.
Current xctest never posts it, so no class is registered. I re-verified: compiled standalone with
`clang++ -std=c++20` (gtest-all.cc, all engine sources, a `main` setting
`UnitTestHelper::pathToResources` to `BChess/`), all **88 pass** in about 1.8 s. From step 3 that
command also passes `-DBCHESS_TEST_HOOKS=1`, which the checkpoint gtest needs (§2.3). The only
`-Wall` warning in our own code is `Shared/Engine/Engine/ChessOpenings.cpp:35` (unused lambda
capture).

**File types.**
- `macOS/Info.plist` *imports* Apple's system `public.json` as plain text, but never declares
  `ch.arizona-software.chess.json`, the type its own document type lists.
- `iOS/Info.plist` declares that type as *imported* and claims the `.json` extension.
- `Shared/ChessDocument.swift:13` defines `static var json` on `UTType`, which shadows Apple's
  `UTType.json`.
- PGN uses `com.apple.chess.pgn`, which Apple's Chess.app owns on macOS.
- The iOS plist still has `UIRequiredDeviceCapabilities = armv7` and `UISupportsDocumentBrowser`.
- Saved games are `.json` files in the `GameState` shape `{pgn, rotated, white?, black?}`
  (`Shared/ChessDocument.swift:22-27`). I1 requires them to keep opening.

**Engine races (I2, I4).**
- `FEngine.mm:305-311` dispatches the search to a *concurrent* global queue. From there,
  `ChessEngine::searchBestMove` (`ChessEngine.hpp:163-173`) reads `game().board` and the shared
  `HistoryPtr`, a `shared_ptr<vector>` that `ChessGame` copies share. `MinMaxSearch` calls
  `push_back`/`pop_back` on that history during the search (`MinMaxSearch.hpp:193,200,273,279`)
  while the main thread moves, undoes or pastes on the same game.
- `infoFor:` (`FEngine.mm:266-271`) copies `engine.game()` on the background thread.
- `IterativeDeepening::status` (`IterativeDeepening.hpp:54`) and `MinMaxSearch::analyzing`
  (`MinMaxSearch.hpp:58`) are plain fields that `stop`/`cancel` write from other threads.
- The public `MinMaxSearch::alphabeta` sets `analyzing = true` at every iterative depth
  (`MinMaxSearch.hpp:78`), so a cancel that lands between the depth check and that line is lost
  for a whole depth.
- The time-limit timer (`FEngine.mm:299-303`) calls `stop` on whatever search is running when it
  fires, which can be a later search.
- A new `evaluate` cancels and immediately dispatches another search to the concurrent queue, so two
  searches can run on the same `iterativeSearch` object.
- On the Swift side, `PiecesView.swift:89-97` plays a completed result with no staleness check. The
  `stateIndex` guard in FEngine only gates the never-assigned `updateCallback` (`FEngine.mm:59-67`;
  no Swift code sets it).
- `ChessEvaluater::positionalAnalysis` is a global static that the background thread writes on every
  search (`FEngine.mm:331`).
- `ChessEngine::initialize()` rewrites the global move tables whenever it is called. The gtest
  fixtures call it from `SetUp` (`BestMoveTests.cpp:19`). That is a race once Swift engine tests run
  in parallel with the gtest suite.
- The UCI tool (`BChess/UCI/UCI.swift:173-190`) blocks the main thread in `readLine` and prints from
  the search callback. Callbacks therefore must never require the main queue (I4).
- The position-changing bridge methods (`setFEN`, `setPGN`, `loadAllGames`, both `move` overloads,
  `setCurrentGameIndex`, `setCurrentMoveNodeUUID`; `FEngine.mm:89-170,204-213`) do not cancel a
  running search. Only `moveTo:variation:` does (`:233`). UCI's `position` command
  (`UCI.swift:49-67`) does not cancel either.

**Engine correctness, found while planning (verified in code).**
- `ChessGame::setCurrentMoveUUID` (`ChessGame.hpp:179-187`) moves only the cursor and never calls
  `replayMoves()`. When you tap an earlier move in the move list, the pieces look right, because
  `getState` replays (`ChessGame.cpp:198-213`). But `board` stays stale, and with it the FEN, the
  legal moves, side-to-move and the search position.
- `ChessGame::setFEN` resets the game before parsing (`ChessGame.cpp:31-37`), and so does
  `FPGN::setGame` (`FPGN.cpp:716-717`). A failed paste therefore destroys the current game.
- `ChessEngine::loadAllGames` clears `games` before parsing (`ChessEngine.hpp:60-63`), so a failed
  load leaves `game()` indexing an empty vector.
- `FPGN::setGames` returns true on empty text without adding a game (`FPGN.cpp:765-775`). So
  `loadAllGames("")` succeeds with zero games, and `game()` then indexes `games[0]`.
- `ChessGame::replayMoves()` (`ChessGame.cpp:188-196`) rebuilds `board` but not `history`. After
  navigating back, the threefold-repetition history still holds the later positions.
- `outcome` is the game *result*. The parser sets it from the termination marker
  (`FPGN.cpp:347-370`), `move()` sets it on mate or stalemate (`ChessGame.cpp:109-123`), and the
  writer emits it as the PGN result (`FPGN.cpp:996`). Navigation does not change it, so
  `canPlay()` (`ChessEngine.hpp:131-133`) stays false on every earlier position of a finished
  game.
- `setCurrentMoveUUID` only searches the current `moveIndexes` path (`ChessGame.hpp:179-187`).
  The move list shows every variation (`InformationView.swift:77-82`), so tapping a move on another
  branch does nothing.
- `ChessGame::moveTo(.backward/.start)` calls `MoveIndexes::resetToMainVariation()`
  (`ChessGame.cpp:146-166`, `ChessGame.hpp:45-49`), which zeroes the path but keeps its length.
  On a branch longer than the main line (`1. e4 e5 (1... c5 2. Nf3 d6) *`, cursor on `d6`), one
  step back replays `[0,0,0]` past the main line's leaf and hits the assert in `MoveNode::visit`
  (an out-of-bounds read in release). `.forward` with a different variation index and `move()`
  in the middle of a line (`MoveIndexes::add`) leave a stale tail the same way, so `.forward` or
  `.end` can walk off the tree.
- `MinMaxSearch::alphabeta` stores a transposition entry after its move loop even when a cancel
  ended that loop early (`MinMaxSearch.hpp:165,220-225`). The entry carries the full requested
  depth and can be `EXACT`. `IterativeDeepening::table` is never cleared, so the next search of
  the same position trusts that partial value.
- `FPGN::getGame` writes `[Setup "1"]` (`FPGN.cpp:958`). The PGN standard tag is `SetUp`. The
  reader only looks at the `FEN` tag (`FPGN.cpp:709`).

**Model.**
- `ChessDocument` (`Shared/ChessDocument.swift:65`) is a `FileDocument` struct that holds
  `let engine = FEngine()` (a reference) plus UI state: `selection`, `lastMove`, `info`,
  `variations`, `mode`, `engineShouldMove`, and `game`, an `ObservableObject`.
- As a result, selecting a square writes the document binding, document copies share one engine, and
  engine-only mutations (navigation at `Actions.swift:94-130`) never mark anything.
- `loadOpenings()` re-reads and re-parses `Openings.pgn` for every document (`ChessDocument.swift:129-138`).
- Every view takes `@Binding var document: ChessDocument`. `Actions` (`Shared/Actions.swift`) is a
  struct that only forwards to that binding.
- `applyEngineSettings()` (`ChessDocument.swift:180-195`) runs *before* the move in both
  `playMove`s (`PiecesView.swift:109,118`), so it picks the level of the side that just moved, not
  the engine's side. That is a latent bug.
- The README lists "unable to have read-only document (it always want to write it back)".

**Views.** `Model/Square.swift:12-14` gives every empty square a fresh `UUID()` on each render, so
SwiftUI rebuilds those squares every time. There are 11 `presentationMode` uses, 14
`PreviewProvider`s, and one `NavigationView` (`NewGameView_iOS.swift:45`). `Animation.swift` is the
`onAnimationCompleted` workaround that `PiecesView.swift:28,50,97,152` uses to start the engine after
a move animation.

**iOS shell.** `BChessUIApp.swift:14` uses `DocumentGroup` on both platforms, so iOS launches into the
document browser and its "Create Document" flow instead of a game.

## 2. Design

### 2.1 Project: XcodeGen (step 1)

Add `project.yml` in the style of the other XcodeGen-based apps, run
`xcodegen generate`, and commit both. Delete the hand-written pbxproj and the user-data scheme
plist (`xcuserdata/`, which `.gitignore` should already cover).

- `options`: `deploymentTarget: {iOS: "18.0", macOS: "15.0"}`, `createIntermediateGroups: true`.
- `settings.base`:
  - `SWIFT_VERSION: "5.0"` in step 1 (it becomes `"6.0"` in step 7).
  - `CLANG_CXX_LANGUAGE_STANDARD: c++20`, `CLANG_CXX_LIBRARY: libc++`.
  - `CODE_SIGN_STYLE: Automatic` (the team comes from a git-ignored `Signing.local.xcconfig`).
  - `HEADER_SEARCH_PATHS: [$(SRCROOT)/Shared/Engine/**, $(SRCROOT)/Shared/Bridge]`.
  - `GENERATE_INFOPLIST_FILE: NO`.
  - `MARKETING_VERSION` and `CURRENT_PROJECT_VERSION` copied from the current pbxproj. This is not
    a bump.
- An `engine` source list (YAML anchor) shared by every target that compiles the engine:
  `Shared/Engine` (all `.cpp`, `.hpp`, `magicmoves.c/.h`) and `Shared/Bridge` (`.mm`, `.h`).
- Targets:

| Target | Type / platform | Sources | Notes |
|---|---|---|---|
| `BChess (iOS)` | application / iOS | `Shared` (excludes `Engine`, `Bridge`), engine list, `iOS`, `BChess/UCI/FENgineInfo+Extension.swift`; resources `BChess/Openings.pgn`, `Shared/Assets.xcassets` | `PRODUCT_NAME: BChess`, `PRODUCT_BUNDLE_IDENTIFIER: ch.arizona-software.BChess`, `INFOPLIST_FILE: iOS/Info.plist`, bridging header `BChess/BChess-Bridging-Header.h`, `TARGETED_DEVICE_FAMILY: "1,2"` |
| `BChess (macOS)` | application / macOS | same as iOS but `macOS` instead of `iOS` | `macOS/macOS.entitlements`, `ENABLE_HARDENED_RUNTIME: YES` |
| `BChessUCI` | tool / macOS | `BChess/main.swift`, `BChess/UCI`, engine list | same bridging header |
| `BChessTests` | bundle.unit-test / macOS, **no host** | `BChessTests`, engine list, `BChess/UCI/UCI.swift`, `BChess/UCI/FENgineInfo+Extension.swift`; resource `BChess/Openings.pgn`. From step 5 also `Shared/Model`, `Shared/Game.swift`, `Shared/FullMove.swift`, `Shared/PiecesFactory.swift` | `HEADER_SEARCH_PATHS` += `Dependencies/gtest/include`, `Dependencies/gtest`; bridging header `BChessTests/BChessTests-Bridging-Header.h` (step 2). From step 3, a build-only dependency on `BChessUCI`, for the subprocess test, and `GCC_PREPROCESSOR_DEFINITIONS: [$(inherited), BCHESS_TEST_HOOKS=1]` (the search checkpoint, §2.3; set on no other target) |
| `Tests iOS` | bundle.ui-testing / iOS | `Tests iOS` | kept only until step 6 replaces it |

  `SettingsView.swift` is now compiled for iOS too (it is plain SwiftUI). It stays reachable only
  from the macOS `Settings` scene.
- Shared schemes (`schemes:` in the spec):
  - `BChess (macOS)`: build `BChess (macOS)`; test `BChessTests`.
  - `BChess (iOS)`: build `BChess (iOS)`; test `Tests iOS`, replaced by `BChessUITests` in step 6.
  - `BChessUCI`: build only.

  These are exactly the three commands in the `/develop` gate. CI uses them too (step 8).
- Delete `Tests macOS/` and its target. A macOS UI test needs accessibility permission, which fails
  headless and in CI. Delete `Shared/Bridge/FEngineMove.swift`, which is dead.
- Fix whatever new warnings C++20 and the Xcode 27 defaults raise in our own sources (expected:
  `ChessOpenings.cpp:35`). The `deprecated onChange` warning stays until step 5 rewrites that code.

### 2.2 GoogleTest cases as individual Swift Testing cases (step 2)

The `GoogleTests.mm` approach (dynamic XCTest classes created on a bundle-load notification) is what
broke. I replace it with **Swift Testing parameterized over the registered gtest names**. Each gtest
case shows up as its own test case in Xcode and in `xcodebuild` output, can be re-run on its own
(the String arguments are stable), and the run prints the count.

- `BChessTests/Helper/GTestRunner.h/.mm` (Objective-C++, replaces `GoogleTests.mm`). It reuses that
  file's mechanics by extracting them. Enumeration and `DISABLED_` filtering come from
  `GoogleTestLoader::registerTestClasses` (`:192-275`). Filtered execution and the
  exactly-one-test check come from `RunTest` (`:149-166`). Failure collection comes from
  `XCTestListener::OnTestPartResult` (`:64-81`), retargeted to return records instead of calling
  XCTest. Only the notification-dependent registration and the XCTest reporting are dropped.
  - `+ (NSArray<NSString*>*)testNames`: lazily, exactly once (`dispatch_once`), it sets
    `UnitTestHelper::pathToResources` from `[NSBundle bundleForClass:GTestRunner.class].resourcePath`,
    calls `testing::InitGoogleTest`, removes the default result printer, and returns every
    `Suite.Name` that is not `DISABLED_`.
  - `+ (NSArray<GTestFailure*>*)run:(NSString*)name`: sets `GTEST_FLAG(filter) = name`, appends a
    `testing::EmptyTestEventListener` that collects failed `TestPartResult`s (file, line, message),
    runs `RUN_ALL_TESTS()`, releases the listener, and returns the failures. If the filter did not
    run exactly one test, it returns a synthetic failure.
  - `GTestFailure` is a tiny `NS_SWIFT_SENDABLE` value object with `file`, `line` and `message`.
- `BChessTests/EngineGoogleTests.swift`:
  `@Suite(.serialized) struct EngineGoogleTests` containing
  - `@Test(arguments: GTestRunner.testNames()) func gtest(_ name: String)`, which maps each failure to
    `Issue.record(Comment(rawValue: f.message), sourceLocation: SourceLocation(fileID: "BChessTests/\(lastPathComponent)", filePath: f.file, line: max(1, f.line), column: 1))`;
  - `@Test func registersAllCases()`: `#expect(GTestRunner.testNames().count >= 88)`. This is the
    floor that turns "zero executed" into red.

  `.serialized` is required because gtest's `UnitTest` singleton, flags and listeners are not
  thread-safe. No other suite touches gtest.
- `BChessTests/BChessTests-Bridging-Header.h` imports `BChess/BChess-Bridging-Header.h` and
  `GTestRunner.h`.
- Port `FEngineTests` (2 tests) and `GamesTests` (7 tests) to Swift Testing, unchanged in substance.
  `GamesTests.assert` waits with `withCheckedContinuation` and resumes on `completed == true` only.
- Make `ChessEngine::initialize()` idempotent with a function-local `std::once_flag` /
  `std::call_once` (`ChessEngine.hpp:51-54`). The gtest fixtures call it from `SetUp` while Swift
  engine tests may be searching in parallel. Portable C++ (I3).

Rejected: (a) repairing `GoogleTests.mm` with an `__attribute__((constructor))` registration. It
depends on the order of static initializers versus `+load`, and it stays XCTest-only. (b) One Swift
test that runs all 88 and reports a single result. That is not individual cases.

### 2.3 Engine thread safety and correctness (step 3)

The goal is I2 and I4 together. Each search works on its own **snapshot**. Searches on one engine
**never overlap**, whether inline or async. Cancel and stop are **atomic**. A **generation number**
gates arming, the timer and delivery. Every position change invalidates the running search.

**What each layer guarantees.** This protocol is the contract the tests check.
- **Bridge (`FEngine`).** Once `cancel`, `evaluate…` or any position-changing method has
  *returned*, no callback from an earlier search is running, and none will start.
  - The search thread re-checks the generation and invokes the callback while holding `_control`.
  - Those methods bump the generation under `_control`.
  - The calling thread therefore waits at most for **one in-flight callback invocation**, never for
    a search. App callbacks only enqueue a main-queue block, and UCI callbacks only `print`.
  - Callbacks must not call `evaluate` again synchronously on the inline (`async == NO`) path,
    because that path holds the search queue. No caller does.
- **App (`GameSession`).** The bridge guarantee cannot cover a main-queue block that was already
  enqueued before the cancel. So a result is applied only if the `positionID` captured when the
  search was requested still equals the session's `positionID`. That comparison runs on the main
  actor at the moment the result would be applied, which makes it the **authority for I2 in the
  app**.
- **UCI** relies on the bridge guarantee alone. It processes commands serially on its main thread,
  and the bridge never touches the main queue (I4).

**C++ (`Shared/Engine`, stays portable):**
- `MinMaxSearch`: replace `bool analyzing` with `std::atomic<bool> stopRequested{false}`.
  - `cancel()` sets it to true; a new `resume()` sets it to false.
  - Loops test `!stopRequested.load(std::memory_order_relaxed)` (`:165`, `:264`).
  - The public `alphabeta` (`:77-83`) **no longer touches the flag**, which removes the lost-cancel
    window. The gtests that call `alphabeta` directly (`BestMoveTests.cpp:36`,
    `SearchChessTests.cpp:37`) keep working, because the default is "not stopped".
  - **No transposition entry from a cut-short loop.** After the move loop (`:220`), store only if
    `!stopRequested`: `if (isValid(bestMove) && !stopRequested.load(relaxed)) table.store(…)`.
    A node whose loop ran to completion before the stop still stores, because its children's
    values were complete. A node whose loop the stop ended stores nothing, and its partial value
    only travels up to parents that are also cut short, which store nothing either. The root's
    partial line is already discarded by `IterativeDeepening` (only completed depths count).
    Quiescence never stores. A loop that finished at the exact moment of the stop skips a valid
    store, which costs nothing but a re-search.
  - **Test-only search checkpoint.** Under `#ifdef BCHESS_TEST_HOOKS` only:
    `std::function<void()> checkpoint;` and, in the move loop right after
    `history->push_back(…)` (`:193`), `if (checkpoint) checkpoint();`. The define is set only on
    `BChessTests` (§2.1) and in the standalone gtest build command (§1), so the apps and UCI
    compile no hook and pay nothing. Plain C++, so I3 holds. It gives tests a point that is
    provably *inside* alpha-beta with the shared history modified: the gtest below uses it to
    cancel at an exact node, and the bridge tests use it to park the search thread.
- `IterativeDeepening`:
  - `std::atomic<Status> status{Status::stopped}`.
  - New `start()` sets `status = running` and calls `minMaxSearch.resume()`.
  - New `std::atomic<int> completedDepth{0}`. `start()` resets it, and the loop sets it after each
    finished depth.
  - `search()` **no longer sets running** (`:64`). The loop rule:
    - **cancelled**: stop at once. A cancel before the first depth returns an empty evaluation.
    - **stopped**: always finish depth 1, then stop. So a stop that arrives before or during
      depth 1 still produces a real best move.
    - Concretely: `for (d = 1; d <= maxDepth; d++) { if (cancelled() || (d > 1 && !running())) break; … }`.
    - Evaluation is still recorded only from fully completed depths.
  - `stop()`: `status = stopped; if (completedDepth > 0) minMaxSearch.cancel();`. It never aborts
    depth 1. If the read races with depth 1 finishing, depth 2 runs to completion (milliseconds),
    and the loop then exits.
  - `cancel()`: `status = cancelled; minMaxSearch.cancel();`, always immediate.
- `ChessEngine::searchBestMove(ChessBoard board, HistoryPtr history, int maxDepth, bool transpositionTable, SearchCallback)`
  takes the position and the TT flag explicitly. It no longer reads `game()`.
- `ChessEngine::loadAllGames` parses into a local `std::vector<ChessGame>`. It commits only if
  parsing succeeded **and** the vector is non-empty: it swaps the vector in and sets
  `gameIndex = 0`. Otherwise it returns false and `games` is untouched. Empty or whitespace-only
  text therefore fails, and the codec reports it as a corrupt file. BChess never wrote empty files,
  since `pgnAllGames()` emits at least `*`.
- `ChessGame::replayMoves()` also rebuilds `history`: clear it, then push the hash after each
  replayed move, exactly as `move()` does (`ChessGame.cpp:107`). Every caller gets this, including
  `moveTo` and `setMoveIndexes`. `outcome` stays untouched, because it is the game result that
  PGN round-trips.
- `ChessEngine::canPlay()` asks whether the current position can be played from:
  `generateMoves(board).count > 0 && (cursor < line length || outcome == in_progress)`. That
  means:
  - an earlier position of a finished or resigned game can be played from, which starts a new
    variation, as with any move made mid-tree;
  - the final position of a game with a declared result cannot;
  - mate and stalemate are caught by the move count.
- **The move path is always a valid root-to-leaf path.** That is the invariant every navigation
  method keeps from now on: each `moves[i]` indexes an existing variation, and the path ends at a
  leaf. One new private helper does it:
  `void ChessGame::extendPathToLeaf(int keep)` keeps `moves[0..keep)`, drops the rest, then appends
  `0` (the main line) from that node down to its leaf. Callers:
  - `moveTo(.backward)` and `moveTo(.start)` **only move the cursor**. The
    `resetToMainVariation()` calls go, and so does that method (no other caller). The path is
    already valid, so stepping back and then forward or to the end stays on the branch the user
    was on, which is also what a move list shows.
  - `moveTo(.forward, v)`: if `v != moves[cursor]`, set `moves[cursor] = v` and
    `extendPathToLeaf(cursor + 1)`; then `cursor++`. Choosing another variation therefore
    replaces the stale tail with that variation's own main line.
  - `move()`: after `moveIndexes.add(…)`, `extendPathToLeaf(moveCursor)`. A new node has no
    children, so the tail is dropped; an existing node continues along its main line.
  - `setCurrentMoveUUID(uuid)` resolves the node's **full path** with a new
    `MoveNode::findPath(uuid, std::vector<int>& path)`, a depth-first search over all variations,
    then calls `extendPathToLeaf(path.size())`, so forward navigation continues on that branch.
    It sets `cursor = node depth` and calls `replayMoves()`. An unknown UUID is a no-op.
  - `setMoveIndexes` (the PGN parser's save/restore, `FPGN.cpp:531-563`) is unchanged: it only
    restores a copy taken from a valid path, and parsing a variation only adds siblings.
- `ChessEvaluater::positionalAnalysis` is no longer written at runtime. The only writer is
  `FEngine.mm:331`, which goes away together with the unused `FEngine.positionalAnalysis` property
  (Swift never sets it; the only mention is commented-out code in `TournamentEngines.swift:17,23`).
  The static keeps its default, `false`, so no engine can change another engine's evaluation in
  the middle of a search.

**Bridge (`Shared/Bridge/FEngine.mm`):**
- New ivars:
  - `dispatch_queue_t _searchQueue`, a serial queue with QoS user-initiated, one per FEngine;
  - `std::recursive_mutex _control`. It is recursive so that a callback calling `cancel` or `stop`
    on its own thread cannot deadlock;
  - `uint64_t _generation` and `uint64_t _stopRequestedGeneration` (0 = none), both guarded by
    `_control`.
- `- (void)invalidate` (private): under `_control`, `++_generation; engine.cancel();`.
  - Public `cancel` is `invalidate`.
  - **Every position-changing method calls it first:** `setFEN`, `setPGN`, `loadAllGames`,
    `move:`, `move:to:`, `moveTo:variation:` (replacing its current `[self cancel]`),
    `setCurrentGameIndex:` and `setCurrentMoveNodeUUID:`.
  - UCI's `position` therefore cancels a running search. The UCI protocol has the GUI send `stop`
    first anyway.
- `stop` (UCI `stop`): under `_control`, `_stopRequestedGeneration = _generation; engine.stop();`.
  It delivers the best result so far, which is its UCI meaning.
  - The stop intent is recorded per generation, so it survives a search that has not been armed
    yet. That case is `go infinite` immediately followed by `stop` while the block is still queued.
  - Stop intent for an older generation is ignored.
- `evaluate:time:callback:`, **on the calling thread**:
  1. `[self invalidate]` and read `gen` under `_control`.
  2. Opening book: unchanged. The callback is invoked inline with `completed = YES`, as today
     (`:290-297`).
  3. Snapshot:
     `auto snap = std::make_shared<const ChessGame>(…copy of engine.game() with history = make_shared<vector>(*engine.game().history)…)`,
     and capture `tt = self.ttEnabled`.
  4. Run a block **on `_searchQueue`**: `dispatch_async` when `async == YES`, and `dispatch_sync`
     when `async == NO`. The UCI `xcode` and `performance` modes use the inline path, which is now
     serialized with any search still unwinding. The block does:
     - Under `_control`:
       `if (gen != _generation) return; engine.iterativeSearch.start(); if (_stopRequestedGeneration == gen) engine.stop();`.
       - The check and the arming share one critical section with `invalidate` and `stop`, so
         arming can never clobber a newer cancel or an earlier stop.
       - A stop recorded before arming makes the search finish depth 1 and deliver `completed`
         with a real move (the C++ rule above).
     - If `time > 0`, arm the timer **here**, so it measures the real search time:
       `dispatch_after(time, global, ^{ lock; if (gen == _generation) engine.stop(); })`.
       A stale timer finds a newer generation and does nothing.
     - `engine.searchBestMove(snap->board, snap->history, depth, tt, …)`. For each result, the info
       is built first, outside the lock: `FEngineInfo *info = [self infoFor:eval game:*snap];`.
       Then the delivery runs under `_control`: `if (gen == _generation) callback(info, done);`.
       That is the bridge guarantee above.

- **Test-only hook.** A private category in `Shared/Bridge/FEngine+Testing.h`, imported only by the
  test bridging header: `- (void)performOnSearchQueue:(dispatch_block_t)block` does
  `dispatch_async(_searchQueue, block)`.
  - Tests use it to hold the queue on a semaphore, so they can deterministically interleave "search
    requested but not armed" with `stop`, `cancel` and mutations.
  - `- (void)setSearchCheckpoint:(nullable dispatch_block_t)block`, compiled only under
    `BCHESS_TEST_HOOKS`, sets `engine.iterativeSearch.minMaxSearch.checkpoint` (the C++ hook
    above). Tests use it to park the search thread *inside* alpha-beta.
  - The app and UCI never import it.

  Because every search runs on the serial queue, `iterativeSearch`, its transposition table and
  `minMaxSearch.config` are only ever touched there. A new search starts only after the cancelled
  one has unwound, which is fast because the loops check `stopRequested`.
- `infoFor:game:` copies the snapshot and gives the copy `history = NEW_HISTORY`, so an
  `FEngineInfo` never shares the history vector the search mutates. `bestLine:`
  (`FEngineInfo.mm:104-105`) already replaces it before playing the line.
- Delete `updateCallback`, `FEngineDidUpdateCallback`, `fireUpdate:` and `stateIndex`. They were
  never wired, and `fireUpdate` hops to the main queue, which UCI never services.
- Callbacks are delivered on `_searchQueue` (or inline on the calling thread for the book) and
  **never** forced onto the main queue. UCI's main thread sits in `readLine` (`UCI.swift:180`), so a
  main-queue hop would mean `bestmove` is never printed (I4). The app does its own main-actor hop
  (§2.4).
- Headers for Swift 6:
  - `FEngine.h`: `NS_ASSUME_NONNULL_BEGIN/END`, and
    `typedef void (NS_SWIFT_SENDABLE ^FEngineSearchCallback)(FEngineInfo *info, BOOL completed);`
    so Swift sees `@Sendable (FEngineInfo, Bool) -> Void`.
  - `FEngineInfo.h`: `NS_SWIFT_SENDABLE` on the interface. It is immutable once `infoFor:` returns:
    every public property is readonly, and the private `info`/`game` are written only before it is
    handed out.
  - `FEngine`, `FEngineMove` and `FEngineMoveNode` stay non-Sendable. They live on the main actor
    (app) or the main thread (UCI).
- The existing `async` property stays. UCI needs it.

### 2.4 Model split (steps 4–5)

**`GameState`** (persisted value; new file `Shared/Model/GameState.swift`, moved out of
`ChessDocument.swift`):
```swift
struct GameState: Codable, Equatable, Sendable {
    var pgn: String; var rotated: Bool; var white: GamePlayer; var black: GamePlayer
}
```
- The coding keys stay exactly `pgn`, `rotated`, `white`, `black` (I1).
- A custom `init(from:)` uses `decodeIfPresent` for `white`/`black`, defaulting to
  human / computer-level-0 as `ChessDocument.swift:119-120` does today.
- `encode` always writes all four keys.
- `GamePlayer` gains `Equatable, Sendable`.
- The codec is shared by the macOS `ChessDocument` and the iOS `GameLibrary`, which are its two
  callers:
  - `init(data: Data, contentType: UTType) throws`
    - `.bchessGame` or `.json` decodes JSON.
    - `.pgn` builds the state from the UTF-8 text with both players human
      (`ChessDocument.swift:153-155`).
    - Anything else throws `CocoaError(.fileReadUnknown)`.
    - The PGN is validated with a throwaway `FEngine().loadAllGames` and throws
      `.fileReadCorruptFile` on failure, as `ChessDocument.swift:116-118` does today.
  - `func data(for contentType: UTType) throws -> Data`: JSON for `.bchessGame`/`.json`, raw UTF-8
    PGN for `.pgn`.
- `static let newGame = GameState(pgn: "*", ...)`.

**`GameSession`** (`Shared/Model/GameSession.swift`): a `@MainActor @Observable final class`. It
owns everything that is not persisted, and it absorbs `ChessDocument`'s runtime half,
`Actions.swift` (deleted, because it only forwarded) and the `ObservableObject` conformance of
`Game`. `Game` (`Shared/Game.swift`) keeps its name and file and becomes a plain struct, with
`rebuild` turning `mutating`.
- State:
  - `private let engine = FEngine()`;
  - `private(set) var gameState: GameState`, the persisted value;
  - `selection`, `lastMove`, `info`, `variations`, `mode` (moved from `ChessDocument.swift:36-63`),
    and `game`;
  - `private(set) var revision = 0`;
  - `private(set) var positionID = 0`.
- **Observing engine-derived state.** Views never see `engine`. Every engine read goes through a
  session accessor that first reads `revision`, which registers the Observation dependency:
  `pieces`, `isWhiteToMove`, `canMove(to:)`, `openingName`, `isValidOpeningMoves`, `games`,
  `currentGameIndex`, `currentMoveUUID`, `capturedPieces(white:)`, `materialPoints(white:)` (the code
  from `TopInformationView.swift:16-59` moves here), `fen`, `pgnCurrentGame`.
- **Two funnels.** Search invalidation is kept separate from persisted-state updates, so
  navigation never re-serializes the PGN. That way, opening a hand-written `"1. e4 e5 *"` and
  stepping through it does not normalize the text and dirty the document.
  - `private func invalidate()` does `positionID += 1; engine.cancel(); revision += 1`. These call
    it:
    - navigation: `undo()`, `redo()`, `move(to:)`, `chooseVariation(_:)`, `selectMove(uuid:)`;
    - `selectGame(_:)`, which also rebuilds `game` for the newly shown game;
    - `setPlayers(white:black:)`, which updates `gameState.white/black`, so a pending search for
      a side that just became human can never play;
    - `toggleAnalyze()` / `toggleTrain()` when they only switch mode;
    - `load(_ state:)`.
  - `private func contentDidChange()` does `invalidate()`, then sets `gameState.pgn` (to
    `engine.pgnAllGames()` in `.play` mode, else `mode.pgnBeforeAnalyzing`, which preserves
    `ChessDocument.swift:162`) and runs `game.rebuild(engine)`. These call it: `play(_ move:)`
    (a new move or a new variation), `newGame(white:black:)`, a successful `paste`,
    `analyzeReset()`, and the train-mode `setFEN`.
  - `select(rank:file:)` touches neither funnel. `rotate()` only sets `gameState.rotated`.
- **Paste without damage.** `paste(_ text: String) -> Bool` first parses into a throwaway `FEngine`:
  `probe.setFEN(text)`, else `probe.setPGN(text)` (the FEN-then-PGN order of
  `Actions.swift:132-140`). Only on success does it apply the same call to `engine`. On failure it
  returns false and the game is untouched. The pasteboard read stays in the view.
- **Engine turns, including computer versus computer.**
  - `requestEngineMoveIfNeeded()` has the guards from `PiecesView.swift:71-87`.
  - It sets `engine.thinkingTime` from the level of the **side to move**, which fixes the
    `applyEngineSettings` ordering bug. The level-to-seconds table becomes
    `GamePlayer.thinkingTime`.
  - `ttEnabled` comes from `UserDefaults`, as today.
  - It captures `let token = positionID` and calls
    `engine.evaluate { info, completed in DispatchQueue.main.async { self.searchDidUpdate(info, completed: completed, token: token) } }`.
    `DispatchQueue.main` keeps FIFO order, so progress never lands after completion.
  - `searchDidUpdate` returns immediately unless `token == positionID` (the app-side guarantee in
    §2.3).
  - Human moves (`playHuman(_ move:)`, called from `PiecesView` and the promotion sheet) and engine
    moves (`searchDidUpdate` on `completed`) both go through one method:
    `perform(animated: { play(move) }, then: { requestEngineMoveIfNeeded() })`. `perform` captures
    `positionID` *after* the change. The completion runs `then` only if `positionID` is unchanged,
    so a completion that fires after an undo, a player change or a game switch does nothing.
    After *every* move
    the session asks whether the next side is a computer. That is what keeps computer-versus-computer
    games running, the way today's animation-completion trigger does after engine moves too
    (`PiecesView.swift:92-98,152-157`).
  - `perform` calls `var animate: @MainActor (_ change: () -> Void, _ completion: @escaping @MainActor () -> Void) -> Void`.
    - Its default runs `change()` and then `completion()`. Tests use the default.
    - `ContentView` installs the SwiftUI version once:
      `session.animate = { withAnimation(.default, completionCriteria: .logicallyComplete, $0, completion: $1) }`.
    - So `Shared/Model` stays SwiftUI-free, and the engine still waits for the move animation, as
      Jean asked when he said to replace `onAnimationCompleted`.
- `Openings.pgn` is read once into a `static let openingsPGN` from
  `Bundle(for: GameSession.self)`. That is the main bundle in the app and the test bundle in
  `BChessTests`. Each session's engine still parses it with `loadOpening`.

**Views.**
- Views take `let session: GameSession`, or `@Bindable var session` where they need bindings: the
  `Picker` in `GameSelectionMenu` and the player editors.
- `ContentView(session:)` is shared by both platforms.
- `engineShouldMove` is removed.
  - The new-game and edit sheets call `session.newGame(...)` / `session.setPlayers(...)` and then
    `session.requestEngineMoveIfNeeded()`.
  - `PiecesView` calls `session.playHuman(move)`.
  - `.onAppear` calls `requestEngineMoveIfNeeded()`.
  - `Animation.swift` is deleted.
- Clipboard: the `#if os(macOS)` pasteboard code from `Actions.swift:142-196` becomes a small
  `Pasteboard` enum (`string`, `set(_:)`) in `Shared/Views/`.

**macOS document sync.**
- `ChessDocument` becomes `struct ChessDocument: FileDocument { var state: GameState }`, a pure
  value.
  - `readableContentTypes` is `[.bchessGame, .json, .pgn]`.
  - `init(configuration:)` and `fileWrapper(configuration:)` delegate to the `GameState` codec.
- `DocumentWindow(document: Binding<ChessDocument>)` holds
  `@State private var session = GameSession(state: document.wrappedValue.state)`.
  - It observes `.onChange(of: session.gameState) { if document.state != $1 { document.state = $1 } }`.
    So only persisted changes (moves, new game, paste, players, rotation) write the binding and
    dirty the document. Selection, navigation, analysis and info never do. That fixes the README
    "always want to write it back" limitation.
  - It observes `.onChange(of: document.state) { if $1 != session.gameState { session.load($1) } }`.
    This is how any external change to the document value reaches the session: Edit ▸ Undo and Redo
    (SwiftUI registers undo actions for writes through a `FileDocument` binding) and File ▸ Revert.
  - **Guaranteed and unit-tested:**
    - `session.load(_:)` rebuilds the position, bumps `positionID` (so an in-flight result is
      dropped) and leaves `gameState == state` (`loadReplacesStateAndDropsPendingSearch`).
    - Equal values never write back (`.loadDoesNotEchoState`).
  - **Not automated:** that SwiftUI's document undo manager records the binding write, and that
    Undo and Redo fire the `onChange`. Proving that needs a macOS UI test driving the Edit menu.
    I did not build that scaffolding (a macOS UI test needs accessibility permission, §2.1). It is
    a manual check owed (§6).
  - Both checks compare with `Equatable`, so the two observers cannot loop.

### 2.5 iOS app shell (step 6)

`BChessUIApp`:
- `#if os(macOS)`: `DocumentGroup(newDocument: ChessDocument()) { DocumentWindow(document: $0.$document) }`
  plus `Settings`.
- `#else`: `WindowGroup { GameRootView(library: .shared) }`.

**`GameLibrary`** (`Shared/Model/GameLibrary.swift`, `@MainActor @Observable final class`). It is
plain Foundation, so the macOS test bundle can test it.
- `init(directory: URL)`. The production directory is the app's **Documents** folder.
  - With `UIFileSharingEnabled` + `LSSupportsOpeningDocumentsInPlace` it is visible in Files under
    *On My iPhone ▸ BChess*.
  - It is where the old DocumentGroup app saved local games (there is no iCloud entitlement). So
    existing users' `.json` games show up in the list with no migration (I1).
- `private(set) var games: [GameFile]`, where `GameFile` is `{url, name, modified}`.
  - `reload()` lists `*.bchess`, `*.json` and `*.pgn` in the directory, newest first.
  - A file that fails to decode is skipped and not deleted.
- `func open(_ file: GameFile) throws -> GameState` uses the codec with the file's type.
- `func save(_ state: GameState, to file: GameFile) throws` writes atomically **in the file's own
  format**: `.json` stays `GameState` JSON and `.pgn` stays standard PGN (I1).
- `func create(_ state: GameState) throws -> GameFile` writes
  `Game yyyy-MM-dd HH.mm.ss.bchess` and appends ` 2`, ` 3`… on a collision.
- `func importFile(at url: URL) throws -> GameFile` brackets security-scoped access, decodes, and
  writes a new `.bchess` file whose name is the imported file's base name.
- `func delete(_ file: GameFile) throws`.
- `var lastOpenedName: String?` is stored in `UserDefaults` under `lastOpenedGame`.
- `func initialGame() throws -> GameFile` returns the last-opened file if it still exists, else the
  newest, else `create(.newGame)`. That last case is the first launch.

**`GameShell`** (`Shared/Model/GameShell.swift`, `@MainActor @Observable final class`). It holds the
iOS shell's state so it can be tested; the view only renders it.
- Owns `library`, `current: GameFile`, `session: GameSession`, `saveError: Error?`, and
  `private var savedState: GameState`, the state last read from or written to `current`.
- `@discardableResult func save() -> Bool`:
  - If `session.gameState == savedState`, it does nothing and returns true. So the autosave that
    fires when a switch installs a new session does not rewrite (or re-date) the file just opened.
  - Otherwise `library.save(session.gameState, to: current)`. On success it sets `savedState` and
    clears `saveError`. On failure it sets `saveError` and returns false; the edits stay in the
    in-memory session.
- `open(_ file:)`, `createGame(white:black:)` and `importFile(at:)` switch games through one
  `switchTo(_ file:, discardingUnsavedChanges: Bool = false) throws -> Bool`:
  1. It **always** calls `save()` first, whether or not the view's autosave observer has run yet.
  2. If that fails and `discardingUnsavedChanges` is false, it returns false and changes nothing.
  3. It decodes the target (`library.open`). If that throws, the error propagates and nothing has
     changed.
  4. Only then does it cancel the old session and install the new session, `current` and
     `savedState`.
- `delete(_ file:) throws`:
  - Not the current game: `library.delete(file)`. No switch, no save.
  - The current game. Deleting it *is* discarding its edits, and the swipe-to-delete is the user's
    confirmation, so it is never saved first. The order is:
    1. Pick the fallback: the newest *other* game in `library.games`, else `library.create(.newGame)`.
       (`initialGame()` would return the game being deleted, since it is the last opened.)
    2. Decode the fallback. If step 1 or 2 throws, the error propagates and nothing has changed:
       the current game, its session and its file are intact.
    3. Install the fallback as in `switchTo` step 4, without saving the old session, and set it as
       last-opened.
    4. Only then `library.delete(old)`. From step 3 on, autosave writes only to the fallback, so it
       can never recreate the deleted file. If the delete itself throws, the error propagates; the
       user is on the fallback and the old file stays in the list with its last saved content.

**`GameRootView`** (`iOS/GameRootView.swift`).
- `@State var shell = GameShell(library:)`, opened from `library.initialGame()` on appear. The app
  opens straight onto the board.
- Auto-save: `.onChange(of: shell.session.gameState) { shell.save() }`, and again on
  `scenePhase == .background`. `GameLibrary` never swallows errors.
- While `shell.saveError` is set, an alert says "Couldn't save this game", with **Retry** and
  **Dismiss**.
- When a switch returns false, a confirmation offers **Discard changes and switch** (which calls
  `switchTo(…, discardingUnsavedChanges: true)`) or **Cancel**. When a switch or a delete throws,
  an alert shows the error ("Couldn't open this game" / "Couldn't delete this game").
- Files are a few KB.
- Toolbar additions:
  - **Games** opens a sheet with a `NavigationStack` + `List` of `library.games`. Tapping a game
    switches to it (new `GameSession`; the old engine is cancelled). Swipe deletes through
    `shell.delete` (order above). The sheet also has an **Import** button
    (`.fileImporter(allowedContentTypes: [.bchessGame, .json, .pgn])` → `importFile` → open it).
  - **Share** is a `ShareLink(item: PGNExport(text: session.gameState.pgn), preview: …)`.
    `PGNExport` is `Transferable` with a `DataRepresentation(exportedContentType: .pgn)` and the
    suggested name `<game name>.pgn`. It exports standard PGN (I1).
- iOS **New Game** (existing sheet) does `library.create(GameState(pgn: "*", ..., players from the sheet))`
  and switches to it, so the Games list fills up naturally. Open decision 3.
- `.onOpenURL` (Files "Open in BChess" / share-to-app) does `importFile` and switches to the result.

**UI-test isolation.** If `ProcessInfo.processInfo.arguments` contains `-uiTestingFreshLibrary`, the
app uses `FileManager.default.temporaryDirectory/UITests-<UUID>/` as the library directory. The
last-opened name then never matches, so the app creates a fresh game. The arguments are read once
in `BChessUIApp.init`. There is no other test hook.

### 2.6 File types (I1, step 4)

- **New exported type** in both plists (`UTExportedTypeDeclarations`):
  - `ch.arizona-software.bchess.game`, described as "BChess Game", extension **`bchess`**,
    conforming to `public.json`.
  - Swift: `extension UTType { static let bchessGame = UTType(exportedAs: "ch.arizona-software.bchess.game") }`.
  - New documents and library games use it.
- **Legacy `.json`**: read and written back through Apple's system `public.json` (`UTType.json`).
  - Delete the shadowing `UTType.json` (`ChessDocument.swift:13-15`).
  - Delete the macOS import of `public.json` and both declarations of
    `ch.arizona-software.chess.json`.
  - Files on disk carry only the extension. An old `.json` resolves to `public.json` on both
    platforms, and the codec decodes the unchanged `GameState` keys.
- **PGN writer**: `FPGN.cpp:958` writes `[SetUp "1"]`, the standard tag. Files with the old
  `[Setup "1"]` still load, because the reader only uses the `FEN` tag (`FPGN.cpp:709`).
- **PGN**: keep `UTType(importedAs: "com.apple.chess.pgn")` and an *imported* declaration
  (extension `pgn`, conforms to `public.plain-text`) in both plists. Imported is correct for a type
  someone else owns. On macOS, Chess.app's exported declaration wins, and on iOS ours is the only
  one.
- **macOS `CFBundleDocumentTypes`**:
  - BChess Game (`ch.arizona-software.bchess.game`, Editor, `LSHandlerRank` Owner);
  - JSON (`public.json`, Editor, Alternate), so old games open and save back as `.json`;
  - PGN (`com.apple.chess.pgn`, Editor, Alternate).

  `fileWrapper` writes the format the document was opened as.
- **iOS plist**:
  - The same exported and imported types.
  - `CFBundleDocumentTypes` for BChess Game (Owner) and PGN (Alternate), which feed `onOpenURL`.
    There is no `public.json` claim on iOS, because it would hijack every JSON file. Legacy `.json`
    still arrives through the library listing or the importer.
  - Remove `UISupportsDocumentBrowser` and `UIRequiredDeviceCapabilities` (`armv7`).
  - Add `UIFileSharingEnabled = YES`.
  - Keep `LSSupportsOpeningDocumentsInPlace = YES`.

### 2.7 Swift 6 and view modernization (step 7)

- `SWIFT_VERSION: "6.0"` on all targets. That means complete strict concurrency. No
  `SWIFT_DEFAULT_ACTOR_ISOLATION`; isolation is explicit, per AGENTS.md.
- UCI: the search callback is `@Sendable`, so it must not capture the non-Sendable `UCI`. Capture
  `let log = self.log, xcode = xcodeMode` and call a `static func output(_:log:xcodeMode:)`
  (`UCI.swift:34-39,103-109`).
- `Tournament.swift` / `TournamentEngines.swift` are unused: `main.swift:11-12` has them commented
  out. Delete them (open decision 1).
- Replace the 11 `presentationMode` uses with `@Environment(\.dismiss)` and the 14 `PreviewProvider`s
  with `#Preview` (each `#Preview` builds a `GameSession(state:)`). Replace `NavigationView`
  (`NewGameView_iOS.swift:45`) with `NavigationStack`, and `.navigationBarTitle` with
  `.navigationTitle`. Every new view (`DocumentWindow`, `GameRootView`, the Games sheet) gets a
  `#Preview`.
- `Square.id` becomes `piece?.name ?? "empty-\(position.rank)-\(position.file)"`, which is stable
  (`Model/Square.swift:12-14`).
- The README gets: the `.bchess` format, the iOS Games list, and removal of the read-only-document
  limitation and the avanderlee attribution.

### 2.8 CI (step 8)

`.github/workflows/ci.yml`, a standard Xcode build-and-test workflow.
- It runs on `pull_request` and on `push` to `main`, with `permissions: contents: read` and
  `concurrency` cancel-in-progress.
- It uses no secrets, so there is no network use beyond GitHub itself (I5 concerns the app, not CI).
- Job `macos` on `runs-on: macos-26`:
  - select the newest Xcode 26.x on the image (explicit `xcode-select -s`);
  - `brew install xcodegen && xcodegen generate && git diff --exit-code`, which proves the committed
    project matches the spec;
  - `xcodebuild test -scheme "BChess (macOS)" -destination 'platform=macOS'`;
  - `xcodebuild build -scheme BChessUCI -destination 'platform=macOS'`;
  - signing overrides `CODE_SIGN_IDENTITY=- DEVELOPMENT_TEAM= CODE_SIGN_STYLE=Manual`.
- Job `ios`, same runner:
  - `xcodebuild test -scheme "BChess (iOS)" -destination 'platform=iOS Simulator,name=iPhone 17 Pro' CODE_SIGNING_ALLOWED=NO`;
  - when the image lacks that device, the step falls back to the first available iPhone from
    `xcrun simctl list devices available`.
- The `macos` job also runs the Thread Sanitizer command from §6.
- Every `xcodebuild` runs under `set -o pipefail` and is piped to `tee` into a log, so its exit
  status is kept. Each check is a required step:
  - no `✘`, `error:` or `ThreadSanitizer` in the logs;
  - **warnings**: the two fresh `-target` builds from the `/develop` warnings gate (fresh
    SYMROOT/OBJROOT, `COMPILER_INDEX_STORE_ENABLE=NO`), grepped with the same filter. Any line fails
    the job;
  - **gtest count**: the macOS test log must contain
    `Test gtest(_:) with N test cases passed` with `N >= 88` (checked with `grep -oE` plus a
    numeric comparison). A missing line or a smaller N fails the job.

## 3. Alternatives rejected

- **Keep the hand-written pbxproj.** It has six targets and dozens of duplicated build-file entries,
  and every file move in steps 4–7 would mean hand surgery. The sibling apps already use XcodeGen.
- **A separate hosted `BChessAppTests` target.** A test host would launch the macOS app, whose
  `DocumentGroup` opens windows or an open panel during tests, and the tests would need
  `@testable import`. App-logic types live in `Shared/Model` and use only Foundation, Observation and
  the bridge. So the hostless `BChessTests` compiles them directly, the same way it already compiles
  the engine. One target, no app launch. The cost is that `Shared/Model` must stay free of SwiftUI
  (the `animate` hook in §2.4 is how animation stays in the views);
  the build enforces that.
- **A per-search `IterativeDeepening` object (or a per-search cancel token threaded through
  `MinMaxSearch`)** instead of a serial queue plus generation. It is equally correct, but it means
  more C++ churn in signatures the gtests call directly, and it loses transposition-table reuse
  across searches.
- **Checking staleness only in Swift, or only in ObjC.** The bridge alone cannot recall a
  main-queue block that was already enqueued. Swift alone leaves UCI and tests receiving results
  after `cancel`. Each layer's exact guarantee is in §2.3.
- **Invoking the callback outside the lock** (revision 1). Codex round 1 showed it leaves a
  check-then-call window. Holding `_control` across the callback closes the window. The cost is that
  `cancel` can wait for one callback invocation (an enqueue or a `print`), never for a search, so
  "the main thread never waits on a search" (I2) holds.
- **Making `positionalAnalysis` a per-search parameter.** It would have to be threaded through every
  `ChessEvaluater` call. Nothing sets the knob, so it is deleted instead (§2.3).

**Codex round 3:** one part rejected. *"Resolve save/discard approval before deleting the current
file."* Deleting the current game is itself the discard of its edits, and the swipe-to-delete is
the confirmation, so `delete` never saves it or asks to. Asking "save changes to a game you are
deleting?" would protect nothing. The ordering half of the finding is accepted: the fallback is
chosen, decoded and installed before the file is deleted, and failures are tested (§2.5, §4).

**Codex round 2:** nothing rejected outright. The macOS undo integration test is scoped down to
unit tests of the session side plus a manual check (§2.4, §6). The SwiftUI undo registration
cannot be tested without a macOS UI-test target, which this plan avoids (§2.1).

**Codex round 1 findings rejected, with the reason:**
- *"The gate counts registration, not execution; record and verify executed names."* Every
  registered name is a Swift Testing argument, so it runs unless someone filters the run.
  - Each case already fails if its filter did not run exactly one gtest (the `RunTest` check).
  - The `/develop` gate requires reading the `gtest(_:) with N test cases` summary line.
  - A cross-test "executed set" would depend on test order, which Swift Testing does not
    guarantee.
- *"Timing loops need controlled synchronization."* With delivery under `_control`,
  `replacedSearchNeverDelivers` and `positionChangeInvalidatesSearch` are deterministic: they assert
  on callbacks that start after a method returned, and the protocol rules those out. The remaining
  time-based tests (`staleTimerDoesNotStopNextSearch`, `cancelStopsPromptly`) only need margins
  well above the scheduler's jitter.
- **Moving the time limit into the C++ search** (a deadline polled every N nodes). It removes the
  timer but changes the hot loop. The generation-gated timer armed at search start is exact and
  touches nothing in the search.
- **iOS keeps `DocumentGroup` with the iOS 18 launch-scene APIs.** Jean chose a normal app shell.
- **iOS library in Application Support.** It is hidden from Files, and it would not pick up the games
  the old app saved in Documents.
- **Snapshot of engine-derived values in a cached struct** instead of the `revision` read. That means
  a dozen cached fields to keep in sync. `revision` plus computed accessors has one invalidation
  point.

## 4. Test plan

All new tests use Swift Testing. "Red" means the test fails without that step's change, proven
with `git checkout -- <file>` as the skill requires.

**`BChessTests` (hostless macOS; engine + bridge + `Shared/Model` + UCI).**

| Test | Step | Proves |
|---|---|---|
| `EngineGoogleTests.gtest(_:)` ×88 | 2 | every GoogleTest case runs as its own case, with failures at the gtest file:line |
| `EngineGoogleTests.registersAllCases` | 2 | registration did not silently drop to zero (red today: 0 registered) |
| `FEngineTests.treeNode`, `.treeNode2` | 2 | ported unchanged |
| `GamesTests` ×7 (UCI best moves) | 2 | ported; also exercises the async bridge path that UCI uses |
| `UCIProcessTests.goInfiniteThenStopPrintsBestMove` | 3 | launches the built `BChessUCI` (a build dependency of `BChessTests`, found next to the test bundle in `BUILT_PRODUCTS_DIR`) with `Process` and pipes. Writes `uci`, `position startpos moves e2e4`, `go infinite`, `stop` back to back, then expects a `bestmove <uci move>` line (not `??`) within 5 s. Then `isready` → `readyok` (stdin stays responsive), `position fen <other>`, `go infinite`, `stop` → a second `bestmove` legal in the new position, then `quit`. Red before step 3: the stop is lost if it arrives before arming |
| gtest `IterativeDeepeningTests.CancelBeforeSearchIsHonored` | 3 | `start(); cancel(); search()` visits 0 nodes and returns no line. Red before step 3, because `search()` re-arms itself |
| gtest `IterativeDeepeningTests.StopEndsSearchAndKeepsBestLine` | 3 | `stop()` from the per-depth callback ends after that depth, keeping its line (atomic stop path) |
| gtest `IterativeDeepeningTests.StopBeforeSearchStillFinishesDepthOne` | 3 | `start(); stop(); search()` returns a one-move line at depth 1. Red if a stop can abort depth 1 |
| `FEngineConcurrencyTests.stopBeforeArmDeliversBestMove` | 3 | hold `_searchQueue` with `performOnSearchQueue` + semaphore, `analyze(cb)`, `stop()`, release → `cb` gets `completed` with a valid move within 2 s, and `isAnalyzing` becomes false. Deterministic. Red before the stop-intent fix (the search runs forever) |
| `FEngineConcurrencyTests.cancelBeforeArmNeverDelivers` | 3 | hold the queue, `analyze(cb)`, `cancel()`, release → no `cb` call, and `isAnalyzing` stays false |
| `FEngineConcurrencyTests.replacedSearchNeverDelivers` | 3 | `analyze(cb1)`, wait for its first callback, then `evaluate(B, cb2)`; set a flag after it returns. No `cb1` call ever sees the flag, and `cb1` never gets `completed`. Deterministic under the §2.3 protocol. Red without the generation gate (the old search sees the re-armed `running` status and keeps delivering) |
| `FEngineConcurrencyTests.positionChangeInvalidatesSearch` | 3 | the same pattern with `setFEN`, `move:`, `setPGN`, `loadAllGames` and `setCurrentMoveNodeUUID` replacing the second `evaluate`. Red before step 3, because those methods do not cancel |
| `FEngineConcurrencyTests.mutatingDuringSearchIsRaceFree` | 3 | One round each for `move:`, `setFEN` and `moveTo:`. A `setSearchCheckpoint` block fires once (an atomic flag): it signals `parked` and waits on `go`. The test calls `analyze()`, waits for `parked` (the search thread is now provably inside alpha-beta with the history pushed), signals `go`, and **then** mutates. Whatever the wall-clock interleaving, the search thread's accesses after `go` (at least the `pop_back` that unwinds the parked node) and the test thread's mutation are unordered by happens-before, which is what TSan reports. It does not depend on the two overlapping in time. A smoke test without TSan. **Under the Thread Sanitizer run (§6) it is red without the snapshot, every run**: the unwinding search pops the shared history vector that `move:` pushes to. Red proof: revert only the snapshot in `evaluate`, run the TSan command three times, all red |
| `FEngineConcurrencyTests.inlineSearchWaitsForUnwinding` | 3 | The same park-then-`go` checkpoint on an async `analyze()`; after `go`, `async = NO; evaluate(depth: 3)`. Under TSan there is no race on `iterativeSearch`, and the inline result arrives. Red under TSan without `dispatch_sync` on `_searchQueue`, for the same happens-before reason |
| gtest `MinMaxSearchTests.CancelledLoopStoresNoEntry` (needs `BCHESS_TEST_HOOKS`) | 3 | Middlegame FEN, `config.maxDepth = 4`, TT on, fresh table. `checkpoint` calls `cancel()` on its 50th call, so the root's loop is cut short at an exact node (single-threaded, deterministic). Asserts: the visited-node count is below a complete run's; `table.exists(rootHash)` is false. Then `resume()`, and a depth-4 search of the same position with this table returns the same score as one with a fresh table. Red before the fix: the root is stored with its partial value |
| gtest `ChessGameTests.SetCurrentMoveUUIDReplaysBoard` | 3 | after `1. e4 e5 2. Nf3`, selecting e4's UUID gives the FEN after 1. e4 and black-to-move legal moves. Red before the fix |
| gtest `ChessGameTests.SetCurrentMoveUUIDAcrossBranches` | 3 | `1. e4 e5 (1... c5 2. Nf3) 2. Nf3`: selecting `c5`'s UUID gives the FEN after 1. e4 c5, and forward navigation reaches 2. Nf3 on that branch. Red before the fix |
| gtest `ChessGameTests.BackwardKeepsLongerBranch` | 3 | `1. e4 e5 (1... c5 2. Nf3 d6) *` (the branch is longer than the main line). Select `d6`'s UUID; `.backward` → FEN after 2. Nf3 on the `c5` branch; `.start`, then `.end` → FEN after `d6` again. Red with `resetToMainVariation` still in `.backward`: that step asserts in `MoveNode::visit` |
| gtest `ChessGameTests.ForwardOntoShorterBranchDropsStaleTail` | 3 | Same PGN, cursor on `d6`; back to after 1. e4 (cursor 1); `.forward` with variation 0 (`e5`) → FEN after 1... e5, `canMoveTo(.forward)` is false, and `.end` stays there. And the reverse lengths: `1. e4 c5 (1... e5) 2. Nf3 d6 *`, select `e5`, `.start`, `.end` → FEN after `e5`; `.backward`, `.forward` with variation 0 → `canMoveTo(.forward)` is true and `.end` reaches `d6`. Red before the fix (stale tail walks off the tree) |
| gtest `ChessGameTests.MoveMidLineDropsStaleTail` | 3 | `1. e4 e5 2. Nf3 *`, back to after 1. e4, play `c5` (a new variation) → `canMoveTo(.forward)` is false. Red before the fix: `.forward` is allowed and asserts |
| gtest `ChessGameTests.NavigationRebuildsHistory` | 3 | `1. Nf3 Nf6 2. Ng1 Ng8 3. Nf3 Nf6 4. Ng1 Ng8 5. Nf3 Nf6`: the position after Black's knight returns to f6 occurs after plies 2, 6 and 10. First assert `ChessEvaluater::isDraw(board, history)` is true at the end (the precondition). Then `.backward` 4 times to ply 6, the same position: the history size is 6 and `isDraw` is false, because it has now occurred only twice. Red before the fix: the history still holds plies 7–10, so `isDraw` stays true |
| gtest `ChessEngineTests.CanPlayFromEarlierPositionOfFinishedGame` | 3 | fool's mate `1. f3 e5 2. g4 Qh4# 0-1`: `canPlay()` is false at the end and true after one step back. A resigned `1. e4 1-0` is false at the end |
| gtest `ChessEngineTests.FailedLoadAllGamesKeepsGames` | 3 | after a valid load, loading garbage **and** loading `""` / `"  \n"` both return false, and `getPGN()` is unchanged. Red before the fix |
| `FEngineConcurrencyTests.staleTimerDoesNotStopNextSearch` | 3 | `evaluate(time: 0.2)`, `cancel()`, `analyze()`. After 0.6 s `isAnalyzing` is still true. Red before step 3 |
| `FEngineConcurrencyTests.cancelStopsPromptly` | 3 | `analyze()`, wait 0.3 s, `cancel()`; `isAnalyzing` is false within 0.5 s |
| `GameStateCodingTests.decodesLegacyJSON` | 4 | a literal file in the old shape (with and without `white`/`black`) decodes, with defaults |
| `.jsonRoundTrip` | 4 | encode then decode is equal, and the keys are exactly `pgn, rotated, white, black` |
| `.bchessAndJSONShareTheFormat` | 4 | the same bytes decode as `.bchessGame` and as `.json` |
| `.pgnRoundTrip` | 4 | PGN text → state → `.pgn` data is byte-identical standard PGN, and both players are human |
| `.generatedFENGameIsStandardPGN` | 4 | `FEngine.setFEN(non-start)` + one move → `pgnAllGames()` contains `[FEN "…"]` and `[SetUp "1"]` (not `Setup`), and `loadAllGames` of that text gives back the same initial FEN and moves. Red before the `FPGN.cpp:958` fix |
| `.legacySetupTagStillLoads` | 4 | a PGN with `[Setup "1"]` + `[FEN …]`, as old BChess wrote it, loads with that FEN |
| `.invalidPGNThrows` / `.unknownTypeThrows` | 4 | the errors that `ChessDocument` relays |
| `GameSessionTests.selectionDoesNotChangeGameState` | 5 | selecting or navigating leaves `gameState` unchanged (no dirtying) |
| `.navigationKeepsUnnormalizedPGN` | 5 | a session loaded from the literal legacy `{"pgn":"1. e4 e5 *",…}` → `undo`, `move(to: .start)`, `selectMove` → `gameState` still equals the loaded value byte for byte |
| `.selectMoveRebuildsPosition` | 5 | `selectMove(uuid:)` of an earlier move → `fen`, `isWhiteToMove` and `canMove` match that move |
| `.undoRedo` | 5 | e4 e5, `undo` → FEN after e4 and `canMove(.forward)`; `redo` → back. `gameState.pgn` is unchanged by both |
| `.pasteFEN` / `.pastePGN` / `.pasteGarbageIsRejected` | 5 | paste order FEN then PGN. Garbage returns false, and the FEN, `gameState` and `game` are unchanged after a game with moves. Red without the probe engine |
| `.analyzeThenResetRestoresGame` | 5 | analyze, play moves, reset → original PGN and FEN; `gameState.pgn` stays the pre-analysis PGN throughout |
| `.trainStartsFromInitialPosition` | 5 | train mode sets the start position, and toggling restores the game |
| `.newGameResets` | 5 | the players are set, the PGN is `*`, and selection, lastMove and info are cleared |
| `.everyPositionChangeBumpsPositionID` | 5 | play, undo, redo, move(to:), new, paste, selectGame, selectMove, setPlayers, mode toggles |
| `.playerChangeDropsPendingSearch` | 5 | black is the computer and its search is running → `setPlayers` makes black human → the delivered result is ignored, and nothing is played after 2.5 s |
| `.staleAnimationCompletionDoesNothing` | 5 | an `animate` hook that stores the completion instead of calling it. White plays e4 (black is the computer), then `undo()`, `redo()`, then fire the stored completion → no reply after 0.5 s (a book reply would be instant). Red without the token check in `perform` |
| `.loadReplacesStateAndDropsPendingSearch` / `.loadDoesNotEchoState` | 5 | `load(s)` sets `gameState == s` and bumps `positionID`, and a result for the old token is ignored. Loading a value equal to the current one leaves `positionID` and `gameState` unchanged |
| `.computerVersusComputerContinues` | 5 | both players are computers, `requestEngineMoveIfNeeded()` → at least 3 half-moves are played (book replies) without any further call. Then `newGame` stops it. Red if `perform(…then:)` is not used for engine moves |
| `.staleSearchResultIsIgnored` | 5 | `searchDidUpdate(info, completed: true, token: positionID - 1)` changes nothing. Red if the token check is removed |
| `.cancelledSearchNeverPlaysItsMove` | 5 | out-of-book FEN, black is the computer; white plays, `requestEngineMoveIfNeeded()`, then `undo()`. After 2.5 s the FEN is still the pre-move FEN, with no lastMove (end-to-end I2) |
| `.engineRepliesFromBook` | 5 | new game, white plays e4 → black's reply lands on the main actor and is in `gameState.pgn` |
| `.thinkingTimeFollowsSideToMove` | 5 | white human level 3, black computer level 0 → the engine's search uses 2 s. Red with the old ordering |
| `GameLibraryTests.firstLaunchCreatesGame` | 6 | empty temp directory → one `.bchess`, which becomes last-opened |
| `.listsLegacyJSONAndPGN` | 6 | an old `.json` and a `.pgn` dropped in the directory are listed and open; an undecodable file is skipped |
| `.saveKeepsFileFormat` | 6 | saving to a `.json` writes `GameState` JSON, and to a `.pgn` writes PGN |
| `.importCopiesIntoLibrary` | 6 | importing a `.pgn` from another directory creates a `.bchess` copy and leaves the source untouched |
| `.deleteCurrentFallsBackToNewest` | 6 | after deleting the last-opened game, `initialGame()` returns the newest |
| `.lastOpenedIsRestored` | 6 | across a new `GameLibrary` instance on the same directory |
| `.createAvoidsNameCollision` | 6 | two creates in the same second → distinct files |
| `.saveFailureThrows` | 6 | saving into a read-only directory throws, and the error is not swallowed |
| `GameShellTests.switchSavesUnsavedMoveFirst` | 6 | play a move on `shell.session`, then immediately `open(other)` **without** calling `save()` (no view, so no autosave observer) → it returns true, and the first file on disk decodes to a state containing the move. Red if `switchTo` saves only when `saveError` is set |
| `GameShellTests.failedSaveBlocksSwitchUntilConfirmed` | 6 | make the current file's directory read-only and play a move, again without calling `save()`. `open(other)` returns false, `saveError` is set, and the current game and session are unchanged. `switchTo(other, discardingUnsavedChanges: true)` switches |
| `GameShellTests.unopenableTargetKeepsCurrentGame` | 6 | remove the other file from disk behind the library's back → `open(other)` throws; `current`, `session` and the current file are unchanged |
| `GameShellTests.deleteCurrentSwitchesBeforeDeleting` | 6 | games A (current, with an unsaved move) and B. `delete(A)` → `current` is B, A is gone from disk and from `library.games`; then `save()` and a further move + `save()` → A is still absent (autosave never recreates it) |
| `GameShellTests.deleteCurrentWithUnopenableFallbackKeepsCurrent` | 6 | B removed from disk behind the library → `delete(A)` throws; A is still on disk and current, with the same session |
| `GameShellTests.deleteOnlyGameCreatesFallback` | 6 | only A → `delete(A)` → `current` is a new game, A is gone. With the directory read-only instead, `delete(A)` throws (the fallback cannot be created) and A is still current and on disk |
| `GameShellTests.saveRecoversAfterFailure` | 6 | restore write permission → the next `save()` clears `saveError` and the file holds the edited state |

`ChessDocument` round-trips are covered through the codec. SwiftUI's `FileDocumentReadConfiguration`
and `WriteConfiguration` have no public initializers, and `ChessDocument` is three one-line
delegations to the codec.

**`BChessUITests` (iOS, replaces `Tests iOS`, step 6).**
`testNewGamePlayE4EngineReplies`:
1. Launch with `-uiTestingFreshLibrary`.
2. Actions ▸ New Game ▸ New Game (defaults: white human, black computer level 0).
3. Tap `square-e2`, then `square-e4`.
4. Assert that `square-e4`'s value is `P`.
5. Wait up to 20 s for the `board` element's value (its FEN) to match `" w .* 2$"`, meaning black
   replied and it is white's move 2.

Supporting identifiers:
- Each square in `PiecesView` gets `.accessibilityIdentifier("square-<file><rank>")` and
  `.accessibilityValue(piece name or "empty")`.
- The board `ZStack` gets `.accessibilityIdentifier("board")` and `.accessibilityValue(session.fen)`.

## 5. Invariants

- **I1 — Files keep opening.** *At risk; held.*
  - `GameState`'s keys are unchanged, and the missing-player decode is kept (`decodesLegacyJSON`).
  - `.json` still opens through `public.json` on macOS (document type) and on iOS (library listing
    and importer), and it saves back as `.json` (`saveKeepsFileFormat`).
  - `.pgn` reads and writes raw standard PGN (`pgnRoundTrip`), and Share exports standard PGN.
  - New files use `.bchess`, which is the same JSON.
- **I2 — Search results land only on their position.** *At risk; held.*
  - The snapshot, the serial queue, the generation gate on timer and delivery, and the Swift
    `positionID` gate (§2.3–2.4).
  - Every position-changing bridge method invalidates the search.
  - Tests: `replacedSearchNeverDelivers`, `positionChangeInvalidatesSearch`,
    `staleTimerDoesNotStopNextSearch`, `mutatingDuringSearchIsRaceFree` (TSan),
    `staleSearchResultIsIgnored`, `cancelledSearchNeverPlaysItsMove`,
    `playerChangeDropsPendingSearch`.
  - The main thread never waits on a search. `_control` is held only for a few instructions or for
    one callback invocation (an enqueue or a `print`), never while searching.
- **I3 — The engine stays portable.** *Touched; held.* Only `<atomic>` and `<mutex>` are added (the
  mutex lives in the bridge), plus the `#ifdef BCHESS_TEST_HOOKS` checkpoint, which is plain
  `std::function`. The standalone `clang++ -std=c++20` build in §1 keeps working.
- **I4 — UCI keeps working.** *At risk; held.* Callbacks arrive on the engine's serial queue, never
  the main queue. A `stop` before arming is recorded per generation and always yields a real
  `bestmove` (`goInfiniteThenStopPrintsBestMove`, `stopBeforeArmDeliversBestMove`). `fireUpdate` (a main-queue hop) is deleted. The `GamesTests` cases drive UCI
  through the async path.
- **I5 — Private and offline.** *Holds.* No network code is added. `ShareLink` and `fileImporter`
  are user-initiated and local.

## 6. Risks and rollout

- **File-type registration on macOS.** Launch Services caches old declarations. After step 4, check
  on a real Mac that a Finder double-click on an old `.json` game and on a `.pgn` opens BChess (or
  "Open With"), and that File ▸ New saves `.bchess`.
- **iOS needs a real-device pass** after step 6:
  - an upgrade install over the old app shows previously saved games in the list;
  - Files shows *On My iPhone ▸ BChess*;
  - Share sheet and "Open in BChess" both work.
- **Document undo on macOS: a manual check is owed.** The session side is unit-tested (§2.4). The
  SwiftUI side is not automated. Check on a Mac after step 5:
  - play a move, then Edit ▸ Undo: the move is gone from the board and the move list;
  - Edit ▸ Redo: it is back;
  - make an engine move, then Undo while a reply is pending: no reply lands on the reverted
    position;
  - File ▸ Revert To ▸ Last Saved restores the board.
- **Timing-based tests.** `staleTimerDoesNotStopNextSearch`, `cancelStopsPromptly`,
  `cancelledSearchNeverPlaysItsMove` and `playerChangeDropsPendingSearch` use margins far above
  scheduler jitter. The last two cost about 2.5 s each. That is acceptable.
- **Thread Sanitizer gate (from step 3).** In addition to the `/develop` gates, run
  `xcodebuild test -scheme "BChess (macOS)" -destination 'platform=macOS' -enableThreadSanitizer YES -only-testing:BChessTests/FEngineConcurrencyTests -only-testing:BChessTests/GameSessionTests`.
  A TSan report counts as red. CI runs it as well (§2.8).
  - What it proves: the TSan tests park the search thread at the checkpoint inside alpha-beta and
    mutate after releasing it, so TSan sees accesses unordered by happens-before on every run,
    with no reliance on timing (§4). What it does not prove: the absence of races on paths no test
    drives. TSan only reports accesses that actually execute in the run.
- **gtest 1.7 under C++20** compiles and passes locally (verified). If Xcode's stricter warning set
  flags vendored gtest, it is exempt from the gate.
- **CI runner Xcode version.** `macos-26` images ship Xcode 26.x. The spec's `xcodeVersion` and the
  generated `objectVersion` must open there; step 8 verifies the first green run. The simulator name
  falls back as described.
- **Openings parse per session.** It is unchanged in cost, and only the file read is shared. Measure
  only if the iOS game switch feels slow.

## 7. Steps (one commit each)

1. **OPS — XcodeGen project.** `project.yml` (§2.1), regenerate, iOS 18 / macOS 15, C++20, three
   shared schemes. Remove `Tests macOS` and the dead `FEngineMove.swift`. Fix new warnings. Gate:
   both apps and UCI build; macOS scheme tests run the 9 existing XCTests (the gtest-count gate
   starts at step 2).
2. **TEST — GoogleTests as Swift Testing.** `GTestRunner`, `EngineGoogleTests`, the test bridging
   header, the Swift Testing ports, and `ChessEngine::initialize` with `call_once`. Delete
   `GoogleTests.mm`. Red proof: `registersAllCases` fails with the old loader.
3. **ENGINE — thread safety and correctness.** The C++ atomics, `start()`, the depth-1 stop rule,
   and the explicit-position `searchBestMove`. `loadAllGames` is atomic and non-empty. `replayMoves`
   rebuilds history. `canPlay` is decided from the current position. The move path stays a valid
   root-to-leaf path (`extendPathToLeaf`; `.backward`/`.start` keep the branch), and
   `setCurrentMoveUUID` resolves full paths. No transposition entry from a cut-short loop. The
   `BCHESS_TEST_HOOKS` checkpoint. In the bridge: per-generation stop intent and the test-only queue
   and checkpoint hooks. Make
   `BChessUCI` a build dependency of `BChessTests`, and add the UCI subprocess test. In the bridge: the snapshot, the serial queue for both async and inline
   searches, the `_control` generation, invalidation in every position-changing method, the gated
   timer, delivery under the lock. Delete `updateCallback` and `positionalAnalysis`; add the
   `NS_SWIFT_SENDABLE`/nonnull headers. Tests first, including the TSan run.
4. **APP — GameState codec and file types.** `Shared/Model/GameState.swift`, `UTType.bchessGame`,
   remove the shadowing `UTType.json`, both plists (§2.6), and `ChessDocument` read/write through
   the codec (it still holds the engine in this step). `FPGN` writes `[SetUp "1"]`.
   `GameStateCodingTests`.
5. **APP — GameSession.** `Game` becomes a plain struct in place. `Game.swift`, `FullMove.swift`
   and `PiecesFactory.swift` stay where they are; the `BChessTests` source list names them
   explicitly next to `Shared/Model`. Add `GameSession`; make `ChessDocument` value-only; add
   `DocumentWindow` with the sync (§2.4), used by both platforms for now. Delete `Actions.swift` and
   `Animation.swift`; switch views to `session`; add the probe-engine paste, the two funnels, and
   `perform(animated:then:)` with the SwiftUI `animate` hook. Fix the thinking-time bug.
   `GameSessionTests`.
6. **APP — iOS shell.** `GameLibrary`, `GameRootView`, the Games sheet, import/Share/`onOpenURL`,
   the platform split in `BChessUIApp`, and the iOS plist cleanup. Replace `Tests iOS` with
   `BChessUITests` in the spec and the scheme; add the accessibility identifiers. Add `GameShell`
   (always save before a switch; delete installs the fallback before deleting) with the save-error
   alert and the discard confirmation. `GameShellTests`.
   `GameLibraryTests`, `testNewGamePlayE4EngineReplies`.
7. **APP — Swift 6 and modern SwiftUI.** `SWIFT_VERSION 6.0` everywhere, the UCI capture fix, delete
   Tournament (pending decision 1), `dismiss`, `#Preview`, `NavigationStack`, `navigationTitle`, the
   `Square.id` fix, and the README. Gate: zero warnings.
8. **OPS — CI.** `.github/workflows/ci.yml` (§2.8).

## 8. Decisions left open for Jean

All four decided by Jean on 2026-10-05: the defaults below.

1. **Decided (Jean, 2026-10-05): default.** **`Tournament.swift` / `TournamentEngines.swift`** (engine-vs-engine harness, commented out in
   `BChess/main.swift:11-12`). **Default: delete in step 7**; git history keeps them. The
   alternative is porting them to Swift 6, which means reworking their `DispatchQueue.main` +
   `RunLoop.main.run()` flow.
2. **Decided (Jean, 2026-10-05): default.** **New file extension.** **Default: `.bchess`** (JSON, type `ch.arizona-software.bchess.game`),
   so BChess games stop competing with every `.json` file. The alternative is to keep writing
   `.json` and only fix the type declarations. That is simpler, but on macOS BChess then claims
   generic JSON as Editor for new documents too.
3. **Decided (Jean, 2026-10-05): default.** **iOS "New Game".** **Default: create a new entry in the Games list** and switch to it. The
   alternative is today's behavior, which resets the current game in place, so the list only grows
   through Import.
4. **Decided (Jean, 2026-10-05): default.** **iOS library location.** **Default: the app's Documents folder**, which is visible in the Files
   app and picks up games the old iOS app saved. The alternative is Application Support, which is
   hidden and starts empty.
