# APP-13 — Game screen layout: captures on their own line, a strip that never clips, each fact once (#61)

Status: plan r3 (2026-11-21; r3: plan review round 2 — a proven width budget for the one-move fallback; r2: plan review round 1 — the one-move fallback takes the offered width, a thinking card, 13–15 captures, the Mac floor). Issue #61 (TestFlight feedback, iPhone, iOS 27.2). Not in scope: #62 (a prominent
end-of-game message that stays while browsing); this plan leaves the status line as the one slot #62 takes over.

## Problem, with evidence

The game screen is one `ContentView` for iPhone, iPad, the iPhone Duo and the Mac
(`Shared/Views/ContentView.swift`); APP-2 designed it (players as rows, one status line, a move strip), UI-WALNUT
restyled it. Four complaints, each traced to the code:

1. **Captured pieces squeeze the names.** `PlayerRow` (`Shared/Views/PlayerRow.swift:41-75`) puts the name and the
   detail ("White · your move", both `.lineLimit(1)`, l.43-51), a `Spacer`, the captured pieces (an `HStack` of 22 pt
   `SquareView`s, l.56-68) and the material points in **one** `HStack`. The pieces have a fixed width and the texts
   are truncatable, so with many captures the texts give way first: "N w", "Je… Bla…". The Mac hides it only through
   its 740 pt window floor (`macOS/DocumentWindow.swift:44`, "fifteen captures, 378 pt in dark mode") and the
   `BoardColumn` row floor (`Shared/Views/BoardColumn.swift`, `rowsMin`), which keeps the row as wide as its *minimum*,
   and a truncatable text's minimum is a few points: the Mac and the iPad truncate names too once the column narrows.
2. **The board sits high, the bottom third is empty.** `tallLayout` (`ContentView.swift:185-205`) stacks board column,
   status line, engine readout, move strip, then `Spacer(minLength: 0)`: every spare point lands below the strip. On
   iPhone the board is width-bound, so nothing grows into that space.
3. **The move strip clips at both ends.** `MoveStrip` (`Shared/Views/MoveStrip.swift:16-49`) shows the last six plies
   (`Game.recentMoves(current:count:)`, `Shared/Game.swift:108`) in a horizontal `ScrollView` and scrolls the current
   move to the trailing edge (`.onChange(of: currentMoveUUID, initial: true) { proxy.scrollTo(uuid, anchor: .trailing) }`,
   l.43-45). Six plies rarely fit beside the **Moves** button, so a scroll view always cuts the first visible move
   (`…e7`); the initial scroll runs before the content has its final width (the current move's pill is wider: bold,
   padding 10 vs 8, l.26-29), so the current move ends partly past the trailing edge, next to the button (`11. (`).
4. **Each fact appears more than once.**
   - Turn: the side's detail "White · your move", accented (`GameText.sideDetail`, `Shared/Model/GameText.swift:66-84`,
     shown by `PlayerRow` l.48-50) **and** the status line "Your move." / "Club Player to move." /
     "Club Player is thinking…" (`GameText.status`, l.91-129, shown by `Shared/Views/StatusLine.swift`).
   - Last move: the status line appends " Last: 15…Kd8" (`GameText.swift:125-128`, key `"%@ Last: %@"`) while the strip
     (iPhone) or the move list (iPad, Mac, `MoveListView`) highlights the same move as the current-move pill, and the
     board highlights its squares.

The gallery has no card that would have shown 1 or 3: "Game screen · Tall" uses `humanToMoveSession` (three moves each,
no capture), "Player row · Captures" one capture per side (`BChessGalleryTests/GalleryScenarios.swift:191-229`,
`GalleryFixtures.swift` `Fixture.captures`). The fifteen-capture `Fixture.worstRow` exists only in an oracle test
(`GalleryScenarioTests.wideLayoutKeepsTheWorstRowBesideTheMoveList`), and the long `Fixture.middlegame` only on the Mac.

**Mac.** The Mac window always takes the wide layout (`ContentView.swift:211`): it shares `PlayerRow` (problem 1, at
narrow window widths), `StatusLine` (problem 4) and `BoardColumn`; it has no move strip (the sidebar's `MoveListView`)
and no empty bottom (the wide column fills the height). So steps 1–2 apply to the Mac, steps 3–4 do not.

## Design

Four view changes and one text change, each reusing what is there. No new type except where named.

### 1. Turn beside the name; the status line says only what nothing else says

- **The turn lives in the player rows**, as today: the accented detail "White · your move" / "White · to move" for a
  human, the accent alone on a computer's bare colour. The one thing the status line said that the rows did not is the
  computer *thinking*: it moves into the computer's detail, "Black · thinking…", while `session.isThinking` and that
  side is to move (`GameText.sideDetail` gains `isThinking: Bool`; it reuses the `"%@ · %@"` sentence and a new leaf
  `"thinking…"`, like `"your move"`/`"to move"`; at Maximum the detail reads "Black · thinking…" while it thinks and
  "Black · 10 s" otherwise). `PlayerRow.detail` passes `session.isThinking && toMove`.
- **The last move is no longer written**: the current-move pill (strip, move list) and the board's highlight already
  show it. `"%@ Last: %@"` goes.
- **`GameText.status` becomes `status(mode:gameEnd:isWhiteToMove:) -> String?`**: "Analyzing. Moves are not saved." /
  "Practicing openings." for those modes; "Checkmate. White wins." / "Checkmate. Black wins." / "Stalemate." /
  "Draw by repetition." / "Game over." at a game end; `nil` otherwise. The parameters `isThinking`, `white`, `black`,
  `lastMove` go, and so does `StatusLine.lastMove`. Keys that become unused — `"Your move."`, `"%@ to move."`,
  `"%@ is thinking…"`, `"%@ Last: %@"` — are removed with `catalog-sync --delete-stale`; `isYou` stays (it decides
  "You" in `GameText.name`) with its comment updated.
- **`StatusLine` always takes one line** (an empty `Text(verbatim: " ")` hidden from accessibility when `status` is
  `nil`), so a game end or a mode change never moves the board, and #62 inherits a fixed slot: it replaces the
  game-end branch (and the view's styling) without touching the layout again. The slot stays where it is: under the
  board column in the tall layout, under the move list in the wide sidebar.

### 2. Captured pieces on their own line

`PlayerRow` becomes two lines inside the same view (no new view; the second caller would be none):

```
VStack(alignment: .leading, spacing: 2)
  HStack(firstTextBaseline) { name, detail }          // the whole row width: nothing else on this line
  HStack { captured pieces, Spacer?, material points } // .frame(height: 22): reserved even with no capture
```

The name gets `.layoutPriority(1)` over the detail, so a long name truncates only when it alone exceeds the row. The
capture line keeps today's pieces, sizes and dark-mode capsule (l.56-68) and is **always 22 pt tall**, so the first
capture never shifts the board. Pieces start at the leading edge, the points follow them (the row reads "pieces +3").
Both rows stay `.accessibilityElement(children: .combine)`. Fifteen captures with the points take about 378 pt in
dark mode (the `DocumentWindow` comment), a little more than the iPhone 17 Pro's 370 pt content width, so past twelve
captures the pieces overlap a few points (`HStack(spacing: -4)`): no wrapping, never a second capture line.

In the wide layout `BoardColumn` keeps measuring the rows as today (`rowsMin` is now the capture line's width, which is
what the 740 pt Mac floor already budgets); each row is ~24 pt taller, the board ~48 pt smaller on the 900 pt Mac
window and the 820 pt iPad. `DocumentWindow`'s floor comment is updated to say the capture line, the floor unchanged.

### 3. A move strip that only shows whole moves

Replace the `ScrollViewReader` + `ScrollView` with a `ViewThatFits(in: .horizontal)` over candidate strips of
`recentMoves(current:count: n)` for n = 8, 7, …, 1 (the existing function already numbers the first token of any
suffix, "11…Nf6", `Game.swift:108-114`): SwiftUI picks the longest that fits whole beside the Moves button. The last
token is always the current move, so it is always fully visible, and no move is cut at the leading edge. The last
candidate (one move) is the fallback when even that does not fit (accessibility text sizes): unlike the others it is
**not** `fixedSize()`, has `.lineLimit(1)` and `.minimumScaleFactor(0.5)`, so it takes the width offered beside the
Moves button and its text shrinks to fit rather than being clipped (review r1 blocker). Width budget (review r2
blocker): the last two candidates show the Moves button as its icon only (same action, same accessibility label), and
the strip caps Dynamic Type with `.dynamicTypeSize(...DynamicTypeSize.accessibility2)`, so the longest current move
(`"67… exd8=Q+"`-sized, about eleven characters) at the 0.5 floor fits beside the icon on the narrowest phone (320 pt
minus the margins). Proven by a gallery card, not by arithmetic alone: **"Move strip · Largest text"** renders the
longest-SAN position at `.accessibility5` on the narrowest phone, and the current move must be whole. `recentMoves`' default `count` stays 6 for no other caller (it has none); the
strip passes its counts. The `.leftToRight` pin and the Moves button are untouched. Up to eight on a wide portrait
(Duo flat, 669 pt) lets the move area grow where there is room.

### 4. The board block centred in the tall layout

In `tallLayout`'s non-tabletop branch, a `Spacer(minLength: 0)` **before** `boardColumn` as well as the one after the
strip: the block (players, board, status, engine, strip) sits in the middle of the free height, so the board moves
down by half of today's empty third. The tabletop branch keeps its top alignment (the board must stay above the fold,
`tabletopKeepsTheBoardAboveTheFoldAndTheStripBelow`). The wide layout is unchanged.

## Alternatives rejected

- **Turn only in the status line** (rows lose "· your move"): the status line would be the only text that changes every
  move, far from the side it is about, and #62 would have to share it with the turn. Kept as D1 (b).
- **The move list inline under the board on iPhone** (instead of centring): fills the space best, but it is a second
  scrollable list with its own height rules, the Moves sheet becomes redundant on some phones and not others, and it
  does not fix the strip on small phones and the Duo tabletop. Kept as D2 (b).
- **Captures beside the name when they fit, below when not** (`ViewThatFits` on the row): the board jumps the moment
  they stop fitting, mid-game. Kept as D3 (b).
- **Fading the strip's edges** (a mask over the scroll view): hides the cut instead of removing it; the current move
  could still be half hidden.
- **Keeping the scroll and fixing the timing** (scroll after layout with a `DispatchQueue.main.async` or
  `.defaultScrollAnchor(.trailing)`): fixes the current move but not the cut first move.

## Test plan

**Failing tests first (Swift Testing, `BChessTests/GameTextTests.swift`):**

- `statusForTheMoveToPlay` → rewritten as `statusIsNilDuringPlay`: `status(.play, end: .none, …) == nil` for every
  player combination of today's test (you, two humans, a named human, a computer's turn after going back).
- `statusForGameEnds`: the five game-end texts with no " Last:" suffix (today's l.92 expectation changes).
- `statusForModes`: unchanged texts, new signature.
- `statusWhileThinking`, `statusWithTheLastMove`, `aPlayerNamedYouIsNotYou` (status part): removed; the "You" naming
  checks that remain move to `names`.
- `sideDetails`: new rows — a computer to move and thinking → "Black · thinking…"; at Maximum thinking →
  "Black · thinking…", not thinking → "Black · 10 s"; a computer thinking but not to move → its usual detail; a human
  is never "thinking".
- `notationIsALeftToRightIsolate`: drop the `status(last:)` line (the isolate itself stays tested).
- `BChessTests/GameTests` (or the existing `Game` suite): `recentMoves(count:)` for n = 1…8 at a black move numbers the
  first token ("11…Nf6") and ends with the current move — the property the strip relies on.

**Localization:** `catalog-sync`, `--delete-stale`, translations of `"thinking…"` in fr/de/it/he/ar;
`BChessMacGalleryTests/LocalizationExpectations.swift` loses `"Your move."` and gains `"thinking…"` per language;
`LocaleIndependenceTests.statusIsNotEnglish` checks a game-end status (e.g. "Checkmate. White wins.") instead of
"Your move."; `LocalizationCatalogTests` green (no stale key, every translation).

**Gallery scenarios** (views are exempt from unit tests; every changed screen has a card):

- New fixtures in `GalleryFixtures.swift` (each parsed by `everyPGNFixtureParses`, its counts checked in
  `fixtureSessionsHoldTheirPositions`): `manyCaptures` — a legal game where **each** side has captured at least ten
  pieces and at least one side has captured 13–15 (past the twelve-piece overlap threshold, up to the fifteen maximum),
two humans with long given names ("Jeanne Blanchard" / "Nikolai Weissmann") so the names are the
  ones that used to truncate; `longCheckmate` — a game of 60+ moves ending in checkmate, so the strip shows high move
  numbers and the status line the game end with no "Last:".
- iPhone: **"Game screen · Many captures"** (new, also at the narrowest supported phone width),
  **"Game screen · Computer thinking"** (new: a real `GameSession` against the computer with `isThinking` set through
  the production path, so `PlayerRow.detail` shows "Black · thinking…"), **"Game screen · Long game"** (new, `longCheckmate` at its end),
  **"Game screen · Tall"** (re-rendered: centred block), **"Player row · Captures"** (switched to `manyCaptures`),
  **"Move strip · Long game"** (new: `longCheckmate` on a castling move in the middle, the current move whole at the
  trailing edge); **"Status line · Your move"** removed (it would render an empty line), **"Status line · Checkmate"**
  kept, **"Status line · Analyze"** added (the mode text).
- iPad (`.ipadLandscape`): **"Game screen · Wide · Many captures"** (new).
- iPhone Duo inner display: **"Duo inner · Portrait · Many captures"** (new, flat pose, the tall layout at 669 pt
  with the 8-move strip) and **"Duo inner · Landscape · Long game"** (new, the wide layout at the hinge).
- Mac (`MacGalleryScenarios.swift`): **"Document window · Many captures"** (new, `manyCaptures`, at the 740 pt window floor — the
budget the floor comment claims — and at 1440 × 900) and
  **"Document window · Checkmate"** (new, `longCheckmate`: the status line without "Last:").
- he/ar: the new and changed cards with `--lang he,ar` (iPhone, `--device ipad`, `--device duo`,
  `scripts/snapshot-mac.sh --lang he,ar`), board region compared with English (`magick compare -metric RMSE`, 0); the
  capture line mirrors (chrome), the strip does not.

**Layout oracles** (`BChessGalleryTests/GalleryScenarioTests.swift`): the five tall/fold/wide oracles stay green
unchanged (centring touches only the non-tabletop tall branch; the flat-pose check compares two centred renders);
`wideLayoutKeepsTheWorstRowBesideTheMoveList` stays green with two-line rows (its row bands are measured from the
board, the capture strip is still in the band's trailing part — the check `card.minX - 124…` moves to the capture
line's leading part if it fails, said in the step). One new oracle: **"the tall layout centres the board block"** —
on `gameScreenTall` at the iPhone size, the space above the top player row equals the space below the strip ±1 pt.

**Gates (`gates.md`):** the test gate (Mac, UCI, iOS on `--spec iphone`, plus `--spec ipad` since regular-width rows
change), the warnings gate, and the gallery gate: `scripts/snapshot-gallery.sh --only <the cards above>`,
`--device duo`, `scripts/snapshot-mac.sh`, each also `--lang he,ar`, shown to Jean.

## Invariants

- **I1 — Files keep opening:** holds; no file format, model or PGN change.
- **I2 — Search results land on their position:** holds; the row reads `session.isThinking`, already set and cleared
  on the main actor by `GameSession` (l.267, 280, 523, 543); no new callback.
- **I3 — Portable engine:** not applicable (no `Shared/Engine/` change).
- **I4 — UCI tool:** not applicable.
- **I5 — Private and offline:** holds; no new API.

## Risks and rollout

- **`ViewThatFits` and buttons:** it measures ideal sizes; the candidates except the last must be `fixedSize()`
  `HStack`s so a candidate never reports a compressed width; the last takes the offered width and scales down. Accessibility text sizes fall to one move — checked in the gallery at
  one accessibility size (the oracle helper already takes `textSize`).
- **Smaller board on the Mac and iPad** (≈ 48 pt): the price of the reserved capture lines. If Jean finds it too much,
  the capture line can collapse when both sides have no capture (D3 (b) without the jump in most games).
- **An empty status line** (≈ 18 pt) in normal play: the price of a fixed #62 slot (D4).
- **Thinking moves to the computer's row:** a reader who looked at the status line for "is thinking" now finds it
  beside the computer's name; VoiceOver reads it with the row.
- Rollout: UI-only behind no flag; one branch, one PR, the gallery shown to Jean before landing.

## Decision left open for Jean

None. Jean decided on 2026-11-21, taking the recommended option (a) for each of D1–D4 below.

- **D1 — Where the turn lives.** (a) Beside the name only, the accented "White · your move", the computer's
  "Black · thinking…" (recommended); (b) in the status line only ("Your move." / "Casual Player is thinking…"), the
  rows keep the accent but lose "· your move"; (c) both, as today, but the status line drops "Last:" only.
- **D2 — Using the empty bottom on iPhone.** (a) Centre the block (players, board, status, strip) in the free height
  (recommended); (b) the move list inline under the board, filling the space, the strip only where it does not fit;
  (c) board at the top, status line and strip pinned to the bottom above the toolbar.
- **D3 — Captured pieces.** (a) Their own line under each name, always reserved (recommended); (b) their own line only
  once a side has captured something (the board moves once per game); (c) on the name line, grouped and counted
  ("♟×5"), never wider than a third of the row.
- **D4 — The status line with nothing to say.** (a) An empty reserved line, so nothing moves at a game end and #62 has
  its slot (recommended); (b) hidden, the layout closes up and shifts at a game end.

## Steps

1. **Status line and turn text** — `GameText.status(mode:gameEnd:isWhiteToMove:) -> String?`, `sideDetail(…isThinking:)`
   with the `"thinking…"` leaf, `StatusLine` reserving its line and `PlayerRow` passing `isThinking`; failing
   `GameTextTests` first; `catalog-sync` (+ `--delete-stale`), translations, `LocalizationExpectations`,
   `LocaleIndependenceTests`.
2. **Captured pieces on their own line** — `PlayerRow` as two lines (name + detail; captures + points, 22 pt reserved,
   overlap past twelve pieces), `DocumentWindow` floor comment; `manyCaptures` fixture and the "Player row · Captures",
   "Game screen · Many captures", iPad, Duo portrait and Mac many-captures cards; the worst-row oracle kept green.
3. **Move strip of whole moves** — `MoveStrip` as `ViewThatFits` over `recentMoves(count: 8…1)`, no scroll view;
   the `recentMoves` numbering test; `longCheckmate` fixture and the "Move strip · Long game", "Game screen · Long game",
   Duo landscape and Mac checkmate cards.
4. **Board block centred on iPhone** — the leading `Spacer` in `tallLayout`'s non-tabletop branch; the "tall layout
   centres the board block" oracle; "Status line · Your move" replaced by "Status line · Analyze".
5. **Gallery pass** — the cards above in English, `--device ipad`, `--device duo`, `snapshot-mac.sh`, then `--lang he,ar`
   with the board-region comparison; fixes found there.
