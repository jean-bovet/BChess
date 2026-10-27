# APP-9 — Mac launch: a new game, a larger window, no gap beside the board

Status: Implemented on main 2026-10-27 — Jean: go, D1–D5 as recommended (revision 4 — Codex round 3: the column never narrower than its rows'
minimum width (the one bounded, visible overflow: the board narrower than the rows), the loop without
a cap (it ends on its own, so no capped case and no gap), the two extra fixtures replaced by one
worst case — near-maximum captures with variations at the minimum height, both appearances, two text
sizes — with the board isolated from the selected variation's border, and D3 re-justified as a
usability floor. Revision 3 — Codex round 2: the unspecified proposal answers the
board's ideal size, a termination rule that guarantees fit, the rows' overflow stated and the minimum
window raised to 720 × 500 so the worst row fits, two more oracle fixtures (variations at a short wide
size, also at a larger text size; a capture-heavy position with the gutter), and an edited unsaved
game in the restoration case. Revision 2 — Codex round 1: the column layout confined to the wide
branch, its sizing clamped and measured at one final width with the evaluation-bar gutter accounted
for, an engine-on wide oracle, and a launch verification matrix with the scripted assertions named).

Jean's request (2026-10-27): "for the macos app, when starting, I want a new document to be opened
directly (right now, the user sees the file selector which is not a great experience). Also, ensure the
size of the window is larger and has the board game and the move list with no gap in between (see
screenshot as example)." The screenshot is a 929 × 699 BChess window: "Casual Player · Black" above a
walnut board of about 550 pt, "Jean · White · your move" below it, the MOVES card beside the board
filling the height, the two about a margin apart, nothing empty between them.

## Problem, with evidence

All three findings were measured on the Debug build of HEAD (`fa89dfa`, built 2026-10-27 08:50) by
launching it with `-ApplePersistenceIgnoreState YES` and asking AppKit under `lldb`:

1. **Launch shows the Open panel.** The only window after launch is an `NSOpenPanel` (880 × 448);
   `NSDocumentController.shared.documents` is empty. The app delegate is `SwiftUI.AppDelegate`, which
   answers both `applicationShouldOpenUntitledFile:` (YES) and `applicationOpenUntitledFile:`: the panel
   is SwiftUI's own answer to AppKit's untitled-file question, not a failure of the document setup.
   `defaultType` is `ch.arizona-software.bchess.game` and `[NSDocumentController.shared newDocument:nil]`
   opens a `SwiftUI.AppKitWindow` titled "You vs Club Player" with the players sheet — the path
   `macOS/DocumentWindow.swift` (toolbar "New Game") and `macOS/GameCommands.swift` (Game ▸ New Game)
   already use, decided in APP-2 D5. Nothing in the repo touches launch: no
   `NSApplicationDelegateAdaptor`, no delegate (`Shared/BChessUIApp.swift:35-47` is the whole Mac scene).
2. **A new window is 900 × 450.** That is the window `newDocument:` produced (and the size a `.pgn`
   opened at launch gets). No `.defaultSize` anywhere; the content's minimum is 380 × 141, so the window
   can also be shrunk until the board vanishes while the 320 pt sidebar stays.
3. **The gap between the board and the move list is the board column stretching.** In
   `Shared/Views/ContentView.swift` the wide layout is
   `HStack { boardColumn.layoutPriority(1); sidebar.frame(width: 320) }` (lines 140–148). The board is
   always square (`BoardFrame` ends in `.aspectRatio(1, contentMode: .fit)`, `BoardView.swift:71`), but
   `boardColumn` is a `VStack(alignment: .leading)` of `PlayerRow`, board, `PlayerRow`, `VariationCards`
   (lines 97–104), and `PlayerRow` ends in `Spacer(minLength: 0)` (`PlayerRow.swift:54`) to put the
   captured pieces at the trailing edge. So the rows take all the width the `HStack` proposes (everything
   but 320 pt and the spacing, because of `layoutPriority(1)`), the column is that wide, the square board
   sits at its leading edge, and the slack is the empty band between the board and the MOVES card. The
   band grows with the window: in a 900 × 450 window the board is about 290 pt in a 540 pt column; the
   iPad gallery card (`previews/iphone/game-screen-wide.png`, 1180 × 820) shows about 100 pt of it. iPad
   landscape shares this branch (APP-2, decided 2026-10-05; APP-8 kept it), so the fix is shared.

## Design

Three small changes, one commit each. Nothing new in the engine, bridge or model.

### 1. Launch opens a new game — `Shared/BChessUIApp.swift` (as built)

AppKit shows the Open panel at launch, and on a Dock click with no window, while the app config
`NSShowAppCentricOpenPanelInsteadOfUntitledFile` is on, which is its default for a foreground app. With it
on, `-[NSApplication _doOpenUntitled]` calls `-[NSDocumentController openDocument:]` directly and never asks
the delegate. With it off, AppKit opens a new document through `DocumentGroup`, the way File ▸ New and Game ▸
New Game do. So `BChessUIApp` gets, under `#if os(macOS)`, an `init()` that registers the default off
(`UserDefaults.standard.register(defaults:)`, which writes nothing to disk):

```swift
UserDefaults.standard.register(defaults: ["NSShowAppCentricOpenPanelInsteadOfUntitledFile": false])
```

The new window is the existing one: `DocumentWindow(isNew: file.fileURL == nil)` offers the players sheet once
(`DocumentWindow.swift:84-90`). AppKit still asks only when nothing else opened a window: a file opened at launch
and restored windows get no extra untitled game from this change.

**Rejected: an `NSApplicationDelegateAdaptor` answering `applicationShouldOpenUntitledFile`** (this plan's first
design), and its fallback (return `true`, open the game in `applicationOpenUntitledFile`). Both were built and
the panel still appeared: breakpoints on both methods, SwiftUI's and ours, never fired, because AppKit's
`_doOpenUntitled` decides on the app config before it ever consults the delegate. The delegate and its file
were removed.

### 2. The wide layout's board column is as wide as the board — `Shared/Views/BoardColumn.swift` (new), `ContentView.swift`

**Scope (Codex round 1, SIMPLER, accepted):** the wide layout only — both of its branches (no fold, and
the fold inside the area). The tall layout keeps its `VStack`, so the iPhone and the Duo tabletop pose do
not change at all, and nothing rests on the new layout dividing space like a `VStack` in a vertical stack.
The rows are shared: `ContentView` gets `@ViewBuilder private var boardRows: some View` (the two
`PlayerRow`s, the board marked `.layoutValue(key: BoardColumn.IsBoard.self, value: true)`, `VariationCards`)
used by `VStack(alignment: .leading, spacing: 10) { boardRows }` in the tall layout and by
`BoardColumn(leading: boardLeading) { boardRows }` in the wide one.

```swift
/// The wide layout's board column: the rows and the board, as wide as the board. The board is the largest
/// square that fits the proposal once the rows have their height, and every row spans that width, so the
/// captured pieces end at the board's edge and the column never stretches past it (a VStack gives the rows
/// all the proposed width, and the slack lands between the board and the move list).
struct BoardColumn: Layout {
    /// The evaluation bar's gutter on the board's leading side (`ContentView.boardLeading`): the board subview
    /// is that much wider than its square, and so is the column.
    var leading: CGFloat
    var spacing: CGFloat = 10
    /// Marks the board among the subviews; the others are rows.
    struct IsBoard: LayoutValueKey { static let defaultValue = false }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ())
}
```

**Sizing, one `nonisolated` static function both methods call** (same inputs, same answer, so what is
placed is what was measured), with `rows(at width)` = the heights of the non-board subviews measured at
`ProposedViewSize(width: width, height: nil)` plus `spacing` between consecutive subviews, and the
proposal's missing dimensions treated as unconstrained:

- **Unspecified is not infinite.** A nil dimension asks for the ideal, as `ProposedViewSize.unspecified`
  does (round 2). With both nil the answer is the column's ideal: `side` = the board subview's own ideal
  (`sizeThatFits(.unspecified).height`, what the tall `VStack` reports today for the same probe — the
  `GeometryReader`'s 10 pt; the window's size comes from `.defaultSize`, not from here), `r = rows(at:
  side + leading)`, so `fixedSize()` and ideal-size probes stay finite. With one nil dimension the other
  decides, as `aspectRatio` does today: `(w, nil)` gives `side = max(0, w − leading)`; `(nil, h)` gives
  `side = max(0, h − rows(at: ∞))`, refined by the loop below with `width = ∞`. Infinite dimensions are
  limits that do not bind: `(∞, h)` is `h − r`, `(w, ∞)` is `w − leading`, `(∞, ∞)` is `∞` in both, like
  the flexible column today.
- **The rows' minimum width** (round 3): `rowsMin` = the widest row's `sizeThatFits(ProposedViewSize(width: 0, height: nil)).width`.
  For `PlayerRow` that is its texts truncated to their ellipsis, the `Spacer(minLength: 0)` collapsed, and
  the captured-piece cells (22 pt each) and the material points, which never shrink — fifteen captures
  make about 370 pt; for `VariationCards` a few dozen points. The column is never narrower than `rowsMin`
  (below), so no row ever draws into the move list.
- **The loop, for two finite or infinite dimensions.** Start at `w = width` (the rows' first measurement
  width). Each pass: `r = rows(at: w)`, `side = max(0, min(width − leading, height − r))`,
  `w′ = max(side + leading, rowsMin)`; if `w′ ≥ w` stop, else `w = w′` and pass again. No cap (round 3):
  `w` strictly decreases on every pass that continues, and `r(w)` takes finitely many values (text wraps
  in whole lines), so the loop ends on its own — with the app's content (one footnote that wraps, one-line
  player rows) in two or three passes — and there is no capped case to bound.
- **The answer, consistent and fitting.** At the stop, `r` was measured at `w`, and the board's side is
  taken from that measurement, bounded by the column: `side = min(side, w − leading)`. The column reports
  `(w, side + r)` — the rows are placed at the width they were measured at, and `side + r ≤ height` holds.
  When the board decides the width (`w == side + leading`, every normal case) there is no slack. When the
  rows' minimum decides it (`w == rowsMin > side + leading`), the board keeps its height-limited side at the
  leading edge and the column is wider than the board by exactly `rowsMin − side − leading`: that is the
  one bounded, visible overflow — the capture strip ending past the board, nothing hidden, nothing drawn
  under the move list — and it needs a window too short for its rows (at 720 × 500 with fifteen captures
  and the variation cards showing, the board is about 300 pt and the slack about 50 pt; without the cards
  the 360 pt board takes the strip). On the first pass `w` is the proposal itself, so a column proposed
  less than `rowsMin` (a wide area under about 400 pt, which no Mac window within D3 and no iPad or Duo wide
  area gives) is `width` wide and its rows overflow the way the tall layout's do today on a narrow iPhone.
- **Clamping.** A zero or too-small height gives `side = 0` and the height `r` (the column's minimum, the
  rows alone — the `VStack` today never shrinks its rows either). Nothing is ever negative.
- Placement: top to bottom from `bounds.minY`, each row proposed `(w, its measured height)`, the board
  `(side + leading, side)` (its leading padding takes `leading`, the square takes `side`), anchored
  `.topLeading`, `spacing` between consecutive subviews.
- No cache; the struct is not `@MainActor` (`Layout` methods are nonisolated).

The column's horizontal profile under a given height is `[leading, leading + (height − r)]`, so the
`HStack` with `boardColumn.layoutPriority(1)` (kept: it is what makes the stack propose the column
everything but the sidebar's minimum, so the board gets the larger of the two limits) proposes the column
`W − spacing − 320`, and `side` is the lesser of that and `height − r`. The sidebar then takes what is
left: `.frame(minWidth: sidebarWidth(placement), maxWidth: .infinity)` instead of `.frame(width:)`
(decision D2), so the MOVES card ends at the window's edge in a wide window, as in Jean's screenshot, and
never a band of background. `sidebarWidth` (APP-8's `min(320, area.width / 2)`) stays as the minimum. The
fold branch's `boardColumn.frame(width: primary)` gets `alignment: .topLeading`, so a height-limited column
keeps the board at the leading edge of its half, where it is today, instead of centring in it.

### 3. A larger default window and a floor — `Shared/BChessUIApp.swift`, `macOS/DocumentWindow.swift`

`.defaultSize(width: 960, height: 708)` on the `DocumentGroup` (decision D1; built as `960 × 760`, the window frame, which is 708 pt of content under a 52 pt title bar and toolbar): with the 16 pt padding, the
8 pt spacing, two 28 pt rows and a 320 pt sidebar, both limits give a 600 pt board (960 − 32 − 8 − 320 =
600; 708 − 32 − 76 = 600), so the first window shows the screenshot's layout with a larger board and no
slack; the sidebar absorbs any row-height difference. `ContentView(session:).frame(minWidth: 740, minHeight: 500)`
in `DocumentWindow` (decision D3, 720 in revisions 1–4, raised to 740 after the code review: see the Deviations) keeps every capture row beside a 320 pt move list at the smallest size (the widest row, fifteen captures in dark mode, measures 378 pt; 740 − 32 − 8 − 320 = 380; the light-mode row is 366) instead of letting the window shrink to 380 × 141. It is a usability floor,
not what keeps the rows out of the move list: that is the column's own minimum (design 2), which the iPad,
with no window minimum, relies on alone. `defaultSize` applies to a window without a remembered size, so existing windows and
restored sessions keep theirs. The implementer reads the real window frame at runtime and adjusts the two
numbers if the row height differs (test plan).

## Alternatives rejected

- **Open the game in `applicationDidFinishLaunching` when `documents.isEmpty`.** Files opened at launch
  arrive after that call (the `odoc` event), so a double-clicked game would open next to an extra untitled
  one; AppKit's untitled question is asked exactly when a new window is wanted.
- **Return `true` and implement only `applicationOpenUntitledFile`.** Works only if SwiftUI forwards that
  method; the `Should` method is the one with the visible forwarding pattern. Kept as the fallback.
- **A `WindowGroup`-based Mac shell.** Drops the document behaviour (I1's Finder path, Save, Revert,
  Undo through the document) for a launch fix of five lines.
- **Fixing the wide branch without a `Layout`** (asked in round 1; each was checked for correctness):
  - *`.aspectRatio(1, contentMode: .fit)` on the column*: makes the column a square `S = min(W − 328, H)`,
    the board inside it `S − rows`, the rows still `S` wide: the gap shrinks to the rows' height (about
    76 pt) but does not go away.
  - *`.fixedSize(horizontal: true)` on the column or the rows*: the rows take their text width, the
    `Spacer` collapses, and the captured pieces no longer end at the board's edge (the UI-WALNUT design).
  - *Measuring and feeding back* (the board's rendered side, or the window size plus the rows' heights,
    through `onGeometryChange` into a `.frame(width:)` on the column): a `@State` loop that settles over
    several frames, caps the column at the old side when the window widens (a width-limited board can no
    longer grow), and re-wraps the variation cards on every pass. The `Layout` has the subviews' real sizes
    in one pass.
  - *The HStack proposing the column its height as width*: no stack modifier expresses "width follows a
    sibling's height minus the rows"; that is what the `Layout` protocol is for.
- **Shrinking the capture cells** (`minimumScaleFactor` or a `ViewThatFits` in `PlayerRow`) so a row always
  fits the board (round 3's other option): it changes `PlayerRow` on every platform, including the iPhone
  where nothing is wrong, for a case only a too-short window reaches; the column's floor is one `max` in
  the layout and keeps the row's look.
- **The same `Layout` in the tall layout too** (revision 1): it changed the Duo tabletop rows for no
  requested reason and relied on the new layout reporting the same profile as a `VStack`; confined to the
  wide branch instead (round 1, SIMPLER).
- **Keep the 320 pt sidebar and centre the pair.** Correct too (no gap between them), but a wide window
  gets equal bands of background on both sides instead of a wider move list; offered in D2.
- **A Mac gallery renderer** to snapshot the Mac window. Out of scope (AGENTS: "a macOS-only view has no
  scenario until the Mac renderer exists"); the wide layout is covered by the iPad scenario, which renders
  the same branch.

## Test plan

- **`BChessGalleryTests/GalleryScenarioTests.swift`, new pixel oracle** `wideLayoutPutsTheMoveListBesideTheBoard`
  (iOS-hosted, the production layout through the production render, like the fold oracles): render the
  wide game screen (`GalleryScenarios.gameScreen(humanToMoveSession(), fold: nil)` at
  `GallerySize.ipadLandscape`, 1180 × 820) in light and dark, twice: with `GalleryScenarios.defaults`
  (engine off) and with `GalleryScenarios.engineOnDefaults` (engine on, through the production `@AppStorage`
  read of `showEngine`, which adds the evaluation-bar gutter). In each capture take
  `boxes(in:style:trailing: true)` and expect `card.minX − frame.maxX ≤ 12.5` (the `HStack` spacing plus
  the frame's corner allowance the fold oracle uses), `card.maxX ≥ 1180 − 16 − 0.5` (the card fills to the
  padding, D2), and with the engine on `frame.minX ≥ 16 + EvaluationBar.width + 6 − 0.5` with the board
  frame square to within a point (the gutter is reserved, the square is not squeezed). Red on HEAD: the card
  starts about 100 pt after the board. Red proof per the skill: commit the fix, revert the fix's lines, run
  `-only-testing:BChessGalleryTests/GalleryScenarioTests`, restore with `git checkout --`.
- **One worst-case fixture in the same oracle** (rounds 2–3, through the same production render): a new
  `Fixture.worstRow` PGN — a legal game with at least fourteen captures by one side whose current position
  has variations, so `VariationCards` shows (the implementer builds it the way `Fixture.arrowsAndCards`
  carries its variations) — with `engineOnDefaults` (the gutter), at the minimum content size (720 × 500 here; 740 × 500 as built, plus 720 × 500 below it: see the Deviations),
  in light and dark, as is and with `.dynamicTypeSize(.accessibility1)` on the view (the system's own
  larger text: taller rows, a smaller board). This is the case where the rows' minimum decides the width:
  the footnote wraps (the loop), and the capture strip is wider than the height-limited board (the floor),
  so one fixture reaches both. Assertions, with the board isolated as below:
  - *the board*: `frame.minX ≥ 16 + EvaluationBar.width + 6 − 0.5` and the frame box square to within a
    point (the gutter is reserved, the square not squeezed);
  - *the column ends where the card begins*: `columnMaxX` = the largest x of any non-`Walnut.background`
    pixel left of the MOVES card (region `x < card.minX − 4`); expect `card.minX − columnMaxX ≤ 12.5`
    (no gap between the column and the card) and `columnMaxX ≥ frame.maxX − 0.5` (the column ends at the
    strip or the board, never short of the board);
  - *no overlap*: no capture-strip pixel inside the card (the card's box, found as today, has the card
    colour only in the band above the first move row, i.e. the strip's rows), and no `Walnut.frame` or
    `Walnut.card` pixel below `500 − 16 + 0.5` (vertical containment: the column, cards included, ends
    inside the padding; the MOVES card ends there by construction).
  Green on HEAD for the containment parts, red for the adjacency part (the column today is 540 pt wide
  with a 300 pt board), which the red proof shows together with the first fixture.
- **Isolating the board from the selected variation's border** (round 3): `boxes` bounds every
  `Walnut.frame` pixel, and the selected variation card draws a 2 pt border in that colour
  (`VariationSelectionView.swift:90`) below the board, which would stretch the box down and could mask an
  overflowing card. The oracle finds the board first as the topmost contiguous run of rows that contain
  `Walnut.frame` pixels (the walnut frame is solid over its full height; the bottom player row separates
  it from the cards), and bounds the frame inside that band only — a `region` passed to the existing
  `box(_:_:in:region:)`, so `boxes` grows a `region` parameter and the fold oracles keep their calls. The
  card and containment searches use that box.
- **Existing fold oracles stay green** (`landscapeFoldKeepsTheBoardAndTheSidebarOffTheHinge`,
  `edgeFoldsKeepTheWideLayoutInTheUsableArea`, `narrowFallbackGoesTallInsideTheUsableArea`,
  `tabletopKeepsTheBoardAboveTheFoldAndTheStripBelow`): they bound the board and the card, the column is
  never wider than before, and the tall layout is untouched.
- **Gallery** (`/preview-gallery`, the iPhone pass and `--device duo`): `Game screen · Wide` and
  `Duo inner · Landscape · *` show the card beside the board; every tall card (iPhone, Duo portrait) is
  unchanged — the implementer compares their PNGs before and after, byte for byte. No new scenario: no new
  screen, and the Mac has no renderer.
- **No unit test for steps 1 and 3**, said plainly: they are AppKit launch glue and two scene modifiers.
  `BChessTests` compiles `Shared/Model` and the engine only (project.yml lines 128–136) and the UI tests
  are iOS-only. The `Layout`'s arithmetic is exercised through the pixel oracle above (the production path),
  not a parallel pure function.
- **Launch verification matrix** (step 1's gate, scripted by the implementer with `lldb -p <pid>`, no GUI
  permission needed; every launch of the built product is a separate instance started with `open -n -g`,
  only the test pids are quit — `pgrep -x BChess` first, never a BChess Jean is running). The assertions
  read `[[NSDocumentController sharedDocumentController] documents]` (count and each document's `fileURL`),
  `[[NSApp windows] valueForKey:@"className"]` (no `NSOpenPanel`; a `SwiftUI.AppKitWindow` per document)
  and the game window's `frame`/`contentMinSize`:
  1. *Fresh launch* (`-ApplePersistenceIgnoreState YES`): one document, `fileURL` nil, its window plus the
     sheet window, content 960 × 708 (step 3), `contentMinSize` 740 × 552 as built (see the Deviations).
  2. *A `.pgn` at launch* (`open -n -g -a <app> fixture.pgn`): exactly one document, `fileURL` = the fixture.
  3. *A legacy `.json` at launch* (I1): a file in the `GameState` shape `GameStateCodingTests` decodes,
     written to the scratchpad; exactly one document, `fileURL` = the file, no untitled one.
  4. *Dock reopen with no window*: in a running instance close the only window from `lldb`
     (`[window close]` on a clean untitled game closes silently), then `open -a <app>` from the shell (the
     `rapp` event the Dock sends): one new untitled document, no `NSOpenPanel`.
  5. *Restoration, pristine untitled window*: in instance (1) resize the window from `lldb`
     (`setFrame:display:`), then `[NSApp terminate:nil]` (restoration is on by default and keeps an untitled
     window); relaunch **without** the flag: exactly one document, `fileURL` nil, the window at the resized
     frame — restored, not duplicated. This case proves the window and the count only.
  5b. *Restoration, edited unsaved game* (round 2): open the `.pgn` fixture as in (2) — a game whose
     players and opening the window shows (`WindowTitle` sets the title to the players and the subtitle to
     the opening name from the session), then from `lldb` `[document duplicateAndReturnError:]`, AppKit's
     File ▸ Duplicate: a second, untitled, edited document holding the same moves; close the file's window,
     terminate, relaunch without the flag: exactly one document, `fileURL` nil, `isDocumentEdited` true,
     and its window's `title` is the fixture's players and `subtitle` its opening — the moves and players
     survived, not just a window. If SwiftUI's `PlatformDocument` refuses `duplicate`, this case is owed to
     Jean (make a move, quit, relaunch, see the game).
  6. *Restoration, saved file*: open the `.pgn` as in (2), resize, terminate, relaunch without the flag:
     exactly one document, `fileURL` = the fixture, the resized frame.
  7. *Relaunch after closing every window*: close the window as in (4), terminate, relaunch without the
     flag: one fresh untitled document (as in 1), no panel.
  Owed to Jean in a GUI session, because they need the eye or a click: the players sheet appearing over
  the launch window, the Dock click itself, Finder's double-click, and the look of the window at its
  default size, resized wider and taller, and at the minimum.

## Invariants

- **I1 — Files keep opening.** Holds. `ChessDocument`, the content types and `Info.plist` are untouched;
  a file at launch still opens through the `DocumentGroup`, and the delegate adds nothing to that path
  (matrix cases 2, 3, 6).
- **I2 — A search result only lands on its position.** Holds. No session, engine or callback code changes;
  the launch window is the same `DocumentWindow`/`SessionBox` New Game creates.
- **I3 — The engine stays portable.** Not applicable: nothing under `Shared/Engine/`.
- **I4 — The UCI tool keeps working.** Not applicable: `BChessUCI` has no delegate and no views.
- **I5 — Private and offline.** Holds. No network, no new required-reason API (`NSDocumentController`,
  `defaultSize`, `Layout`); `PrivacyInfo.xcprivacy` unchanged.

## Risks and rollout

- **SwiftUI's forwarding of `applicationShouldOpenUntitledFile`** is not documented; verified at runtime in
  step 1 (matrix case 1), with the fallback named in the design.
- **`.defaultSize` on a `DocumentGroup`**: documented for every scene since macOS 13; if the window still
  comes up at 900 × 450, the fallback is `.frame(idealWidth: 960, idealHeight: 708)` alongside the minimum on
  `DocumentWindow`. The numbers are tuned against the measured frame.
- **State restoration** (matrix cases 5, 5b, 6, 7): a quit with windows open restores them at their size,
  with their unsaved moves, and adds no untitled game; a quit with no window opens a new game at the next
  launch.
- **Rows wider than the board**: the column widens to its rows' minimum and the board stays at the leading
  edge (design 2) — a bounded, visible slack beside the board only in a window too short for its rows, on
  the Mac and the iPad alike, covered by the worst-case fixture. A column proposed less than its rows'
  minimum (a wide area under about 400 pt, which no supported window gives) overflows unclipped as the
  tall layout does today.
- **File-format compatibility**: none touched.
- **Visible changes outside the Mac**: the iPad wide layout and the Duo landscape cards lose their gap and
  the MOVES card widens (D2). Nothing changes in the tall layout.
- **What needs a real device**: the Mac run itself (the GUI checks owed above); an iPad or the iPad card
  for the wide layout; a Duo pass for the landscape cards.

## Decisions (Jean, 2026-10-27: go, D1–D5 as recommended)

- **D1 — Default window size.** Recommended: content 960 × 708 (a 600 pt board; the window is about
  960 × 760 with its title bar and toolbar, which fits a 13" MacBook Air). Alternative: the screenshot's
  929 × 699 window (a 550 pt board).
- **D2 — What the extra width goes to.** Recommended: the move list (`minWidth: 320, maxWidth: .infinity`),
  so the MOVES card reaches the window's edge at any size, as in the screenshot. Alternative: keep the
  sidebar at 320 and centre the pair (equal background bands on both sides in a wide window).
- **D3 — A minimum window size.** Recommended: 740 × 500 content (built; 720 in revisions 1–4: the widest row needs 378 pt, so the column needs 740 − 32 − 8 − 320 = 380 pt of width). Alternative: none, as today (the window shrinks to 380 × 141
  and the board to nothing). Either way the rows never enter the move list: design 2 keeps the column at
  least as wide as its rows.
- **D4 — The players sheet at launch.** Recommended: yes, the launch window is a New Game window and offers
  the sheet once (APP-2 D5); the game plays Club by default when it is cancelled (APP-3). Alternative:
  no sheet at launch, which needs a flag through `DocumentWindow` for no gain.
- **D5 — Dock click with every window closed.** Recommended: opens a new game (it falls out of the design
  and is the Mac convention). Alternative: nothing happens (needs `applicationShouldHandleReopen` returning
  `false`, one more method).

## Steps

1. **Launch opens a new game** — `BChessUIApp.init()` under `#if os(macOS)` registers
   `NSShowAppCentricOpenPanelInsteadOfUntitledFile` off (no delegate: see design 1);
   the launch verification matrix, cases 1–7 scripted (the window-size assertions of case 1 wait for step 3).
2. **The wide layout's board column is as wide as the board** — the failing pixel oracle
   `wideLayoutPutsTheMoveListBesideTheBoard` (engine off and on at iPad size; the worst-case fixture
   `Fixture.worstRow` with the gutter at 740 × 500 and 720 × 500, two appearances, two text sizes; `boxes` with a board
   region); `Shared/Views/BoardColumn.swift` (`BoardColumn: Layout`, `IsBoard`, ideal and clamped sizing,
   the rows' minimum width as the column's floor, the uncapped loop); `ContentView.boardRows`
   shared by the tall `VStack` and the wide `BoardColumn(leading:)`, the no-fold sidebar
   `minWidth … maxWidth: .infinity`, the fold branch's frame `alignment: .topLeading`; red proof; gallery
   re-rendered (iPhone and Duo passes), tall cards byte-identical.
3. **A larger default window and a floor** — `.defaultSize(width: 960, height: 760)` (708 pt of content) on the
   `DocumentGroup`, `.frame(minWidth: 740, minHeight: 500)` in `DocumentWindow`; matrix case 1's size
   assertions, numbers adjusted so the board is 600 pt with no slack.

## Deviations (as built)

1. **Step 1: no `AppDelegate`.** A registered default instead; AppKit never asks the delegate (design 1). The
   default `NSShowAppCentricOpenPanelInsteadOfUntitledFile` is long-standing AppKit behaviour (it dates from the
   app-centric open panel, well before macOS 15), so the registration should apply to every supported macOS; it
   was measured only on macOS 27 and older systems are owed to Jean.
2. **`defaultSize` is `960 × 760`.** On a document window it sets the window frame; the 52 pt title bar and
   toolbar leave 708 pt of content.
3. **`contentMinSize` reads 740 × 552** for the same reason; `ContentView` gets 740 × 500.
4. **The worst-row oracle's gap check allows 16 pt, not 12.5** (the light-mode trailing points text is too faint
   for the pixel measure); the first oracle keeps 12.5.
5. **Board and card measurement.** The board is its columns' topmost contiguous run of frame-colour rows, which
   must be as tall as the board is wide (within 1 pt); the card is measured on its own, then its full height down
   the middle of its columns. `boxes` is unchanged.
6. **`Fixture.worstRow`** was generated with python-chess: fifteen white captures by the position before the last
   move, which has a variation (`worstRowSession`: `.end`, `.backward`, `.forward`).
7. **`GalleryPixels`** gained `rasterize`, `differing(from:in:region:tolerance:)` and `firstRowRun`.
8. **The floor and the minimum (code review, round 1).** `BoardColumn` reported the proposed width when the rows'
   minimum exceeded it, so a column proposed 360 pt could still draw a 378 pt row toward the move list. It now
   reports `max(width, rowsMin)` and measures the rows at that width, so the parent makes room. The measured
   `rowsMin` is 366 pt in light and 378 pt in dark (fifteen captures, default and `.accessibility1` text: the
   cells and points never shrink), so D3 went from 720 to 740. The worst-row oracle runs at 740 × 500 and at
   720 × 500 (below the minimum, where the floor decides); reverting the floor fails its gap assertion at 720.

9. **`(∞, ∞)` proposals.** Revision 4 specified an unbounded size for an infinite dimension; `BoardColumn.fit`
   treats an infinite dimension like a nil one, so `(∞, ∞)` gets the board's ideal size, as `fixedSize` would. A
   `Layout` should not report an infinite size.
10. **`movesCard` in the oracle** returns only the card's horizontal extent beside the board; no caller uses its
   vertical bounds.

## Verification (measured on macOS 27, Debug build, 2026-10-27)

Launch matrix, scripted with `lldb -p` on a Debug build of this branch:

1. Fresh launch (`-ApplePersistenceIgnoreState YES`): one document, `fileURL` nil, a `SwiftUI.AppKitWindow` plus
   the sheet window, no `NSOpenPanel`, window 960 × 760 (content 960 × 708).
2. `.pgn` at launch: one document, `fileURL` is the fixture.
3. Legacy `.json` at launch (I1): one document, `fileURL` is the file.
4. Dock reopen with no window (`open -a`): one new untitled document, no panel.
5. Pristine untitled game, resized, quit, relaunched: exactly one untitled document, no panel; the resized frame
   was not restored (a pristine untitled game comes back at the default size).
5b. **Owed to Jean.** `duplicateAndReturnError:` worked (an edited "Untitled copy"), but quitting with an edited
   untitled game raises a Save panel, so restoring an unsaved game cannot be scripted: make a move, quit,
   relaunch, see the game.
6. A saved `.pgn`, resized, quit, relaunched: one document and no panel, but a fresh untitled one at the default
   size; the file window was not restored (not investigated).
7. Every window closed, quit, relaunched: one fresh untitled document, no panel.

Restoration, `main` against this branch (a Debug build of `main` from a temporary worktree, same container, no
`-ApplePersistenceIgnoreState`, each launched with `open -n` from its own build path, only the test pids killed):
cases 5 and 6 were run identically on both. Case 5 (pristine untitled, resized, quit, relaunch): `main`
relaunches to the Open panel with no document and no restored window or size; the branch relaunches to one fresh
untitled game at the default size. Case 6 (saved `.pgn`, resized, quit, relaunch): `main` relaunches to the Open
panel, the file window not restored; the branch relaunches to one fresh untitled game, the file window not
restored. So the branch does not change restoration (neither build restored a window or a size in these runs);
its only difference is the intended one: a new game where `main` shows the Open panel. Why nothing is restored
on this Mac was not investigated (a scripted quit may not exercise what Cmd-Q does).

Observations: with the New Game sheet open, quitting is blocked by AppKit ("App termination blocked by modal
sheet"), so a scripted quit needs the sheet cancelled first (standard sheet behaviour, unchanged here);
File ▸ Duplicate shows the players sheet on the copy (unchanged); leftover saved state can add one restored
untitled game beside a file opened at launch, with or without this change (checked by forcing the panel default
back on). Owed to Jean in a GUI session: the sheet over the launch window, the Dock click, Finder's double-click,
Cmd-Q with the sheet open, the look of the window at default, larger and minimum sizes, case 5b, and older macOS.
