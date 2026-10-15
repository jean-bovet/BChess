# APP-5 — Gallery scenarios: no `#Preview`, every screen a scenario in the test target

Revision 3 (2026-10-14). Jean: go, D1 merge (38 cards).

- Revision 1: initial plan.
- Revision 2: Codex plan round 1 (3 SHOULD-FIX accepted): simulator marker outside DerivedData plus an explicit simulator lifecycle across DerivedData folders (§2.4, §5); every PGN fixture parsed and production-session checks (§2.1, §4 tests 7–8); per-scenario timings forwarded to stdout and the log kept on failure (§2.4, §5).
- Revision 3: Codex plan round 2 (2 SHOULD-FIX accepted): marker path set only after the UDID is resolved or created, with a create → keep-booted → shutdown-from-another-DerivedData gate (§2.4, §5); both gallery suites nested in one serialized parent suite, because the fixtures write the shared scratch defaults (§2.2, §4).

Jean's request: convert BChess's preview gallery to maestro's reference method
(`maestro/skills/preview-gallery/SKILL.md`): no `#Preview` in the app targets; every screen is a
scenario in a list inside `BChessGalleryTests`, rendered light and dark by one snapshot test; spot checks
with `--only` instead of Xcode's canvas. Model implementation: Departure (`DepartureTests/Gallery/`,
`scripts/snapshot-gallery.sh`, `scripts/preview-gallery.py`, `docs/preview-gallery-plan.md`).

Settled by Jean before planning (not reopened here):

- **J1.** The macOS-only `#Preview("Document window")` (`macOS/DocumentWindow.swift:134`) is deleted; no
  Mac pass now (the Mac renderer is proven later in another repo).
- **J2.** The three scenarios hidden with `gallery: false` (Navigation, Arrow, Palette) become ordinary cards.
- **J3.** `GamesList` (`iOS/GameRootView.swift:237`, private) becomes internal so the test target builds
  it through `@testable import`; the DEBUG preview helpers (`iOS/GameRootView.swift:377-420`) leave the app.
- **J4.** English only, iOS only (iPhone plus the existing iPad-landscape card), one simulator at a time,
  the existing "BChess Agent" simulator.

## 1. Problem, with evidence

APP-4 built the gallery around `#Preview`s: each of the 40 `#Preview`s (37 in `Shared/`, 2 in `iOS/`,
1 in `macOS/`) calls a scenario of `Shared/PreviewSupport/PreviewScenarios.swift` (363 lines, `#if DEBUG`,
compiled into both app targets), and `scripts/preview-gallery.py` (389 lines) parses Swift to pair each
`#Preview` with its scenario and render (`discover_previews`, `read_scenarios`, `check_sources`), plus a
source-mtime freshness snapshot (`--snapshot`, `--sources`). The reference method drops all of that:

- A `#Preview` duplicates its scenario and needs that pairing check to stay in step; the scenario list
  alone is the one source, and it ships nothing in the app (today `PreviewScenarios`, the preview-only
  `previewShell()` / `gamesListPreview()` and 19 `#if DEBUG` blocks are compiled into Debug app builds).
- The page script parses Swift; the reference has the test write `manifest.json` so it never does.
- Cards are keyed by `<file stem>/<preview name>` (`SnapshotGalleryTests.swift`, tree
  `<light|dark>/<stem>/<name>.png`); the reference keys by a slug derived from a globally unique name,
  written flat as `<slug>.png` / `<slug>.dark.png`. Today's names collide across files ("Rotated" ×3,
  "White at the bottom" ×2).
- `scripts/snapshot-gallery.sh` misses the reference's 10-minute wait for another simulator,
  `-enableCodeCoverage NO`, `-testLanguage en`, `--only` (no `ONLY` filter in the test either), and the
  boot/build/test/total timings.
- `PreviewScenario` has no per-scenario `settle`; every card waits a fixed 400 ms.

## 2. Design

### 2.1 Scenario list in the test target (`BChessGalleryTests/GalleryScenarios.swift`)

Shaped on Departure's `GalleryScenario`, reduced to what BChess needs (no store seeding, no network stub,
no shared singletons, no widgets):

```swift
@MainActor
struct GalleryScenario {
    let name: String            // the card title, unique: "Game screen · Tall"
    let group: String           // the page section, in list order
    var size = GalleryScenario.phone   // CGSize; .phone is 402×874 (iPhone 17 Pro)
    var settle: Duration = .milliseconds(400)
    let build: @MainActor () -> AnyView
    var slug: String            // from name: "game-screen-tall"
    func view() -> some View    // build().defaultAppStorage(GalleryScenarios.defaults)
}
@MainActor enum GalleryScenarios {
    static let defaults: UserDefaults   // scratch suite "BChessGallery", emptied once per process
    static let all: [GalleryScenario]   // in group order: the page order
    static func matching(_ filter: String) -> [GalleryScenario]  // the ONLY filter
}
```

- **Reuse.** Every builder is today's `PreviewScenarios.<x>.build` body moved verbatim (same sessions,
  same PGNs, same frames), plus `humanToMoveSession()`, `boardFrame(_:)` and the `walnutBackdrop()`
  extension (`PreviewScenarios.swift:38-44`, fileprivate, moves with them). `view()` keeps
  `.defaultAppStorage` on a scratch suite (today `PreviewScenarios.defaults`, renamed to "BChessGallery"):
  every `@AppStorage` (`ContentView.swift:17` `showEngine`, `GameRootView.swift:79`, `SettingsView.swift:13-20`,
  `LabelsView.swift:15`, …) reads its declared default, so the readout is off and no stored setting changes
  a picture. No `#if DEBUG`, no `#if os(iOS)`: the target is iOS-only.
- **PGN fixtures as named constants.** Every PGN a builder passes to `GameState(pgn:)` moves into one
  `GalleryScenarios.Fixture` enum of `static let` strings plus `static let allPGNs: [String]`, and the
  builders use the constants. Reason: `GameSession.init` (`GameSession.swift:138-145`) silently falls back to
  `"*"` when `loadAllGames` rejects a PGN, so a broken fixture renders an empty board without failing anything;
  the constants let tests 7–8 (§4) parse every one.
- **Size.** A plain `CGSize`, as today (`nil` → `.phone`; only "Game screen · Wide" is 1180×820). The
  manifest writes it as `"402x874"`. No component canvas (rejected, §3).
- **Settle.** 400 ms default (APP-4's proven value for every card); 1 s for "Launch · Empty library"
  (`GameRootView` shows `ProgressView`, then builds the `GameShell` in `onAppear`) and
  "Games list · Four games" (a `NavigationStack` `List`), adjusted in step 2 if a card shows a half state.
- **Games list fixture.** `previewShell()` (`GameRootView.swift:378-404`) moves into the test target as
  `GalleryScenarios.gamesShell()`, unchanged (temporary directory, scratch defaults, four games at fixed
  calendar times, `library.reload()`, `GameShell(library:)` — the production reader). The scenario builds
  `GamesList(shell:attempt:onNewGame:actionError:)` directly (J3).
- **Access levels in the app (J3).** `GamesList` becomes internal, and so must `PendingSwitch`
  (`GameRootView.swift:26`, private): `GamesList.attempt` is `(PendingSwitch) -> Void`, and an internal
  struct cannot expose a private type in its memberwise initializer. Nothing else changes in the app: all
  other types the builders use are already internal (`BoardFrame`, `VariationCards`, `EvaluationBar`,
  `Promotion`, `GameLibrary.init(directory:defaults:)`, `walnutCard`, `currentMovePill`).

The 38 scenarios (the 40 `#Preview`s minus the macOS one, with the two identical board previews merged by
D1; the three J2 ones now render). Names are
"Screen · State"; groups follow today's `SECTIONS` table (`preview-gallery.py:38-45`), with Walnut, which
fell into "Other screens", given its own group:

| Group | Name (slug from it) | From |
|---|---|---|
| Game | Game screen · Tall / · Wide (1180×820) / · Analyze / · Train / · Rotated | `content*` |
| Game | Player row · To move / · Captures | `playerRow*` |
| Game | Status line · Your move / · Checkmate | `statusLine*` |
| Game | Navigation buttons (J2) | `navigationButtons` |
| Board | Board · White at the bottom (D1: one card for both) | `board`, `labelsWhiteAtTheBottom` |
| Board | Board labels · Rotated | `labelsRotated` |
| Board | Pieces · White at the bottom / · Rotated | `pieces*` |
| Board | Promotion · Drops from the top / · Rises from the bottom | `promotion*` |
| Board | Variations · Arrows and cards | `variationArrowsAndCards` |
| Board | Arrow (J2) | `arrow` |
| Engine | Engine · Equal / · Slightly better / · Mate / · Analyzing / · Statistics / · Stacked / · Evaluation bars | `engine*` |
| Moves | Move strip · Start / · Middle / · With variations | `moveStrip*` |
| Moves | Move list · Short game / · Variations and comments / · Card | `moveList*` |
| Games list | Games list · Four games; Launch · Empty library | `gamesList`, `gamesLaunch` |
| Games list | New game · New game / · Edit game (iPhone sheet); New game · Players & Level | `newGame*` |
| Settings | Settings | `settings` |
| Walnut | Walnut · Palette (J2) | `walnutPalette` |

`board` and `labelsWhiteAtTheBottom` had the same builder (`boardFrame()`) and identical images; Jean merged
them into one card (D1).

### 2.2 The snapshot test (`BChessGalleryTests/SnapshotGalleryTests.swift`, rewritten)

Swift Testing, as today, with Departure's body:

- `.enabled(if:)` on `BCHESS_SNAPSHOT_DIR` (unchanged), so the scheme's normal test run and Xcode Cloud skip it.
- `BCHESS_SNAPSHOT_ONLY` (comma-separated, case-insensitive substrings of names or slugs) through
  `GalleryScenarios.matching`; `#require` a non-empty match.
- `#expect` unique slugs over `all`.
- Per scenario: the existing `render(_:style:)` (`UIHostingController` in a `UIWindow` on the app's scene,
  `overrideUserInterfaceStyle` light then dark, `drawHierarchy` at 2x, `#require(drawn)`), waiting
  `scenario.settle` instead of the fixed 400 ms, and releasing the window (`isHidden = true`,
  `rootViewController = nil`). Writes `<slug>.png` and `<slug>.dark.png` flat into the directory, prints
  `gallery: <slug> <duration>`.
- Writes `manifest.json` (`name`, `group`, `slug`, `size` of **every** scenario, also on an `--only` run),
  then prints `gallery: <n> scenario(s)`. No network line: BChess has no network code (I5); the report
  states "network: none (I5)".

`PreviewScenarioTests` becomes `GalleryScenarioTests` (§4).

**Serialized.** The fixtures write process-wide state: `gamesShell()` → `GameShell.init` stores
`lastOpenedGame` (`GameShell.swift:119`, `GameLibrary.swift:49-51`) in the shared `GalleryScenarios.defaults`,
and the snapshot test reads that suite through every `@AppStorage` while it awaits each `settle`, so a
main-actor test of the other suite could interleave at those awaits. Both suites are therefore nested in one
parent, `@MainActor @Suite(.serialized) enum GallerySuites` (each declared in its own file as
`extension GallerySuites { @Suite struct … }`): `.serialized` on the parent serializes every test of both
(AGENTS.md, Swift Testing rules). The script's filter becomes
`-only-testing:BChessGalleryTests/GallerySuites/SnapshotGalleryTests`; step 1 checks that this identifier
selects the test (the log shows it ran, not "0 tests"), and falls back to the identifier the test log
prints if Xcode names nested Swift Testing suites differently.

### 2.3 `scripts/preview-gallery.py` (rewritten around the manifest, ~180 lines like Departure's)

- `--import DIR [--partial]`: replace `previews/` (or, with `--partial`, copy only DIR's PNGs over it),
  copy `manifest.json`, build the page.
- `--check`: rebuild the page, then fail on every item of the reference gate: a manifest scenario missing
  either image, a stray PNG, a duplicate slug, a light image that is dark or a dark one that is light
  (mean luminance against **0.45** via the kept `scripts/preview-luminance.swift`), a dark image
  byte-identical to its light one, an undecodable image. Prints
  `CHECK OK [en]: <n> cards, light and dark complete and correctly lit` or `CHECK FAILED [en] (<k>):` and
  exits 1. One repo extra kept from APP-4: fail on `.preferredColorScheme` / `\.locale` in
  `GalleryScenarios.swift` (three lines; the luminance check misses a forced locale).
- `--coverage`: `struct X: View` types under `Shared/` and `iOS/` that `GalleryScenarios.swift` does not
  name (informational).
- The page: groups in manifest order, light left / dark right per card. The wide-card rule is kept
  (`preview-gallery.py:365-366`: a landscape render is as tall as a phone card, so proportionally wider),
  read from the manifest's `size` instead of the PNG header.
- Deleted: `discover_previews`, `read_scenarios`, `check_sources`, `SECTIONS`, `--snapshot` /
  `--sources` and the freshness file (rejected-alternative §3).

### 2.4 `scripts/snapshot-gallery.sh` (extended, not rewritten)

Keeps BChess's simulator code, which is already stricter than Departure's (`release()` keeps the marker
when a shutdown fails; `--shutdown` never creates a simulator;
`BCHESS_SNAPSHOT_DD` persistent DerivedData; the "BChess Agent" iPhone 17 Pro simulator created if
missing; `TEST_RUNNER_` variables in xcodebuild's environment). Adds:

- `--only PATTERN` (→ `TEST_RUNNER_BCHESS_SNAPSHOT_ONLY`, and `--import … --partial`) and `--no-open`;
  the argument loop becomes `while/shift`; the optional simulator name or id stays positional.
- The 10-minute wait: when another simulator is booted, wait in 15 s steps up to 10 min, then stop with a
  message; never touch it.
- `test-without-building … -parallel-testing-enabled NO -enableCodeCoverage NO -testLanguage en`.
- Import, then `--check` (its exit status is the script's), timings `boot, build, test, total`.
- **Simulator marker outside DerivedData.** Today it is `$DD/booted-by-snapshot-gallery`
  (`snapshot-gallery.sh:32`), so a run or `--shutdown` under another `BCHESS_SNAPSHOT_DD` cannot see that it
  booted the simulator and leaves it running. It moves to `${TMPDIR:-/tmp}/bchess-snapshot-gallery.<UDID>.booted`
  (per simulator, as Departure keeps it in `$TMPDIR`), so ownership survives any DerivedData change; the
  `owned()`/`release()` logic is unchanged. The path is set **only after** the UDID is resolved or created
  (today `MARKER` is assigned at `snapshot-gallery.sh:32`, before `simctl create` at :48, so on a first run
  with no "BChess Agent" the new path would read `bchess-snapshot-gallery..booted` and no later run could
  release it). `--shutdown` resolves the UDID the same way and never creates one.
- **Per-scenario timings and the log.** The test output still goes to a log, but the log lives outside `$WORK`
  (`$WORK.log` beside it, which the `trap` does not delete), and after the run the script prints the
  `gallery: <slug> <duration>` and `gallery: <n> scenario(s)` lines, the Swift Testing summary line and any
  `error:` line to stdout (`grep -E`, indented). On failure it prints the tail and the log's path; on success
  the log is deleted.
- No SPM packages, so no package flags; no build-lock wrapper exists in `scripts/`, so none to keep.

### 2.5 What leaves the app (step 2)

`Shared/PreviewSupport/PreviewScenarios.swift` (and its folder); every `#Preview` and its `#if DEBUG`
wrapper in the 17 `Shared/` files listed by `grep -rn '#Preview' Shared iOS macOS`; in
`iOS/GameRootView.swift` the whole `#if DEBUG` block (`previewShell`, `gamesListPreview`, the two
`#Preview`s); `macOS/DocumentWindow.swift:134-136` (J1). Afterwards
`grep -rn -e '#Preview' -e PreviewProvider -e PreviewScenario Shared iOS macOS BChess` is empty and no
`#if DEBUG` remains in the app targets. `ENABLE_PREVIEWS` stays in `project.yml` (Departure kept it too; it
only affects how Xcode builds for the canvas). XcodeGen picks up the folder change: `xcodegen generate`,
commit `project.yml` (unchanged) and `BChess.xcodeproj`; the deletion also removes the file from the macOS
target, which must still build with 0 warnings.

## 3. Alternatives rejected

- **Keep `#Preview`s calling test-target scenarios.** Impossible (the app cannot import its test target)
  and the opposite of the request.
- **Keep the freshness check (`--snapshot`/`--sources`, mtimes of `Shared/`, `iOS/`).** The reference gate
  has no staleness; the gallery is regenerated on demand and an import replaces the set. Kept, it would
  have to be rewritten to snapshot `BChessGalleryTests/` too, for a gate nobody else runs.
- **A short "component" canvas for the small views** (the reference mentions one). It changes 25 cards'
  layout in the same plan as the move, which would hide a conversion regression behind an intended
  change. Today's sizes are kept; a component size is a later, visible change.
- **Departure's `size` enum (`phone`/`component`/`widget`).** BChess has no widgets and no component size
  (above): a `CGSize` with a `.phone` constant is the whole need.
- **A dedicated gallery scheme** so `build-for-testing` skips `BChessUITests`. Not until step 1's
  measurement shows the UI-test build matters; a second scheme is a second thing to keep in step.
- **XCTest** (Departure's choice). BChess's tests are Swift Testing (AGENTS.md), and the current test
  already skips through `.enabled(if:)`.

## 4. Test plan

New logic gets a failing Swift Testing test first, in `BChessGalleryTests/GalleryScenarioTests.swift`
(renamed from `PreviewScenarioTests.swift`; runs in the normal iOS scheme test, gallery skipped):

1. **"every scenario has a non-empty name and group and a unique slug"** — replaces the file/name check;
   fails on today's names if they were moved without renaming ("Rotated" ×3).
2. **"the slug is derived from the name"** — `"Game screen · Tall"` → `game-screen-tall`,
   `"New game · Players & Level"` → `new-game-players-level`, `"Board · White at the bottom"` →
   `board-white-at-the-bottom`.
3. **"the ONLY filter matches names or slugs, comma-separated, case-insensitive; empty means all"** —
   `matching("")` is `all`; `matching("Engine · Equal")` and `matching("engine-equal")` are that one
   scenario; `matching("GAME-SCREEN-TALL, engine · equal")` is those two; `matching("nothing")` is empty
   (only scenarios that exist from step 1 on, so the test does not change in step 2).
4. **"the Tall and Wide fixture has a human to move, so the app starts no search"** — kept from
   `PreviewScenarioTests`, now on `GalleryScenarios.humanToMoveSession()`.
5. **"the games fixture lists four games through the production library"** — `gamesShell()`'s library
   (`GameLibrary.reload()`, the reader the screen uses) holds the four named games with their dates (two
   today, one yesterday, one 9 days ago), so the "Games list" card cannot silently go empty.
6. **"the scheme passes -uiTestingFreshLibrary to the test host"** — kept.
7. **"every PGN fixture parses"** — parameterized over `GalleryScenarios.Fixture.allPGNs`:
   `#expect(FEngine().loadAllGames(pgn))` for each (the parser `GameSession.init` uses, without its `"*"`
   fallback). Seen red once by breaking one fixture (`2. Nf3` → `2. Nf9`) and restored with
   `git checkout -- <file>`.
8. **"the fixture sessions hold the positions their cards claim"** — production `GameSession(state:)` on the
   fixtures, read through what the views read: the Ruy Lopez fixture (`humanToMoveSession`) has
   `game.rows.count == 3`, a FEN that is not the start position, and white to move; the variation fixtures
   (Move strip · With variations, Variations · Arrows and cards, Move list · Variations and comments) have
   `game.variationCount > 0`; the commented fixture keeps `{King's pawn}` and `{Sicilian}` in
   `pgnCurrentGame`; the checkmate fixture (`1. f3 e5 2. g4 Qh4#`) has `gameEnd == .checkmate`; the captures
   fixture has non-empty `capturedPieces(white:)` for both sides. Step 1 covers the fixtures of its three
   scenarios; step 2 adds the rest.

Visual parity alone proves nothing about fixtures (a baseline rendered from a silently empty fallback
would match itself); tests 7–8 are what prove the fixtures load.

The gate `--check` is proven red once in step 1 (delete one `.dark.png` → `CHECK FAILED … missing`; copy a
light PNG over its dark one → `dark identical to light` and `light render in the dark slot`), then restored
by re-running the script. No production behaviour changes, so there is no regression test to red-prove.

New entities: the manifest fields are written by `SnapshotGalleryTests` and shown by
`preview-gallery.py`'s page (card title = `name`, section = `group`, image = `slug`); `--check` and the
step-2 card read cover that path.

**Visual parity (step 2).** Before step 1, render today's gallery on this branch
(`scripts/snapshot-gallery.sh --keep-booted`) and copy `previews/` to the scratch folder as the baseline
(36 cards). After step 2, compare each baseline pair (`<stem>-<name>[.dark].png`) with its new slug through
the §2.1 table: pixel-identical, or the difference explained in the step report (expected: none; the
Games list dates move only across midnight). Both baseline cards `boardview-board` and
`labelsview-white-at-the-bottom` are compared with the merged `board-white-at-the-bottom` (D1). The three J2
cards have no baseline and are read.

## 5. Steps

1. **Test, scripts, three scenarios** — `GalleryScenarios.swift` with three scenarios: "Game screen · Tall"
   (full screen with a session), "Engine · Equal" (component), "Games list · Four games" (the library
   fixture; makes `GamesList` and `PendingSwitch` internal). `SnapshotGalleryTests` rewritten (§2.2);
   `GalleryScenarioTests` (§4, tests 1–8 for its three scenarios, written first and seen failing to compile/fail); the simulator
   marker moved out of DerivedData and the timing lines forwarded (§2.4);
   `preview-gallery.py` and `snapshot-gallery.sh` (§2.3, §2.4). `PreviewScenarios.swift`, the
   `#Preview`s and `PreviewScenarioTests` stay untouched in this step (the app is unchanged except J3).
2. **Every screen a scenario, every `#Preview` gone** — the other 35 scenarios (§2.1 table), settle
   values; delete everything in §2.5 and `PreviewScenarioTests.swift`; `xcodegen generate`.
3. **Skill and working agreement** — `.claude/skills/preview-gallery/SKILL.md` rewritten as an instance of
   the maestro reference (§7); `AGENTS.md`; the develop skill; the plans index (§7).

### Gates per step

All gates run in the worktree, per `.claude/skills/develop/SKILL.md` (one build folder `<dd>` =
`/private/tmp/app-5-gallery-scenarios-dd` for the step gates, a fresh one for the final gate;
`BCHESS_SNAPSHOT_DD=<dd>/snap` for gallery runs, so the main checkout's snapshot DerivedData is not shared).
The plan's one simulator is "BChess Agent". Its lifecycle across DerivedData folders:

1. The **baseline** runs the current script (marker still in `$DD`), with `BCHESS_SNAPSHOT_DD=<dd>/snap`
   and `--keep-booted`, then `BCHESS_SNAPSHOT_DD=<dd>/snap scripts/snapshot-gallery.sh --shutdown` under that
   same folder, and `xcrun simctl list devices booted` shows it shut down — before step 1 changes the marker's
   location.
2. From step 1 on, the marker is in `$TMPDIR` (§2.4) and ownership no longer depends on the DerivedData
   folder. The **cold** measurement starts from that shut-down simulator and an empty
   `BCHESS_SNAPSHOT_DD=<dd>/snap-cold` with `--keep-booted`; the **warm** run follows on the booted simulator;
   later step gates reuse it with `--keep-booted`.
3. The **final gate** runs under a fresh `<dd>` (and its own `snap`), on the same booted simulator (the marker
   still names it), then `scripts/snapshot-gallery.sh --shutdown`. After every `--shutdown`, and when a gate
   fails and work stops, `xcrun simctl list devices booted` must show no "BChess Agent".

- **Step 1.**
  - Test gate (macOS tests, iOS scheme tests with the gallery skipped — the Swift Testing count shows
    `GalleryScenarioTests` run and `SnapshotGalleryTests` skipped, UCI build) and the warnings gate (three
    targets, 0 warnings).
  - Gallery: `CHECK OK [en]: 3 cards`, and the three cards read in both appearances.
  - `--only "engine"` renders 1 card, imports partially, and `--check` still covers all 3.
  - First-run ownership: with "BChess Agent" absent (`xcrun simctl delete` of the agent simulator, only when
    it is shut down; the script recreates it), run `BCHESS_SNAPSHOT_DD=<dd>/snap-a … --keep-booted --only engine`,
    check the marker file is `bchess-snapshot-gallery.<UDID>.booted` with the real UDID, then
    `BCHESS_SNAPSHOT_DD=<dd>/snap-b scripts/snapshot-gallery.sh --shutdown` from the other DerivedData
    folder shuts it down and removes the marker (`xcrun simctl list devices booted` shows no "BChess Agent"). Run before the cold measurement, which then boots it again.
  - `--check` proven red (§4) and green again.
  - **Measured and recorded in this plan's Outcome:** a **cold** run (simulator shut down, empty
    `BCHESS_SNAPSHOT_DD`) and a **warm** run (booted, built): the script's boot/build/test/total timings,
    and memory with `vm_stat` sampled every 5 s during each run (active + wired + compressed pages × page
    size; baseline before the run, peak during boot, peak during the test), plus the cost per scenario
    from the `gallery: <slug> <duration>` lines, which a successful run must print to stdout (checked: three
    lines, one per scenario). A note whether the `BChessUITests` build is a large share
    of `build-for-testing` (§3).
- **Step 2.**
  - `grep -rn -e '#Preview' -e PreviewProvider -e PreviewScenario -e '#if DEBUG' Shared iOS macOS BChess`
    returns nothing (exit 1).
  - Test gate and warnings gate (iOS, macOS, gallery targets, 0 warnings; the Mac target compiles
    without `PreviewScenarios.swift` and `DocumentWindow`'s preview).
  - Gallery: `CHECK OK [en]: 38 cards`, network: none (I5).
  - Visual parity against the baseline (§4).
  - **Every card read in both appearances**, findings listed (reported, not fixed in passing).
  - `--coverage` output pasted into the report (informational).
  - Timings of the full warm run, including the 38 `gallery: <slug> <duration>` lines on stdout.
- **Step 3.** Docs-only gate: `git diff --check`; every file and symbol the skill and AGENTS.md cite
  exists; `python3 scripts/preview-gallery.py --check` still `CHECK OK`; Jean reviews the gallery.
- **Final gate** (fresh `<dd>`): every test and warnings gate, plus the full gallery run, then the
  simulator shut down.

## 6. Invariants

- **I1 — Files keep opening.** Not applicable: no model, document or format code changes. `GamesList` and
  `PendingSwitch` only change access level.
- **I2 — A search result only lands on its position.** Holds; no `GameSession` code changes. The renders
  must start no search: every scenario keeps a human to move or a non-play position, and `view()` gives
  `@AppStorage("showEngine")` its default `false` (scratch suite), so `analyzeIfNeeded`
  (`GameSession.swift:552`) returns. Test 4 proves the full-screen fixture; the host app launches with
  `-uiTestingFreshLibrary` (test 6), which clears `showEngine` in the real defaults
  (`BChessUIApp.swift:18-24`). Same limit APP-4 accepted: no test proves that no builder ever starts a
  search; the cards are read.
- **I3 — The engine stays portable.** Not applicable: `Shared/Engine/` untouched.
- **I4 — The UCI tool keeps working.** Not applicable: `BChess/` untouched; the UCI build stays in the gate.
- **I5 — Private and offline.** Holds: no network code is added; the gallery stays local (`previews/` is
  gitignored, `.gitignore:12`); renders use temporary directories and a scratch defaults suite.

## 7. Docs (step 3)

- **`.claude/skills/preview-gallery/SKILL.md`**: the maestro reference text with its `repo-specific`
  markers kept (so `/audit-skills` can diff it), filled with BChess facts:
  - *identity*: description naming BChess, iOS, English, adopted; `argument-hint: [--only pattern]`;
    `allowed-tools: Read, Glob, Grep, Bash` (the Xcode MCP `RenderPreview` section and its tools go:
    there is nothing for the canvas to render).
  - *app*: `BChess.xcodeproj`, scheme "BChess (iOS)", target `BChessGalleryTests`,
    `GalleryScenarios.swift`, `previews/index.html`, groups as in §2.1, the Walnut design canvas as the
    approved spec (`planning/README.md`, UI-WALNUT row).
  - *platforms-and-languages*: iPhone 17 Pro plus one iPad-landscape card rendered at 1180×820 on the
    iPhone simulator; English; no Mac pass — macOS-only views (`DocumentWindow`) have no scenario until the
    Mac renderer is proven (J1).
  - *status*: adopted (APP-5).
  - *script*: `SnapshotGalleryTests`, `BCHESS_SNAPSHOT_DIR`, `BCHESS_SNAPSHOT_ONLY`, "BChess Agent"
    (iPhone 17 Pro, latest runtime), `BCHESS_SNAPSHOT_DD` and its default, the marker file, step 1's
    measured costs.
  - *extras*: hermetic by construction — no network code (I5), a human to move and the readout off so no
    search starts, the scratch "BChessGallery" defaults; the host launches with `-uiTestingFreshLibrary`.
- **`AGENTS.md`**: the Layout line for `BChessGalleryTests/` ("the gallery scenarios and the snapshot
  test"); the Tests rule (`AGENTS.md`, "Views are exempt … every new view gets a named `#Preview` … A
  macOS-only view keeps an inline `#Preview`") becomes: views are exempt from unit tests; **every screen
  needs a scenario** in `BChessGalleryTests/GalleryScenarios.swift`, and the app has no `#Preview`;
  `/preview-gallery` renders them; a macOS-only view has no scenario until the Mac renderer exists; a
  scenario never forces an appearance or a language.
- **`.claude/skills/develop/SKILL.md`**: "the test or preview that covers the path" (phase 2) and "a test or
  preview that uses the production read path" (phase 3 prompt) become "test or gallery scenario". This is
  shared process text: report it so maestro's reference `develop` follows (Jean's call through
  `/audit-skills`), not changed there by this plan.
- **`planning/README.md`**: this row; the APP-4 row gets "superseded by APP-5" appended.

## 8. Risks and rollout

- **File-format compatibility:** none (no model or document code changes).
- **Real device:** nothing needs one; the gallery runs on the simulator by design. Owed after landing:
  Jean's look at the gallery (step 3 gate). No owed device check.
- **`GamesList`'s memberwise initializer.** Its `@State private` properties all have initial values, so the
  synthesized init stays internal once the struct is; if the compiler disagrees, add an explicit internal
  `init(shell:attempt:onNewGame:actionError:)` (smallest fix, noted as a deviation).
- **Build time.** `build-for-testing` on "BChess (iOS)" also builds `BChessUITests`; step 1 measures it (§3).
- **Settle.** A 400 ms default may be short for the List and Launch screens on a cold simulator; the step-2
  read catches a half-rendered card, and the value is raised per scenario.
- **Shared snapshot DerivedData.** The default `BCHESS_SNAPSHOT_DD` is one folder for every checkout; the
  plan passes its own (§5) so the main checkout's incremental state is not churned.
- **Rollout:** one squashed PR (develop phase 6). Rollback is a revert; nothing ships to users (test
  target, scripts, and deletions of DEBUG-only code).

## 9. Decisions (resolved)

- **D1. `Board · Start` duplicated `Board labels · White at the bottom`** (both `boardFrame()`, identical
  images). Jean (2026-10-14): merge into one card, "Board · White at the bottom": 38 cards.

No decision is left open.

## 10. Outcome (implementation, 2026-10-14)

- 38 scenarios; `CHECK OK [en]: 38 cards`; every one of the 36 baseline pairs (APP-4 gallery rendered on this
  branch before step 1) is pixel-identical to its new card, both board baselines to the merged
  `board-white-at-the-bottom`. The three J2 cards (Navigation buttons, Arrow, Walnut · Palette) render; they are
  small components on a full-phone canvas (a later component size would fit them, see §3).
- Step 1 measured on 3 scenarios, simulator shut down and empty DerivedData (cold): boot 38.8 s, build 60.9 s,
  test 58.6 s, total 161.2 s; warm: boot 0.7 s, build 9.8 s, test 20.0 s, total 33.2 s. `vm_stat` (active + wired +
  compressed, every 5 s, on a Mac that another session also used): 12.4 GB before the cold run, 14.8 GB at the
  boot, 18.9 GB at the end of build and test; warm run 18.9 GB to 19.8 GB. The 38-card warm run: test 52.6 s,
  total 63.5 s, about 1.4 s per card (Games list and Launch 2.6 s with their 1 s settle). The share of the
  `BChessUITests` build in `build-for-testing` was not measured (the whole cold build is 61 s, so a gallery
  scheme is not pursued; a measured comparison is left open).
- The first-run ownership gate passed: with "BChess Agent" deleted, the script created it, wrote
  `bchess-snapshot-gallery.<UDID>.booted` with the real UDID, and `--shutdown` under another
  `BCHESS_SNAPSHOT_DD` shut it down and removed the marker.
- Deviations: `BChessGalleryTests` gets `SWIFT_OBJC_BRIDGING_HEADER: BChess/BChess-Bridging-Header.h` in
  `project.yml` (the scenarios use `FEngineMove`, the PGN test uses `FEngine`); the nested suites are
  `@MainActor` themselves (the parent's attribute is not inherited); `GalleryScenario` has no `.component`
  size (as planned) and `slug` is computed.
- Every card read in both appearances (contact sheets, light left, dark right). Findings, reported not fixed:
  the component cards (Player row, Status line, Navigation buttons, Engine ×6, Move strip ×3, Move list short and
  commented) sit small on a full-phone canvas, on the plain system white or black, not the Walnut background; the
  Player row · Captures card puts the captured-piece badge ("+2") flush against the right edge; the Arrow card is a
  bare blue arrow on the full canvas; the Wide card's move panel is small. No card is empty, half-rendered or in
  the wrong appearance; the Games list dates and the Launch card render fully with their 1 s settle.
- `--coverage` (informational): 18 of 26 view types appear in a scenario; not rendered: `GameView`, `LabelsView`,
  `MoveRowView`, `NewPlayerConfigurationView`, `SquareView`, `WalnutRowLabel`, `WalnutTextField`, `WalnutToggleRow`.
- Final gate, fresh build folder, before review round 1: warnings 0 / 0 / 0 (iOS, macOS, gallery target);
  macOS `Test run with 172 tests in 18 suites passed`, 183 GoogleTest cases started; UCI `BUILD SUCCEEDED`; iOS
  `Test run with 9 tests in 3 suites passed`; gallery `CHECK OK [en]: 38 cards`, 38 per-scenario lines, simulator
  shut down.
- Review round 1 (Codex): a failed `simctl list devices booted` now aborts the script (it is listed once per
  loop turn, its status checked, and the ownership marker is written only from a fresh successful listing; seen
  with a stub `xcrun` whose listing fails: the script stops with "Could not list the booted simulators; not
  booting anything.", exit 1, no simulator booted, no marker); a failed shutdown after a successful run keeps the
  marker and exits non-zero; test 8 reads `humanToMoveSession()`; fixture creation throws (a scenario `build`
  may throw and `view()` rethrows) instead of photographing an empty card.
