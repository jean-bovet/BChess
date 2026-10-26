# APP-8 — iPhone Duo: the audit, the hinge-aware game screen, and the gallery's Duo pass

Revision 4 (2026-10-26). Branch `app-8-iphone-duo` (worktree `.claude/worktrees/app-8-iphone-duo`, from `main`).

- Revision 1: initial plan.
- Revision 2: Codex plan round 1 (2 blockers, 6 should-fix, 2 simpler; all accepted but SF7 and half of SF6, rejected
  below): the geometry is measured inside the padding, in one coordinate space, with an off-centre case for the
  asymmetric side bars (B1); a region that intersects the content is never ignored — a fold that leaves one side
  under the minimum pushes the layout onto the other side (`usable`, B2); one `FoldRegion` value type with its active
  flag through the production filter, the same region rendered active and inactive in both orientations (SF3); tests
  6–9 run with the iOS scheme's tests and red proofs, not with the gallery run, and the outer-display precondition
  sits in the capture entry point (SF4); the oracles are the bounding boxes of the resolved Walnut colours through
  the production layout, the move strip's card explicitly below the fold (SF5); an inner scenario through the
  production shell and tabletop variations (SF6); iPhone → Duo → iPhone import keeps both galleries, with a lifecycle
  case (SF8); the no-fold branch (`layoutPriority(1)`, the 320 pt sidebar) is kept and the explicit split applies
  only with a fold inside the usable area (S9); the `ArrangementView` rejection answers the review's points (S10).
- Revision 3: Codex plan round 2 (1 blocker, 3 should-fix, all accepted): the tabletop board column reserves the
  whole primary extent, top-aligned (`.frame(height:alignment:)`, not `maxHeight`), so the controls start after the
  fold whatever the board's own height, with a narrow render test (B1, test 12); the card oracle searches only outside
  the board frame's box, where no white piece can be, on fixtures without captures (SF2); `split` defines the
  both-sides-small and fully-covered outcomes with the gutter consumed, tested (SF3, tests 4–5); off-centre and edge
  folds are rendered through `ContentView` and the board and controls asserted inside `usable` (SF4, tests 13–14).
- Revision 4: Codex plan round 3 (1 blocker, accepted): the tall / wide decision and the sidebar's width are taken on
  the **usable area**, not the container (`FoldLayout.usableArea`), so the existing wide branch runs only when the
  whole width is usable and a one-sided fallback that leaves a narrow strip gets the tall layout, which fits any
  width; the sidebar is `min(320, usable.width / 2)` on iOS (320 on every real wide container); rendered by test 15.
- Revision 5: Jean's go (2026-10-26): D1 and D2 as planned; D3 **changed** — landscape on the iPhone: step 5 lifts
  the portrait lock of 3c0611a (`iOS/Info.plist`, no `project.yml` or project change), with a `.phoneLandscape`
  gallery size (the screen transposed: 874 x 402 on the pool's iPhone, 678 x 466 on the Duo pass's outer display,
  compact / compact) and two cards picturing the board size Jean accepted (§3.3, §3.5, §9).

- Revision 6 (2026-10-26, after implementation): **D3 reverted.** Landscape on the iPhone was built (step 5) and measured
  for real: the rotated board is 151 pt, not the 230 pt planned. Jean reverted it the same day: the portrait lock of
  3c0611a is back, the two "Phone landscape" cards, `GallerySize.phoneLandscape` and the landscape UI test are gone
  (48 cards). Every paragraph below that speaks of landscape on the iPhone (§1 row 2, §3.3 and §3.5 landscape parts,
  tests 9 and the step 5 line) is the plan as written and was not carried out; §9 and §10 say what happened.

### Review findings rejected (with the rationale, so the next round does not re-raise them)

- **SF7, a transition test preserving view and session state across active → inactive and wide → tall → wide.**
  Rejected. The state the review names lives in `GameSession` (`Shared/Model/GameSession.swift`: the position, the
  selected move, the variation choice), which `ContentView` references and does not own; no layout change can create
  or drop it, and `GameSession`'s own tests cover it. The view's only state is `showAllMoves` (the Moves sheet) and
  `isWide`, both on `ContentView` itself, whose identity a size change does not touch (`.id(shell.current.url)` keys
  it on the game, not on the layout). A hosted resize test would prove SwiftUI's identity rules, not BChess code.
  What is worth a look is the Moves sheet open while the device unfolds (the sidebar then also lists the moves): an
  owed Device Hub check (§8), not a test.
- **SF6, "tabletop coverage with the engine visible".** Rejected for the engine: a game-screen card with the readout
  on starts a search (`GameSession.analyzeIfNeeded`, I2; APP-5 §6 keeps every full-screen card hermetic with the
  readout off), which is why no full-screen card shows the engine today; the engine card's look at any width is the
  "Engine · Wide" card. The variations part is accepted (§3.3).

Jean's request: audit BChess's screens for the iPhone Duo (Apple's two-display folding iPhone, on sale
2026-10-23) against the checklist in maestro's `docs/iphone-duo.md`, record the findings, and plan the fixes.
This is step 1 of that document's rollout; its step 3 (the fixes, through `/develop`) and step 4 (the gallery's
`duo` pass) are planned here too, so one plan is approved. Step 5 (App Store screenshots) is out of scope (§9).

Models: xFractal's `planning/iphone-duo-plan.md`, `GalleryTests/GalleryFixtures.swift` (`GallerySize`),
`GalleryHarness.swift` and `scripts/snapshot-gallery.sh --device duo` (the Duo pass, the fixed-size inner-display
windows with the regular size class, the fold hook); Departure's `scripts/preview-gallery.py` (the
`previews/<platform>/` layout with `data/manifest.json`, migrated resumably, the selective cleanup of an import),
`DepartureTests/Gallery/GalleryMount.swift` (size-class overrides on the window and the host),
`scripts/test_snapshot_gallery.sh` (`pool_duo`, `unknown_device`, `layout`). The updated `/preview-gallery` skill
(PR #24) already states what BChess's gallery lacks.

## 1. The device, in short (from `docs/iphone-duo.md`)

| | Points | Size classes |
|---|---|---|
| Outer display, portrait | 466 x 678 | compact / regular; the status bar stands on the side |
| Outer display, landscape | 678 x 466 | compact / compact |
| Inner display, landscape | 951 x 669 | regular / regular; the hinge vertical at x = 475 |
| Inner display, portrait | 669 x 951 | regular / regular; the hinge horizontal (tabletop pose) |

Both displays are 3x. Half-open and fully open have the same size and size classes: only
`GeometryProxy.reservedRegions(kind: .division)` (iOS 27.1) tells the fold. The inner display ignores
`UISupportedInterfaceOrientations`. The simulator (`simpool` spec `duo`, iOS 27.1) boots folded and cannot be folded
from `simctl`; poses are driven only from Xcode's Device Hub. Local Xcode is 27.1 (27A9275), so the 27.1 API compiles;
Xcode Cloud's "Latest Release" is 27.1 too (the workflow's version is checked before `/testflight`, §8).

## 2. The audit

Grep (one Explore pass over `Shared/`, `iOS/`, `macOS/`, `project.yml` and the test folders) then the screens read.
Verdicts: **pass**, **fail** (what Apple asks instead), **n.a.** (nothing of the kind in BChess).

| # | Rule | Verdict | Evidence | Fix |
|---|---|---|---|---|
| 1 | `UIScreen.main` | pass | none in app code; the gallery sizes its window from a fixed `CGSize` (`BChessGalleryTests/SnapshotGalleryTests.swift:66-67`) | the gallery's `.phone` reads the scene's screen (§3.3), never `UIScreen.main` |
| 2 | Orientation for layout | pass | none; the layout is chosen by size, `Shared/Views/ContentView.swift:109-113` (`width > height`) | step 5 lifts the portrait lock of `iOS/Info.plist:65-68` (D3, Jean): the wide layout takes the phone in landscape |
| 3 | Idiom for layout | pass | no `userInterfaceIdiom`; `EngineView.wide` and `MoveListView.card` are plain inputs the container sets (`ContentView.swift:73-75, 87`) | — |
| 4 | Device-size tables | pass | app: none. Test only: `GalleryScenarios.swift:30` (402 x 874), `:149` (1180 x 820), `:321` (375 x 667) | the sizes become a `GallerySize` enum (§3.3) |
| 5 | Full-bleed `.fill` | pass | none; the board is `.aspectRatio(1, contentMode: .fit)` (`BoardView.swift:39, 71`) | — |
| 6 | Safe-area arithmetic | pass | `ignoresSafeArea()` on backgrounds only (`ContentView.swift:107`, `GameRootView.swift:396`, `NewGameSheet.swift:175`, `SettingsView.swift:50`); `safeAreaInset(edge: .bottom)` for the full-width buttons (`GameRootView.swift:405`, `NewGameSheet.swift:176`) | — |
| 7 | Bottom-centred floating control on the hinge | pass | the bottom bar is a system toolbar (`GameRootView.swift:153-160`: Back, Forward, Spacer, Engine), which the system moves to the side; no custom overlay (`ZStack(alignment: .bottom)` only in the evaluation bar, `EngineView.swift:130`); the promotion column sits on the board (`PromotionView.swift:89-92`), which item 14 keeps off the hinge | — |
| 8 | Detent sheet with background interaction | pass | no `presentationDetents` / `presentationBackgroundInteraction` anywhere; the four sheets (`ContentView.swift:124`, `GameRootView.swift:175, 190, 200`) become centred form sheets on regular width, which is right for Moves, Players, Settings and Games | — (the HIG's "one more level" on the inner display is the wide layout's moves sidebar, which is the Moves sheet of the phone) |
| 9 | Toolbar items carry a title and a symbol | **fail** (minor) | Games list: `Button("Import")`, `Menu("Export")` text only (`GameRootView.swift:430-434`); the rest carry a `Label` with a symbol (`:134, 157, 252`; `NavigationButtons.swift:24, 35`) or are the standard text actions Done / Cancel in semantic placements (`ContentView.swift:130`, `GameRootView.swift:194`) | step 5: `Label("Import", systemImage: "square.and.arrow.down")`, `Menu("Export", systemImage: "square.and.arrow.up")` |
| 10 | `UIRequiresFullScreen`; the layout survives any size | pass | the key is absent; `ContentView` re-chooses tall / wide on every size change (`:109-113`), and the tall layout holds at 375 x 667 ("Games list · Small iPhone") | — |
| 11 | Corner-following UI (`ConcentricRectangle`) | n.a. | nothing follows the screen corners: card radii are 6–16 pt (`Walnut.swift`, `NewGameSheet.swift:92`) | — |
| 12 | Games fill every pose, no letterbox | pass | the board fills the smaller dimension of its column (`BoardView.swift:52-71`), the rest flows | — (item 14 keeps it true on the inner display) |
| 13 | Split View multitasking, controls to the outer edge | pass (manual) | system bars; the tall layout holds at any narrow width (item 10) | owed: the app on the left and on the right in Device Hub (§8) |
| 14 | Two columns built by hand | **fail** | `ContentView.swift:81-94`: `HStack` of the board column (`layoutPriority(1)`) and a `.frame(width: 320)` sidebar. In a 951 x 669 window the board column is 591 pt wide and the board 569 pt (the height's limit), x = 27…596: the hinge at x = 475 cuts the board through its g-file. The HIG: the folding region excludes the centre; a custom layout keeps interactive elements off it | §3.1–3.2: the boundary on the hinge, read from `reservedRegions` behind `#available(iOS 27.1, *)`, with a gutter, pure geometry tested on the Mac |
| 15 | A detail column that can be empty | n.a. | no list + detail; the sidebar always holds the moves card | — |
| 16 | Close or Back drawn over the content | pass | every sheet closes from a toolbar item; the `xmark` of `PromotionView.swift:52` is the picker's own cancel cell inside the board, not a screen close | — |
| 17 | Positional `topBarLeading` / `topBarTrailing` | **fail** (minor) | `.navigationBarLeading` / `.navigationBarTrailing` at `GameRootView.swift:132, 150, 429, 441` and `NewGameSheet.swift:196` | step 5: `.navigation` (Games, Cancel), `.primaryAction` (More), `.confirmationAction` (Done), `.topBarLeading` as one `ToolbarItemGroup` for Import / Export (the phone look judged on the gallery) |

Two more findings outside the numbered list:

- **Tabletop pose** (inner display in portrait, 669 x 951, half-folded): `width > height` is false, so the tall layout
  runs; the board is 637 pt (`ContentView.swift:96-103` with the 16 pt padding) and spans y ≈ 100…737: the horizontal
  hinge at y = 475 crosses ranks 4 and 5. The HIG's tabletop rule: controls belong in the bottom half. §3.2 caps the
  board column at the fold while the division region is active (flat open keeps the big board). D2 lets Jean drop it.
- **The gallery** (`scripts/snapshot-gallery.sh`, `BChessGalleryTests/`): no `--device`, no `SIMULATOR_UDID`,
  `-testLanguage en` without `-testRegion US`, a flat `previews/`, `.phone` a hard-coded 402 x 874, no size-class
  override (the "Game screen · Wide" card renders 1180 x 820 on a compact-width phone window), no inner-display
  scenario. §3.3–3.4.

What the gallery pictures of each failing screen on the inner display, after §3.3: item 14 → "Duo inner · Landscape ·
Game screen", "· Flat open", "· Variations" and "· Shell"; the tabletop finding → "Duo inner · Portrait · Tabletop" and
"· Tabletop · Variations" (beside "· Game screen", flat open); items 9 and 17 → "Launch · Empty library" (the game
screen's toolbar), "Games list · Four games", "New game · Club" (the phone look), and the same three on the Duo pass's
outer display.

## 3. Design

### 3.1 Pure geometry: `FoldLayout` (`Shared/Model/FoldSplit.swift`, CoreGraphics only)

`Shared/Model/` is compiled into the macOS `BChessTests` target (`project.yml`, `BChessTests.sources`), so the
geometry is tested there like the rest of the model. Value types and free of view code:

```swift
/// A reserved region of the display, as the layout sees it: the frame in the layout's own coordinates (margins
/// included, as the OS reports it) and whether it is active (partially folded) or a flat seam (fully open).
struct FoldRegion: Equatable, Sendable {
    var frame: CGRect
    var isActive: Bool
}

/// How a layout steps over a fold along one axis.
struct FoldSplit: Equatable {
    /// The part of the length the content may use. The whole length unless the fold leaves one side under
    /// `minimum`: then the larger side alone, and the fold lies outside it (never under content).
    var usable: ClosedRange<CGFloat>
    /// With the fold inside `usable`: the extent of the first part (the board column, or the board rows), from
    /// `usable.lowerBound`, ending `gutter` before the fold; nil when there is no fold inside (today's layout runs).
    var primary: CGFloat?
    /// The distance from the end of the first part to the start of the second: the fold plus a gutter each side.
    var gap: CGFloat
}

enum FoldLayout {
    /// The fold the layout reacts to, from the regions in its coordinates: `wide` takes any region taller than wide
    /// (a vertical seam), active or not — a flat-open Duo still has its crease; tall takes only an active region
    /// wider than tall (the tabletop pose). The range is along the axis across the fold (x for columns, y for rows).
    static func fold(in regions: [FoldRegion], wide: Bool) -> ClosedRange<CGFloat>?

    /// The split of `length` across `fold` (nil: the whole length, no primary).
    static func split(length: CGFloat, fold: ClosedRange<CGFloat>?, gutter: CGFloat = 12, minimum: CGFloat = 200) -> FoldSplit

    /// The rectangle of `size` the content may use, before the layout is chosen: the x range is `split`'s `usable`
    /// across any vertical region, the y range across an active horizontal one (the same rules as `fold(in:wide:)`,
    /// both axes at once). The whole size without a region. Tall or wide is decided on this rectangle.
    static func usableArea(size: CGSize, regions: [FoldRegion], gutter: CGFloat = 12, minimum: CGFloat = 200) -> CGRect
}
```

`split`, in order: a fold that does not intersect 0...length → as no fold: `usable` 0...length, `primary` nil,
`gap` 0. Otherwise the fold is clamped to 0...length and the two sides are measured *after* the gutter:
`leading = max(0, fold.lowerBound − gutter)`, `trailing = max(0, length − fold.upperBound − gutter)`. Both ≥ `minimum`
→ `usable` 0...length, `primary` = leading, `gap` = fold.width + 2·gutter. Else the layout goes onto the larger side
alone, `primary` nil: `leading ≥ trailing` → `usable` 0...leading, otherwise `usable` (length − trailing)...length
(ties go leading). When the larger side is 0 (the fold covers the length, or leaves no more than the gutter) →
`usable` 0...length, `primary` nil: nothing can step aside, the layout runs as without a fold, no worse than today,
and the case is documented in the code. Every range is built from clamped, ordered bounds, so no input constructs an
invalid `ClosedRange`. A region that intersects the content is therefore never ignored: it is split around, stepped
past, or (only when it leaves no room at all) drawn over as today. The region's frame "includes the margins for
interactive content", so the gutter is on top of Apple's margins. RTL: the regions come mirrored
(`layoutDirectionBehavior: .mirrors`) and the HStack lays out in the same mirrored space, so "primary = leading" holds
without a direction input.

### 3.2 `ContentView`: one reader inside the padding, the fold as a plain value (`Shared/Views/ContentView.swift`)

- **One coordinate space (B1).** Today's `.onGeometryChange` sits after `.padding()` (`:106-113`), so its size
  includes the 32 pt of padding. It moves onto the `Group` *inside* the padding: the proxy's `size` is the content's,
  and `proxy.reservedRegions(...)` reports frames in that same local space (xFractal reads them from the proxy that
  lays the capsule out, the same rule). Nothing subtracts a padding or a safe-area inset anywhere: on the real inner
  display the navigation stack and the side bars inset the content, and the region arrives in the content's space
  already (checklist 6: no inset arithmetic). The hook (below) is expressed in that same space.
- **A test-only hook, like xFractal's `foldRegions`:** `ContentView(session:foldRegions: [FoldRegion]? = nil)`, stored
  as `foldRegionsOverride`, nil in the app; `GameRootView(library:foldRegions:)` and the private `GameView` pass it
  through to `ContentView` (default nil; `BChessUIApp.swift:49` and `macOS/DocumentWindow.swift` pass nothing), so a
  scenario can render the production shell with a fold (§3.3). Only the *source* of the regions is injected; the
  filter, the split, the frames and the placement are the production path.

  ```swift
  private func foldRegions(_ proxy: GeometryProxy) -> [FoldRegion] {
      if let foldRegionsOverride { return foldRegionsOverride }
      if #available(iOS 27.1, *) {
          return proxy.reservedRegions(kind: .division, options: .includeInactive)
              .map { FoldRegion(frame: $0.frame, isActive: $0.isActive) }
      }
      return []
  }
  ```
  The reader publishes `FoldGeometry(size: CGSize, regions: [FoldRegion])` (Equatable) through
  `onGeometryChange(for:)`. **The layout is decided on the usable area (round 3):**
  `area = FoldLayout.usableArea(size:regions:)`, `isWide = area.width > area.height` (the same `width > height` rule,
  on the rectangle the content may use), then
  `split = FoldLayout.split(length: isWide ? size.width : size.height, fold: FoldLayout.fold(in: regions, wide: isWide))`,
  and both branches lay out inside `area` (`.padding` of its four insets). A one-sided fallback that leaves a narrow
  strip (content 300 x 240 with a vertical region at x = 140...180 → area 128 x 240) is therefore **tall**, and the
  tall `VStack` fits any width (the board is aspect-fit, the strip scrolls, the texts truncate); the wide `HStack`
  runs only on an area wider than tall. A device without a hinge, iOS 18–27.0 and the Mac get no region: the area is
  the whole size, `primary` nil, `isWide` exactly today's decision.
- **Wide layout (`:81-94`), the existing branch kept (S9):** with `primary` nil the `HStack` is today's
  (`layoutPriority(1)`, the default spacing) with the sidebar `.frame(width: sidebarWidth)` where `sidebarWidth` is
  `min(320, area.width / 2)` on iOS — 320 on every real wide container (the narrowest wide iOS container is an iPad
  in landscape, ≥ 1032 pt; the iPhone is portrait-locked), so today's picture is byte for byte the same, and a
  small wide area after a fallback can never overflow (the board column keeps at least half) — and the literal 320
  on the Mac (no reader there). With a `primary`: `HStack(alignment: .top, spacing: split.gap)` with the board column
  `.frame(width: split.primary)` and the sidebar `.frame(maxWidth: .infinity)`. Either branch sits inside `area`
  through `.padding(.leading, area.minX).padding(.trailing, size.width - area.maxX)` (and the same on y). On the Duo in landscape
  (the gallery's window, no bars): the stand-in hinge x = 455.5…495.5 in the window is 439.5…479.5 in the content;
  the board column is 427.5 pt (board 427 pt, from x = 16 of the window), the gap 64, the sidebar from window
  x = 507.5, 427.5 pt wide. A fold off centre, as the real side bars make it, only changes the range.
- **Tall layout (`:96-103`):** with a `primary` (an active horizontal fold) the board column gets
  `.frame(height: split.primary, alignment: .top)` — the **whole** extent above the fold is reserved, not capped
  (B1): a narrow window whose square board plus player rows is shorter than `primary` would otherwise let the
  controls climb above the fold's trailing edge — and the rest of the `VStack` (status, engine, move strip) follows
  after `.padding(.top, split.gap - spacing)`, so it starts at `primary + gap` whatever the board's height; with a
  fold outside `usable` the column is padded onto the usable side; with `primary` nil it flows as today. In the
  tabletop pose the board shrinks to the top half (about 360 pt), status, engine and the move strip sit on the flat
  half.
- **The Mac** keeps `isWide = true` and no region: today's branch, unchanged.
- **Sidebar content at half the display:** the moves card, status and engine already stretch
  (`MoveListView` is a `List`, `EngineView` `.frame(maxWidth: .infinity)`); nothing else changes.

### 3.3 Gallery: a `GallerySize`, inner-display scenarios, the fold hook (`BChessGalleryTests/`)

- **`GallerySize`** replaces the `CGSize` of `GalleryScenario.size` (`GalleryScenarios.swift:23, 30`), shaped on
  Departure's enum: `.phone` (the hosting scene's screen: 402 x 874 on the pool's iPhone 17 Pro, 466 x 678 on a
  folded Duo), `.phoneLandscape` (the screen transposed: 874 x 402 on the iPhone, 678 x 466 on the Duo pass's outer
  display; compact / compact, the phone's landscape classes, forced because the scene stays portrait), `.smallPhone`
  (375 x 667), `.ipadLandscape` (1180 x 820, regular / regular), `.duoInnerLandscape`
  (951 x 669, regular / regular), `.duoInnerPortrait` (669 x 951, regular / regular); `points(screen:)`,
  `sizeClasses` (nil for the phone sizes), `scale(duoPass:)` (3 for the inner sizes and for every capture of the Duo
  pass, the displays' own scale; 2 otherwise), and `platform` (`"duo-inner"` for the inner sizes, `"iphone"` else:
  the manifest field and the folder of §3.4). The manifest's `size` string stays `"WxH"` (the page's wide-card rule
  reads it); `platform` is added.
- **The render** (`SnapshotGalleryTests.render`, `:60-89`) sets the size's `sizeClasses` on the window **and** the
  host with `traitOverrides` (Departure's `GalleryMount.apply`, `:117-130`), so a fixed inner-display window on a
  phone screen reads regular / regular, and captures at `scale(duoPass:)`. `render` becomes a `static func` with a
  primitive `render(_ view: AnyView, size: CGSize, sizeClasses:, scale:, style:, settle:)` under it, which the
  scenario render calls with the scenario's values and the oracle tests of §5 call with ad-hoc views and sizes (the
  narrow and edge-fold renders need no gallery card). No harness type.
- **The Duo pass asserts the outer display in the capture entry point (SF4):** `renderEveryScenarioInLightAndDark`
  reads `BCHESS_SNAPSHOT_DEVICE`; for `duo` it calls `duoPassProblem()` **before the first capture** and fails with
  its message ("the Duo simulator is not folded: screen W x H") unless `scene.screen.bounds.size == 466 x 678` and a
  `.phone` probe reads compact width, then prints `gallery: duo screen 466 x 678 pt`, which the script forwards.
  Test 10 calls the same function on its own (skipped unless the variable is `duo`). A leased Duo may come back in
  another posture.
- **Fixtures carry `FoldRegion`s in the content's coordinates** (the window minus the 16 pt padding; the shell
  scenario's window minus its bars and the padding, the implementer measures it once and comments the number):
  the stand-in hinge is 40 pt wide at the window's centre (the reference's number), landscape
  `(439.5, 0, 40, 637)`, portrait `(0, 439.5, 637, 40)`; the real frame is read off a device in Device Hub later and
  the fixtures updated then.
- **Scenarios** (group "iPhone Duo · inner display", after Game; 38 → 47 cards):

  | Name | Size | Build | Region (hook) |
  |---|---|---|---|
  | Duo inner · Landscape · Game screen | duoInnerLandscape | `ContentView(session: humanToMoveSession(), foldRegions:)` | landscape, active |
  | Duo inner · Landscape · Flat open | duoInnerLandscape | the same | landscape, inactive |
  | Duo inner · Landscape · Variations | duoInnerLandscape | the arrows-and-cards session (two humans) in `ContentView` | landscape, active |
  | Duo inner · Landscape · Shell | duoInnerLandscape | `GameRootView(library:foldRegions:)` on the empty-library fixture (the Launch card's), settle 1 s | landscape, active |
  | Duo inner · Portrait · Game screen | duoInnerPortrait | `ContentView(session: humanToMoveSession(), foldRegions:)` | portrait, inactive (flat open) |
  | Duo inner · Portrait · Tabletop | duoInnerPortrait | the same | portrait, active |
  | Duo inner · Portrait · Tabletop · Variations | duoInnerPortrait | the arrows-and-cards session | portrait, active |

  The same region is rendered active and inactive in both orientations (SF3): landscape active and inactive give the
  same split (test 7 asserts the two captures equal), portrait inactive gives the flat layout (test 8 asserts the board
  bounds equal a no-fold render). The shell scenario carries the production navigation and bottom bars (horizontal in
  a fixed window: the vertical side bars exist only on the real inner display, §8). "Game screen · Wide" stays (the
  iPad approximation, now with the regular trait; its picture does not change). The phone scenarios double as
  outer-display scenarios on the Duo pass, with the real side insets.
- **The phone in landscape (D3, step 5), group Game:** "Game screen · Phone landscape" (`ContentView` on
  `humanToMoveSession()` at `.phoneLandscape`: the wide layout, the board about 300 pt beside the 320 pt sidebar in
  a bare 874 x 402 window) and "Launch · Phone landscape" (`GameRootView` on the empty-library fixture at
  `.phoneLandscape`, settle 1 s: the production shell with its compact-height navigation and bottom bars, the board
  about 230 pt — the size 3c0611a locked out and Jean accepted on 2026-10-26). On the Duo pass both render at 678 x 466
  (about 310 pt with the bars). No minimum board size and no third layout: `width > height` on the usable area picks
  wide, the sidebar is `min(320, area.width / 2)` = 320, the board takes the height that is left (§3.2).
- **No `.phone` constant in the page script:** `PHONE_ASPECT` (`preview-gallery.py:23`) stays for the card width.

### 3.4 Scripts: the Duo pass, the folder layout (`scripts/`)

- **`snapshot-gallery.sh`:** `--device iphone|duo` (`iphone` default; anything else exits 2 before a lease);
  `simpool acquire --spec "$DEVICE"`; `SIMULATOR_UDID` passed by the caller is used as is and never released; the
  Duo pass sets `PREVIEW_GALLERY_OUT=previews/duo` (the iPhone gallery untouched) and
  `TEST_RUNNER_BCHESS_SNAPSHOT_DEVICE="$DEVICE"`; the test command gains `-testRegion US` and keeps
  `-only-testing:BChessGalleryTests/GallerySuites/SnapshotGalleryTests` (the gallery run renders; the suite's other
  tests run with the iOS scheme's tests, §5); the fallback's `duo` simulator is "BChess Agent Duo" from the
  `iPhone Duo` device type on the `iOS-27-1` runtime (the only one that has it; the marker is already per UDID); the
  message "No $DEVICE simulator from the pool". The `duo` block mirrors xFractal's (`snapshot-gallery.sh:85-95`). No
  `--lang` (the skill: never a language pass).
- **`preview-gallery.py`:** Departure's layout (`:18-21, 50-130`): only `index.html` at the top of the output folder,
  images in `<platform>/` (the manifest entry's `platform`, default `iphone`), an unnamed image in `other/`,
  `data/manifest.json` (and `data/coverage.json`); `PREVIEW_GALLERY_OUT` replaces `previews/`; every command first
  moves a flat gallery into the layout, resumably (`migrate`); **a full import removes only the images of the image
  folders, the manifest and the page — never another directory** (Departure's `do_import`, `:98-115`), so the Duo
  pass's `previews/duo/` survives a full iPhone import and the iPhone gallery survives a Duo pass (SF8; today's
  `shutil.rmtree(OUT)` at `:43` would delete the nested Duo gallery). `image_folders()` therefore lists only the
  folders that hold images and skips `data/` and `duo/` (a folder with its own `data/` is another gallery, not a
  platform). `--check` lists the PNGs of every image folder and names them `<folder>/<file>`; the page links
  `<platform>/<file>`. `preview-luminance.swift` prints `<folder>/<file>` (Departure's one-line change). The snapshot
  test still writes one flat directory per run; only the import places the files.
- **`test_snapshot_gallery.sh`:** `pool_run` additionally asserts `-testRegion US`, `device=iphone` and the unchanged
  `-only-testing:…/SnapshotGalleryTests` in the test command; new cases `pool_duo` (lease `--spec duo`, never
  `iphone`, `device=duo`, the page in `previews/duo/index.html` and none in `previews/`, released once, no `simctl`
  lifecycle call), `unknown_device` (`--device watch` exits 2, no lease, no build), `simulator_udid` (no
  `simpool acquire`, the test on that id, no `simpool release`), `layout` (Departure's `:254-270`: the real page
  script on a fake manifest — default folder `iphone/`, `platform` picks the folder, a stray image lands in `other/`,
  the manifest in `data/`, the page links the folder, only pages at the top; a flat gallery is migrated by the next
  command, resumably; `data/coverage.json` survives a full import) and `coexist` (the real page script: a full iPhone
  import, then a Duo import under `previews/duo`, then a full iPhone import again — both `index.html` exist, the Duo
  images and manifest are intact, and the iPhone `--check` does not count the Duo images as stray).

### 3.5 Toolbar items and landscape on the iPhone (`iOS/GameRootView.swift`, `Shared/Views/NewGameSheet.swift`, `iOS/Info.plist`)

**Landscape (D3, Jean 2026-10-26).** `UISupportedInterfaceOrientations` (`iOS/Info.plist:65-68`, the iPhone key;
`~ipad` already lists all four) becomes Portrait, LandscapeLeft, LandscapeRight (upside down is ignored on Face ID
iPhones). The key lives in the plist, not in `project.yml` (`GENERATE_INFOPLIST_FILE: NO`, `INFOPLIST_FILE:
iOS/Info.plist`), so no `xcodegen generate` and no project change. Nothing in the shell or the sheets assumed
portrait: `ContentView` already chooses by size (§3.2), the sheets are plain `.sheet`s with `safeAreaInset` buttons,
the bottom bar is a system toolbar, and the UI tests set no orientation (the simulator launches portrait as today).
The tent pose and the outer display held sideways now rotate.

**Toolbar items,** items 9 and 17, UI-only, no logic: `Label("Import", systemImage: "square.and.arrow.down")` and
`Menu("Export", systemImage: "square.and.arrow.up")` in one `ToolbarItemGroup(placement: .topBarLeading)`; the
game screen's Games → `.navigation`, More → `.primaryAction`; the Games list's Done → `.confirmationAction`; the New
Game sheet's Cancel → `.cancellationAction`. The phone look is judged on the gallery cards ("Launch · Empty library",
"Games list · Four games", "New game · Club"): a changed order or an icon where text was is reported, not fixed in
passing.

### 3.6 Docs

`.claude/skills/preview-gallery/SKILL.md` (on `main` after PR #24 lands; the step rebases on it): the Duo pass is no
longer "due"; 47 cards, the "iPhone Duo · inner display" group, `--device duo`, `previews/duo/`, `SIMULATOR_UDID`,
`-testRegion US`, the folder layout, the owed Device Hub check. `AGENTS.md`: the Builds line names
`scripts/snapshot-gallery.sh --device duo`; the Tests rule adds "a screen whose layout changes at regular width gets
an inner-display scenario". `planning/README.md`: this row.

## 4. Alternatives rejected

- **The boundary at the centre of every wide layout** (pure geometry, no 27.1 API: the sidebar fills the trailing
  half). Exact on the Duo, but it shrinks the iPad's board: on a 1180 x 820 window from 569 to about 566 pt (no
  loss) but on the 13" iPad in landscape (1376 x 1032) from about 830 to 664 pt, a 20 % smaller board on a decided
  layout (APP-2, Jean 2026-10-05: the wide layout with the 320 pt sidebar). Kept as D1's alternative.
- **`ArrangementView(.split)`** (iOS 27.1) for the board | sidebar pair (S10). It places the boundary on the hinge by
  itself, but: (1) the iOS 18 minimum keeps today's `HStack` as a second implementation of the same screen beside it,
  so nothing gets simpler; (2) on the iPad and in a fixed window it carries no region, and what proportion it then
  takes is undocumented — BChess's `HStack` gives the board the width it needs (`layoutPriority(1)`) and the sidebar
  320 pt, which a split arrangement would not; on the Mac it does not exist; (3) it cannot be pictured: the gallery's
  fixed windows carry no region and there is no hook into it, so Device Hub would be its *only* check, whereas the
  custom path is pictured on every pass through the hook (tests 7–8) and only the OS's delivery of the region stays
  manual; (4) the pool's iPhone (27.0) cannot run it at all. Both paths need Device Hub for the real region; only one
  needs it for everything else.
- **`NavigationSplitView` with the games list as the sidebar** (the HIG's "one more level"). A redesign of the iPad
  and the phone shells for a list that is a sheet today; the inner display's extra level is already the moves sidebar.
- **Branching on the size class** ("regular width means two columns"). The inner display is regular / regular in both
  poses: it would split the tabletop pose into two narrow columns (the Departure lesson). `width > height` stays.
- **A device check** (shift the boundary by a fixed amount on the Duo). Wrong on the next foldable and on an open
  device; checklist 3 and 4.
- **Ignoring a fold that leaves a column too small** (revision 1). It put the board column back across the region
  (review B2). Replaced by `usable`: the layout steps onto the larger side.
- **A `GalleryMount` harness class** (Departure, xFractal). BChess's render is one function with no sheets or
  detents to drive; the trait overrides are four lines in it, and `render` as a static function serves the oracle
  tests.
- **A uniform hinge band as the oracle** (revision 1). The board frame's shadow (`BoardView.swift:58`) bleeds into
  the gutter (review SF5). Replaced by the bounding boxes of the resolved Walnut fill colours (§5).
- **Production layout instrumentation for the oracle** (an `onGeometryChange` or preference in `ContentView` the test
  reads, round 2's suggestion). It ships test code in the app and measures what the view *reports*, not what it
  *draws*; the two-staged colour oracle (§5) measures the capture through the production path and needs nothing in
  the app. Taken up only if the colour oracle proves unstable (§8).
- **An iPad pass** (`--device ipad`) in this plan. Nothing in the request; one more `case` once the `duo` block exists
  (the pool has the spec). Left open (D5).
- **Keeping the iPhone's portrait lock** (revision 1's D3 recommendation; 3c0611a locked portrait because the
  landscape board was 230 pt on a phone, about 310 pt on the Duo's outer display). Jean chose landscape on
  2026-10-26, the board size accepted: step 5, §3.5.

## 5. Test plan (red first)

Geometry, `BChessTests/FoldSplitTests.swift` (Swift Testing, macOS, the step gate):

1. `noFoldLeavesTheLayoutAlone`: `split(length: 919, fold: nil)` → usable 0...919, primary nil, gap 0 (today's wide
   layout exactly: the existing branch runs).
2. `centredFoldSplitsAroundIt`: `split(length: 919, fold: 439.5...479.5)` → usable 0...919, primary 427.5, gap 64;
   primary + gap + the rest partitions the length.
3. `offCentreFoldFromTheSideBars`: `split(length: 857, fold: 377.5...417.5)` (the content 62 pt narrower, the hinge
   shifted by the leading side bar) → primary 365.5, gap 64 — the asymmetric case is only a different range (B1).
4. `edgeFoldMovesTheLayoutOntoTheLargerSide` (B2, SF3): `fold: 10...50` → usable 62...919, primary nil;
   `fold: 880...919` → usable 0...868, primary nil; both sides small, `length: 300, fold: 140...180` → leading 128 ≥
   trailing 108 → usable 0...128, primary nil; `fold: 120...160` → trailing 128 → usable 172...300; a tie goes leading;
   in every case the usable range does not intersect the fold.
5. `foldOutsideOrCoveringTheLength` (SF3): `fold: 1000...1040` → as test 1; `fold: -10...310` on 300 (covers it) →
   usable 0...300, primary nil, gap 0; `fold: 280...400` on 300 (runs off the end) → usable 0...268; `fold: -20...30`
   → usable 42...300; every result's `usable` is a valid range inside 0...length.
6. `foldFilterByLayout`: `fold(in:wide:)` — wide takes a vertical region active or inactive (x range) and ignores a
   horizontal one; tall takes only an active horizontal region (y range) and ignores an inactive one and any vertical
   one; two regions → the first matching (one hinge per device, documented). `usableArea`: no region → the whole
   size; 300 x 240 with an active vertical region x = 140...180 → (0, 0, 128, 240) (the both-sides-small case: the
   decision on it is tall, 128 < 240); 951 x 669 with the centred vertical region → the whole size (both sides fit);
   669 x 951 with an inactive horizontal region → the whole size; with an active one at y = 10...50 → (0, 62, 669, 889).

Each is red before `FoldSplit.swift` exists (a compile error on the symbol is the right red; the implementer may
commit a stub returning the no-fold split first, against which 2–4 and 6 fail).

Gallery, `BChessGalleryTests/GalleryScenarioTests.swift` and `SnapshotGalleryTests.swift`. **Where they run (SF4):**
the gallery run selects `SnapshotGalleryTests` only (`snapshot-gallery.sh:208`, unchanged); these tests run with the
iOS scheme's tests — the final gate's `test-without-building` of `BChess (iOS)` — and, for the red proofs, with
`-only-testing:BChessGalleryTests/GallerySuites/GalleryScenarioTests` on a leased simulator, as the develop skill's
red-proof rule says. The gallery run proves the pictures, not these tests. The pixel oracles are a small test-only
`GalleryPixels.boundingBox(of color: UIColor, in image: UIImage, region: CGRect, tolerance: 2/255) -> CGRect?` over
the resolved Walnut fills (`UIColor(Walnut.frame).resolvedColor(with: host.traitCollection)`: the board frame is a
flat `RoundedRectangle.fill`, `BoardView.swift:56-57`; the cards are flat `Walnut.card`, `Walnut.swift:44`), which the
shadow (a blended black) and the coordinates (small glyphs) do not match. **The card colour is not unique in the whole
image (SF2):** light `Walnut.card` is pure white (`WalnutCard.colorset`) and so are the white pieces. The oracle is
therefore two-staged: the board is the `Walnut.frame` box (brown in both appearances, `WalnutFrame.colorset`; no
piece, square, pill or background uses it), and a card is searched **only in the region outside that box** — on the
trailing side of it for the sidebar, below it for the strip — where the only white-piece pixels could be captured
pieces in a player row, which the fixtures of these tests do not have (`ruyLopez` and `arrowsAndCards`: no captures;
test 8 asserts `capturedPieces` empty for both sides first). The background (`WalnutBackground`, cream / near black),
the pills and the squares are distinct from both target colours. Two callers, tests 7 and 8:

7. `landscapeFoldKeepsTheBoardAndTheSidebarOffTheHinge`: "Duo inner · Landscape · Game screen" rendered light and
   dark through the production `render`; the `Walnut.frame` bounding box ends at or before x = 455.5 − 12 (the fold
   minus the gutter, window coordinates) and starts after x = 16; the `Walnut.card` bounding box searched in the
   region trailing of the frame box (the moves card) starts at or after x = 495.5 + 12; neither intersects
   455.5...495.5. The "Flat open" capture equals the active one byte for byte (the wide layout aligns to the seam
   either way). With `foldRegions: nil` the frame box crosses the band (today's layout: the finding). Red after
   step 2, green after step 3.
8. `tabletopKeepsTheBoardAboveTheFoldAndTheStripBelow`: "Duo inner · Portrait · Tabletop" (no captures, asserted):
   the `Walnut.frame` box ends at or before y = 455.5 − 12; the move strip's "Moves" card (`MoveStrip.swift:59`,
   `walnutCard(radius: 16)`, the `Walnut.card` box searched below the frame box) starts at or after y = 495.5 + 12,
   and no `Walnut.card` pixel lies outside the frame box above the fold. "Duo inner · Portrait · Game screen"
   (inactive region): the frame box equals the one of the same build with `foldRegions: nil` (the flat layout: an
   inactive horizontal region changes nothing). Red until step 4.
9. `innerSizesReadRegularBothWays`: a `SizeClassProbe` mounted at `.duoInnerLandscape` and `.duoInnerPortrait`
   records `.regular` / `.regular` and the window is 951 x 669 / 669 x 951; `.ipadLandscape` reads regular width;
   `.phone` reads the scene's own classes and the screen's size; `.phoneLandscape` (step 5) reads compact / compact
   and the screen's size transposed (874 x 402 on the pool's iPhone, 678 x 466 on the Duo). Red: the sizes do not exist.
10. `duoPassRequiresTheOuterDisplay` (`SnapshotGalleryTests`, skipped unless `BCHESS_SNAPSHOT_DEVICE=duo`):
    `duoPassProblem()` is nil on a folded Duo, and `renderEveryScenarioInLightAndDark` calls it before its first
    capture (the entry point, §3.3). Red: the function does not exist.
11. `everyScenarioHasAPlatform`: each manifest entry's `platform` is `iphone` or `duo-inner`, and the inner sizes are
    the `duo-inner` ones (extends test 1 of APP-5).
12. `narrowTabletopReservesTheWholeCap` (B1): `ContentView(session: humanToMoveSession(), foldRegions:)` rendered
    through the primitive at 300 x 919 with the active horizontal region `(0, 439.5, 268, 40)` (content coordinates):
    the board is at most 268 pt wide, so the board column is far shorter than `primary` = 427.5; the `Walnut.frame`
    box still ends above y = 455.5 − 12, and the "Moves" card box starts at or after y = 495.5 + 12 (the controls did
    not climb into the reserved extent). Red with `maxHeight`, green with `height` + `alignment: .top`.
13. `edgeFoldsKeepTheWideLayoutInTheUsableArea` (SF4): `ContentView` at 951 x 669 with a vertical active region at
    content x = 10...50 → the frame box starts at or after window x = 16 + 62 and the card box is trailing of it (the
    existing branch, padded onto the usable side); at x = 869...909 (the trailing side under `minimum`) → the card box
    ends at or before window x = 16 + 857 and nothing is drawn in 869...909 + 16 (the band holds only `Walnut.background`
    pixels, a valid oracle here because no shadow reaches a region no view is laid out in). Red until step 3.
14. `edgeFoldsKeepTheTallLayoutInTheUsableArea` (SF4): `ContentView` at 669 x 951 with an active horizontal region at
    content y = 10...50 → the frame box starts at or after window y = 16 + 62; at y = 869...909 → the "Moves" card
    box ends at or before window y = 16 + 857. Red until step 4.
15. `narrowFallbackGoesTallInsideTheUsableArea` (round 3): `ContentView` at 332 x 272 (content 300 x 240) with the
    active vertical region x = 140...180 → the tall layout inside the 128 pt strip: the `Walnut.frame` box lies within
    window x = 16...144 and the "Moves" card box (below the frame box) within the same x range; no `Walnut.frame` or
    `Walnut.card` pixel at window x ≥ 156 (the fold and the far side hold only background). Red until step 3 (today's
    `width > height` on the container picks wide and the 320 pt sidebar overflows).

Scripts (the step gate of every script step): `scripts/test_snapshot_gallery.sh` with the cases of §3.4, red before
the script and page-script changes (`pool_duo` fails on the missing option, `layout` on the flat folder, `coexist` on
the full-tree removal); the existing fifteen cases stay green.

Screens: the new entities are the manifest's `platform` (written by `SnapshotGalleryTests`, read by
`preview-gallery.py` to place and link the file; test 11 and the `layout` case cover it) and the hook's `FoldRegion`s
(written by the seven fixtures, passed by `GalleryScenario.build` into `ContentView(foldRegions:)` or
`GameRootView(library:foldRegions:)`, read by `foldRegions(_:)`, filtered by `FoldLayout.fold(in:wide:)`, split by
`FoldLayout.split`, drawn on the seven inner cards and measured by tests 7–8 and 12–15 through the production
layout). Only the
`reservedRegions` call itself has no test: a fixed window carries no region and `simctl` cannot fold. It is the owed
Device Hub check (§8).

Views (toolbar step) are exempt from unit tests; the three gallery cards are read in both appearances. The landscape
change (step 5) is a plist key and two cards: test 9's `.phoneLandscape` row, test 11's platform (`iphone`), and the
two landscape cards read on the iPhone pass (the 230 pt board with the bars, the 320 pt sidebar beside it) and on the
Duo pass (the outer display sideways, 678 x 466); the real rotation is an owed device check (§8).

## 6. Invariants (`AGENTS.md`)

- **I1 — Files keep opening.** Not applicable: no document, model-format or PGN code changes.
- **I2 — A search result only lands on its position.** Holds: `GameSession` is untouched; the new scenarios keep a
  human to move (`humanToMoveSession`, the arrows fixture with two humans, the empty library) and the readout off (the
  scratch defaults), so no search starts; the hook only feeds geometry.
- **I3 — The engine stays portable.** Not applicable: `Shared/Engine/` untouched.
- **I4 — The UCI tool keeps working.** Not applicable: `BChess/` untouched; the UCI build stays in the gate.
- **I5 — Private and offline.** Holds: no network, no new required-reason API (`reservedRegions` is a layout query;
  `PrivacyInfo.xcprivacy` unchanged); the gallery stays local (`previews/` gitignored).

## 7. Steps

1. **Fold geometry** — `Shared/Model/FoldSplit.swift` (`FoldRegion`, `FoldSplit`, `FoldLayout.fold`,
   `FoldLayout.split`) with `BChessTests/FoldSplitTests.swift` (tests 1–6) written first and seen red.
2. **Gallery sizes, inner-display scenarios, the hook** — `GallerySize` with the size-class overrides and the capture
   scale in the render (`render` static), the `platform` manifest field, `GalleryPixels`,
   `ContentView(session:foldRegions:)` and `GameRootView(library:foldRegions:)` stored and unused, the seven
   "iPhone Duo · inner display" scenarios (47 cards), tests 7–9 and 11–15 (9 and 11 green, 7, 8 and 12–15 red). Gallery:
   `CHECK OK [en]: 47 cards`, the landscape cards show the board across the stand-in hinge (the finding, pictured).
3. **The wide layout splits at the hinge** — `ContentView`: the reader inside the padding, `reservedRegions` behind
   `#available(iOS 27.1, *)`, the decision on `usableArea`, the split branch beside the existing one, the sidebar's
   `min(320, area.width / 2)`, the area padding. Tests 7, 13 and 15 green; the
   Mac and the iPhone cards pixel-identical to step 2's. Gallery read: the four landscape cards in both appearances.
4. **The tabletop pose** (D2) — the tall layout's reserved extent (`height`, top-aligned) and the padding below the
   fold. Tests 8, 12 and 14 green; the three portrait cards read.
5. **Toolbar items and landscape on the iPhone** — §3.5: the toolbar labels and placements, the three cards read for
   the phone look, findings reported; `UISupportedInterfaceOrientations` opened to landscape in `iOS/Info.plist`
   (no project change), `GallerySize.phoneLandscape`, the two landscape cards (47 cards), test 9's row. Gate: the
   iOS build, the gallery run, the two cards read; the UI tests stay with the final gate.
6. **The Duo pass and the folder layout** — `snapshot-gallery.sh` (`--device`, `SIMULATOR_UDID`, `-testRegion US`,
   the device variable, the `duo` block), `preview-gallery.py` and `preview-luminance.swift` (the layout, the
   migration, the selective cleanup), `SnapshotGalleryTests` (test 10, `duoPassProblem()` in the entry point),
   `test_snapshot_gallery.sh` (the new cases, red first). Gate: the lifecycle tests, `scripts/snapshot-gallery.sh` on
   the iPhone (the flat gallery migrated, `CHECK OK [en]: 47 cards` under `previews/iphone/` and
   `previews/duo-inner/`), then `--device duo` to `CHECK OK` under `previews/duo/`, then the iPhone run again with
   both galleries intact; every outer-display card read (the side status bar, the sheets' buttons, the toolbar) and
   the inner cards on the 27.1 runtime; `simpool status` shows nothing leased.
7. **Docs** — §3.6: the preview-gallery skill (rebased on PR #24), `AGENTS.md`, this plan's Outcome, `planning/README.md`.
   Docs-only gate.

Gates per the develop skill: one step-gate build folder for the plan, the final gate on a fresh one (its iOS
`test-without-building` runs tests 7–15 with the UI tests), the gallery on the iPhone pass at every step that changes
a picture (2–6) and the Duo pass at step 6 and in the final gate.

## 8. Risks and rollout

- **File-format compatibility:** none (no model or document code).
- **The iOS 27.1 SDK.** `reservedRegions` compiles only with it: local Xcode is 27.1 (27A9275, checked); Xcode Cloud's
  "Latest Release" is 27.1 since late October (`docs/iphone-duo.md`). Before the next `/testflight`, the workflow's
  Xcode version is checked: a workflow pinned to 27.0 fails on the symbol, not silently. The live build #17
  (2026-10-24) predates the switch and ships the 27.0 tier; a new build is the rollout's step 2, outside this plan.
- **What needs a device or Device Hub (owed, no test can cover):** the OS delivering the real division region on a
  Duo simulator folded and opened in Xcode 27.1's Device Hub — the boundary measured on the hinge (x = 475 on 951),
  its frame in the content's space inside the vertical side bars (the asymmetric available area that a fixed window
  cannot show: the shell scenario's bars are horizontal), the tabletop cap, the region's real width (then the
  fixtures' 40 pt stand-in is corrected), the sheets presented as form sheets off the fold, the Moves sheet open while
  the device unfolds (SF7), Split View with the app on the left and on the right (item 13), the vertical bars with the
  Import / Export symbols; and, if `includeInactive` returns nothing on a flat-open Duo, the wide layout's fallback
  (the 320 pt sidebar, the seam under the board's g-file: no worse than today, recorded as a finding). A real device
  when one is at hand.
- **The pool's iPhone runs iOS 27.0:** its pass cannot execute the `#available(iOS 27.1, *)` branch; the inner cards
  render through the hook on every pass, and the Duo pass (27.1) is where the branch at least compiles and runs
  (returning no region in a fixed window). The gate counts the Duo pass's `CHECK OK` as part of step 6 and the final
  gate.
- **A fixed window larger than the screen.** The 1180 x 820 card already draws on a 402 x 874 screen; if the Duo
  runtime clips an oversized window, the inner cards on the Duo pass are a finding and the iPhone pass stays their home.
- **A reused Duo lease in another posture.** The entry point fails the pass before any capture is labelled "outer".
- **The colour oracles.** A flat fill resolved for the capture's appearance; if the renderer dithers or the asset's
  dark variant is not what `resolvedColor` returns, the tolerance is widened to 4/255 and noted as a deviation — never
  to a band check. The card search stays outside the board frame's box (the white pieces); a fixture that gains
  captured pieces breaks test 8's precondition loudly, not silently.
- **The migration of a flat `previews/`.** Resumable and idempotent (Departure's `migrate`); a half-moved folder is
  finished by the next command. `previews/` is gitignored; nothing to lose.
- **PR #24 (`skills-iphone-duo`)** touches the preview-gallery skill this plan's step 7 edits: step 7 rebases on
  `main` after that PR lands, or edits the branch's text if it has not.
- **Landscape on every iPhone (D3).** The plist change reaches every iPhone on iOS 18 and later, not only the Duo: a
  230 pt board on a 17 Pro in landscape, by Jean's choice. Owed on a device: rotate a phone with the Moves sheet, the
  New Game sheet and the promotion picker open, and the tent pose on a Duo. The UI tests launch portrait and set no
  orientation, so they are unaffected.
- **Rollout:** one squashed PR (develop phase 6); rollback is a revert. The hinge layout ships to users only through
  a 27.1-SDK build; on iOS 18–27.0 the app changes only by the landscape orientations.

## 9. Decisions for Jean

The planning subagent had no way to ask these mid-plan; the plan was written to the recommended choice of each.
**Decided by Jean on 2026-10-26 (go):** D1 hinge-aware, as planned; D2 the tabletop step kept, as planned; D3 first
**landscape on the iPhone**, then reverted (below). D4 and D5 stay open.

- **D1. The inner-display landscape boundary.** *Recommended (planned):* hinge-aware through `reservedRegions`
  (27.1) with the test hook; the iPad and iOS 18–27.0 keep today's 320 pt sidebar. *Alternative:* the boundary at
  the centre of every wide layout, no 27.1 API, fully pictured on every pass — at the cost of a 20 % smaller board on
  the 13" iPad in landscape (§4).
- **D2. The tabletop pose (step 4).** *Recommended (planned):* the board capped above an active horizontal fold, the
  controls on the flat half (a few lines on D1's machinery, two scenarios, test 8). *Alternative:* drop step 4 and
  live with the hinge through ranks 4–5 while half-folded in portrait; flat open is unaffected either way.
- **D3. Landscape on the iPhone (the tent pose, the outer display held sideways).** *Recommended (revision 1):* keep
  the portrait lock of 3c0611a. Jean (2026-10-26) first chose landscape, the board sizes accepted; it was built and the
  real rotated board measured 151 pt (not 230 pt). **Landscape on the iPhone tried on 2026-10-26, reverted the same day:
  the real rotated board measured 151 pt; a compact-height layout is a possible follow-up plan.**
- **D4. App Store screenshots** (rollout step 5: the inner display in landscape as the hero at 2853 x 2007, the outer
  display at 1398 x 2034, uploaded by hand): out of scope here; a follow-up once the Duo pass renders.
- **D5. An iPad pass** (`--device ipad`, the pool's spec): one more case after step 6; not planned.

## 10. Outcome (implementation, 2026-10-26)

Steps 1–7 landed as one commit each on `app-8-iphone-duo`. Gates: macOS 229 tests, the UCI build, the iOS scheme (UI tests
and the gallery tests; the engine GoogleTest cases are the 254 `gtest` cases of the macOS run), the lifecycle tests
(132 checks), zero warnings in the three targets, the gallery on the iPhone, the Duo pass and the iPhone again
(`CHECK OK [en]: 48 cards` each, both galleries intact; the Duo pass skips one). Deviations from the plan:

- **Project regenerated.** New files (`FoldSplit.swift`, `FoldSplitTests.swift`, `GalleryPixels.swift`) need
  `xcodegen generate`; `project.yml` is unchanged and `BChess.xcodeproj` is committed with it (steps 1 and 2).
- **Card count.** The gallery had 41 cards, not 38: 48 after step 2 (50 while the landscape cards existed, 48 at the end).
- **Steps 3 and 4.** The area padding is generic, so test 14 (the tall layout's top edge fold) is green at step 3; tests 8
  and 12 turn green at step 4. Red proofs: step 1 against a stub (all but `noFoldLeavesTheLayoutAlone`), step 2's tests
  against the unsplit layout, step 3 by restoring step 2's `ContentView`, step 4 on the step-3 tree.
- **Bare game screens ignore the safe area** (`GalleryScenarios.gameScreen`): a fixed window on a phone screen carries the
  phone's insets, which shifted every y coordinate of the fixtures.
- **The pixel oracle needs a solid block** (3 pt): the board frame's brown is also the primary text colour, so a plain
  colour box ran across the sidebar's text.
- **D3 reverted.** Step 5's landscape part was built and then reverted at Jean's decision: the real rotated game screen
  (a UI test on the pool's iPhone) had a 151 x 152 pt board in a 874 x 402 window, not the 230 pt of §3.3. The portrait
  lock is back (`iOS/Info.plist` as before step 5), the two "Phone landscape" cards, `GallerySize.phoneLandscape` and
  the landscape UI test are removed; step 5 keeps only the toolbar placements and symbols. A compact-height layout is a
  possible follow-up plan.
- **Findings, not fixed.** (1) Tabletop with variations: the cards inside the board column leave a board of about
  278 pt above the fold. (2) Import and Export in the Games list toolbar are icon-only now.
- **Harness limit, not an accepted picture (fix round 1).** The folded Duo places the system bars against its own
  466 x 678 screen, so on the Duo pass the "Duo inner · Landscape · Shell" card is skipped with a printed reason and a
  manifest flag, shown on the page as "not rendered on this pass", and `--check` accepts only that gap; the render fails
  when a mount's bounds differ from the requested size. The iPhone pass renders all 48.
- **`duoPassProblem()`** reads the scene's own horizontal size class instead of mounting a `.phone` probe (test 9 proves
  the two agree).
- **The gallery script passes `-collect-test-diagnostics never`** (develop skill, PR #25); the branch is rebased on main
  with PRs #24 and #25.
