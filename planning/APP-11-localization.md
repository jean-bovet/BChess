# APP-11 — Localization: the base four, then Hebrew and Arabic right to left

Status: accepted by Jean 2026-10-28 (go, D1–D6 as recommended), revision 3 (Codex plan rounds 1–2 folded in; round 2: six should-fix, all accepted; see
Revision history). Branch
`jean-bovet/hebrew-and-arabic-right-to-left` (Orca worktree, from `main`). GitHub issue #36; the shared list
`~/GitHub/maestro/global/languages.txt`; the method `~/GitHub/maestro/docs/right-to-left.md` and xFractal's
`planning/hebrew-arabic-rtl-plan.md` (the template the issue names).

Jean's scope (2026-10-28): **the base four first, then issue 36, on this one branch.** (1) The app's string catalog —
there is none today — with French, German and Italian (English the source). (2) The App Store page in the base four
(en-US, fr-FR, de-DE, it): name, subtitle, keywords, descriptions, the headlines of the five slide configs. (3) Hebrew
(`he`) and Arabic (`ar`; App Store Connect `ar-SA`) in the app and on the page, with the right-to-left checks the issue
lists. The steps put the base four before Hebrew and Arabic, so the branch can ship the base four alone (after step 5).
Out of scope: the other reach languages (es-ES, es-MX, pt-BR, ja, tr: a later plan adds them to the store page, the
same files and the same slide configs); uploading anything to App Store Connect (`/release`); What's New (a first
version has none; from the second release `/release` writes one file per locale); `InfoPlist.xcstrings` (the document
type names stay English, as xFractal's display name does; a follow-up with the reach languages if Finder's Kind column
matters).

## Revision history

- **Revision 3** (2026-10-28), Codex plan review round 2 (0 blockers, 6 should-fix, all accepted):
  - SF1 (comparing the exported PGN with the same run's engine output cannot see a locale leak): the PGN, the SAN
    labels and the FEN are pinned as byte literals in the fixtures, beside the JSON (Test plan, "I1 under a locale").
  - SF2 (`LocaleIndependenceTests` could skip silently; `TEST_RUNNER_` is stripped): the step-7 commands set
    `TEST_RUNNER_BCHESS_EXPECT_LANGUAGE` and `…_REGION` explicitly, the suite reads `BCHESS_EXPECT_LANGUAGE` /
    `BCHESS_EXPECT_REGION` and `#require`s both on `Locale.current`; the gate reads the executed-test count (a skip is
    red).
  - SF3 (sample-based coverage): the hosted assertions enumerate every level's five members, every one of the nine
    verdict branches, the friend's three side labels and the four piece names, each in every language.
  - SF4 ("Evaluation %@" assigned to `statistics(of:)`; export/delete failures and the Mac menus without a
    production-path check): `Verdict.accessibilityLabel` and `GameText.exportFailed/deleteFailed` are leaf resources
    with hosted samples; a hosted `MacMenuTests` reads the running app's Game and Edit menus.
  - SF5 (Design D's `--only` rule vs the Mac; the mixed-script scenario in the step-4 set; `move-strip-start`): the
    `--only` requirement is `snapshot-gallery.sh`'s only (the Mac has six windows, all rendered); the review set is
    versioned per step (the mixed-script scenario joins it in step 6); `move-strip-start` is in the set.
  - SF6 (`variationText`'s expected spacing contradicted `afterOpen`/`.close`): the assertion keeps today's spacing
    (no space after "(" or before ")").
  - The builder lives in `Shared/Views/MoveListView.swift` (`MoveRowView` is a private type there, no file of its
    own); views are not compiled into `BChessTests`, so the `variationText` and `statistics(of:)` tests are hosted
    (`BChessMacGalleryTests`), and the catalog-independent assertions on `EngineView` move there too.
- **Revision 2** (2026-10-28), Codex plan review round 1 (0 blockers, 6 should-fix, 2 simpler):
  - SF1 (I1 had no byte-stability test): accepted. `GameStateCodingTests` pins the JSON bytes and the PGN of games with
    named players (Latin, Hebrew, Arabic) and computer players against fixtures, and the same assertions run in a
    hosted suite under `-testLanguage ar -testRegion SA` and `he IL` in step 7 (Test plan, "I1 under a locale").
  - SF2 (the production-read coverage was three samples plus store captures): accepted. A coverage table maps every
    group of changed keys to a hosted assertion or a named scenario; the language runs render a **review set** of
    scenarios, not only the slides' captures (Design D, Test plan); the export message becomes a testable resource.
  - SF3 (mixed-direction comments in the move list): accepted. The variation line is a left-to-right isolate with
    each comment in a first-strong isolate, display only, with a pure-function test and a new scenario "Move list ·
    Mixed-script comments" (Design B).
  - SF4 (`Depth 9/12` and `⑂3` ordering): accepted. Both go through `GameText.notation` and the review set shows them
    under Arabic (Design B).
  - SF5 (`"Best " + line`, `"Mate"`, nine verdict keys): accepted (Design A).
  - SF6 (`NewGame` labels as resources vs `WalnutTextField`'s `LocalizedStringKey`): accepted with a correction — the
    labels reach the screen through `NewGameSheet.field(_ label: String, …)` → `Text(label)`, not through the text
    field (whose placeholder "Name" is a literal); the helper takes a `LocalizedStringResource`, and the friend's
    side-dependent labels are in the hosted samples and the review set (Design A, Test plan).
  - S1 (extend the gallery runs beyond the store captures): accepted — the review set.
  - S2 (per-language runs instead of a comma-separated `--lang`): rejected (Alternatives).
  - The plural's file is `iOS/GameRootView.swift` (the bare name in three places corrected).
  - The parent corrected a fact: the live en-US page already carries a description, subtitle and keywords; step 5
    copies them into the repo from `app-store check`.
- **Revision 1** (2026-10-28): first draft, written by the planning subagent from the issue, the code and the
  xFractal template.

## Facts established while planning

- **No localization exists.** No `.xcstrings`, `.lproj`, `.strings`; no `String(localized:)`, `NSLocalizedString`,
  `LocalizedStringResource`, `String(format:)`; `project.pbxproj` has `knownRegions = (Base, en)`. `project.yml:30`
  sets `STRING_CATALOG_GENERATE_SYMBOLS: YES` (a no-op without a catalog) and no `SWIFT_EMIT_LOC_STRINGS`
  (`catalog-sync` refuses a catalog target without it). The Walnut form components already take
  `LocalizedStringKey` (`Shared/Views/Walnut.swift:58-176`); only `WalnutSegmented.title: (Option) -> String` (:140,
  rendered by `Text(title(option))` :149) shows a `String` as given.
- **About 210 user-facing strings.** Literals in views (`Text("…")`, `Button`, `Label`, `.navigationTitle`, alerts,
  the Mac `CommandMenu` in `macOS/GameCommands.swift:35-114`) become `LocalizedStringKey`s and localize by themselves
  once a catalog exists. The rest is built as plain `String` in model types and shown with `Text(String)`, so it never
  localizes: `Shared/Model/GameText.swift` (names, titles, side details, status sentences), `Verdict.swift:20-48`
  (sentence, score), `NewGame.swift:28-73, 125-148` (opponent name, blurb, Elo, play label, side and name labels),
  `GameState.swift:18-34` (`EngineStrength.displayName`, `computerName`), `AppSettings.swift:20-26`
  (`AppTheme.title`), `GameSection.swift:17-23` (`Group.title`, hand-upper-cased "TODAY"), `GameShell.swift:132-134`
  (`ExportError`), `Shared/Views/PromotionView.swift:98-105` (piece names, accessibility labels),
  `EngineView.swift:99-105` (`statistics`), :150 (accessibility label), `iOS/GameRootView.swift:314-326` (export
  and delete messages). `GameCommands.swift:88` replaces the system pasteboard group, so "Cut" (:89) and "Select All"
  (:114) are the app's own strings.
- **Strings that cannot be localized as written** (interpolation or concatenation): `GameText.swift:33` ("A vs B"),
  :44 ("White · 10 s"), :46 ("White · Club"), :51 ("White · your move"), :74 ("Checkmate. Black wins."), :86 ("Ann is
  thinking…"), :90 ("Ann to move."), :96 ("… Last: 8…O-O"); `Verdict.swift:26-32` ("\(leader) is slightly better" —
  the adjective agrees with the colour in fr/it/he/ar); `GameState.swift:32` ("\(displayName) Player");
  `NewGame.swift:72` ("Play the \(computerName)"); `EngineView.swift:32` (`Text("Best ") + Text(line)`), :101-105
  ("Depth 9/12 with 1,234,567 nodes at 410,000 n/s"); `NewGameSheet.swift:152` ("\(Int($0)) s");
  `iOS/GameRootView.swift:314` ("\(n) games exported to “…”": a plural; Arabic has six forms), :316, :326.
- **Chess data never leaves the Swift side localized.** SAN, PGN and FEN are made and parsed in C++
  (`Shared/Engine/Helpers/FPGN.cpp`; the Seven Tag Roster at :1037-1043 from parsed tags and `resultString`), and
  Swift only copies node names (`Game.swift:91`) and builds "8. c3" (`GameText.moveLabel`, :55-57, ASCII
  interpolation). The JSON `GameState` (`GameState.swift:88-122`) stores a player's `name` only as typed (a computer
  is `name: ""`, :82; its label is computed at display time), `computer`, `level`, `pgn`, `rotated`: no English label
  is ever written. The default file name `"Game " + timestamp` (`GameLibrary.swift:103`, `en_US_POSIX` :201-206) is
  written to disk and shown as the title. The UCI tool's level names (`BChess/UCI/UCI.swift:207, 225`) are its own
  literals. `GameText.swift:87` compares a name with the literal `"You"` — broken by any translation (and by a human
  named "You").
- **Numbers.** Swift `"\(Int)"` interpolation gives ASCII digits; `EngineView.swift:99-100` uses `.formatted(.number)`
  (locale digits and grouping); the games-list dates are `Text(_, format: .dateTime…)` (`iOS/GameRootView.swift:332-335`,
  locale). Three `Text` literals interpolate a number into a `LocalizedStringKey`, which SwiftUI formats in the
  locale's digits: the rank labels `Text("\(8 - ai)")` (`LabelsView.swift:42`), the move numbers
  `Text("\(row.number).")` (`MoveListView.swift:138`), the variation count (`MoveStrip.swift:52`). Digits per locale
  (xFractal's probe, Foundation on this Mac): only `ar_SA` formats integers with Eastern Arabic-Indic digits (`٢٥٠`);
  `he_IL`, `ar`, `ar_AE`, `ar_MA` use Western. iOS lets a Saudi user pick either (Settings › Language & Region ›
  Numbers).
- **Layout direction.** Nothing pins it. The board is one subtree: `ContentView.swift:81-91` (`BoardFrame` around
  `BoardView`, `PiecesView`, `VariationSelectionView`; the promotion picker and the labels inside `BoardFrame`,
  `BoardView.swift:45-73`). `BoardView.swift:25-38` draws the files as an `HStack` (mirrors: the a-file would land on
  the right); `LabelsView.swift:31-57`, `PiecesView.swift:45-66`, `VariationSelectionView.swift:19-51` and
  `PromotionView.swift:84-92` place by `.offset(x:)` / `.position` (mirror under right to left); `Arrow.swift:15-36`
  is a `Path`. Taps are per square (`PiecesView.swift:59`): no point-to-square math, no `DragGesture`. Piece images are
  never flipped. The evaluation bar sits left of the board by `.padding(.leading)` + `.overlay(alignment: .leading)`
  (`ContentView.swift:94-99`). The move strip is a horizontal `ScrollView` anchored `.trailing`
  (`MoveStrip.swift:17-46`); the move list rows are an `HStack` of number, White, Black (`MoveListView.swift:136-144`)
  and the variation lines an `AttributedString` of SAN, "(" ")" and comments (:104-133). `NavigationButtons.swift:21-35`
  mixes `chevron.backward/forward` (SF Symbols that flip) with `backward.end/forward.end` (which do not). `BoardColumn`
  (`BoardColumn.swift:39`, `anchor: .topLeading`) and `FoldLayout` (`FoldSplit.swift:34-78`; APP-8 §Facts:176-178 "the
  regions come mirrored and the HStack lays out in the same mirrored space") are custom layouts whose mirroring only a
  render shows. The Mac shortcuts `←`/`→` and `⌘←`/`⌘→` (`GameCommands.swift:63-72`) step the game.
- **Tests and gallery.** `BChessUITests.swift:21-86` matches "More", "New Game", "Back", "Engine", "30 s", "Black" by
  label, everything else by identifier; the final gate's simulator runs in English. `BChessTests` compiles
  `Shared/Model` into an unhosted bundle (`project.yml:128-136`): `Bundle.main` is the xctest runner, so a
  `String(localized:)` there falls back to its key (English) — the existing `GameTextTests`, `NewGameTests`,
  `VerdictTests`, `GameSectionsTests`, `AppThemeTests` keep passing, and a translation can only be resolved in a
  **hosted** target: `BChessMacGalleryTests` (hosted by the Mac app, in the Mac scheme's test gate) and
  `BChessGalleryTests`. The gallery scripts hard-code `-testLanguage en -testRegion US`
  (`scripts/snapshot-gallery.sh:250`, `scripts/snapshot-mac.sh:52`); `scripts/test_snapshot_gallery.sh:179` asserts
  it; `scripts/preview-gallery.py:244` prints the literal `CHECK OK [en]` and :237 fails the check on a forced
  appearance or `\.locale` in a scenario file. The snapshot test (`SnapshotGalleryTests.swift:41-73`) renders the
  scenarios `BCHESS_SNAPSHOT_ONLY` names into `BCHESS_SNAPSHOT_DIR` and writes a manifest with a `platform` per
  entry; `preview-gallery.py` lays the gallery out as `previews/<platform>/<slug>[.dark].png` (iPhone `previews/iphone/`,
  Duo `previews/duo/{iphone,duo-inner}/`, iPad `previews/ipad/ipad/`, Mac `previews/mac/mac/`) and a full import
  removes only the top-level PNGs of those folders. `MacRenderer.swift:125` waits for `window.title ==
  scenario.title`, and `MacGalleryScenarios.swift:119, 126, 133, 140` hard-code "You vs Club Player" / "Settings"
  (:83 and :93 use `GameText.title`). The gallery's pixel tests (`GalleryScenarioTests.swift:221-442`) assume the
  board on the left; the scripts run only `SnapshotGalleryTests` (`-only-testing:…/SnapshotGalleryTests`), so a
  language run never executes them.
- **The renderer and the store tools.** `~/GitHub/maestro/tools/app-store-screenshots/layout.mjs:65-72`
  (`localizedCapture`) shows a locale the capture `<dir><locale>/<base>` or `<dir><language>/<base>` **inside the
  captures folder** (`--captures previews/iphone` → `previews/iphone/fr/<slug>.png`; Mac `previews/mac/mac/fr/`; iPad
  `previews/ipad/ipad/fr/`; Duo inner `previews/duo/duo-inner/fr/`, outer `previews/duo/iphone/fr/`), else the
  English one. Right-to-left headlines are done (`direction()`, `RTL_LANGUAGES`, `dir="rtl"` on the headline block,
  letter-spacing zeroed; maestro's reference skill says so). `app-store metadata` takes `--add-locale`, `--name`,
  `--subtitle`, `--keywords`, `--description LOCALE=FILE`; `release-check` and `app-store` hold no locale whitelist.
  The BChess `/release` skill §4 says "`AppStore/` holds only `screenshots.json`, no page texts" and §6 fills the page
  with `app-store metadata` by hand; the xFractal `/release` reads `AppStore/app-info.txt` (`locale|name|subtitle`),
  `AppStore/keywords.txt` (`locale=…`, ≤ 100 bytes), `AppStore/description-{ios,mac}-<locale>.txt` (≤ 4000 characters).
  The five slide configs (`AppStore/screenshots*.json`) have `locales: ["en-US"]` and one caption per slide (5, 5, 4,
  3, 5 slides). The live record (app 1360721014) has 1.0 on both platforms, en-US only, and its English page is
  already written in App Store Connect by hand (name `BChess`, subtitle "Chess with its own engine", ten keywords, a
  description with PLAY / UNDERSTAND sections; `app-store check --app "BChess (iOS)"` prints them read-only), but no
  copy of that text lives in the repo yet: step 5 brings it into the `AppStore/` files, so the translations start
  from the text the page carries, and `/release` keeps the two in step from then on.
- **`catalog-sync`** (on PATH) syncs a catalog headless from a build with
  `SWIFT_EMIT_LOC_STRINGS=YES`, needs the repo's `repos.yaml` entry to carry `catalog_project` and `catalogs`
  (`<path>@<target>+<target>`; `catalog_destinations: [<target>=macOS]` for the Mac target; the inline-list parser
  strips items, so target names with spaces and parentheses are fine) — BChess's entry (`repos.yaml:83-88`) has
  neither. XcodeGen derives `knownRegions` from the catalog's languages: `xcodegen generate` after each language
  batch, never a hand edit. The project already sets `productName: BChess` on both app targets (the scheme
  flip-flop xFractal fixed is not an issue here).
- **Codes.** Xcode, the catalog, `-testLanguage`: `fr`, `de`, `it`, `he`, `ar` (regions `FR`, `DE`, `IT`, `IL`, `SA`).
  App Store Connect: `fr-FR`, `de-DE`, `it`, `he`, `ar-SA` (store order per `languages.txt`: the base four, then
  `ar-SA` before `he`). Keywords are limited to 100 **bytes**: about 45 Hebrew or Arabic characters.

## Problem with evidence

1. The app is English only (Facts: no catalog, `knownRegions = (Base, en)`), and most of its words are plain
   `String`s in model types that no catalog would reach (`GameText.swift`, `NewGame.swift`, `Verdict.swift`,
   `GameState.swift:18-34`), several built by interpolation in a word order other languages do not share
   (`GameState.swift:32`, `NewGame.swift:72`, `Verdict.swift:26-32`), one a plural (`iOS/GameRootView.swift:314`), and one
   compared with its English text (`GameText.swift:87`).
2. The App Store page has no texts in the repo at all: `/release` fills it by hand in en-US (its §4, §6), and the five
   slide configs carry one locale.
3. Right to left was never looked at. The board's files are an `HStack` and its labels, pieces, arrows and promotion
   column are placed by `.offset(x:)` (Facts): under Hebrew the a-file, the coordinates and the pieces would mirror,
   and the arrows would not follow. The move strip, the move list and its variation paragraphs would run right to
   left around Latin SAN; a lone "−1.2" or "8…O-O" in a right-to-left paragraph puts its sign or number on the wrong
   side (Unicode bidi W5/N1; maestro's doc: the Mac showed `0.1230-`). Three numbers of the notation go through
   `LocalizedStringKey` and would take Eastern Arabic-Indic digits under `ar-SA` (`LabelsView.swift:42`,
   `MoveListView.swift:138`, `MoveStrip.swift:52`).
4. Nothing can show a screen in another language: the gallery scripts hard-code English, and the renderer's
   per-language captures have no producer.

## Design

### A. One catalog, two kinds of string (steps 2–3)

- **`Shared/Localizable.xcstrings`** (`sourceLanguage: en`), picked up by both app targets through their `Shared`
  source path (XcodeGen adds an `.xcstrings` as a resource); `BChessTests` does not get it (unhosted; Facts).
  `project.yml` base settings gain `SWIFT_EMIT_LOC_STRINGS: YES` (a comment: `catalog-sync` refuses a catalog target
  without it); `xcodegen generate` committed with it and after each language batch (`knownRegions`). The maestro
  `repos.yaml` entry for BChess gains `catalog_project: BChess.xcodeproj`, `catalogs: [Shared/Localizable.xcstrings@BChess
  (iOS)+BChess (macOS)]`, `catalog_destinations: [BChess (macOS)=macOS]` (step 1, committed in maestro). The sync is
  `catalog-sync` (builds both apps, adds every key, marks unused ones stale), `--delete-stale`, and `--check
  --skip-build` must print "catalog unchanged" before each commit: `AGENTS.md` gets the three commands in a new
  § Languages (as xFractal's), the `/develop` skill a "String Catalog" bullet.
- **View literals stay literals.** `Text("Moves")`, `Button("Cancel")`, `Label("Back", …)`, the alerts, the Mac menu
  items, the Walnut rows: `LocalizedStringKey`s the compiler extracts. Four exceptions become `Text(verbatim:)` so they
  never localize: the rank labels (`LabelsView.swift:42`) and files (:49), the move numbers (`MoveListView.swift:138`),
  the variation count (`MoveStrip.swift:52`). The hand-upper-cased "TODAY"/"YESTERDAY"/"EARLIER", "OPPONENT", "MOVES",
  "MAIN LINE"/"VARIATION", "OPEN" become title-case keys ("Today", …) with `.textCase(.uppercase)` on the `Text`
  (a no-op for Hebrew and Arabic, which have no case).
- **Leaf display members become `LocalizedStringResource`** (Foundation, so `Shared/Model` stays Foundation-only and
  the tests reach it): `EngineStrength.displayName` and `computerName` (one key per level: "Beginner Player", …,
  "Full Engine"; `GameState.swift:18-34`), `NewGame.Opponent.name` ("A friend"), `blurb`, `elo` ("about 550", the
  digits as text), `playLabel` (one key per level: "Play the Beginner Player", …, "Start Game"), `NewGame.sideLabel`,
  `firstNameLabel`, `secondNameLabel`, `AppTheme.title`, `GameSection.Group.title`, `PromotionView.label(of:)`,
  `Verdict.sentence` (nine keys: "The position is equal" and, for each colour, "… is slightly better", "… is
  better", "… is winning", "… has a forced mate"), `WalnutSegmented.title: (Option) -> LocalizedStringResource`
  (`Text(title(option))`), and the export message as a function `GameText.exported(count: Int, folder: String) ->
  LocalizedStringResource` (the plural key below), so that a hosted test resolves it per language and count. Views
  show them with `Text(resource)`; where a `String` is needed (`NewGameSheet` button titles, accessibility labels, the
  Mac window title, the alert's `exported` string) `String(localized: resource)`. The New Game name labels reach the
  screen through `NewGameSheet.field(_ label: String, text:identifier:)` (:114-122) → `Text(label)`, not through
  `WalnutTextField` (whose placeholder `"Name"` at :119 is a literal key): the helper's parameter becomes
  `LocalizedStringResource`. A test sets `resource.locale` and resolves it (xFractal's `LocalizationTests.localized`).
- **Composed sentences resolve with `String(localized:)`** and keep returning `String`: `GameText.name/title/
  sideDetail/status` (`String(localized: "\(name) to move.")` → key `%@ to move.`; the colour and the level resolved
  first with `String(localized:)`), "Checkmate. White wins." / "Checkmate. Black wins." as two keys,
  `ExportError.errorDescription`, `EngineView.statistics` (one key "Depth %@ with %@ nodes at %@ n/s", the first
  argument "9" or "9/12" as one isolated string — B), the accessibility label "Evaluation %@",
  `NewGameSheet.swift:152` ("%@ s"), the export messages (:314 the plural key `%lld games exported to “%@”` of
  `GameText.exported` with `variations.plural` — `one`/`other`, and `zero`/`two`/`few`/`many` for Arabic, `two`/`many`
  for Hebrew — written straight into the catalog JSON; :316, :326 become `GameText.exportFailed(_ error: Error)` and
  `deleteFailed(_:)`, `LocalizedStringResource`s with the key "Couldn't export the games. %@" / "Couldn't delete this
  game. %@" and `error.localizedDescription` as the argument). `Verdict.score` returns `String(localized: "Mate")`
  for a mate and the isolated signed number otherwise (B); the engine card's accessibility label (`EngineView.swift:150`)
  becomes `Verdict.accessibilityLabel` ("Evaluation %@" with the score; the view uses `Text(verdict?.accessibilityLabel
  ?? "Evaluation")`), a leaf resource a hosted test resolves. The best line
  (`EngineView.swift:31-37`) becomes one reorderable key: `Text("Best \(Text(notation(line)).fontWeight(.semibold)…)")`
  — a `LocalizedStringKey` interpolates a styled `Text`, so the key is `Best %@` and a language may put the line
  first — instead of `Text("Best ") + Text(line)`. The thinking time (`GameText.swift:44`): `"\(color) ·
  \(thinkingTime) s"` with the seconds as a `String` — see C.
- **`GameText.swift:87`**: `name == "You"` becomes the structural condition (the player has no given name and the
  opponent is a computer), the same one `name(of:)` uses at :20-22; `GameTextTests` gains the case of a human named
  "You" against a friend ("You to move.", not "Your move.").
- **What stays English, on purpose** (I1 and the notation): SAN, PGN, FEN, the piece letters (`Promotion.swift:16`,
  the bridge), "O-O", the move labels "8. c3" / "8…O-O" (`GameText.moveLabel`), the UCI option and level names
  (`UCI.swift`), the opening names from `Openings.pgn`, the default file name "Game <timestamp>" (data on disk; D3),
  the JSON keys, the accessibility identifiers and the board's accessibility value (the FEN), the asset names, the
  product name "BChess". No piece letters are localized ("Dame" is D in German notation: BChess writes standard
  English SAN, and the notation on screen is the notation in the file).
- **Translations** (fr, de, it in step 3; he, ar in step 7) are written by the implementation subagent into the
  catalog with a scratchpad script (the units in Xcode's JSON shape, `state: translated`; `catalog-sync --skip-build`
  re-sorts, `--check --skip-build` must print "catalog unchanged"), in the tone of xFractal's texts in each language
  (French `vous`, German `Sie`, Italian the imperative as its store text; standard spelling, so German keeps `ß` — the
  store locale is `de-DE`). The chess vocabulary that needs care, checked against Apple's glossary where Apple has the
  word (the `.loctable` files: Done, Cancel, Settings, Cut, Copy, Paste, Select All, Back, Forward, Light, Dark,
  System, Today, Yesterday) and Wikidata for the chess terms (the right-to-left doc's method): the pieces (Queen, Rook,
  Bishop, Knight), checkmate, stalemate, draw by repetition, "Game over", castling never appears, "en passant" never
  appears; the levels from APP-3 (Beginner, Casual, Club, Strong, Maximum: level names, not adjectives of the player —
  "Club" is the club player), "Club Player", "Full Engine", "A friend", "You", "White"/"Black" (as colours and as
  sides), "your move" / "to move", "is thinking…", "Analyzing", "Best", "Depth", "nodes", "n/s", "Engine",
  "Analyze Game", "Practice Openings", "Practicing openings.", "Thinking time", the blurbs (short, idiomatic),
  "about 1350" (the Elo). Hebrew interface verbs in Apple's gender-neutral forms, Arabic in Modern Standard Arabic
  with Apple's terms; a blind back-translation by Codex (`codex exec --sandbox read-only`, prompt on stdin) of every
  he and ar string and store text, read one by one, with the findings and decisions in this plan's implementation
  log (xFractal's step 4 log is the model: it caught "Replay" read as "Restart" and the app's gender in Arabic).

### B. Right to left: what mirrors, what must not (step 6; verified by the he/ar captures of step 7)

| Element | Under Hebrew/Arabic | How it is enforced (file, symbol) |
|---|---|---|
| Board: squares, coordinates, pieces, last-move and selection highlights, variation arrows, promotion column | **never mirrors** (a-file on the left, rank 1 at the bottom for White, exactly as in English) | `.environment(\.layoutDirection, .leftToRight)` on the `board` view of `ContentView.swift:81-91`, placed after the `.overlay` of :95 so it covers the whole `BoardFrame` subtree and the bar |
| Evaluation bar | stays **left** of the board (White's share grows from White's side, a vertical bar; its side is chrome, not meaning) | the same pin (the `.padding(.leading)`/`.overlay(alignment: .leading)` of `ContentView.swift:94-99` are inside it) |
| Move strip (recent moves) | **left to right**: the newest move at the right edge, scrolled to `.trailing` | `.environment(\.layoutDirection, .leftToRight)` on the `ScrollViewReader` of `MoveStrip.swift:18-46`; the "Moves" button beside it keeps mirroring (it lands on the left) |
| Move list rows: number, White's move, Black's move | **left to right**: "8. c3 c6", the number column right-aligned on the left | `.environment(\.layoutDirection, .leftToRight)` on the row's `HStack` (`MoveListView.swift:137-143`): the three cells keep their order; the list itself, its "Moves" caption and the card keep mirroring |
| Variation lines and comments in the move list: "( 8…O-O 9. d4 {a comment} )", a comment in Hebrew or Arabic between Latin moves, a standalone comment under a row | the **sequence** of moves and parentheses reads left to right; each comment reads in its **own** direction inside it (a Hebrew comment right to left, an English one left to right); nothing is written to the PGN | display only, in the paragraph builder `MoveRowView.variation(_:)` (`Shared/Views/MoveListView.swift:104-133`; `MoveRowView` is a private type in that file, there is no file of its own), made a static pure function `variationText(_ tokens: [MoveToken], current: UInt) -> AttributedString` on the type, which drops `private` so the hosted test reaches it: the whole line is wrapped in a left-to-right isolate (U+2066 … U+2069, so the base direction of the sequence never follows the window), and every `.comment` token in a first-strong isolate (U+2068 … U+2069, so the comment takes the direction of its own first strong character); the move tokens are plain (ASCII, strongly left to right); the standalone comments (:145-, `row.whiteComment`/`blackComment`) are their own paragraphs and need nothing (first-strong by default). A layout pin on the `Text` is **not** used (it does not set the bidi base direction; maestro's doc). Tested by a pure-function test and the new scenario "Move list · Mixed-script comments" |
| SAN or a signed number inside a sentence or alone: "… Last: 8…O-O", the best line, the score chip "−1.2", the depth "9/12" in the statistics, the variation count "⑂3" on the Moves button (outside the strip's pin) | the notation reads left to right inside the right-to-left sentence, and a slash or a symbol stays on its side of the number | `GameText.notation(_:)`, a pure function wrapping its argument in a left-to-right isolate (U+2066 … U+2069), used by `GameText.status` (the last move), `EngineView.bestLine` (`line`), `Verdict.score`, `EngineView.statistics` (the depth argument "9" / "9/12" as one isolated string) and `MoveStrip.swift:52` (`Text(verbatim: GameText.notation("⑂\(count)"))`); tested (maestro's doc: `.environment(\.layoutDirection)` on a `Text` does not fix the bidi base direction, the isolate does); the review set shows `engine-statistics` and `move-strip-with-variations` under Arabic |
| Back / Forward and Start / End | the chevrons keep pointing **left = earlier, right = later**, like the strip and the list | `chevron.left` / `chevron.right` in `NavigationButtons.swift:24, 35` (the non-flipping variants, consistent with `backward.end` / `forward.end` beside them); the Mac shortcuts `←`/`→`, `⌘←`/`⌘→` stay (D5) |
| Digits: coordinates, move numbers, the score, the thinking time, the Elo, the depth | **Western everywhere** (D1): the numbers of the notation and the ones that sit next to it | `Text(verbatim:)` (A) and `%@` arguments (`String(n)`) in the catalog keys; the catalog test forbids `%lld`/`%d` outside the plural allowlist |
| Node count and speed in the statistics; the games-list dates | **follow the locale** (digits and grouping): counts, not notation | unchanged (`EngineView.swift:99-100` `.formatted(.number)`, `iOS/GameRootView.swift:332-335`) |
| Game screen chrome: the players' rows, the status line, the engine card, the toolbar, the More menu, the New Game sheet (ladder, segmented controls, name fields), Settings, the Games list, the Mac menus and Settings window | **mirror** (SwiftUI: `HStack`, `.leading`/`.trailing`, `List`, sheets) | nothing to do; the he/ar captures of step 7 are the check |
| Wide layout (`BoardColumn`, iPad and Mac): the move list beside the board | expected to mirror (the list on the left of the board) — acceptable; only a render shows whether a custom `Layout`'s placement mirrors | the iPad and Mac captures of step 7; if the column does **not** mirror while its contents do, nothing is wrong either (the board is pinned); the plan takes what the render shows and records it |
| iPhone Duo split (`FoldLayout`) | APP-8 says the regions and the `HStack` mirror together | the Duo inner-display capture of step 7 under `he`; a real Duo half folded under Hebrew is owed |
| Name fields (Hebrew/Arabic keyboard, mixed names "Ann vs דני") | system behaviour | a real device (Risks) |

Nothing else in the app reads x coordinates (Facts: taps per square, no `DragGesture`).

### C. Digits and times (D1)

Western digits for everything that belongs to the notation or sits next to it: coordinates, move numbers, the score,
the depth, the thinking time ("10 s"), the Elo ("about 1350"), the variation count. Locale formatting (which only
differs under `ar-SA`, and only when the user keeps the default) for the node count, the speed, and the dates. The
thinking time is a catalog key `%@ s` (the `s` translated: fr/de/it `%@ s`, he/ar the translator's abbreviation),
not `Duration.formatted` (no control over the digits, and the segmented control's "5 s / 10 s / 30 s" and the UI
test's `"30 s"` keep their text).

### D. The gallery in another language (step 4; reused by steps 5, 7 and 8)

- `scripts/snapshot-gallery.sh` and `scripts/snapshot-mac.sh` gain `--lang en,fr,…` (default `en`; whitelist
  `en|fr|de|it` in step 4, `|he|ar` in step 7, like xFractal's) and `region()` (`en→US ja→JP he→IL ar→SA xx-YY→YY
  else upper-case`): one test run per language, `-testLanguage "$lang" -testRegion "$(region "$lang")"` in place of
  the hard-coded `en`/`US` (:250, :52). English imports as today; another language imports with
  `scripts/preview-gallery.py --import DIR --lang fr`, a new flag that copies the run's PNGs into
  `previews/<platform>/<lang>/` (the platform from the run's manifest) and prints `imported N image(s) [fr] into
  previews/<platform>/<lang>/` — no manifest, no page, no check for a language run (the gallery stays English: the
  `--check`, the page, `CHECK OK [en]`, the forced-locale guard are untouched; a full English import never deletes
  the language subfolders, Facts). That layout is exactly where the renderer looks (`localizedCapture`, Facts), for
  all five configs. An iPhone, iPad or Duo language run must use `--only` (the skill's rule: never a full gallery in
  another language); `snapshot-gallery.sh` refuses `--lang` without `--only` for a language other than `en`.
  `snapshot-mac.sh` has no such rule: the Mac gallery is six windows, all of them in the review set, so `--lang`
  renders them all (`--only` still works there).
- `scripts/test_snapshot_gallery.sh` gains a case `pool_languages`: `--lang fr,he --only x` calls xcodebuild with
  `-testLanguage fr -testRegion FR` and `-testLanguage he -testRegion IL`, and `--lang xx` exits 2 (red first:
  exit 2 on `--lang` today).
- The Mac scenarios' hard-coded titles (`MacGalleryScenarios.swift:119, 126, 133`) become `GameText.title(white:
  .defaultWhite, black: .defaultBlack)` (as :83 does) and :140 the `String(localized:)` of "Settings", so
  `MacRenderer.waitUntilReady` matches under any language (the test bundle runs inside the host app: the same
  catalog, the same locale); `MacGalleryScenarioTests.swift:73, 165` compare with the same expression.
- **The review set.** A language run renders one named list, kept in the `/preview-gallery` skill (and quoted by
  `/app-store-screenshots`), which holds the slides' captures **and** the screens whose words or direction the
  catalog changes — one coverage policy, not two: on the iPhone `game-screen-engine-on`, `game-screen-rotated`,
  `player-row-to-move`, `player-row-captures`, `status-line-your-move`, `status-line-checkmate`,
  `navigation-buttons`, `engine-equal`, `engine-mate`, `engine-analyzing`, `engine-statistics`, `engine-long-line`, `move-strip-start`,
  `move-strip-middle`, `move-strip-with-variations`, `move-list-variations-and-comments`, `move-list-card`,
  `promotion-drops-from-the-top`, `variations-arrows-and-cards`, `games-list-four-games`, `launch-empty-library`,
  `new-game-club`, `new-game-friend`, `new-game-maximum`, `new-game-players`, `settings` — that is the set step 4
  writes into the skill; step 6 adds `move-list-mixed-script-comments` (the scenario it creates, B) to it; on the
  iPad `game-screen-wide` and the slides' captures; on the Duo the inner-display scenarios the Duo config names plus
  `duo-inner-landscape-variations`; on the Mac every Mac scenario (the document window with the engine, the
  variations, the New Game sheet in its three layouts, Settings: `scripts/snapshot-mac.sh --lang` renders them all,
  there are six, no `--only`). The visual check of a translation or a right-to-left screen is therefore
  `scripts/snapshot-gallery.sh --only "<the review set>" --lang he,ar` (and `--device ipad`, `--device duo`,
  `scripts/snapshot-mac.sh --lang he,ar`), then the PNGs read with the Read tool against the table of B. The slides'
  captures are a subset, so the store renders need no second run. No scenario forces a language (AGENTS.md); the
  language comes from `xcodebuild`.

### E. The App Store page files (steps 5 and 8), read by `/release` and `/app-store-screenshots`

xFractal's layout, which the shared `/release` reference already describes: `AppStore/app-info.txt` (`locale|name|
subtitle`, ≤ 30 characters each; the name `BChess` in every locale), `AppStore/keywords.txt` (`locale=k1,k2,…`, ≤ 100
bytes; checked with `LC_ALL=C awk '{ print length($0) - index($0, "=") }'`), `AppStore/description-ios-<locale>.txt`
and `description-mac-<locale>.txt` (≤ 4000 characters; the Mac text says document windows and the Game menu where the
iOS one says the Games list and the More menu). English first (step 5: the text the live en-US page already carries, copied
from App Store Connect through `app-store check --app "BChess (iOS)"` — the lead paragraph and the PLAY / UNDERSTAND
sections — into `description-ios-en-US.txt`, and a Mac variant of it; no retired domain, no email), then fr-FR,
de-DE, it; he and ar-SA in step 8. The five slide configs: `locales` in store order (`en-US, fr-FR, de-DE, it`, then
`ar-SA, he`), every slide's `text` with one `{title, sub}` per locale, titles broken with `\n` as the English (one line
in the Mac config), claims kept to the description's. Rendered and reviewed, never uploaded: `app-store-screenshots
--captures previews/iphone` (and `--config … --captures …` for the iPad, Mac, Duo inner and outer sets) after the
captures of D in each language; the review page shows one row per locale; "headline shrunk" lines mean a shorter
title. Store order and codes per `languages.txt`.

The BChess `/release` skill changes with step 5: §4 "The App Store page" says the files above exist (the xFractal
paragraph, `BChess`'s names), §6 gains the `app-store metadata … --add-locale … --name … --subtitle … --description
LOCALE=AppStore/description-<p>-<locale>.txt --keywords …` block per platform (run on the first release, and later
only when `AppStore/` changed), the "First release" paragraphs say the page is filled from `AppStore/`, and the
notes paragraph says one file per locale from the second release on (`ReleaseNotes/<v>-<locale>.txt`, `--notes
<locale>=<file>`; Jean decides what to translate). `/app-store-screenshots` drops "One store language, en-US", lists
the locales, and gets the `--only … --lang` capture commands per device pass (xFractal's wording, BChess's slugs:
`game-screen-engine-on`, `new-game-club`, `variations-arrows-and-cards`, `games-list-four-games`, the dark capture;
the iPad, Duo and Mac slugs from their configs). `/preview-gallery` and `/develop` get the `--lang` sentence.
Step 8 adds `he`, `ar-SA` to every list and the storefront-order check of xFractal's skill §4 (the pair fallback does
not apply: BChess has no two-panel pair).

### F. Scope guard for the base four

After step 5 the branch is shippable as "the base four": the catalog with fr/de/it, the store files for four locales,
the gallery's `--lang`, the skills. Steps 6–8 add right to left, he and ar, and the two store locales.

## Alternatives rejected

- **`String(localized:)` everywhere, `String` members kept** (no `LocalizedStringResource`): simpler types, but no
  test can resolve a member under `he` or `ar-SA` (`String(localized:)` takes the current locale; threading a `locale:`
  parameter through `GameText` for tests only is a test-only path). The leaf members are resources, the composed
  sentences strings: the catalog test covers both, the hosted test resolves the leaves.
- **`CFBundleLocalizations` / `.lproj` folders / `.strings`**: the catalog is the current format; `knownRegions` follows
  it through `xcodegen generate`.
- **Pinning the whole game screen left to right**: hides the right-to-left pass the issue asks for; the chrome
  should read right to left for a Hebrew or Arabic user, and only the notation must not.
- **Locale digits everywhere** (`.formatted()` on the move numbers and coordinates): Eastern digits beside Latin
  SAN on the same line under `ar-SA`, and a Saudi user's notation would differ from every book and site. The
  alternative of D1.
- **A `Locale` with `numberingSystem: latn` helper**: one caller; `String(n)` arguments and `Text(verbatim:)` do it
  with no helper.
- **`Duration.formatted` for the thinking time**: locale digits, an "s" that varies by width; the key `%@ s` is one
  catalog entry.
- **A language dimension in the gallery page and check** (xFractal's `previews/<lang>/` galleries): BChess's gallery is
  laid out per platform and the renderer looks for `<platform>/<lang>/`; a language run is the review set only,
  reviewed by eye, so no second manifest and no per-language page.
- **One `--lang` per invocation instead of a comma-separated list** (Codex S2): a single invocation builds for
  testing once, leases one simulator and runs one test per language (xFractal's loop, about ten lines); per-language
  invocations repeat the lease, the build check and the launch for every language, and the lifecycle case is one
  `expect` either way. The list stays; `--lang fr` alone is the same path.
- **A layout-direction pin on the variation `Text`** (revision 1): it orders the cells of an `HStack` but does not
  set a paragraph's bidi base direction (maestro's doc, the Mac's `0.1230-`), and it would force a Hebrew comment to
  read left to right. The isolates of B do both jobs, display only.
- **Direction-aware gallery pixel tests** (xFractal's step 5): BChess's scripts never run `GalleryScenarioTests` in
  another language (`-only-testing:` the snapshot test), so nothing assumes a side under `he`; not touched.
- **Accessibility identifiers for the six labels the UI tests match**: the final gate runs the simulator in English,
  the English text does not change, and the identifiers would be a change nobody runs under another language. Left
  as is; the UI tests stay green.
- **Changing the Mac arrow shortcuts under right to left** (D5 alternative): Back is `←` in every chess app;
  the strip and list stay left to right, so left is earlier in the user's own layout too.
- **Hand-written `knownRegions`** in `project.yml`: XcodeGen derives them; regenerate (xFractal B1).

## Test plan (red first)

- **`BChessTests/LocalizationCatalogTests.swift`** (Swift Testing, unhosted: parses `Shared/Localizable.xcstrings`
  through `#filePath`): `static let languages` (`[]` in step 2, `["fr","de","it"]` in step 3, `+ ["he","ar"]` in
  step 7). (1) every key whose `shouldTranslate` is not `false` has `localizations[lang].stringUnit.state ==
  "translated"` for every language, or, for a `variations.plural` key, every form translated; red in step 3 and
  step 7 until the translations are written (xFractal's red proof: "<key> has no fr translation" × N); (2) no key is
  `extractionState: stale`; (3) a key containing `%lld` or `%d` is in the allowlist `["%lld games exported to “%@”"]`
  — the digits rule of C, red if a composed key ever interpolates an `Int` directly; (4) no key contains U+2066/U+2069
  (the isolate is applied by code, never typed into a key).
- **`BChessMacGalleryTests/LocalizationTests.swift`** (hosted by the Mac app, in the Mac scheme's test gate; Swift
  Testing): `localized(_ resource: LocalizedStringResource, _ language: String) -> String` (sets `resource.locale`);
  for every language of the catalog test's list, the enumerated assertions of the coverage table below (every
  branch of every leaf member — the English value and each translation, so a wrong or swapped unit fails by name),
  written as parameterized tests over the cases and the languages; red until the units exist. In step 7: `NewGame.Opponent
  .club.elo` under `ar-SA` contains `1350` and no scalar in U+0660…U+0669 / U+06F0…U+06F9 (compare scalars:
  `String.contains` folds digit forms), and `GameText.exported(count:folder:)` resolves for 1, 2, 3 and 11 under
  `ar` to four different strings (the plural forms) and under `he` for 1 and 2.
- **Coverage: every group of changed keys to the test or scenario that reads it through production code**
  (the key is read by `Text` / `String(localized:)` in the app the host runs, or by the hosted test):

  | Keys | Written in | Read on screen by | Covered by |
  |---|---|---|---|
  | Level names, computer names, play labels, blurbs, Elo | `GameState.swift`, `NewGame.swift` | `NewGameSheet` (`Text(opponent.name/elo/blurb)`, `Button(buttonTitle)`), `PlayerRow`, the title | hosted: **all five** `EngineStrength` cases × `displayName`, `computerName`, and all six `Opponent` cases × `name`, `blurb`, `elo`, `playLabel`, in every language (a table of expected values per language, `#expect` by name); review set `new-game-club`, `new-game-maximum`, `new-game-friend`, `player-row-to-move`, Mac New Game sheet ×3 |
  | Side and name labels (friend: White / Black / Random colour; computer: Your name, You play) | `NewGame.swift:125-148` | `NewGameSheet.field(_:)` → `Text(label)`, `Text(choice.sideLabel)` | hosted: `sideLabel`, `firstNameLabel`, `secondNameLabel` for `.friend` × `.white`, `.black`, `.random` and for a computer, every language; review set `new-game-friend`, `new-game-players` |
  | Composed statuses, titles, side details, "Your move.", "Checkmate. … wins.", "Last: …" | `GameText.swift` | `StatusLine`, `PlayerRow`, `GameRootView:142`, `DocumentWindow:48` | `GameTextTests` (English composition, the "You" case, the isolate); review set `status-line-your-move`, `status-line-checkmate`, `player-row-to-move`, `game-screen-engine-on`; the Mac window title (`MacRenderer.waitUntilReady` matches the localized title); the locale runs of `LocaleIndependenceTests` assert `GameText.status` under `ar`/`he` is not the English sentence |
  | Verdict sentences (nine), "Mate", the score, "Evaluation %@" | `Verdict.swift` | `EngineView` (`Text(verdict.sentence)`, `scoreChip`, `.accessibilityLabel`) | hosted: **all nine branches** — `centipawns` 0, +50, −50, +150, −150, +300, −300, and `isMate` for both colours — plus `Verdict.accessibilityLabel` and `score` of a mate, every language; `VerdictTests` (English); review set `engine-equal`, `engine-mate` |
  | Statistics, best line, "Analyzing…" | `EngineView.swift` | `EngineView` | hosted `EngineView.statistics(of:)` (the isolated depth, the localized sentence per language); review set `engine-statistics`, `engine-long-line` (the best line under Arabic), `engine-analyzing` |
  | Export success (plural), export and delete failures, `ExportError` | `GameText.exported`, `GameText.exportFailed/deleteFailed`, `GameShell.swift` | the alerts of `iOS/GameRootView.swift` | hosted: the plural for 1/2/3/11 (above), `exportFailed(CocoaError(.fileWriteNoPermission))` and `deleteFailed(…)` per language (the key resolved, the error's text appended); `GameShellTests` for `ExportError.errorDescription`; no scenario (a transient alert) — the owed device check exports once under Hebrew |
  | Theme titles, day groups ("Today" …) | `AppSettings.swift`, `GameSection.swift` | Settings segmented control, the Games list headers | `AppThemeTests`, `GameSectionsTests` (English); hosted: the three themes and the three groups, every language; review set `settings`, `games-list-four-games` |
  | Piece names (promotion accessibility labels) | `PromotionView.swift:98-105` | `.accessibilityLabel` | hosted: the four pieces, every language; review set `promotion-drops-from-the-top` (the picker itself has no text) |
  | View literals on iOS: buttons, alerts, Settings rows, "No moves yet", "Moves" | the views | themselves | the catalog test (every extracted key translated); review set `launch-empty-library` (navigation and bottom bars), `settings`, `move-strip-start` ("No moves yet"), `move-list-card` |
  | The Mac `CommandMenu` ("Game": New Game, Players…, Flip Board, Back, Forward, Start of Game, End of Game, Show Engine, Analyze Game, Practice Openings) and the replaced pasteboard group (Cut, Copy Game, Copy Position, Paste Game or Position, Select All) | `macOS/GameCommands.swift:35-114` | AppKit's menu bar of the running app (the Mac gallery renders windows, never the menu bar) | hosted `BChessMacGalleryTests/MacMenuTests.swift`: finds `NSApp.mainMenu`'s Game menu by `String(localized: "Game")` and asserts each item's `title` equals `String(localized:)` of its key, and the Edit menu holds the five replaced items likewise; run in the English gate and in step 7's two locale runs, where it also asserts the titles differ from the English keys (a translation reached the menu) |
  | Move list rows, variation lines, mixed-script comments | `Shared/Views/MoveListView.swift` | the move list | the hosted `variationText` test; review set `move-list-variations-and-comments`, `move-list-mixed-script-comments` (from step 6) |

- **I1 under a locale** (byte stability). `BChessTests/GameStateCodingTests.swift` gains `namedPlayersWriteTheSameBytes`:
  a `GameState` with `white: GamePlayer(name: "Ann")`, `black: .computer(.club)`, and one with Hebrew and Arabic names
  (`"דני"`, `"سامي"`) and a Maximum computer, encoded with `data(for: .bchessGame)`, equal byte for byte to a
  fixture literal in the test (sorted keys, the names as typed, `name: ""` for the computer, `level` as an integer);
  `data(for: .pgn)`, the engine's `getPGNCurrentGame` after a short game (1. e4 e5 2. Nf3 Nc6 3. Bb5 with a
  promotion-free capture line), `session.fen` and the `GameText.moveLabel` of each move equal to **byte literals in the
  test** (the Seven Tag Roster in ASCII, `[Result "*"]`, standard SAN, the FEN's digits and side letters) — never to
  the output of the same run, so an engine or bridge that consulted the locale would fail against the literal;
  `decodesLegacyJSON` (:18) already reopens a file without `white`/`black`. The same assertions live in a hosted
  suite `BChessMacGalleryTests/LocaleIndependenceTests.swift` that reads `BCHESS_EXPECT_LANGUAGE` and
  `BCHESS_EXPECT_REGION` from its environment (xcodebuild strips the `TEST_RUNNER_` prefix on delivery, as the gallery
  scripts document) and `#require`s `Locale.current.language.languageCode?.identifier` and `Locale.current.region?
  .identifier` to equal them; the suite is skipped (`.enabled(if:)`) only when the language variable is unset, which
  is the English gate, and asserts, besides the bytes, that `GameText.moveLabel`, `Verdict.score`,
  `EngineView.statistics(of:)`'s depth and `GameLibrary.timestamp` carry no Eastern Arabic-Indic scalar. Step 7's
  gate runs it twice beyond the English test gate, each time with the variables set on the command line:

  ```
  TEST_RUNNER_BCHESS_EXPECT_LANGUAGE=ar TEST_RUNNER_BCHESS_EXPECT_REGION=SA buildlock --folder ~/Library/Containers/ch.arizona-software.BChess --no-slot -- buildlock --folder <dd>/dd-mac -- xcodebuild test -scheme "BChess (macOS)" -destination 'platform=macOS' -derivedDataPath <dd>/dd-mac -only-testing:BChessMacGalleryTests/LocaleIndependenceTests -only-testing:BChessMacGalleryTests/MacMenuTests -testLanguage ar -testRegion SA
  TEST_RUNNER_BCHESS_EXPECT_LANGUAGE=he TEST_RUNNER_BCHESS_EXPECT_REGION=IL … -testLanguage he -testRegion IL
  ```

  and reads each log's executed-test count: the suite's tests must have **run** (a skipped suite, or a `#require`
  that failed on the wrong locale, is red), so the JSON, the PGN, the FEN and the notation are proven byte-identical
  with the process locale really set to Saudi Arabic and Hebrew, not only argued from the writers' code. Red proof:
  the fixture bytes are a characterization (red if any writer ever consults the locale or a label leaks in); the
  digits assertion is proven red by formatting one value through `.formatted()` under `ar-SA` once, then restored.
- **`BChessTests/GameTextTests.swift`**: the "You"-named human ("You to move.", not "Your move."), red with the
  literal comparison at :87; `GameText.notation("8…O-O") == "\u{2066}8…O-O\u{2069}"`, `status(…, lastMove:)` ends
  with the isolated last move, `Verdict(centipawns: -120, isMate: false).score == "\u{2066}−1.2\u{2069}"` (and
  `VerdictTests` adjusted), red before step 6. Views are not compiled into `BChessTests`, so the two view-side pure
  functions are tested hosted, in `BChessMacGalleryTests/MoveListTextTests.swift` (Swift Testing, `@testable import
  BChess`): `EngineView.statistics(of:)` with depth 9 and quiescence depth 12 contains `"\u{2066}9/12\u{2069}"`, and
  `MoveRowView.variationText([.open, .move("8…O-O", 3), .comment("הערה"), .move("9. d4", 4), .close], current: 0)`'s
  characters are exactly `U+2066` `(` `8…O-O` ` ` `U+2068` `הערה` `U+2069` ` ` `9. d4` `)` `U+2069` — today's
  spacing kept: no space after "(" (`afterOpen`) and none before ")" (the `.close` rule at :126), one space before
  every other piece — and a token list without a comment carries exactly one isolate pair; the `MoveToken`s passed in
  are unchanged. Red before step 6. The existing `GameTextTests`, `NewGameTests`, `VerdictTests`,
  `GameSectionsTests`, `AppThemeTests` keep their English expectations (`String(localized:)` resolves to the English
  key in the unhosted bundle; `#expect(String(localized: NewGame.Opponent.friend.name) == "A friend")`).
- **`scripts/test_snapshot_gallery.sh`** `pool_languages` (D): red (exit 2 on `--lang`) before step 4; the existing
  case at :179 keeps asserting `-testRegion US` for the default run.
- **Gallery and captures**: after step 2 the full English gallery (`scripts/snapshot-gallery.sh --no-open`, plus
  `--device duo` and `scripts/snapshot-mac.sh --no-open`: the step touches every screen's text) still ends `CHECK OK
  [en]` with the cards unchanged by eye (title case + `.textCase` renders the same "MOVES"). Step 6 adds the scenario
  "Move list · Mixed-script comments" (group "Moves"): a `Fixture` PGN whose variation carries a Hebrew comment
  (`{הערה}`) and an Arabic one between Latin moves, and a standalone Arabic comment under a row — data in a PGN,
  not a forced language — rendered in English too (an RTL comment inside an LTR line) and listed in the review set.
  After step 4 the review set in `fr,de,it` on the iPhone, iPad, Duo and Mac, read for truncation and overflow
  (German in the New Game ladder and the players' rows, the status line, the Mac menu). After step 7 the same in
  `he,ar`, read against the table of B, plus `magick compare -metric RMSE` of the board region of each he/ar capture
  against the English one (0: the board is pixel-identical, never mirrored) — the production read path for every new
  entity: a catalog unit is read by `Text`/`String(localized:)` in the app the test host runs; the pins and isolates
  are in the views the captures show.
- **The store page**: `app-store-screenshots` on each config refuses a locale without text or a missing capture; the
  review page read per locale (right-aligned he/ar headlines, joined Arabic letters, no "shrunk" line). The byte
  count of every keywords line; `grep -c TODO AppStore/` is 0.
- **UI tests** (final gate, English): unchanged, green: "More", "New Game", "Back", "Engine", "30 s", "Black" keep
  their English text.
- **Owed on devices**: an iPhone set to Hebrew, then Arabic (Saudi): the board and pieces, taps and promotion, the
  name fields with the Hebrew/Arabic keyboard, the Games list grouped by day, the share sheet; an iPhone Duo half
  folded under Hebrew; the Mac under Hebrew (menus, the document window, Settings). After `/release`: the storefront
  pages in each language.

## Invariants

- **I1 — Files keep opening**: **holds**. The JSON shape and the PGN writer are untouched (Facts: no label is stored;
  the player's typed name stays bytes); SAN/FEN/PGN are produced in C++ in English notation; the catalog test's
  isolate rule (4) and the `verbatim` texts keep notation out of the catalog. The default file name stays "Game
  <timestamp>" (D3). Paste reads raw PGN/FEN.
- **I2 — A search result lands on its position**: **not applicable** (no search or callback change).
- **I3 — Engine portable**: **holds** (nothing under `Shared/Engine/` changes).
- **I4 — UCI works**: **holds** (`UCI.swift` keeps its own literals; a `String(localized:)` is never on its path).
- **I5 — Private and offline**: **holds**; no new required-reason API (`PrivacyInfo.xcprivacy` unchanged).
- **Gallery rule** (no forced appearance or language; every screen a scenario): **holds** — the language comes from
  `-testLanguage`; no new screen state (the same scenarios in another language).
- **Project generated**: **holds** (`project.yml` + `xcodegen generate` committed in steps 2, 3 and 7).
- **Public repo**: **holds** (no absolute path, no email; maestro named by `~/GitHub/maestro` as the agreement does).

## Risks and rollout

- **File-format compatibility (I1)**: the one risk is a translated string or a locale-formatted number reaching a
  file; the design keeps every writer on its current path, the catalog test fences the notation, and the byte
  fixtures of the Test plan, run under Saudi Arabic and Hebrew in step 7, prove the JSON and PGN bytes unchanged.
  `GameText.title` is shown, never written; the isolates of B are display-only characters that never enter the PGN
  (the `variationText` test checks the stored tokens are untouched: the isolate is added to the attributed string,
  not to the `MoveToken`).
- **A real device**: right to left on an iPhone and a Mac set to Hebrew/Arabic (the keyboard, the share sheet, Files;
  the custom `Layout`s if the simulator capture disagrees with a device); the Duo fold under Hebrew; `ar-SA` with
  the Numbers setting on Eastern digits (the node count then shows Eastern digits beside Western notation, by design).
- **Translation quality**: Jean reads neither Hebrew nor Arabic; the three checks (Apple's glossary, Wikidata, the
  Codex back-translation) are the review, their findings logged. French, German and Italian Jean can read: the
  implementer shows the catalog's units and the store texts in the hand-back.
- **Text that grows**: German blurbs and level names in the ladder's rows, "Beginner Player" in the title at the
  smallest iPhone width, the Mac menu; the fr/de/it captures of step 4 show it; a too-long string is shortened in the
  catalog, never by a layout change.
- **App Store Connect locale codes**: the app's `ar`/`he` vs the store's `ar-SA`/`he`; `it` (not `it-IT`); the files
  and configs use the store codes, the catalog the app's, as xFractal does. Keywords 100 bytes.
- **`catalog-sync` on a target that compiles C++** (the Engine template): the Swift extraction only; a build is a
  build. If the tool trips on the target names with spaces, `catalog_schemes` maps them; the step says what it hit.
- **The Mac gallery's title wait** under a language (D): fixed by computing the title; if the hosted test bundle's
  locale ever differed from the app's, the wait would time out by name, not hang.
- **Rollout**: nothing ships from this plan. `/release` (1.0) fills the page from `AppStore/` for every locale and
  uploads the screenshot sets per locale; What's New does not exist for 1.0. The next plan adds es-ES, es-MX, pt-BR,
  ja, tr to the store page only.

## Decision left open for Jean

Not asked (the planning subagent had no `AskUserQuestion` tool); the recommendation comes first.

1. **Digits (C).** Recommended: **Western digits for the notation and what sits next to it; the locale's digits for
   the node count, the speed and the dates.** Alternative: Western everywhere (xFractal's choice: then
   `.formatted(.number.locale(Locale(identifier: "en_US_POSIX")))` on the two statistics, and the dates stay), or
   locale digits everywhere (rejected above).
2. **The evaluation bar and the move list under right to left (B).** Recommended: **the bar stays left of the board
   (inside the pin); the move list's rows are pinned left to right and its variation lines are left-to-right
   isolates with each comment in its own direction; the list and the wide layout's column mirror as SwiftUI does.**
   Alternative: pin the whole move list card (its "Moves" caption left-aligned too; comments still need the isolates).
3. **The default file name "Game <timestamp>".** Recommended: **keep it English** (it is the file's name on disk,
   in Files and in exports; translating it would make new files sort apart from old ones and is a format choice,
   not a label). Alternative: a catalog key for the prefix, new files only.
4. **Who translates.** Recommended: **the implementation subagent writes fr, de, it, he, ar** (catalog and store
   texts), checked by the three methods and, for fr/de/it, shown to Jean at hand-back. Alternative: Jean writes or
   reviews fr/de/it himself before step 5; a native reader for he/ar before 1.0 ships.
5. **Mac arrow shortcuts under right to left.** Recommended: **unchanged** (`←` Back, `→` Forward, `⌘←`/`⌘→`):
   the notation stays left to right, so left is earlier. Alternative: swap under `rightToLeft`.
6. **The maestro `repos.yaml` entry (step 1).** Recommended: **add it in maestro** (three keys, as every repo that
   uses `catalog-sync`; its own commit there). Alternative: skip `catalog-sync` and run `xcrun xcstringstool sync`
   by hand (loses the tool's checks: `--check` in the gate, stale handling, the `#Preview` filter).

## Steps

1. **[maestro] repos.yaml: BChess's catalog entry** — `catalog_project`, `catalogs` (`Shared/Localizable.xcstrings@BChess (iOS)+BChess (macOS)`), `catalog_destinations` (the Mac target); committed in `~/GitHub/maestro` (D6).
2. **The catalog and the strings that cannot be localized as written** — `Shared/Localizable.xcstrings` (en), `SWIFT_EMIT_LOC_STRINGS: YES` and `xcodegen generate`; the leaf members as `LocalizedStringResource` (`NewGameSheet.field(_:)` takes one), the composed sentences as `String(localized:)` with `%@` arguments, `GameText.exported` with the plural key and `exportFailed`/`deleteFailed`, the nine verdict keys, "Mate" and `Verdict.accessibilityLabel`, the per-level keys, the best line as one `Best %@` key, the `"You"` fix (test red first), `Text(verbatim:)` for coordinates, move numbers and the variation count, title-case keys with `.textCase(.uppercase)`; `catalog-sync` fills the keys, `--check --skip-build` clean; `LocalizationCatalogTests` (languages `[]`: no stale key, the `%lld` allowlist, no isolate in a key) and `GameStateCodingTests.namedPlayersWriteTheSameBytes` (the I1 byte fixtures); the existing tests adjusted; test gate green, the full English gallery (`CHECK OK [en]`, Duo, Mac) unchanged by eye.
3. **French, German and Italian in the app** — the units written into the catalog (A's conventions), `languages = [fr, de, it]` in the catalog test (red first) and the hosted `LocalizationTests` samples in `BChessMacGalleryTests` (red first), `xcodegen generate` with `knownRegions`, the Mac scenarios' titles computed (`GameText.title`, "Settings"); `AGENTS.md` § Languages and the `/develop` String Catalog bullet; test gate green.
4. **The gallery in another language** — `--lang` and `region()` on both scripts, `preview-gallery.py --import --lang` into `previews/<platform>/<lang>/`, the `pool_languages` lifecycle case (red first), the review set written into the `/preview-gallery` skill; the review set in fr, de, it on the iPhone, iPad, Duo and Mac, read for overflow (strings shortened in the catalog if needed); the full English gallery still `CHECK OK [en]`, `scripts/test_snapshot_gallery.sh` green.
5. **The App Store page in the base four** — `AppStore/app-info.txt`, `keywords.txt` (byte-checked), the eight descriptions (en-US, fr-FR, de-DE, it × iOS/Mac), the five slide configs' `locales` and headlines; rendered and reviewed per locale on every config, nothing uploaded; the `/release` skill (§4 page files, §6 `metadata` block, notes per locale from the second release) and `/app-store-screenshots` (locales, `--lang` capture commands) updated. The branch ships the base four from here.
6. **Right to left: the board, the notation and the digits** — `GameText.notation` with its tests (red first) in `status`, `EngineView.bestLine`, `Verdict.score`, the statistics' depth and the strip's variation count; `MoveRowView.variationText` (`Shared/Views/MoveListView.swift`) with the line and comment isolates (hosted test red first), the scenario "Move list · Mixed-script comments" added to the review set in the skill; the layout-direction pin on the board view (bar included), the move strip and the move list rows; `chevron.left`/`chevron.right`; test gate green, the English gallery with the new card (`CHECK OK [en]`) and otherwise unchanged by eye (the pins and isolates are inert left to right).
7. **Hebrew and Arabic in the app** — the units with the three checks (findings in the implementation log), `languages += he, ar` (catalog test red first), the `ar-SA` digits and plural samples, `xcodegen generate`, `he|ar` in the scripts' whitelists; `LocaleIndependenceTests` and `MacMenuTests` run under `-testLanguage ar -testRegion SA` and `he`/`IL` with `BCHESS_EXPECT_LANGUAGE`/`_REGION` set (the I1 bytes, the notation's digits and the menus with the process locale set; the executed-test count read); the review set in he and ar on the iPhone, iPad, Duo and Mac read against the table of B and the board region compared with the English capture (RMSE 0); what the captures show that the plan did not foresee is fixed in this step and logged; test gate green.
8. **The App Store page in Hebrew and Arabic** — `he` and `ar-SA` in `app-info.txt`, `keywords.txt` (byte-checked), four descriptions, the five configs' `locales` (after `it`: `ar-SA`, `he`) and headlines; rendered and reviewed (right-aligned, joined letters, nothing shrunk), nothing uploaded; the skills' locale lists and the storefront-order check; `AGENTS.md` § Languages names the six languages and the right-to-left rule (the board, the notation and the digits never mirror; `--lang he,ar` on the gallery scripts is the check).

## Implementation log

(Filled in by the implementation: the translation checks' findings and decisions per language, what the fr/de/it
and he/ar captures showed, which of the conditional fixes of B were needed, and what `catalog-sync` reported on the
first run.)

### Steps 1-4 (fr, de, it)

- **Step 1**: maestro commit `9117c0c` (`repos.yaml`: `catalog_project`, `catalogs`, `catalog_destinations`).
- **`catalog-sync` first run** (step 2): both targets built, 97 files per configuration, 0 preview strings, 145 keys; the
  plural key is written by hand (`variations.plural`, en one/other) and `--check --skip-build` then says "catalog unchanged".
  Multi-argument keys get positional specifiers (`%1$@`) in their en unit; translations use them.
- **Deviations**: `NewGame.Opponent.elo` is `LocalizedStringResource?` (nil for a friend; an empty literal would be a
  catalog key); `EngineView.statistics(depth:quiescenceDepth:nodes:speed:)` is a pure overload (a hosted test cannot build a
  `FEngineInfo`); `GameLibrary.timestamp` is internal (for the hosted digits test); `MacMenuTests` and
  `LocaleIndependenceTests` were created in step 3 (run under fr, de, it) instead of step 7; the lifecycle case
  `pool_languages` uses `--lang fr,de` in step 4 (he joins in step 7); the review-set slug is `new-game-a-friend`; the gallery
  scenarios `engine-statistics`, `engine-wide` and `engine-evaluation-bars` now build their statistics line with
  `EngineView.statistics` (they hard-coded English text that no language run could translate; the two wide cards read
  "Depth 9/14 with 1,234,567 nodes at 410,000 n/s" now). The committed `project.pbxproj` carries a `TEMP_…` group named
  after the worktree folder (an XcodeGen quirk, as before).
- **Step 4 captures (fr, de, it; iPhone review set, iPad, Duo inner, Mac)**: German and French fit everywhere except the
  game title: "Tu contro Giocatore da circolo" was cut on the iPhone, and "Vous contre Joueur débutant" sits at the limit.
  Shortened in the catalog: fr Beginner Player "Débutant", Casual "Amateur" / "Joueur amateur" (was "Occasionnel"); it
  computer names are the level names (Principiante, Occasionale, Circolo, Forte; "Motore completo"). The engine statistics
  card showed English in every language until the scenarios were fixed (above). Node counts and speeds follow the locale
  (fr "1 234 567", de "1.234.567").
- **Step 5 (store page, base four)**: the English texts are the live page's (`app-store check`), copied verbatim into
  `description-ios-en-US.txt`; the Mac variant swaps the Engine-button and move-list bullets for the toolbar / Game menu /
  arrow keys wording and adds the document-window bullet (the app writes the format a file was opened as, so "saved as a
  BChess or PGN file" is true). Subtitles 25 / 29 / 25 / 25 characters, keywords 74 / 87 / 78 / 84 bytes, descriptions
  846-1117 characters. Headlines: the first French, German and Italian drafts shrank to 92-104 px (English shrinks to
  112 px on its own); trimmed ("Cinq niveaux, Débutant à Maximum", "Fünf Stärken, Anfänger bis Maximum", "Vos parties,
  enregistrées en jouant", "Ihre Partien, automatisch gesichert") so every locale shrinks about as much as English. All five
  configs render for the four locales with no missing capture; the iPad English captures needed a full English iPad pass
  first (this worktree had none). Nothing uploaded.

### Step 6 (right to left: the board, the notation, the digits)

- Red first: `notationIsALeftToRightIsolate`, the isolated `Verdict.score`/status expectations and the hosted
  `MoveListTextTests` failed to compile before the change (`GameText.notation` and `MoveRowView.variationText` did not
  exist); the pins are views and are read from the he/ar captures of step 7. `VerdictTests`/`GameTextTests` expectations
  now carry the isolates (the isolate is invisible in English, the card is unchanged by eye).
- The English gallery gained the card "Move list · Mixed-script comments" (50 cards, `CHECK OK [en]`); the Hebrew comment
  inside the variation and the Arabic one under the row render in their own direction already in English.
- `MoveRowView` lost `private` (the hosted test reaches `variationText`); `Verdict.accessibilityLabel` now reads the
  isolated score.

### Step 7 (Hebrew and Arabic in the app)

- **Translation checks.** Apple's glossary files and Wikidata were not consulted programmatically; the vocabulary is the
  conventional chess terms (he: מלכה, צריח, רץ, פרש, מט, פט; ar: وزير, قلعة, فيل, حصان, كش مات, جمود) and Apple's UI verbs
  (he: imperative forms as in Apple's Hebrew UI; ar: Modern Standard Arabic). A blind back-translation by Codex
  (`codex exec --sandbox read-only`, the 144 strings and the two plurals without their English) read every string; findings
  and decisions: (1) Hebrew imperatives ("העתק", "הצג", "שחק מול") are masculine singular: kept, they are Apple's Hebrew UI
  convention, and nouns/"your ..." forms are used wherever the sentence allows ("תורך", "השם שלך", "הצד שלך", "אני" for the
  person at the device); (2) he "Promote to" was an awkward fragment ("הכתרה ל"): now "הכתרה לכלי"; (3) he plural one read
  "game number N": now "משחק אחד יוצא אל …"; (4) ar "winning" read as "a clear advantage": now "الأسود رابح" /
  "الأبيض رابح"; (5) ar "Stalemate." was bare "جمود": now "تعادل بالجمود."; (6) ar "Pass and play" used a dual
  imperative: now the verbal noun "اللعب بالتناوب على …"; (7) ar "Follow the system, or always light or dark" was
  disjointed: now "يتبع النظام، أو فاتح دائمًا أو داكن دائمًا"; (8) ar "Play the Club Player" suggested one club: "العب ضد لاعب
  بمستوى النادي"; (9) ar "You play" needed a complement and the next control is the colour: now "لونك" (he "הצד שלך");
  (10) he "Tints the two squares ..." had a wrong gender/verb: "צובע את שתי המשבצות של המהלך שבוצע זה עתה". Findings left as
  is: the navigation words "Back"/"Forward" (he אחורה/קדימה, ar السابق/التالي) are labels, not the English words;
  masculine "חושב" for a named computer.
- **Foundation isolates the `%@` arguments of a right-to-left language** (U+2068 ... U+2069 around each): the hosted
  tests expect them (`LocalizationTests.argument`); nothing in the catalog carries them (`LocalizationCatalogTests`).
- **Captures (he, ar; iPhone review set, iPad, Duo inner, Mac)**: the game screen's board, pieces, coordinates and
  evaluation bar are pixel-identical to English (RMSE 0 on the board region of `game-screen-engine-on`,
  `game-screen-rotated`, light and dark, he and ar); the move strip and the move-list rows read left to right with "Moves"
  on the left; variation lines and the Hebrew/Arabic comments read correctly; "−0.2", "9/12", "2…Qh4#" and the Elo keep
  their order and Western digits; the chrome (toolbar, sheets, lists, Settings, the New Game ladder and segmented
  controls, the Mac toolbar and sheet) mirrors. Wide layouts (iPad, Duo inner, Mac) put the move list left of the board and
  keep the board unmirrored, as the plan expected. What the captures showed that the plan did not foresee: the gallery's
  `Variations · Arrows and cards` and `Promotion` scenarios compose `BoardView`, `PiecesView`, `VariationSelectionView` and
  `PromotionView` without `ContentView`, so the board pin there never applied and their boards (and the promotion column)
  came out mirrored. Fix: the pin is now also at the root of each board component (`View.neverMirrored()` in
  `BoardView.swift`: the squares, the pieces, the coordinates, the arrows and the promotion column); after it the
  promotion captures are identical to English (RMSE 0) and the arrows sit on the same files. The node count and the speed
  follow the locale, so under `ar-SA` they show Eastern Arabic-Indic digits beside Western notation (D1, by design), and
  the Games list dates follow the Saudi locale (Umm al-Qura calendar, Eastern digits). Back/Forward in a right-to-left
  toolbar: the buttons mirror (Back on the right) while the chevrons keep pointing left = earlier (the plan's rule), which
  reads slightly odd next to the system's own back button; kept as decided.

### Step 8 (store page, Hebrew and Arabic)

- `app-info.txt` (subtitles 18 / 17 characters), `keywords.txt` (ar-SA 99 bytes, he 93: the first drafts were 130 and 110
  and were cut to the stronger words), four descriptions (he 696 / 752, ar 774 / 845 characters; the Mac variants say document
  window and the "Game" menu, as the other locales do), the five slides configs with `ar-SA`, then `he` after `it`, headlines
  rendered right to left with joined Arabic letters and no clipped line; the only shrink lines are the long Arabic
  "strengths" headline (120 / 128 px, English 112 / 120) and two Hebrew ones (108-120 px), the same size as the English
  and Romance ones. The slides' captures were re-rendered in he and ar after the board-pin fix. Nothing uploaded.
- The storefront question (do the App Store pages show a right-to-left locale's screenshots right to left) is unverified
  until the first upload; BChess has no two-panel pair, so no caption swap applies (`/app-store-screenshots` says so).
- `AGENTS.md` § Languages names the six languages and the right-to-left rule; the skills carry the six locales and the
  he/ar commands.

### Fix round 1 (Codex review, passes A, B, C; all findings accepted)

- Tests: `LocalizationCatalogTests` now requires each language's full plural category set (ar six, he four, others two; red:
  an ar catalog without "few" fails) and no "ß" in German (red: 8 units). `LocaleIndependenceTests` (run under the real
  process locale) asserts through production code: the statistics sentence equals the catalog unit with isolated depth and
  locale-formatted counts, the thinking time and Elo are the catalog unit with Western digits (replaces the
  `resource.locale` test, which could not see a formatting leak), the mate score and accessibility label for both colours,
  the `ExportError` text, and the saved PGN bytes, the session FEN and the capture lists of a game with a Hebrew-named
  player as literals; the duplicate score assertion and the second Eastern-digit predicate are gone. Red proof: the four
  production lines (`statistics`, `seconds` with `.formatted()`, the mate score, the export error) made English or locale
  formatted failed those tests under ar-SA. `GameShellTests` also reads the English `errorDescription`.
- Translations: he "ללא הגבלות" for the full engine; he "ממעט לטעות; כדי לנצח צריך תוכנית אמיתית" and ar "…تحتاج إلى خطة حقيقية
  لتهزمه" (the human needs the plan); German is Swiss-spelled everywhere (Weiss, Schliessen, ausserhalb, einschliesslich:
  catalog and both German descriptions). This reverses the plan's "German keeps ß".
- Scripts: `scripts/languages.sh` (region and whitelist) is sourced by both gallery scripts; `lang_import` now uses distinct
  PNG bytes per language and compares the English bytes before and after (red: importing into the platform folder fails
  five checks). The release skill's first-release paragraph now includes the `metadata` upload.
- Code: `Opponent.name` is `strength?.displayName ?? "A friend"` (catalog-sync still reports "catalog unchanged").
