# APP-4 — Preview gallery: every screen rendered light and dark on one page

Revision 3 (2026-10-07). Codex plan review rounds 1–2 folded in. Implementation notes after the first code review: the card count is 39, and the fix round added the simulator rules, an exact PNG mtime, stray-PNG and unsupported-`#Preview` checks, a source snapshot taken before the build (a deleted file also makes the gallery stale), a drawn-hierarchy requirement in the renderer, and calendar-based Games dates. `PreviewScenarioTests` proves what it names: unique keys, a human to move in the Tall/Wide fixture, and the scheme argument reaching the host. It does not prove that `.defaultAppStorage` is applied or that no search ever starts; the limit is accepted, since the renders are looked at.

- Revision 1: initial plan.
- Revision 2: Codex round 1. Changes:
  - The Games preview factory stays in `iOS/GameRootView.swift`, so `GamesList` and
    `PendingSwitch` stay private.
  - Fixture libraries use isolated defaults.
  - The test host launches with `-uiTestingFreshLibrary`.
  - Freshness is conservative: any newer file under `Shared/` or `iOS/` makes every card stale.
  - An import replaces the whole set.
  - `--check` verifies that each preview renders its own scenario.
  - The red proofs name their rerender.
  - The AGENTS rule is scoped to iOS.
  - Rejected: making the luminance helper read nested paths (§2.4, "Rejected in round 1").
- Revision 3: Codex round 2. Changes:
  - `PreviewScenario.view()` applies the isolated defaults, so Xcode previews get them too.
  - `BChess/Openings.pgn` counts for freshness.
  - The warnings gate builds `BChessGalleryTests`.

Jean's request: port the preview-gallery method of the sibling repo CaVa (read-only reference:
`CaVa/.claude/skills/preview-gallery/SKILL.md`, `scripts/snapshot-gallery.sh`,
`scripts/preview-gallery.py`, `scripts/preview-luminance.swift`,
`CaVa/PreviewSupport/PreviewScenarios.swift`, `CaVaTests/Gallery/SnapshotGalleryTests.swift`). Jean
settled three points before planning, and this plan does not reopen them:

- **J1.** iOS only. Renders happen on an iOS simulator through `UIHostingController`, as in CaVa. The
  macOS-only `DocumentWindow` preview stays out of the gallery. A macOS renderer may come later.
- **J2.** Previews that force `.preferredColorScheme(.dark)` are removed, because every card shows
  both appearances. CaVa's rule applies: a preview never forces an appearance or a language.
- **J3.** The work runs through `/develop`.

The number is APP-4 because APP-3 is taken by strength levels (accepted, on branch
`app-3-strength-levels`).

## 1. Problem, with evidence

Today nobody can see BChess's screens without opening each `#Preview` in Xcode, one at a time. The
Walnut redesign (UI-WALNUT, UI-WALNUT-2) still owes "a visual check of those screens on iPhone and
Mac, light and dark" (`planning/README.md`, UI-WALNUT row). Several gaps get in the way of a gallery:

- **Forced dark previews.** 10 previews force dark (`grep -rn preferredColorScheme Shared iOS`):
  - `Shared/SettingsView.swift:69` "Dark"
  - `Shared/Views/VariationSelectionView.swift:121` "Dark"
  - `Shared/Views/MoveStrip.swift:83` "Dark"
  - `Shared/Views/PlayerRow.swift:94` "Dark"
  - `Shared/Views/MoveListView.swift:169` "Card, dark"
  - `Shared/Views/EngineView.swift:194` "Dark"
  - `Shared/Views/ContentView.swift:153` "Tall, dark" and `:159` "Wide, dark"
  - `Shared/Views/PromotionView.swift:117` "Rises from the bottom, dark"
  - `iOS/GameRootView.swift:401` "Games, dark"

  The brief counted 11; the source has 10. In a gallery that renders both appearances, these make the
  "light" card dark. Three of them are also the only preview of a distinct state:
  - `card: true` of `MoveListView`
  - `EvaluationBar` (`EngineView.swift:200-201`)
  - the black promotion rising from the bottom (`PromotionView.swift:120-121`)
- **Unnamed previews.** Five previews have no name: `Shared/Views/BoardView.swift:75`,
  `Shared/Views/NavigationButtons.swift:44`, `Shared/Views/Arrow.swift:44`, `iOS/GameRootView.swift:408`
  and `macOS/DocumentWindow.swift:134`. The gallery matches previews by name.
- **No test target compiles the views on iOS.** `BChessTests` is a macOS bundle with no host that
  compiles only `Shared/Model` and a few files (`project.yml`, target `BChessTests`). `BChessUITests`
  is a UI-testing bundle (`project.yml`, `BChessUITests`). The "BChess (iOS)" scheme tests only
  `BChessUITests` (`project.yml`, `schemes`).
- **Fixtures that are not deterministic or not reachable:**
  - `previewShell()` is `private` in `iOS/GameRootView.swift:381-393`. Its dates are
    `Date() - days*86400 - 600`, so the row times change on every run. Run just after midnight, a
    "today" game lands in "Yesterday".
  - `GamesList` is `private` (`iOS/GameRootView.swift:239`).
- **Previews that can start a real search.** `GameSession.init(state:mode:)`
  (`Shared/Model/GameSession.swift:138`) starts nothing. Two triggers do:
  - `PiecesView.onAppear` calls `session.startIfNeeded()` (`Shared/Views/PiecesView.swift:68-71`),
    which goes through `requestEngineMoveIfNeeded()` (`GameSession.swift:495-528`). That method
    searches when the mode is `.play` and the side to move is a computer. ContentView "Tall" and
    "Wide" use `1. e4 e5 2. Nf3 Nc6 3. Bb5 *` (`ContentView.swift:143-151`). With the default players
    (black is the computer) and black to move, these start a 2 s search whose move may or may not
    land before the snapshot.
  - `ContentView` copies `@AppStorage("showEngine")` into `session.showsEngine`
    (`ContentView.swift:17, 119-121`), and that starts a 10 s analysis (`analyzeIfNeeded`,
    `GameSession.swift:552`) whenever the stored default is true.

  "Analyze" and "Train" (`ContentView.swift:165-171`) do **not** search by themselves: they use the
  start position, and `requestEngineMoveIfNeeded` returns early when the mode is not `.play`. They
  analyze only through `showEngine`.
- **Stored settings change the picture.** ContentView and the board read the `@AppStorage` keys
  `appTheme`, `showEngine`, `showEngineStatistics`, `showCoordinates`, `showLegalMoves` and
  `highlightLastMove`. If the simulator holds a stored value, the render changes.

## 2. Design

The design is CaVa's, made smaller where BChess allows it. A single scenario list feeds the
`#Preview`s and a snapshot test. One script builds, renders and checks. One Python script assembles
the page and gates it.

### 2.1 Scenarios: `Shared/PreviewSupport/PreviewScenarios.swift` (step 1)

```swift
#if DEBUG
import SwiftUI

/// One named screen state, set up in one place: its `#Preview` and the gallery
/// (`BChessGalleryTests`) both render it.
struct PreviewScenario {
    /// The file holding the `#Preview`, e.g. "ContentView.swift", and exactly the `#Preview` name.
    let file: String
    let name: String
    /// Points; nil is the iPhone screen.
    var size: CGSize? = nil
    let build: @MainActor () -> AnyView
    /// Isolated settings for both callers (Xcode previews and the gallery): every @AppStorage
    /// reads its declared default, and nothing writes the app's real defaults.
    @MainActor func view() -> some View { build().defaultAppStorage(PreviewScenarios.defaults) }
}

@MainActor
enum PreviewScenarios {
    static let contentTall = PreviewScenario(file: "ContentView.swift", name: "Tall") { AnyView(...) }
    ...
    static let all: [PreviewScenario] = [...]
}
#endif
```

**Matching rule.** Each scenario is keyed by `(file, name)`, with no index. CaVa's per-file index and
its Swift copy of the slug function are dropped. With no index, inserting a preview cannot shift the
others. With no Swift slug, the Swift and Python sides cannot disagree on a slug. A key has to be the
pair because names repeat across files: "Rotated" appears in three files and "White at the bottom" in
two.

**Every `#Preview` calls its scenario.** For example, `#Preview("Tall") { PreviewScenarios.contentTall.view() }`.
Each preview is wrapped in `#if DEBUG`, as CaVa does (`CaVa/Features/People/WelcomeView.swift:79`),
because the scenarios exist only in Debug.

**macOS membership.** `Shared/` compiles into both apps. The iOS-only scenarios are wrapped in
`#if os(iOS)`, both in their declarations and in `all`:
- "Games" and "Launch", which use `GamesList` and `GameRootView` from `iOS/`
- "New game" and "Edit game" (`NewGameView_iOS`, excluded from macOS in `project.yml`)

`DocumentWindow`'s `#Preview` gets the name "Document window". It stays inline: it is macOS-only and
outside the gallery (J1), and it is the one documented exception to "every preview calls a scenario".

**The Games preview stays next to the private types (r2).** `GamesList.attempt` takes the private
`PendingSwitch` (`iOS/GameRootView.swift:26, 241`). `iOS/GameRootView.swift` therefore keeps a
`#if DEBUG` internal factory, `@MainActor func gamesListPreview() -> some View`, which also owns
`previewShell()`. The "Games" scenario calls it. `GamesList` and `PendingSwitch` stay private, and
production visibility does not change.

**`PreviewScenarios.defaults` (r3).** It is a `static let`, initialized once per process:
`UserDefaults(suiteName: "BChessPreviews")!`, emptied with `removePersistentDomain(forName:)` before
it is returned. Every Xcode preview process and every gallery run therefore starts from the declared
defaults. A Settings preview toggled in the canvas writes only to this suite. `view()` applies the
suite, so the renderer does not apply or empty it again.

**Fixtures never touch real defaults (r2).** `GameShell.init` calls `GameLibrary.initialGame()`
(`Shared/Model/GameShell.swift:25`), and that method writes `lastOpenedGame`
(`Shared/Model/GameLibrary.swift:131-140`). `GameLibrary(directory:)` defaults to `.standard`, so as
written the fixtures would write to the real defaults. Every fixture library is built with the
existing seam `GameLibrary.init(directory:defaults:)` (`GameLibrary.swift:43`) and passes
`PreviewScenarios.defaults`. That is one scratch suite, `UserDefaults(suiteName: "BChessPreviews")`,
used by two callers: the fixture libraries ("Games", "Launch") and the renderer's
`.defaultAppStorage` (§2.2).

**The resulting preview set (46 today, 40 after this plan, 39 in the gallery, which leaves out the macOS-only Document window):**

| File | Previews after APP-4 | Change |
|------|----------------------|--------|
| ContentView.swift | Tall, Wide, Analyze, Train, Rotated | "Tall, dark" and "Wide, dark" removed. Tall and Wide end with white to move. Wide gets `size` 1180×820 (iPad landscape; 900×600 cut the player row and status line off). |
| SettingsView.swift | Settings | "Light" renamed, "Dark" removed |
| PlayerRow.swift | To move, Captures | "Dark" removed (same content as "Captures") |
| StatusLine.swift | Your move, Checkmate | — |
| NavigationButtons.swift | Navigation | named |
| BoardView.swift | Board | named |
| LabelsView.swift | White at the bottom, Rotated | — |
| PiecesView.swift | White at the bottom, Rotated | — |
| PromotionView.swift | Drops from the top, Rises from the bottom | renamed from "…, dark" (J2: distinct state) |
| VariationSelectionView.swift | Arrows and cards | "Dark" removed (same content) |
| Arrow.swift | Arrow | named |
| EngineView.swift | Equal, Slightly better, Mate, Analyzing, Statistics, Stacked, Evaluation bars | "Dark" renamed "Evaluation bars" (distinct: the only `EvaluationBar` preview), see D1 |
| MoveStrip.swift | Start, Middle, With variations | "Dark" removed (variations already shown) |
| MoveListView.swift | Short game, Variations and comments, Card | "Card, dark" renamed "Card" (distinct: `card: true`), see D1 |
| NewGameView.swift | Players & Level | — |
| NewGameView_iOS.swift | New game, Edit game | iOS-only scenarios |
| GameRootView.swift (iOS) | Games, Launch | "Games, dark" removed, the unnamed one named "Launch" |
| Walnut.swift | Palette | — |
| DocumentWindow.swift (macOS) | Document window | named, inline, not in the gallery |

Each renamed preview keeps its content. Only its `.preferredColorScheme(.dark)` goes. Where the
removed preview set `.background(Walnut.background)`, the renamed one keeps it.

### 2.2 No search, the same picture every time (step 1, fixtures)

The fixtures are chosen so that no search starts. No new engine seam is added:

- **Tall and Wide** use `1. e4 e5 2. Nf3 Nc6 3. Bb5 a6 *`. White (human) is to move, so
  `requestEngineMoveIfNeeded` returns at `player.computer`. This is the existing seam. Every other
  scenario that contains `PiecesView` already has a human, or nobody, to move (checked: the start
  position, and VariationSelection with human/human players).
- **Analyze and Train** keep `GameSession(mode:)`. Only `showsEngine` could make them search, and the
  next point makes it false.
- **Stored settings** stay out of the renders and the Xcode previews alike.
  `PreviewScenario.view()` applies the SwiftUI modifier `.defaultAppStorage(_:)`, pointing it at
  `PreviewScenarios.defaults`, which is emptied once per process (§2.1, r3). Every `@AppStorage` then reads its declared default: `appTheme` is
  system, so no forced scheme, and `showEngine` is off, so no analysis. The renders and fixtures never
  write the simulator's real app defaults. The only write is the host's existing `showEngine`
  removal, covered under "The test host is isolated" below. `GameSession` reads `UserDefaults.standard` only inside a search
  (`useTranspositionTable`, `GameSession.swift:516`), and that never runs.
- **Games list dates** become fixed times of day: `Calendar.current.startOfDay(for: .now)` plus
  09:30 today, 18:15 yesterday, and 11:00 nine days ago. The row times are then stable, and the
  midnight flake goes away. The "earlier" date label still changes from day to day. That is
  acceptable, because the gallery is not a pixel diff. Injecting a clock into `GamesList` would be a
  new seam with no second caller.
- **The test host is isolated (r2).** The hosted tests launch the whole app. On a reused simulator,
  the host could open a saved game where the computer is to move, or turn the engine readout on, and
  search in the background. The "BChess (iOS)" scheme's test action therefore passes the existing
  launch argument `-uiTestingFreshLibrary` (XcodeGen `test.commandLineArguments`). `BChessUIApp.init`
  (`Shared/BChessUIApp.swift:17-24`) then opens an empty temp library, which shows a new game with
  white to move. It also removes `showEngine` from standard defaults, the same write the UI test
  already makes on the gate simulator (D4). This adds no app code. `BChessUITests` launches its own
  app with its own arguments, so it is unaffected.
- **UUID temp directories** stay. They never show in the picture.
- **Animations.** The renderer waits 400 ms after layout, as CaVa does, so `onAppear` and the
  promotion transitions have settled.

### 2.3 Gallery test target `BChessGalleryTests` (step 2)

A new target in `project.yml`, followed by `xcodegen generate` (the `.xcodeproj` is never edited by
hand). Its settings:
- `type: bundle.unit-test`, `platform: iOS`
- sources `BChessGalleryTests/`
- `dependencies: [target: "BChess (iOS)"]`
- settings: `TEST_HOST: $(BUILT_PRODUCTS_DIR)/BChess.app/BChess`, `BUNDLE_LOADER: $(TEST_HOST)`,
  `GENERATE_INFOPLIST_FILE: YES`, `PRODUCT_BUNDLE_IDENTIFIER: ch.arizona-software.BChessGalleryTests`,
  `TARGETED_DEVICE_FAMILY: "1,2"`

The target is added to the "BChess (iOS)" scheme's `test.targets`, next to `BChessUITests`. Two
reasons:
- `snapshot-gallery.sh` needs a scheme that contains it.
- The always-on scenario test (§4) then runs in the `/develop` iOS gate.

The snapshot test itself is skipped without its environment variable, so the gate gains about a
second.

The target holds two files:

- **`BChessGalleryTests/SnapshotGalleryTests.swift`** is CaVa's renderer, `@MainActor @Suite`, with
  these changes:
  - It is `.enabled(if:)` on `BCHESS_SNAPSHOT_DIR`, which xcodebuild sets from
    `TEST_RUNNER_BCHESS_SNAPSHOT_DIR`.
  - The render size is `scenario.size ?? CGSize(width: 402, height: 874)`, the iPhone 17 Pro.
  - It renders `scenario.view()`, which already carries the isolated defaults, with
    `overrideUserInterfaceStyle` light and then dark.
  - It writes `<dir>/<light|dark>/<file stem>/<name>.png`, using directories rather than a slug, so
    the Swift side has no naming logic.
  - CaVa's widget sizes and Dynamic Type variants are dropped: BChess has neither.
- **`BChessGalleryTests/PreviewScenarioTests.swift`** holds the always-on test (§4).

### 2.4 Scripts (step 3)

**`scripts/snapshot-gallery.sh`** is CaVa's script, with these changes:
- the default simulator is "BChess Agent", created from "iPhone 17 Pro" when missing
- DerivedData goes to `BCHESS_SNAPSHOT_DD`, default
  `~/Library/Developer/Xcode/DerivedData/BChess-snapshots`
- it runs `xcodebuild build-for-testing -scheme "BChess (iOS)"`, then
  `test-without-building -only-testing:BChessGalleryTests/SnapshotGalleryTests`, calling `xcodebuild`
  directly (BChess has no `scripts/xcb` lock)
- it keeps `--keep-booted` and `--shutdown`
- it runs `python3 scripts/preview-gallery.py --import "$WORK/png"` and then opens
  `previews/index.html`

**`scripts/preview-luminance.swift`** is copied unchanged. It reads only `previews/`, which is flat:
see the next paragraph.

**Rejected in round 1: making the helper read nested paths.** The nested
`<appearance>/<file stem>/<name>.png` tree exists only in the script's temp `WORK` directory. The
import copies each render to a flat, unique name in `previews/`:
`<slug(file stem)>-<slug(name)>.png`, with `.dark.png` for the dark render (CaVa's `base_name`,
without the index). The luminance helper and `--check` only ever read `previews/`, which has no
subdirectories and no repeated basenames. `--check` reports a slug collision between two keys as a
problem.

**`scripts/preview-gallery.py`** is CaVa's script, made smaller. It runs in two modes:

- `--import DIR` **replaces** the gallery. It deletes every PNG and the manifest in `previews/`,
  copies both appearances from the snapshot tree, writes the manifest and `index.html`, and runs the
  check. A slot with no render in `DIR` is therefore missing, never an old PNG (r2).
- `--check` rebuilds the page from the PNGs already in `previews/` and checks both appearances. It
  exits 1 on any problem.

Dropped from CaVa:
- `--lang` and all the French machinery (English only)
- `--since` and the RenderPreview file-name matching (only the snapshot test feeds the gallery)
- `--appearance` (one import brings both) and `--reuse-images` (`--check` already rebuilds the page)

Kept:
- discovery of `#Preview("…")` under `Shared/**/*.swift` and `iOS/**/*.swift` (`macOS/` is out, J1)
- a versioned `previews/.freshness.json`, made **conservative** in r2. It records the import's
  render time, which is the oldest render's mtime, and each PNG's mtime. Every card is stale when any
  file under `Shared/` or `iOS/`, or `BChess/Openings.pgn`, is newer than the render time.
  `Openings.pgn` is listed explicitly (r3): `GameSession.openingsPGN` loads it, and the status line
  shows the opening's name. That covers views, Walnut assets
  (`Shared/Assets.xcassets`), modifiers, the model, the engine and `PreviewScenarios.swift`, so
  nothing that can change a card is missed. A single card is also stale when its PNG's mtime differs
  from the record. CaVa's per-slot `rendered` and `stale` bookkeeping goes, because an import always
  renders the whole set.
- the light/dark luminance gate (0.45)
- orphan PNG cleanup
- the light/dark/both page switch

The page's localStorage key becomes `bchess-gallery-mode`.

Problems `--check` reports, besides CaVa's (missing, stale, wrong luminance, undecodable):
1. an **unnamed** `#Preview` in a scanned file
2. a **duplicate** `(file, name)`, or a duplicate scanned file basename
3. a render with no `#Preview` (**a scenario without a preview**)
4. **a `#Preview` that does not render its own scenario (r2).** The body must be exactly
   `PreviewScenarios.<ident>.view()`. Each scenario is declared on one line, as
   `static let <ident> = PreviewScenario(file: "<file>", name: "<name>"`, a convention stated in the
   file's header comment. The script reads `<ident>` from `PreviewScenarios.swift` and requires its
   `file` and `name` to be this preview's file basename and name. A body that names an unknown
   `<ident>` is a problem, and so is a declaration that breaks the one-line convention. Membership in
   `all` is covered by checks 3 and `missing`: a scenario left out of `all` leaves its card missing.
5. `preferredColorScheme(` or `\.locale` inside `PreviewScenarios.swift` (the J2 rule, caught
   before the luminance check has to)

**Sections are mapped by file, not by preview.** One table, from file to section, replaces CaVa's
list of `(file, name, label)` entries, so adding a preview to a known file needs no edit to the
script:

| Section | Files |
|---------|-------|
| Game | ContentView, PlayerRow, StatusLine, NavigationButtons |
| Board | BoardView, LabelsView, PiecesView, PromotionView, VariationSelectionView, Arrow |
| Engine | EngineView |
| Moves | MoveStrip, MoveListView |
| Games list | GameRootView, NewGameView_iOS, NewGameView |
| Settings | SettingsView |
| Walnut | Walnut |

A file not in the table goes to "Other screens". Cards keep the order of the files and the order of
the previews within each file. The card label is the preview name.

**`.gitignore`** gains `previews/`.

### 2.5 Skill and rules (step 4)

- **`.claude/skills/preview-gallery/SKILL.md`** is CaVa's skill, rewritten for BChess:
  - the script is the method
  - "Done = `CHECK OK: N cards, light and dark complete and correctly lit`", then read the new or
    changed PNGs in both appearances and shut the simulator down
  - the rule that previews never force an appearance or a language
  - how to add a scenario
  - the Xcode MCP `RenderPreview` is mentioned in one paragraph, for spot checks while editing a
    view (no import path)

  BChess has no `.agents/` folder, so CaVa's mirrored copy is not made.
- **`AGENTS.md`, Tests line (scoped in r2).** "every new view gets a `#Preview`" becomes: "every
  new view gets a named `#Preview`. A view compiled for iOS gets a scenario in
  `Shared/PreviewSupport/PreviewScenarios.swift`, and its `#Preview` renders that scenario.
  `/preview-gallery` renders those on iOS. A macOS-only view keeps an inline `#Preview`, outside the
  gallery. A preview never forces an appearance or a language."
- **`AGENTS.md`, Layout.** It gains `BChessGalleryTests/`, the iOS-hosted gallery tests.
- **`.claude/skills/develop/SKILL.md` (r3).** The warning commands build only the app targets, so
  they never compile the gallery tests. The warnings gate gains a third command, the same shape as
  the iOS one with fresh scratch directories:
  `xcodebuild -target BChessGalleryTests -sdk iphonesimulator -configuration Debug SYMROOT=… OBJROOT=… COMPILER_INDEX_STORE_ENABLE=NO build`.
  It is piped through the same grep, and it builds its host app as a dependency.
  `BChessGalleryTests/` joins the list of folders whose warnings count. An explicit target build was
  chosen over grepping the test log of the iOS test gate: that log is not built from fresh
  directories, and a warning can scroll past.

## 3. Alternatives rejected

- **Rendering the `#Preview`s themselves, without a scenario list.** There is no public API that
  enumerates `#Preview`s at run time. The Xcode MCP `RenderPreview`, one call per preview, is CaVa's
  older, slower and flakier path (ambiguous `__designTimeSelection`, misnamed snapshots). It stays
  for spot checks only.
- **CaVa's file index plus a slug computed in both Swift and Python.** These are two copies of one
  naming rule, and they break when a preview is inserted. `(file, name)` plus directories is simpler.
- **Matching by name alone.** BChess's names are not unique across files. Making them unique
  ("Pieces · Rotated") would only repeat the file name inside the name.
- **Disabling the engine with a preview flag on `GameSession` or `FEngine`.** That adds a seam with
  no second caller. Choosing positions where a human is to move uses the existing guard.
- **Resetting the app's real defaults domain in the test.** That would wipe Jean's settings on any
  simulator the gallery runs on. `.defaultAppStorage` with a dedicated suite isolates the render
  instead.
- **Adding the gallery to `BChessTests` (macOS).** J1 rules out a macOS renderer, and that target
  compiles no views.
- **A separate scheme just for the gallery.** That is one more scheme to maintain. The iOS scheme's
  test action can hold it at almost no cost, because the snapshot test is skipped without the variable.
- **Python unit tests for `preview-gallery.py`.** The red proofs in §4 exercise each `--check` rule
  on the real tree. A test harness for a 300-line tool script is more than its job requires.

## 4. Test plan

**Written first, red before step 2's implementation:**
`BChessGalleryTests/PreviewScenarioTests.swift`, a `@MainActor @Suite`:

- **`everyScenarioHasAUniqueFileAndName`.** Over `PreviewScenarios.all`, the `(file, name)` pairs
  are unique, every name is non-empty and contains no `/`, and every file ends in `.swift`. This
  proves a duplicated key cannot make two scenarios overwrite one PNG.
  - **Red proof:** add a second scenario `("ContentView.swift", "Tall")` to `all` and see the test
    fail. Then restore it with `git checkout -- Shared/PreviewSupport/PreviewScenarios.swift`.
  - It runs in every iOS gate.
- **`renderEveryScenarioInLightAndDark`** (`SnapshotGalleryTests`) is the renderer. It is skipped
  unless `BCHESS_SNAPSHOT_DIR` is set. It runs through `scripts/snapshot-gallery.sh`.

**Red proofs of the `--check` gate (step 3).** Each is made on the tree, seen failing, then
reverted. Each line goes in the step's commit message. "Rerender" means a full
`scripts/snapshot-gallery.sh --keep-booted` run, which imports and checks. "Check" means
`python3 scripts/preview-gallery.py --check` on the current gallery.

1. Delete one scenario from `all`, then rerender. That card is `missing light` and `missing dark`,
   because the import replaced the set.
2. Add `.preferredColorScheme(.dark)` to one scenario. Check: the source rule fires. Then rerender
   with the source rule commented out: the luminance check reports a dark render in the light slot.
3. Add a scenario to `all` with no `#Preview`, then rerender. It is reported as "scenario without a
   preview".
4. Add an unnamed `#Preview { … }` to a Shared view. Check: it is reported as "unnamed".
5. Make the "Tall" preview call `PreviewScenarios.contentWide.view()`. Check: it is reported as
   rendering another scenario (r2).
6. `touch Shared/Views/Walnut.swift` after a render. Check: every card is stale.
7. Rerender, then `touch BChess/Openings.pgn`. Check: every card is stale (r3).

**Always-on test of the host isolation (r2).** In `PreviewScenarioTests`,
`hostLaunchesWithAFreshLibrary` asserts that `ProcessInfo.processInfo.arguments` contains
`-uiTestingFreshLibrary`. A hosted test runs inside the host process, so this proves the scheme
argument reaches the host. It is red before the scheme change.

**Gates:**
- the `/develop` gates: macOS and iOS test, UCI build, and zero warnings in iOS and macOS Debug,
  plus the new `BChessGalleryTests` warnings build (§2.5, r3)
- plus Release builds of "BChess (iOS)" and "BChess (macOS)", because `#if DEBUG` wraps every preview
  and a missed wrapper only breaks Release
- plus one full `scripts/snapshot-gallery.sh` run ending in `CHECK OK`. The implementer reads the
  PNGs of ContentView Tall and Wide, Games and Settings, in both appearances, and reports what looks
  wrong. A visual finding is a finding, not a fix for this plan.

## 5. Invariants

- **I1 (files keep opening): not applicable.** No file format or reader changes. Preview fixtures
  only create games in temp directories.
- **I2 (search results land only on their position): holds.** No engine or session code changes. The
  fixtures and the isolated host avoid starting searches. The only production edit is a
  `#if DEBUG` factory added to `iOS/GameRootView.swift`.
- **I3 (portable engine): not applicable.** `Shared/Engine/` is untouched.
- **I4 (UCI tool): not applicable.** The UCI build gate still runs.
- **I5 (private and offline): holds.** The renders and the page are local, and `previews/` is
  gitignored. The page loads nothing from the network: its styles are inline, as in CaVa.

## 6. Risks and rollout

- **Release build.** Any `#Preview` left outside `#if DEBUG` that calls `PreviewScenarios` breaks
  Release only. This is why the Release builds were added to the gates (§4).
- **The luminance threshold (0.45) against Walnut light.** The light walnut background and wood board
  may measure darker than CaVa's screens. Board-heavy cards at phone size are mostly the system
  background, so they should be fine. If a correctly lit light card fails, the implementer reports
  the measured values; the threshold is not tuned silently. See D2.
- **Hosted test and the running app.** `BChessGalleryTests` launches BChess as its host. With
  `-uiTestingFreshLibrary` (§2.2), the host shows a new game with white to move in an empty temp
  library, so it runs no search, whatever the simulator holds. The renders use their own windows, so
  the host's screen does not show in them. A risk to verify in step 2: the scheme's test arguments
  must reach the host in `test-without-building` (carried by the `.xctestrun` file). The always-on
  test `hostLaunchesWithAFreshLibrary` proves it.
- **Merge with APP-3.** APP-3 (`app-3-strength-levels`) changes the New Game sheets, whose previews
  move into scenarios here. Whichever lands second converts or updates those previews. The check
  then fails loudly ("body does not call PreviewScenarios") rather than silently.
- **What needs a person.** None of this changes the app's behaviour, so no real device is needed.
  Jean's look at `previews/index.html` replaces the owed UI-WALNUT visual check on iPhone, light and
  dark. The Mac check stays owed.

## 7. Steps (one commit each)

1. **Scenarios and previews.**
   - Add `Shared/PreviewSupport/PreviewScenarios.swift`.
   - Every `#Preview` in `Shared/` and `iOS/` calls its scenario inside `#if DEBUG`.
   - Remove the forced darks, rename or remove previews as in §2.1, and name the unnamed ones.
   - `iOS/GameRootView.swift` gains the `#if DEBUG` `gamesListPreview()` factory, and
     `previewShell()` gets fixed times and isolated defaults.
   - Tall and Wide get a position with white to move.
   - Gates: build both apps in Debug and Release with zero warnings.
2. **Gallery test target.**
   - Add `BChessGalleryTests` in `project.yml`, regenerate the project, and add the target to the iOS
     scheme's test action, with `-uiTestingFreshLibrary` as its argument.
   - Write `PreviewScenarioTests` first, both tests, with their red proofs.
   - Add `SnapshotGalleryTests`.
   - Gates: the full `/develop` gates.
3. **Scripts.**
   - Add `scripts/snapshot-gallery.sh`, `scripts/preview-gallery.py` and
     `scripts/preview-luminance.swift`, plus `previews/` in `.gitignore`.
   - Make the 7 red proofs.
   - One full gallery run ending in `CHECK OK`.
4. **Skill and rules.** Add `.claude/skills/preview-gallery/SKILL.md`, the two `AGENTS.md` lines and
   the warnings-gate folder in the develop skill.

## 8. Decisions left open for Jean

- **D1. Keep "Card" and "Evaluation bars" as renamed light previews?** Your brief named only
  PromotionView for keeping. `MoveListView` "Card, dark" and `EngineView` "Dark" are also the only
  previews of a distinct state: the `card: true` move list, and the `EvaluationBar` in both
  orientations. Deleting them would leave those states out of the gallery.
  **Recommendation: keep both, renamed, with the forced dark removed.**
- **D2. Luminance threshold.** Keep CaVa's 0.45, and change it only with measured values from a
  failing, correctly lit card. **Recommendation: keep 0.45.**
- **D3. Should the renderer also run in the normal iOS test gate?** It would render about 39 × 2
  screens without writing files, which catches a scenario that crashes or a fixture that returns nil.
  The cost is roughly 30–40 s per iOS gate. **Recommendation: no.** Keep it skipped unless the
  variable is set, as CaVa does. `scripts/snapshot-gallery.sh` is the place to see renders.
- **D4 (r2). Isolate the test host with `-uiTestingFreshLibrary`.** The argument goes in the iOS
  scheme's test action, so the host never opens your saved games or analyzes. The cost: on the test
  simulator, this existing path removes `showEngine` from the app's standard defaults, as the UI test
  already does. The alternative is to leave the host alone and run the gallery only on the dedicated
  "BChess Agent" simulator. **Recommendation: use the argument.**
