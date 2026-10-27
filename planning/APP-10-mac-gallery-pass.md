# APP-10 — Mac gallery pass: the Mac window off screen, for the App Store and for coverage

Status: Implemented on main 2026-10-27 — Jean: go, D1–D7 as recommended (revision 3 — Codex plan round 2: the snapshot selector names the nested suite,
`BChessMacGalleryTests/MacGallerySuites/MacSnapshotGalleryTests`, and `mac_run`'s stub prints captures only for
that exact selector. Revision 2 — Codex plan round 1: the sheet's preferences seeded through
`NewGame.remember(in:)` into a scratch suite that `DocumentWindow` now takes as a parameter, three sheet cards
(Club, A friend, Maximum); the manifest's size is the mounted frame; a serialized parent suite; the sheet test
compares the parent-only and composited captures inside the sheet's bounds and needs Retina; the mac gate line
carries the container lock; only the fixtures both targets use move, with one shared `galleryMatches`).
Revision 1: the proposal. Builds on PR #33 (`ipad-pass`: `--device ipad`, `PASS_LABELS`,
`GallerySize.platform(ipadPass:)`, `skipReason(duoPass:ipadPass:)`), which lands before this is implemented;
the branch is rebased on it and touches none of its hunks.

## Problem, with evidence

1. The Mac App Store set for 1.0 has no source of captures. `.claude/skills/app-store-screenshots/SKILL.md`
   (after #33): "There is no Mac renderer, so the Mac set (`AppStore/screenshots-mac.json`, 2880 x 1800) uses
   window captures taken by hand into `previews/mac/`". Neither the slides file nor any capture exists
   (`AppStore/` holds `screenshots.json` and, from #33, `screenshots-ipad.json`). The renderer already knows the
   Mac set: `"device": "window"` (a capture at its natural size with a drop shadow, no frame;
   `~/GitHub/maestro/tools/app-store-screenshots/render.mjs:57-58`), `displayType` `APP_DESKTOP`, a config-level
   `textStyle` for a headline centred above the window.
2. The Mac's own screens have no gallery coverage. `AGENTS.md`: "A macOS-only view has no scenario until the
   Mac renderer exists." `macOS/DocumentWindow.swift` (the game window: title from the players, subtitle the
   opening, the toolbar New Game / Flip Board / Back / Forward / Show Engine, the players sheet), the Mac
   layout of `Shared/Views/NewGameSheet.swift:157-` (`#else` branch) and the Mac form of
   `Shared/SettingsView.swift:60-64` are never rendered. `BChessGalleryTests/GalleryScenarios.swift:478`: "The Mac
   layout has no card until the Mac renderer exists." APP-3's owed check "the sheet on a Mac (the Mac layout has no
   gallery card)" is still open.
3. The recipe and a proven port exist. `~/GitHub/maestro/skills/preview-gallery/mac-offscreen-renderer.md`
   (a real `NSWindow` never ordered on screen, `CARenderer` at 2x, sheets composited, readiness without a display
   cycle) is implemented in xFractal (`Tests/MacWindowSnapshotTests.swift`, `scripts/snapshot-mac.sh`, a
   sandboxed team-signed host like BChess's), Folio (`app/AppTests/Mac/MacRenderer.swift`, titled windows through
   `contentViewController = NSHostingController`) and Chirpter (`AppTests/Mac/MacRenderer.swift:60-140`, the
   attached sheet composited over its parent). BChess has none of it: no `AppKit`, `CARenderer`, `NSHostingController`
   or `NSWindow` subclass anywhere (Explore pass).
4. The gallery scripts already sort by platform. `scripts/preview-gallery.py` places each image in
   `<platform>/` from the manifest entry's `platform` (`platform_of`, line 53), a gallery per pass under
   `$PREVIEW_GALLERY_OUT` (`previews/duo`, `previews/ipad` from #33) and `PASS_LABELS` for the page's subtitle
   (#33). Only the `--check`'s forced-appearance scan is hard-wired to one file (`SCENARIOS`, line 36) and
   `--coverage` scans `Shared/` and `iOS/` only (`do_coverage`).

## Design

The smallest port of xFractal's Mac snapshot test, generalised by exactly what BChess needs that xFractal did not:
a manifest and the gallery check (light and dark per card), a sheet, and a shared scenario fixture file.

### 1. A macOS app-hosted test target, `BChessMacGalleryTests`

`project.yml`: `bundle.unit-test`, platform macOS, dependency `"BChess (macOS)"`,
`TEST_HOST: $(BUILT_PRODUCTS_DIR)/BChess.app/Contents/MacOS/BChess`, `BUNDLE_LOADER: $(TEST_HOST)`,
`GENERATE_INFOPLIST_FILE: YES`, `SWIFT_OBJC_BRIDGING_HEADER: BChess/BChess-Bridging-Header.h` (the scenarios build
views over `GameSession`, which owns an `FEngine`), `PRODUCT_BUNDLE_IDENTIFIER: ch.arizona-software.BChessMacGalleryTests`.
Sources: `BChessMacGalleryTests/` plus the shared `BChessGalleryTests/GalleryFixtures.swift` (§2). Modelled on
`BChessGalleryTests` (iOS) and xFractal's `xFractalTests` (`TEST_HOST` of a Mac app).

The `"BChess (macOS)"` scheme's test action adds the target after `BChessTests` and the command-line argument
`"-ApplePersistenceIgnoreState YES"` (Folio's `FolioMacTests` scheme): the host is Jean's own BChess bundle id, so
without it a hosted launch would restore his last game windows into the test run. `xcodegen generate`, both committed.

**The host's launch.** The hosted test launches the Mac app itself. APP-9 registered
`NSShowAppCentricOpenPanelInsteadOfUntitledFile = false` (`Shared/BChessUIApp.swift:36`), so the host opens one
untitled game window with the players sheet on screen for as long as the test process lives, and APP-9 showed the
delegate cannot veto it (`planning/APP-9-mac-launch-window.md:74-77`: `_doOpenUntitled` decides before it consults
the delegate). The plan copes in the test, not in the app: the snapshot test's first act closes every window the
host opened (`NSApp.windows` that are not its own `OffscreenWindow`; an attached sheet ended first with
`endSheet`; a clean untitled game closes silently, APP-9's check 275). The plain gate tests do nothing about it: the
window shows for the second they take. No app code changes for the host (D1 weighs a dedicated scheme instead).

**The host's container.** Every launch of the hosted target runs the app on its sandbox container
(`~/Library/Containers/ch.arizona-software.BChess`: preferences, saved state), the ordinary mac gate included, not
only the snapshot script. So the lock xFractal's script holds around the hosted run applies to every launcher:
the `/develop` mac gate line becomes `buildlock --folder ~/Library/Containers/ch.arizona-software.BChess --no-slot
-- buildlock --folder <dd>/dd-mac -- xcodebuild test -scheme "BChess (macOS)" …` (the same two locks as §5), so
two worktrees never run the hosted app at once. `buildlock` keeps its lock files in its own state folder, keyed by
the path, so the container need not exist yet (the first host launch creates it).

### 2. Shared fixtures, a Mac scenario list

`BChessGalleryTests/GalleryScenarios.swift` cannot compile on macOS (`UIUserInterfaceSizeClass` at line 45,
`GameRootView` and `GamesList` from `iOS/GameRootView.swift`, the iPhone shells). What the Mac scenarios actually
use from it is platform-neutral: the `Fixture` PGNs and `allPGNs`, the scratch suites `defaults` and
`engineOnDefaults`, the slug derivation and the `matching` filter. The session helpers (`humanToMoveSession`,
`variationsSession`, `worstRowSession`) stay in the iOS file: no Mac scenario calls them (`DocumentWindow` builds
its own session from a `GameState`).

- **`BChessGalleryTests/GalleryFixtures.swift`** (new, compiled by both targets): the `GalleryScenarios` enum's
  `defaults`, `engineOnDefaults` and `Fixture` move there verbatim (an `extension GalleryScenarios` is enough: the
  enum stays declared in `GalleryScenarios.swift` for the iOS target; the Mac target declares the empty
  `@MainActor enum GalleryScenarios {}` in its own list file). Two file-level functions carry the shared rules:
  `gallerySlug(of name: String) -> String` (the body of `GalleryScenario.slug(of:)`, which keeps its name and calls
  it, so `GalleryScenarioTests` and `preview-gallery.py` are untouched) and `galleryMatches(name: String, slug:
  String, filter: String) -> Bool` (the body of `GalleryScenarios.matching(_:)`'s predicate: comma-separated,
  trimmed, case-insensitive substrings, an empty filter matches all; `matching` calls it), so the Mac list filters
  by the same rules without a second copy. One new fixture, `Fixture.middlegame`
  (D2): a Ruy Lopez Closed, Chigorin, 16 moves each, white to move
  (`1. e4 e5 2. Nf3 Nc6 3. Bb5 a6 4. Ba4 Nf6 5. O-O Be7 6. Re1 b5 7. Bb3 d6 8. c3 O-O 9. h3 Na5 10. Bc2 c5 11. d4 Qc7
  12. Nbd2 cxd4 13. cxd4 Nc6 14. Nb3 a5 15. Be3 a4 16. Nbd2 Bd7 *`), added to `allPGNs` so the existing parse test
  covers it. No other change to the iOS file; the iOS gallery renders the same 48 cards.
- **`BChessMacGalleryTests/MacGalleryScenarios.swift`**: `MacGalleryScenario` (`name`, `group`, `size:
  MacWindowSize`, `settle: Duration = .milliseconds(300)`, `title: String?` — the window title the render waits
  for, `waitsForSheet = false`, `build: @MainActor () throws -> AnyView`, `slug` from `gallerySlug(of:)`) and
  `MacGalleryScenarios.all` / `matching(_:)` (`all.filter { galleryMatches(…) }`). `MacWindowSize` has two
  cases, each with a scenario: `.frame(CGSize)` (the whole window, title bar included, 1440 x 900 pt = 2880 x 1800
  px, the App Store's `APP_DESKTOP`, D7) and `.fits(width:)` (a window SwiftUI sizes to its content's ideal height,
  measured with `NSHostingController.sizeThatFits`, Folio's `.fits`); `MacWindowSize.points(for view:)` returns
  the window frame either way (the given frame, or the measured content plus the title bar once mounted), the one
  value the mount uses and the manifest records. Every scenario applies `.appTheme()` as `BChessUIApp` does and
  `.defaultAppStorage(GalleryScenarios.defaults)` (or `engineOnDefaults`), so the host's real defaults are never
  written.

  **The sheet's preferences, through the production path.** `DocumentWindow.swift:64` builds the new-game sheet
  from `NewGame(remembered: .standard)`, which reads the opponent, the side, both names and the thinking time
  (`Shared/Model/NewGame.swift:177-192`), and `NewGameSheet.playersControls` shows the names and switches its
  layout on them (a second name field for a friend, the thinking-time row at Maximum). A render over the host's
  standard defaults would capture Jean's names and whichever layout he last chose. The one app code change of this
  plan is the smallest seam: `DocumentWindow` gains `let newGameDefaults: UserDefaults` with `init(document:isNew:
  newGameDefaults: UserDefaults = .standard)`, and line 64 reads `NewGame(remembered: newGameDefaults)`; the app's
  call (`BChessUIApp.swift:43`) is unchanged. A sheet scenario seeds its own scratch suite
  (`UserDefaults(suiteName: "BChessMacGallery.<slug>")`, emptied first) with the production writer,
  `NewGame.remember(in:)` of the `NewGame` it wants, and passes the suite in. The sheet then shows exactly the
  seeded state, and the three layouts the Mac branch of `NewGameSheet` has get a card each. The six scenarios,
  group "Mac":
  - **"Document window · Engine on"** — `DocumentWindow(document: .constant(ChessDocument(state:
     GameState(pgn: Fixture.middlegame))), isNew: false)` on `engineOnDefaults`; `title: GameText.title(white:
     .defaultWhite, black: .defaultBlack)` ("You vs Club Player"); `settle: .seconds(2)` for the analysis of the
     position (the iOS "Game screen · Engine on" card does the same; the numbers differ per run). The hero and
     the dark slide.
  - **"Document window · Variations"** — the same window on `Fixture.commented`, both players human (title
     "White vs Black"), engine off: the move list beside the board with its variations and comments. The variation
     cards need a stepped position, which `DocumentWindow` builds its session without (`SessionBox`, no cursor in
     `GameState`): the list is the slide, as Jean asked.
  - **"Document window · New game sheet"** — `DocumentWindow(document: .constant(ChessDocument()), isNew: true,
     newGameDefaults: suite)`, the suite seeded with `NewGame()` (Club, white, no names, the sheet's own defaults):
     the window offers the players sheet in `onAppear`; `waitsForSheet: true`, captured with the sheet composited
     over the window (§3). The strengths slide.
  - **"Document window · New game sheet · A friend"** — the same, seeded with `opponent = .friend`, `firstName
     "Anna"`, `secondName "Jean"`: the second name field (the Mac layout's friend blurb "Take turns on this Mac").
  - **"Document window · New game sheet · Maximum"** — the same, seeded with `opponent = .maximum`,
     `thinkingTime = 10`: the thinking-time row with the Mac-only caption "More time, stronger play."
     (`NewGameSheet.swift:141-145`). The three close APP-3's owed "the sheet on a Mac" check (D3).
  - **"Settings window"** — `SettingsView().appTheme()` in a titled window, `.fits(width: 460)`
     (`SettingsView.swift:61`), the Mac form with its Engine section. Coverage only; no slide.

  A `DocumentWindow` over a constant binding ignores the writes `onChange(of: session.gameState)` would make: none
  happen in a render (no move is played). `WindowTitle` (`DocumentWindow.swift:109-149`) sets the title through
  `viewDidMoveToWindow` and keeps it: the title is the readiness signal.

### 3. The renderer, `BChessMacGalleryTests/MacRenderer.swift`

A port, by symbol, of the proven code:

- `OffscreenWindow: NSWindow` — xFractal's `OffscreenWindow` as is (`constrainFrameRect` unchanged, `order` only
  `.out`, `orderFront` / `orderFrontRegardless` / `makeKeyAndOrderFront` no-ops, the key/main appearance overrides so
  the traffic lights and controls draw active), origin (-30 000, -30 000).
- `mount(_:appearance:)` — Chirpter's: style `[.titled, .closable, .miniaturizable, .resizable]`,
  `contentViewController = NSHostingController(rootView:)` with `sizingOptions = []` (the toolbar and the sheet
  bridge to AppKit only through a window's hosting controller: the recipe's "The window"), `appearance`
  `.aqua` / `.darkAqua`, `isReleasedWhenClosed = false`, `ignoresMouseEvents = true`; for `.frame` the window's
  frame is set to the size (`setFrame(_:display: false)`), for `.fits` the content size to the measured one. Then
  the display passes AppKit would run before showing it (`_ = contentView`, `layoutIfNeeded`,
  `layoutSubtreeIfNeeded`, `displayIfNeeded`, for the window and its attached sheet: Chirpter's `settle`).
- `render(_:appearance:)` — mount; poll every 50 ms, with a pass before each poll, until the title matches and,
  when `waitsForSheet`, `attachedSheet != nil` (10 s, failing by name); the scenario's `settle`; one more pass;
  capture. The window (sheet ended first) is closed in a `defer`.
- `draw(_ window:behind:)` — the recipe's skeleton verbatim (Retina guard, the frame view's topmost layer, the
  Metal texture cleared, `CARenderer` with the 2x scale on the root layer restored in `defer`, the fence before
  `getBytes`, the flipped rows), one window's layer tree to a `CGImage` with its frame; `capture(_:)` — Chirpter's:
  `draw` of the parent, then, when a sheet is attached, `draw` of the sheet with the parent's picture inserted as
  its bottom layer, composited at the sheet's offset; `NSBitmapImageRep` with `rep.size = window.frame.size`
  (144 dpi). The two stay separate functions (Chirpter's shape) so the sheet test can compare them (Test plan).
- The `.frame` capture is checked: a PNG that is not exactly `size * 2` pixels fails the scenario by name (the iOS
  test's "mounted at … not …" check), so SwiftUI resizing the window to an ideal size (Chirpter measured it) is
  caught, not shipped as a wrong-sized slide (see Risks).

### 4. The snapshot test and how the PNGs leave the host

`BChessMacGalleryTests/MacSnapshotGalleryTests.swift`, Swift Testing. Both Mac suites are nested in one
`@MainActor @Suite(.serialized) enum MacGallerySuites {}` (the iOS `GallerySuites` pattern,
`GalleryScenarioTests.swift`): the tests mount AppKit windows and share the scratch suites while they suspend in
readiness and settle waits, and main-actor isolation alone lets asynchronous tests interleave.

- `renderEveryMacScenarioInLightAndDark`, `.enabled(if: BCHESS_MAC_SNAPSHOT is set)` (the iOS test's
  `.enabled(if: BCHESS_SNAPSHOT_DIR …)`); filters with `BCHESS_SNAPSHOT_ONLY` (the same variable as iOS); closes the
  host's windows first (§1); renders each scenario light then dark; writes the manifest (the iOS `ManifestEntry`
  shape: `name`, `group`, `slug`, `size`, `platform: "mac"`, `skipped: nil`, no flags); prints
  `gallery: <slug> <duration>` and `gallery: <n> scenario(s)` as the iOS test does. `size` is the window frame in
  points as mounted, "1440x900" for a `.frame` scenario and the measured frame for a `.fits` one (the Settings
  window, 460 wide by its content's height plus the title bar): `MacWindowSize.points(for:)`, the value the mount
  used, is what the manifest records for every scenario, rendered or not (an `--only` run still lists them all).
  The page sizes a card from it (`preview-gallery.py:size_ratio`), so a wrong size shows as a squashed card.
- The host is sandboxed (`macOS/macOS.entitlements`) and team-signed, and macOS keeps other processes out of such
  a container: xFractal's transport, verbatim but for the file name — every file (`<slug>.png`, `<slug>.dark.png`,
  `manifest.json`) goes to stdout as `mac-gallery-file <name> <base64 chunk>` lines of 64 KiB, which the script
  joins and decodes (D4). No `BCHESS_SNAPSHOT_DIR` on the Mac.

Plain tests, run by every mac gate (`MacGalleryScenarioTests.swift`), see Test plan.

### 5. `scripts/snapshot-mac.sh`

xFractal's `scripts/snapshot-mac.sh` without `--lang` (BChess is English only; the skill forbids a language pass)
and with the gallery import after the decode:

```
scripts/snapshot-mac.sh [--only PATTERN] [--no-open]
```

`caffeinate -dims -w $$`; DerivedData `BCHESS_SNAPSHOT_DD` (the gallery's folder; a Mac build lives beside the
iOS one in it); when `buildlock` is on PATH, `buildlock --folder ~/Library/Containers/ch.arizona-software.BChess
--no-slot -- buildlock --folder "$DD" -- xcodebuild …` (xFractal's two locks: the host's container, so two
worktrees never run the hosted app at once, around the build slot; the mac gate line holds the same container
lock, §1), else plain `xcodebuild` (public repo). One
`xcodebuild test -project BChess.xcodeproj -scheme "BChess (macOS)" -destination 'platform=macOS' -derivedDataPath
"$DD" -only-testing:BChessMacGalleryTests/MacGallerySuites/MacSnapshotGalleryTests (the nested suite of §4, the
shape of `scripts/snapshot-gallery.sh:245`'s `BChessGalleryTests/GallerySuites/SnapshotGalleryTests`; xFractal's
shorter selector names a top-level class) -parallel-testing-enabled NO
-collect-test-diagnostics never -enableCodeCoverage NO -testLanguage en -testRegion US` with
`TEST_RUNNER_BCHESS_MAC_SNAPSHOT=1 TEST_RUNNER_BCHESS_SNAPSHOT_ONLY="$ONLY"` in its environment; the log to a
temp file. On failure: the `gallery:` / `error:` lines and exit 1. Then the decode into `$WORK/png` (an `awk` per
file name, `base64 -D`; no file printed is a failure), `PREVIEW_GALLERY_OUT=previews/mac python3
scripts/preview-gallery.py --import "$WORK/png" ${ONLY:+--partial}` and `--check`, `network: none (I5)`, the
timings (build+test, total), `open previews/mac/index.html` unless `--no-open`. No simulator, no `simpool`.

The gallery: `previews/mac/index.html`, the images in `previews/mac/mac/` (the manifest's platform, the layout of
`previews/ipad/ipad/` from #33, D6), the manifest in `previews/mac/data/`. The iPhone gallery stays untouched (the
`coexist` guarantee already tested).

### 6. `scripts/preview-gallery.py`

Three small edits: `PASS_LABELS['mac'] = 'Mac'` (#33's table); the forced-appearance scan reads a list
`SCENARIO_FILES` (`BChessGalleryTests/GalleryScenarios.swift`, `BChessGalleryTests/GalleryFixtures.swift`,
`BChessMacGalleryTests/MacGalleryScenarios.swift`) and names the file in its message; `--coverage` scans `macOS/`
too and both scenario files. Nothing else: the card layout already widens a landscape card by its ratio
(`size_ratio / PHONE_ASPECT`), and the luminance check reads the window's PNG as any other (its transparent
rounded corners weigh nothing).

### 7. `AppStore/screenshots-mac.json` and the render

`displayType` `APP_DESKTOP`, 2880 x 1800, `locales: ["en-US"]`, `textStyle` centred above the window (xFractal's
`"top:120px; left:110px; width:2660px; text-align:center;"`), four slides, each one phone with
`"device": "window"` and a starting placement `left:0px; top:320px; transform: scale(.6);` (the 2880-px capture
centred, 1728 px wide, under the headline; tuned on the review page):

| id | capture | title | sub |
|---|---|---|---|
| hero | `document-window-engine-on` | Chess with its\nown engine | Play offline, and see who stands better, the evaluation and the best line. |
| variations | `document-window-variations` | Every move,\nevery variation | Where the game branches, click a line. The move list keeps variations and comments. |
| strengths | `document-window-new-game-sheet` | Five strengths,\nBeginner to Maximum | Pick your opponent. Below Maximum the computer takes a moment before it replies, like a human player. |
| dark | `document-window-engine-on.dark` | Light and dark | A wooden board in a walnut frame. No accounts, no ads, no network: the engine runs on your Mac. |

Backgrounds: the iPhone file's gradients for the same ids. Rendered with
`app-store-screenshots --config AppStore/screenshots-mac.json --captures previews/mac/mac` into
`.build/app-store-screenshots-mac/en-US/` (the command's `.build/app-store-<config name>/`); no upload (that is
`/release`'s, after Jean's go).

### 8. Docs

`.claude/skills/preview-gallery/SKILL.md` (the Mac pass: script, target, files, 6 cards, what differs off screen,
"Mac" in the groups line; item 5's "BChess has no Mac pass yet" replaced), `.claude/skills/app-store-screenshots/SKILL.md`
(#33's "There is no Mac renderer…" paragraph replaced by the pass and the render command), `.claude/skills/develop/SKILL.md`
(the mac test gate line wrapped in the container lock, §1; the warnings gate gains `-target BChessMacGalleryTests` on
the macOS SDK; the gallery gate: `scripts/snapshot-mac.sh --no-open` when the plan touched a Mac screen, green
`CHECK OK [en]: 6 cards …`), `AGENTS.md` ("A macOS-only view has
no scenario until the Mac renderer exists" becomes: a Mac screen gets a scenario in
`BChessMacGalleryTests/MacGalleryScenarios.swift`, rendered by `scripts/snapshot-mac.sh`), and
`planning/README.md`'s APP-3 row (the owed Mac sheet check is closed by the gallery card).

### What it reuses, by file and symbol

`GalleryScenarios.Fixture`, `.defaults`, `.engineOnDefaults`, `GalleryScenario.slug(of:)` and the `matching`
predicate (`BChessGalleryTests/GalleryScenarios.swift`); `GallerySuites`' serialized parent
(`GalleryScenarioTests.swift`); the manifest shape and the `gallery:` lines (`SnapshotGalleryTests.ManifestEntry`);
`preview-gallery.py`'s `platform_of`, `size_ratio`, `PREVIEW_GALLERY_OUT`, `--partial`, `--check` and #33's
`PASS_LABELS`; `DocumentWindow`, `WindowTitle`, `GameText.title`, `ChessDocument`, `NewGame(remembered:)` and
`NewGame.remember(in:)` (the sheet's own reader and writer, now over an injected suite), `SettingsView`,
`appTheme()`; xFractal's `OffscreenWindow`, `capture`, the
base64 transport and `snapshot-mac.sh`; Chirpter's `settle`, sheet `draw(… behind:)` and composite; Folio's
`.fits` measure; the renderer's `"device": "window"` and `textStyle`.

## Alternatives rejected

- **One scenario file compiled by both targets** (`#if os(iOS)` around the iOS sizes, shells and `all`). The iOS
  list is 48 scenarios of phone sizes, size classes and fold regions; the Mac wants six windows with a title, a
  sheet and a frame. Gating that file leaves two lists interleaved in one file and a `GallerySize` that means
  nothing on the Mac. Sharing the fixtures (what is actually common) is the honest split.
- **`NSHostingView` alone, or `cacheDisplay`.** No toolbar, no title bar, no sheet (the recipe's table). The
  captures must look like the app window.
- **ScreenCaptureKit of an on-screen window.** Needs an unlocked session and the Screen Recording permission,
  and flashes the window; the recipe rejects it for every repo.
- **The Mac test writing into `BCHESS_SNAPSHOT_DIR`** (Folio, Chirpter). Their hosts are ad-hoc signed gallery
  variants whose containers the shell can read; BChess's host is the team-signed app, whose container macOS keeps
  other processes out of (xFractal's finding, same signing). Base64 over stdout costs one `awk` per file.
- **A dedicated gallery host bundle id** (Chirpter's `.gallery` host). It frees the run from Jean's running app
  and defaults, at the price of a signing variant and a container to create; six windows do not justify it. D1
  and D3 list what the shared host costs.
- **`applicationShouldOpenUntitledFile` in an app delegate** to keep the host's launch window away. APP-9 built it
  and found AppKit never asks (`APP-9:74-77`); the test closes the window instead.
- **The `Settings` scene rendered through its own `Settings` window**: SwiftUI creates that window; the test
  renders `SettingsView` in its own titled window, the way it renders the document window.
- **The sheet over the host's standard defaults, or those defaults cleared for the render** (revision 1's D3).
  The first captures Jean's names and his last layout; the second edits his real preferences. Rejected in Codex
  round 1 for the injected suite seeded through `NewGame.remember(in:)`.
- **A test-only env var read by `DocumentWindow`** to pick the suite. A production view reading a test variable
  is a hook in app code; a defaulted init parameter is the same size and plain Swift.

Codex plan round 1: every SHOULD-FIX and SIMPLER finding accepted (the header's changelog); nothing rejected.

## Test plan

Failing tests first (step 2's tests are written against the stubbed renderer and go green with it):

- `MacGalleryScenarioTests` (`BChessMacGalleryTests/`, the gate runs it every time, no env var):
  - `slugsAreUnique` and `everyScenarioBuilds` — the list is well-formed and each `build()` returns a view
    (`DocumentWindow` over `ChessDocument`, `SettingsView`); proves the Mac target compiles the Shared views and
    the shared fixtures.
  - `middlegameParses` — `FEngine().loadAllGames(Fixture.middlegame)` is true (the iOS `allPGNs` test covers it
    too; this one runs on the Mac without a simulator).
  - `documentWindowMountsWithThePlayersAsTitle` — `MacRenderer.mount` of the engine-on scenario (light), then the readiness
    poll: `window.title == "You vs Club Player"`, `window.toolbar?.items.count >= 4`, the window never visible
    (`isVisible == false`). Red before `mount` sets the hosting controller and runs the passes.
  - `newGameSheetAttaches` — the new-game-sheet scenario mounted: `attachedSheet != nil` within the timeout. Red before the passes
    run `onAppear`.
  - `sheetShowsTheSeededChoice` — the three sheet scenarios' `NewGame(remembered:)` read back from their seeded
    suites equals what each seeded (Club / friend with "Anna" and "Jean" / Maximum at 10 s), and
    `DocumentWindow(…, newGameDefaults:)` is the init the scenario calls; proves the seam carries the seed through
    the production reader. Red before the seam exists (the parameter is missing: a compile failure stands in for red,
    as the seam is one line).
  - `manifestSizeIsTheMountedFrame` — for the Settings scenario, `MacWindowSize.points(for:)` equals the mounted
    window's frame size, and the manifest entry encodes it as "460x<h>"; for a `.frame` scenario, "1440x900".
    Red before the measure (a `.fits` entry would read "460x0").
  - `frameCaptureIs2880x1800` — the variations scenario rendered light: the PNG decodes to 2880 x 1800 px. Proves
    the frame size survives SwiftUI's layout and the 2x. This is the test that catches the resize risk.
  - `sheetIsCompositedInsideItsFrame` — the new-game-sheet scenario mounted and settled with its sheet attached;
    `draw(window)` (the parent alone, the sheet's region shows the dimmed parent) and `capture(window)` (the
    composite) of that same settled state are compared pixel by pixel: every differing pixel lies inside the
    sheet's frame relative to the parent (`sheet.frame` offset by `parent.frame.origin`, times 2), and more than
    half of the pixels inside that frame differ (the sheet's content, not a dimming shade). Red when the composite
    is skipped (no difference) or drawn at the wrong offset (differences outside the frame).
  - The two capture tests carry `.enabled(if: NSScreen.main?.backingScaleFactor == 2, "needs a Retina display")`:
    the capture fails by name on 1x by design, so on 1x they are skipped by name, never failed or faked.
- `MacGallerySuites/MacSnapshotGalleryTests.renderEveryMacScenarioInLightAndDark` (opt-in): the production path from the scenario
  list through `MacRenderer` to the base64 lines; `scripts/snapshot-mac.sh --no-open` ends with
  `CHECK OK [en]: 6 cards, light and dark complete and correctly lit`.
- `scripts/test_snapshot_gallery.sh` gains `mac_run`, `mac_test_fails`, `mac_no_file` (the stub `xcodebuild`
  prints `mac-gallery-file` lines for a 4 x 4 PNG pair and a manifest **only when its arguments carry the exact
  selector** `-only-testing:BChessMacGalleryTests/MacGallerySuites/MacSnapshotGalleryTests`, and prints nothing
  for any other selector, so a script naming the wrong suite fails `mac_run` with "the test printed no file"
  instead of passing on a stub that answers regardless; `mac_run` also asserts the selector in the stub log; the
  script decodes the files, imports under `previews/mac`, reaches `CHECK OK`, locks the container and
  DerivedData under `buildlock`, calls `caffeinate`, never calls `simctl` or `simpool`; a failed test or no
  printed file exits 1) and `layout_mac` (the real page
  script on a fake Mac manifest with a "1440x900" and a "460x380" entry: images in `mac/`, the page says "Mac",
  and each figure carries the `--r` width ratio `size_ratio` derives from its size — `style="--r:3.48"` and
  `--r:2.63` — so the recorded size reaches the card through import and page generation). Each new field's path:
  the manifest's `platform: "mac"` and the mounted `size` are written by the test (§4), placed and read by
  `do_import` / `platform_of` / `size_ratio`, shown by the page, and checked by `layout_mac` and
  `manifestSizeIsTheMountedFrame`.
- Existing tests unchanged in meaning: `GalleryScenarioTests` (iOS) still parses every fixture, now from
  `GalleryFixtures.swift`; the iOS gallery renders its 48 cards (`scripts/snapshot-gallery.sh --no-open`).
- Views are exempt from unit tests; the six cards are read in both appearances (owed check).

No data source is replaced; no file format is touched.

## Invariants

- **I1 — Files keep opening.** Holds: `GameState`, `ChessDocument` and the PGN writer are untouched; the new
  fixture is a test constant.
- **I2 — A search result only lands on the position it was computed for.** Holds: the engine-on scenario starts an analysis
  in the host's engine on its own `GameSession`, which the closed window discards; the render never waits on the
  search (it waits on the title and a fixed settle) and no callback reaches another scenario's session.
- **I3 — The engine stays portable.** Not applicable: `Shared/Engine/` untouched.
- **I4 — The UCI tool keeps working.** Not applicable.
- **I5 — Private and offline.** Holds: nothing new ships in either app (test target, scripts, slides); no network
  (the script prints `network: none (I5)`); `PrivacyInfo.xcprivacy` unchanged (the test's `UserDefaults` suites are
  test code).

## Risks and rollout

- **SwiftUI resizes the window to its content's ideal size** (Chirpter measured 1280 x 852 whatever was asked).
  `frameCaptureIs2880x1800` catches it; the fix order is `sizingOptions = []` (planned), then
  `contentMinSize = contentMaxSize = content size` for the `.frame` case (the game layout is fluid, so pinning
  cannot cut it off, unlike Chirpter's sidebar), never a scaled PNG.
- **The toolbar or the window background is not bridged** through a plain `NSWindow`. The toolbar is the
  recipe's proven case (Folio's `NavigationSplitView` + `.toolbar`); if it is missing, `host.sceneBridgingOptions
  = [.toolbars]`. `.containerBackground(for: .window)` may not reach an AppKit-made window: then
  `window.backgroundColor = NSColor(Walnut.background)`; `ContentView` paints its own Walnut background either way.
- **Chrome that differs from the on-screen window, accepted** (the recipe): neutral dark mode (no wallpaper), no
  document proxy icon in the title bar (no `NSDocument` behind the window; the title and subtitle are the app's own
  `WindowTitle`), inactive selection where the key overrides do not reach.
- **The host is Jean's BChess.** A gate or a pass launches a second instance while his is running, both on the
  same container; the scenarios read and write their scratch suites only (the sheet's suite is injected, §2), so
  his preferences stay untouched. Run the pass with his BChess closed; the script does not refuse (xFractal does
  not either). Two gates or passes from two worktrees serialize on the container lock (§1).
- **A window flashes on every mac gate** (the host's untitled game and its sheet, §1). Accepted in A of D1; B
  removes it at the price of a scheme and a gate line.
- **Retina only.** A 1x display fails the render by name (and skips `frameCaptureIs2880x1800`).
- **The engine-on card differs per run** (live analysis numbers), as its iOS twin does.
- **File-format compatibility:** none touched. **A real device:** none; the Mac is the device. The visual check
  against the real window on screen is owed.
- **Rollout:** the branch lands after #33; `/preview-gallery` and `/app-store-screenshots` docs ship with it; the
  App Store set is rendered to `.build/` for Jean's review and uploaded only by `/release`. Timings unmeasured
  before the run: xFractal renders four windows in seconds; the first build of the Mac host in the gallery's
  DerivedData is the cost (minutes).

## Decisions left open for Jean (recommended defaults)

- **D1 — Where the target runs.** (A, recommended, as asked) in the `"BChess (macOS)"` scheme's test action: the
  gate line `xcodebuild test -scheme "BChess (macOS)"` already runs it; cost: the host app (its untitled window and
  sheet) opens on screen for the seconds its plain tests take, on every mac gate. (B) a dedicated scheme `BChess Mac
  Gallery` (Folio's `FolioMacTests`), one more gate line, no window in the plain mac gate.
- **D2 — The hero's game.** (recommended) a new `Fixture.middlegame` (Ruy Lopez Closed, 16 moves each, white to
  move) so the 1440-pt move list is not three moves in an empty card; or `Fixture.ruyLopez` as on the iPhone.
- **D3 — The sheet cards.** (recommended) three, one per layout of the Mac sheet (Club for the slide, A friend
  with two names, Maximum with the thinking time), each over a seeded scratch suite through the one app seam
  (`DocumentWindow(…, newGameDefaults:)`); or the slide's Club card only.
- **D4 — Transport.** (recommended) xFractal's base64 lines on stdout; or a `BCHESS_SNAPSHOT_DIR` inside the
  container's `Data/tmp`, if the shell can read a team-signed app's container on this Mac (xFractal found it cannot).
- **D5 — The Settings window card.** (recommended) included, for coverage; or the three slide windows only.
- **D6 — Folder.** (recommended) `previews/mac/` as its own gallery with the images in `previews/mac/mac/`,
  the iPad pass's layout, `--captures previews/mac/mac`; or the images directly in `previews/mac/` with the
  gallery check skipped (xFractal's plain folder, no light/dark check: not what was asked).
- **D7 — What 1440 x 900 is.** (recommended) the window frame, title bar included, so a capture is exactly 2880 x
  1800 px; or the content size (the PNG then is 2880 x ~1904 and the slide scales it).

## Steps

1. **Shared fixtures, the seam and the Mac target** — `GalleryFixtures.swift` (the moves, `gallerySlug(of:)`,
   `galleryMatches`, `Fixture.middlegame`), `DocumentWindow`'s `newGameDefaults` parameter, `BChessMacGalleryTests`
   in `project.yml` with the scheme's test target and `-ApplePersistenceIgnoreState YES`, `xcodegen generate`,
   `MacGalleryScenarios.swift` (the six scenarios, the serialized `MacGallerySuites` parent) and the list tests
   (`slugsAreUnique`, `everyScenarioBuilds`, `middlegameParses`, `sheetShowsTheSeededChoice`), and the develop
   skill's mac gate line with the container lock (§1). Gate: the mac tests run the new target under that line;
   the iOS gallery still renders 48 cards.
2. **The renderer and the snapshot test** — `MacRenderer.swift` (mount, readiness, `draw`, `capture` with the
   sheet composite, `MacWindowSize.points(for:)`), the mount, size and capture tests (red first),
   `MacSnapshotGalleryTests.swift` with the base64 transport and the manifest. Gate: the mac tests; a hand run of
   the test with `TEST_RUNNER_BCHESS_MAC_SNAPSHOT=1` and
   `-only-testing:BChessMacGalleryTests/MacGallerySuites/MacSnapshotGalleryTests` prints six `gallery:` lines.
3. **`scripts/snapshot-mac.sh`, the page script and the lifecycle tests** — the script (locks, decode, import
   under `previews/mac`, check, timings), `preview-gallery.py` (`PASS_LABELS`, `SCENARIO_FILES`, `--coverage`),
   `test_snapshot_gallery.sh` (`mac_run`, `mac_test_fails`, `mac_no_file`, `layout_mac`), and the docs (§8). Gate:
   `scripts/test_snapshot_gallery.sh` all green; `scripts/snapshot-mac.sh --no-open` ends `CHECK OK [en]: 6 cards`;
   the six cards read in both appearances.
4. **The Mac App Store slides** — `AppStore/screenshots-mac.json` (§7), rendered with `app-store-screenshots
   --config AppStore/screenshots-mac.json --captures previews/mac/mac` into `.build/app-store-screenshots-mac/`,
   the four PNGs read and the placement tuned; no upload. The `app-store-screenshots` skill's Mac paragraph points
   at it.

## Deviations (as built)

From the implementation:

- The off-screen window reports `isVisible == true` (a sheet attaches to its parent only when AppKit takes the parent for
  visible; the window is still never ordered on screen), so the mount test checks `occlusionState` instead of
  `isVisible == false`; presenting the sheet moves the window, so `settle` puts its origin back.
- A `.fits` window's size is read from a mounted window (`sizeThatFits` plus a title bar is 6 pt off what SwiftUI gives).
- The Settings scenario is titled by `.navigationTitle("Settings")` and waits for it.
- `BChessMacGalleryTests` compiles no engine sources (the host provides them, as for the iOS gallery target).
- The iOS gallery has 49 cards on the base branch, not 48.

From Codex's code round 1:

- `NewGameSheet` takes the defaults it remembers a new game in (`defaults`, default `.standard`); `DocumentWindow` passes
  `newGameDefaults`, so the injected suite is a real isolation boundary (the sheet's Start Game no longer writes the app's
  preferences from a gallery window).
- `sheetShowsTheSeededChoice` reads the name fields of the mounted sheets (one for Club and Maximum, "Anna" and "Jean" for
  the friend card), and `sheetReadsTheInjectedSuite` mounts a sheet over a suite holding a name nobody else has; both go
  red when `DocumentWindow` reads `.standard`. The list test only reads the seeded suites back.
- `manifestSizeIsTheMountedFrame` calls the writer the snapshot test uses (`MacSnapshotGalleryTests.manifestData`) and
  decodes its entries; `render` returns the PNG and the mounted frame, which sizes a rendered entry, and only an unrendered
  `.fits` entry (a partial run) is measured on a probe window. A capture whose pixels are not the frame x 2 fails by name.
- `GalleryManifestEntry` (shared, next to the fixtures) replaces the iOS test's private `ManifestEntry`; an unset optional
  is omitted from the JSON, so the iOS manifest is unchanged.
- `mac_only` seeds a gallery with a second card, runs `--only`, and asserts the filter in the test runner's environment,
  `--partial` at the importer (the card outside the filter survives) and an empty filter without `--only`.

From Codex's code round 2:

- The earlier name-field oracle could not tell the Club and Maximum sheets apart, so the sheet reports through
  `NewGameSheetProbe`, read from an environment value (`newGameSheetProbe`, nil in both apps): the choice the mounted sheet
  holds, the defaults it remembers in and the action of its Start Game button. `sheetShowsTheSeededChoice` mounts each
  sheet scenario and compares the held choice with its own seed (Club, Friend with Anna and Jean, Maximum with its thinking
  time and `showsThinkingTime`) and the suite it was given; pointing the Maximum scenario at the Club suite fails it.
- `startGameWritesTheInjectedSuite` presses Start Game on a sheet over a probe suite (Maximum, 30 s, a unique name), checks
  that the suite received it and that `.standard` does not hold the name. The test snapshots `.standard`'s `newGame.*`
  keys and puts them back in a `defer`, so a regression that writes there does not leave the host's preferences changed.
  Replaces `sheetReadsTheInjectedSuite`.
- `manifestSizeIsTheMountedFrame` feeds the writer a captured frame (1234 x 567) that no probe would measure, so dropping
  the `rendered[...]` branch fails it.
