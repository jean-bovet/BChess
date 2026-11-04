# LEGAL-1 — Licensed chess pieces, an About screen with credits, and a licensing audit

**Status:** plan r3, not started; D1 decided (new icon, step 5). **Branch:** `legal-1-piece-artwork`.

**Changelog.** r3: D1 decided by Jean on 2026-11-04 (a new icon, a carved Commons knight on two CC0 veneers); new step 5, the app icon, and the README images become step 6. r2: Jean's D2–D6 and the first Codex review folded in (a factual record of pre-fix sources and builds, a hosted test of the About path, piece-square tables kept).

## Problem

App Review held BChess 1.0 for information (Guideline 2.1); item 6 asks about protected third-party material. The piece
artwork is of unknown origin, so its rights cannot be documented. Jean's decision: replace it with the Wikimedia Commons
set, put every due citation in an About screen (iOS and macOS) and on the App Store listing, and audit the whole tree.

The audit (below) found more than the pieces: one piece of **GPLv3 code copied into the engine** and an **app icon with no
recorded origin**. Nothing here is legal advice; it is a reading of the licences and the history.

## Current state (evidence)

- **Pieces.** 12 imagesets in `Shared/Assets.xcassets/pieces/`, one PDF each (`<piece>_<w|b>.pdf`, 1024 x 1024, Illustrator
  output, no author or licence). No `-1`/`-2` extras remain. Names used by `Shared/PiecesFactory.swift`,
  `Shared/Model/NewGame.swift`, `Shared/Views/PromotionView.swift`, `Shared/Views/NewGameSheet.swift`, `iOS/GameRootView.swift:343`.
  `Contents.json` has no `preserves-vector-representation`, so `actool` rasterises each PDF from its native size.
- **About.** The Mac has only the default About panel (no `Credits` file, `macOS/Info.plist` copyright line). iOS has none;
  `Shared/SettingsView.swift` is a sheet inside a `NavigationStack` (`iOS/GameRootView.swift:193`). The README has an
  "Attributions" section with links only.
- **Network.** `macOS/macOS.entitlements` has the sandbox and no network client. I5 holds today.
- **Listing.** `AppStore/description-{ios,mac}-<locale>.txt`, six locales, each ending in an "Open source" line; the longest
  is 1648 bytes, the limit 4000 characters. Pushing them belongs to `/release` (`app-store metadata`), not to this plan.

## The Commons source

All 12 pages (`File:Chess_klt45.svg`, `qlt`, `rlt`, `blt`, `nlt`, `plt`, `kdt`, `qdt`, `rdt`, `bdt`, `ndt`, `pdt`): own work of
Cburnett, 2006-12-27. Licence tags: `{{self|GFDL|migration=relicense|BSD|GPL}}`, and "You may select the license of your
choice". **The licence chain is clean:** page histories show Cburnett himself adding BSD on all 12 on 2007-01-12 ("Dual
license with BSD") and GPL on 2007-12-12, not a third party. BChess chooses BSD. Lichess lists the same art as GPLv2+ only, so
the files come from Commons, not from Lichess. Commons shows the username; the full name Colin M.L. Burnett comes from Lichess's
`COPYING.md`, so notices give both.

**Later uploads by others.** The current revision of every file is not Cburnett's: Antonsusi (2010, 2012, "valid code",
"adjustings"), TomFryers (2020-21, symmetry fixes), Apathor (2021, baseline alignment), Cyco130 (2021, colour typo),
Smasongarrison (2022, svgomg), Edemaine (2022, typo). Their edits were uploaded over the file under its licences and are
technical. The plan uses the current revisions and names these contributors (see D3).

Files, pinned by SHA-1 (current revision, all verified against the Commons API and the scratch download on 2026-11-04):

| Commons file | Asset | SHA-1 |
|---|---|---|
| Chess_klt45.svg | king_w | 2c7569b837971207e40f7148e2b2086aaf8e4bbd |
| Chess_qlt45.svg | queen_w | e638eb28ec25007b9f8fac8476bdf6ae1fc5a0ee |
| Chess_rlt45.svg | rook_w | 126b7779885b87e87acc713474587732711bc8d3 |
| Chess_blt45.svg | bishop_w | 35dd477dc22636bfcc559a01f75b00369205ffda |
| Chess_nlt45.svg | knight_w | 3a2253429c0e39863b3f5ecf447209dccecdc337 |
| Chess_plt45.svg | pawn_w | 09d59e2770fcee23722ac53b26e875f76d2c1eb1 |
| Chess_kdt45.svg | king_b | b1165ef85a3df6f1af2549ab0af78ab21b540e8a |
| Chess_qdt45.svg | queen_b | ed72e75b7bdbf880a3c9bee053c8786cfab8bdb9 |
| Chess_rdt45.svg | rook_b | bd0e866f1e6da8e3d6f9c0b356b60fc58391aff6 |
| Chess_bdt45.svg | bishop_b | da6dd1b5ef629bacebbd2ce26c7d81ba8a205587 |
| Chess_ndt45.svg | knight_b | 3c79cbbda76bcf1d4e4062cef6dd3b58a250a562 |
| Chess_pdt45.svg | pawn_b | 0a6d2f3dc6327a02ca591bc489d701fbff228138 |

Download URL pattern: `https://commons.wikimedia.org/wiki/Special:FilePath/Chess_klt45.svg`, with a descriptive User-Agent;
reject any file whose SHA-1 differs.

### The BSD text, exactly as Commons renders it on the file pages

(From `Template:BSD/i18n/en` and the rendered `File:Chess_klt45.svg`; the template renders the disclaimer in upper case by CSS
only. Version 3, "3-clause BSD License". The placeholder stays "The author", as on the page.)

> Copyright © The author
>
> Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following
> conditions are met:
>
> 1. Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
> 2. Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following
>    disclaimer in the documentation and/or other materials provided with the distribution.
> 3. Neither the name of The author nor the names of its contributors may be used to endorse or promote products derived from
>    this software without specific prior written permission.
>
> This software is provided by The author and contributors "as is" and any express or implied warranties, including, but not
> limited to, the implied warranties of merchantability and fitness for a particular purpose are disclaimed. In no event shall
> The author and contributors be liable for any direct, indirect, incidental, special, exemplary, or consequential damages
> (including, but not limited to, procurement of substitute goods or services; loss of use, data, or profits; or business
> interruption) however caused and on any theory of liability, whether in contract, strict liability, or tort (including
> negligence or otherwise) arising in any way out of the use of this software, even if advised of the possibility of such damage.

**What the notice must contain.** Condition 2 makes the copyright notice, the three conditions and the disclaimer ship with the
binary, so the About screen shows the **full text**, offline; a link alone does not satisfy it. Condition 1 applies to the SVGs
committed to the repo, so they sit next to the same text. Condition 3 means credit, never promotion: the listing states the
attribution in a neutral credits line. Converting to PDF is a modification, which the licence permits; the notice says it was done.

## Rendering (proved in scratch)

| Route | Result |
|---|---|
| **`NSImage` draws the SVG into a `CGContext` PDF page, 1024 x 1024** | **Chosen.** Tried on 9 of the 12 files: 6 KB, no image XObject (vector), strokes and the white inner lines of the black pieces intact. Same canvas as the old PDFs, so `Contents.json`, `actool` and every view stay as they are |
| SVG directly in the asset catalog | Rejected. Needs `preserves-vector-representation`, or `actool` rasterises from the 45 pt native size and the pieces blur at a board's 100+ pt squares. It changes a pipeline nothing asks to change |
| PDF at 45 x 45 | Rejected, same blur |
| ImageMagick | Rejected, drops strokes; has no `gs` for PDF here |

Size on the board, as a fraction of the canvas, measured from the rendered PDFs (white set; old → new width, old → new height):
king .79 → .77, .82 → .78; queen .88 → .85, .82 → .77; rook .64 → .64, .75 → .70; bishop .82 → .77, .81 → .77; knight .81 → .75,
.82 → .74; pawn .57 → .55, .74 → .71. The Commons art has the same baseline as the old set (bottom at about .89) and is 3 to 8 %
smaller. **Render 1:1, with no scaling.** It keeps the art as drawn and the same air in the square; if Jean finds it small
in the gallery, one uniform scale constant in the script, anchored at the baseline, is a one-line change.

## Design

- **Sources:** `Art/pieces/` (outside `Shared/`, so XcodeGen does not bundle them) holds the 12 SVGs under their Commons names
  and a `LICENSE.txt` with the piece section of the notice. `scripts/render-pieces.swift` writes the 12 PDFs, overwriting the
  imagesets' PDFs (same file names); a re-run gives the same art.
- **One text, shipped:** `Shared/ThirdPartyNotices.txt`, read by the app. Only what ships. `Shared/` is already a source path of
  both apps and XcodeGen makes a `.txt` a resource. Loaded by `ThirdPartyNotices.text` in `Shared/Model/ThirdPartyNotices.swift`
  with `Bundle(for: GameSession.self)`, the idiom of `Openings.pgn`; `project.yml` adds the file to `BChessTests`.
- **`Shared/Views/AboutView.swift`, one view for both apps** (a SwiftUI view gets a gallery scenario, the system About panel cannot):
  the app icon is not repeated; title, `Version %@` (`CFBundleShortVersionString (CFBundleVersion)`), `Copyright © 2021–2026 Jean
  Bovet` and the repository URL as `Text(verbatim:)`, the MIT sentence, a heading, a sentence saying the licenses are in
  English, then the notices as `Text(verbatim:)` in a `ScrollView`. Legal text is not translated: a translation has no standing.
  The notice block is pinned left to right, leading-aligned, in every language; the chrome mirrors. `.textSelection(.enabled)`.
  No `Link` (D4), so I5 stays literally true. No required-reason API.
- **iOS:** `SettingsView` gets, under `#if os(iOS)`, a `WalnutSection` with a row "About BChess" / "Version, credits and
  licenses", a `NavigationLink` to `AboutView` (the sheet already has a `NavigationStack`).
- **macOS:** the standard place. `CommandGroup(replacing: .appInfo)` in `GameCommands` with `Button("About BChess")` and
  `@Environment(\.openWindow)`; a `Window("About BChess", id: "about")` scene in `BChessUIApp`, after `DocumentGroup` so a new
  game still opens at launch (APP-9), with `.commandsRemoved()` (no second entry in the Window menu), `.windowResizability(.contentSize)`
  and `.restorationBehavior(.disabled)`. Fixed 460 x 560, the width of Settings.
- **Engine:** `ChessBoardHash.cpp`'s `PRNG` class is replaced by own code; see step 1.

### `Shared/ThirdPartyNotices.txt` (content)

```
BChess includes the following third-party material.

CHESS PIECES
Artwork by Colin M.L. Burnett (Wikimedia Commons user Cburnett), 2006, with later technical corrections
by the Wikimedia Commons contributors Antonsusi, TomFryers, Apathor, Cyco130, Smasongarrison and Edemaine.
Source: Wikimedia Commons, https://commons.wikimedia.org/wiki/File:Chess_klt45.svg and its eleven companions.
Converted from SVG to PDF for BChess. Offered by the author under several licenses; BChess uses the BSD license:

<the BSD text above, verbatim, the disclaimer in upper case as rendered>

MOVE GENERATION
magicmoves, Copyright (C) 2007 Pradyumna Kannan.

<the notice of magicmoves.h verbatim, from "This code is provided 'as-is'" to the end of condition 3>

ALSO USED, WITH THANKS
xorshift64* random number generator: Sebastiano Vigna, 2014, dedicated to the public domain.
Piece-square tables: Simplified Evaluation Function by Tomasz Michniewski.
```

### Strings (all new; `Shared/Localizable.xcstrings`)

| en | fr | de | it | he | ar |
|---|---|---|---|---|---|
| About BChess | À propos de BChess | Über BChess | Informazioni su BChess | אודות BChess | حول BChess |
| Version, credits and licenses | Version, remerciements et licences | Version, Danksagung und Lizenzen | Versione, riconoscimenti e licenze | גרסה, קרדיטים ורישיונות | الإصدار والشكر والتراخيص |
| Version %@ | Version %@ | Version %@ | Versione %@ | גרסה %@ | الإصدار %@ |
| Free and open source under the MIT License. | Libre et open source, sous licence MIT. | Freie Open-Source-Software unter der MIT-Lizenz. | Libero e open source, con licenza MIT. | חופשי וקוד פתוח, ברישיון MIT. | مجاني ومفتوح المصدر بموجب رخصة MIT. |
| Acknowledgments and licenses | Remerciements et licences | Danksagung und Lizenzen | Riconoscimenti e licenze | קרדיטים ורישיונות | الشكر والتراخيص |
| The licenses below are in English. | Les licences ci-dessous sont en anglais. | Die folgenden Lizenzen sind auf Englisch. | Le licenze qui sotto sono in inglese. | הרישיונות שלהלן באנגלית. | التراخيص أدناه باللغة الإنجليزية. |

The version argument goes through `GameText.notation` (Western digits, a left-to-right isolate).

### Listing: a line appended after the "Open source" line, all 12 files (iOS and Mac alike)

- en-US: `Credits: chess pieces by Colin M.L. Burnett (Wikimedia Commons), BSD license. Move generation uses magicmoves by Pradyumna Kannan. The full notices are in the app, under About BChess.`
- fr-FR: `Crédits : pièces d’échecs de Colin M.L. Burnett (Wikimedia Commons), licence BSD. La génération des coups utilise magicmoves de Pradyumna Kannan. Les mentions complètes sont dans l’app, sous À propos de BChess.`
- de-DE: `Danksagung: Schachfiguren von Colin M.L. Burnett (Wikimedia Commons), BSD-Lizenz. Die Zuggenerierung verwendet magicmoves von Pradyumna Kannan. Die vollständigen Hinweise stehen in der App unter „Über BChess“.`
- it: `Riconoscimenti: pezzi degli scacchi di Colin M.L. Burnett (Wikimedia Commons), licenza BSD. La generazione delle mosse usa magicmoves di Pradyumna Kannan. Le note complete sono nell’app, in Informazioni su BChess.`
- he: `קרדיטים: כלי השחמט מאת Colin M.L. Burnett (ויקישיתוף), רישיון BSD. יצירת המהלכים משתמשת ב-magicmoves מאת Pradyumna Kannan. ההודעות המלאות נמצאות באפליקציה, בעמוד אודות BChess.`
- ar-SA: `الشكر والتقدير: قطع الشطرنج من تصميم Colin M.L. Burnett (ويكيميديا كومنز)، برخصة BSD. يستخدم توليد النقلات magicmoves من Pradyumna Kannan. الإشعارات الكاملة موجودة في التطبيق، ضمن حول BChess.`

## Licensing audit

All 490 tracked files searched (copyright, licence, URL, credit and copied-code terms, file types); assets and every flagged file read. Ours = written for BChess. OK = third party, terms met once this plan lands. **Risk** = needs a fix or an answer.
What ships: the two apps. `BChessUCI` is built but not distributed; test targets, `Dependencies/`, `scripts/`, `planning/` never ship.

| Item | Origin and licence | Ships | Class | Action |
|---|---|---|---|---|
| `pieces/*.pdf` | Unknown origin, no licence | Yes | **Risk** | Replaced, step 2 |
| Old pieces in `markdown/ios.png`, `markdown/macos.png` | Screenshots of the app with the old art (README images) | No (public) | **Risk** (OK after step 6) | Retaken, step 6 |
| `ChessBoardHash.cpp` `PRNG` | **Copied from Stockfish, GPLv3**: the file says "Taken from the stockfish source code"; the comment block and class match `src/misc.h` line for line, and the seed `1070372` is the one in `position.cpp`. The underlying generator is Vigna's public-domain xorshift64*, but this expression of it is GPL | Yes | **Risk** | Rewritten, step 1, which covers future binaries only; the record below goes in `docs/licensing.md` |
| `AppIcon.appiconset` (all PNGs; light, dark, tinted, Mac) | Staunton knight in wood on a wooden board, added 2026-10-07 ("polished walnut knight"), dark and tinted derived from it. **Not derived from either piece set** (silhouette, base, photographic shading compared side by side). Origin of the source image is not recorded anywhere in the repo. **Replaced in step 5:** the Commons knight (Cburnett, BSD) carved by `scripts/render-icon.swift` over Poly Haven CC0 veneers, sources in `Art/icon/`; class OK | Yes | **Risk** (OK after step 5) | Replaced, step 5 (D1) |
| Old piece PDFs in git history | As above, public history | No | **Risk (low)** | Left in place (D5) |
| `Shared/Engine/Helpers/magicmoves.{c,h}` | Pradyumna Kannan, 2007, zlib-style. Notice kept; acknowledgment "appreciated". Git history since the 2017 import shows one whitespace-only change to the `.c` and none to the `.h`, so nothing to mark as altered (condition 2); whether the import's config block was edited before it cannot be told, and that block is meant to be edited | Yes | OK | Credited in About and listing, and in the README |
| `ChessEvaluater.cpp` piece-square tables, values | Michniewski's Simplified Evaluation Function, via the chessprogramming wiki (comment says so). Numeric parameters, the thinnest kind of protectable content; the wiki's licence could not be confirmed | Yes | OK (low) | Kept, Jean's decision; credited in the notices and About; the unconfirmed licence is a known residual in `docs/licensing.md`. Replacing them was raised in review and rejected: they are numeric search parameters, and replacing them means retuning the engine and remeasuring its strength with no documented claim behind it. Not to be raised again |
| Bishop-pair, SEE, futility, null move, fifty-move heuristics | Ideas from the literature; comments cite sources. Identifier search for Stockfish's names found nothing else; a full similarity scan against other engines was not done | Yes | OK | None |
| Remaining `Shared/Engine`, `Shared/Bridge`, Swift | Ours (headers, 480 commits, one author) | Yes | Ours | None |
| `BChess/Openings.pgn` | 17 lines, added 2018 and 2021, opening names and moves (facts); scores ours | Yes | Ours | None |
| Fonts | None bundled. `.system(design: .serif)` is the system's New York; no `UIAppFonts` | System | OK | None |
| Sounds | None in the tree or in code | — | Ours | None |
| Colours, `*.colorset` | Numbers, ours | Yes | Ours | None |
| `Dependencies/gtest`, `BChessTests/Helper/gtest-all.cc` | Google Test, BSD-3, `LICENSE` and headers kept. Compiled into `BChessTests` only. `build-aux/`, `m4/` and `configure` carry GPL autotools files, source only and never compiled | No | OK | Listed in the audit |
| `BChessTests` fixtures | FEN and PGN positions, perft numbers (published facts). No real players' game files | No | Ours | None |
| `scripts/elo-match.sh` | Downloads fastchess, Stockfish and a book into git-ignored `.elo/`; nothing redistributed. Stockfish is a measuring tool; the name is not in the UI, strings or listing | No | OK | None |
| `planning/assets/*.dc.html`, `APP-2-review.html` | Our mock-ups. No embedded art (image slots are placeholders); fonts are system stacks, one link to Google Fonts in a review page | No | Ours | None |
| `planning/assets/ENGINE-*` | Our scripts and patches | No | Ours | None |
| `.claude/skills/*` | Our tooling, no third-party notice found | No | Ours | None |
| App Store screenshots and previews | Not tracked (`AppStore/*.json` hold layouts only). Phones drawn in CSS, no Apple bezel files; headlines in the system font. **Show the old art until redone** | Listing | OK | Owed follow-up |
| Listing and UI text | No third-party marks (Stockfish, Apple, FIDE, other sites) | Yes | Ours | None |
| `LICENSE` (MIT) | "2021-2026 jean-bovet", while headers go back to 2017 | Repo | OK | Step 4 (D6) |
| File headers "All rights reserved", `NSHumanReadableCopyright` | Xcode boilerplate beside the MIT `LICENSE`; the licence still grants the rights | Yes | OK | None |

**Record of pre-fix sources and builds** (facts only, no legal conclusion; goes into `docs/licensing.md` as written, state on 2026-11-04). The `PRNG` class was in the engine source from 2018-02-04 until step 1, so earlier revisions in the repository's history contain it, and so do the TestFlight builds made before the fix. No pre-fix build went public on the App Store: the iOS and Mac 1.0 submissions were rejected or withdrawn (iOS `REJECTED`, Mac `DEVELOPER_REJECTED`).

## Steps

Each step is one Sonnet implementer and the step gates of `/develop`.

**Step 1. The engine's random numbers (`Shared/Engine/Helpers/ChessBoardHash.cpp`).** First add `BoardHashTests.StartPositionHashIsPinned`: the
start position's hash as a literal, captured on `main` (green before and after: this step preserves behaviour, so the pin stands in
for a red test). Save `scripts/bench.sh` on `main`. Then remove the comment block and the `PRNG` class, including the unused
`sparse_rand`, and write a small own function, written from Vigna's description and not from the old text: a `uint64_t` state,
`state ^= state >> 12; state ^= state << 25; state ^= state >> 27; return state * 2685821657736338717ULL;`, with a one-line comment
citing "xorshift64*, Sebastiano Vigna, 2014, public domain" and the paper. Same generator, same seed (D2), so the same keys, and
every search count stays. `ChessBoardHash::initialize` keeps its loop order. Done when `scripts/bench.sh --compare` shows an
unchanged signature and "stockfish" is gone from the file. I3 holds.

**Step 2. The pieces.** Fetch the 12 SVGs into `Art/pieces/` and check the SHA-1 table. Add `Art/pieces/LICENSE.txt`. Add
`scripts/render-pieces.swift` (the scratch tool: `NSImage(contentsOf:)`, `CGContext(url, mediaBox:)` at 1024 x 1024,
`NSGraphicsContext(cgContext:flipped: false)`, `image.draw(in:)`). Render; replace the 12 PDFs. `Contents.json` untouched.
Check: `git grep -l Illustrator -- Shared` is empty; `--only` gallery of the game screen, promotion, New Game and Games list,
light and dark; a contact sheet for Jean.

**Step 3. About (red tests first).** `ThirdPartyNotices.txt`, `ThirdPartyNotices.swift`, `AboutView`, the Settings row, the Mac menu item and
window, `project.yml` then `xcodegen generate`, the six strings through the catalog routine of `/develop`, and scenarios: `About`
in `GalleryScenarios.swift` (group Settings, inside a `NavigationStack`), `About window` in `MacGalleryScenarios.swift`. The Settings
scenario renders the new row by itself. Layout does not change at regular width, so no inner-display scenario. Run the
`he,ar` check of `AGENTS.md` on these slugs, iOS and Mac.

**Step 4. Words outside the app.** The 12 description files; README: "Attributions" states the shipped credits accurately and points to the notices; `docs/licensing.md`, the audit table of this plan,
kept current, with the SHA-1 table, the BSD text, the record of pre-fix sources and builds, and the piece-square tables' unconfirmed licence as a known residual; `LICENSE` line 3 becomes `Copyright (c) 2017-2026 Jean Bovet`; in `AGENTS.md` under Conventions: "Third-party material: a new asset, font, sound or
copied code gets a line in `docs/licensing.md`, and in `Shared/ThirdPartyNotices.txt` when it ships. No code copied from GPL
engines." Check: each description at most 4000 characters, no `TODO`.

**Step 5. The app icon (D1).** Jean approved on 2026-11-04 a new icon in place of the one with no recorded origin: the Commons knight
(`Art/pieces/Chess_ndt45.svg`, Cburnett, BSD) carved in walnut over a 2 x 2 board of two Poly Haven CC0 veneers (`okoume_veneer` for
the light squares, `teak_veneer` for the dark ones, Diffuse 2k jpg, each scaled to a target mean colour). Made reproducible from the
repo: `Art/icon/` holds the two textures and `SOURCES.txt` (URLs, SHA-1 of both, the CC0 terms at `polyhaven.com/license`, checked
against the Poly Haven API); `scripts/render-icon.swift` (a Swift script that needs ImageMagick) derives the masks from the SVG, builds
the board, lights the knight and writes every PNG of `AppIcon.appiconset`, file names unchanged. The light iOS icon matches the
approved image (RMSE 0.0004). `AppIcon-iOS-1024.png` is opaque with square corners; the Mac sizes 16 to 1024 are the same art cut to the
macOS rounded square (824 px, 100 px inset, radius 185.4 px) with a soft shadow measured on the earlier Mac icon; `AppIcon-Dark.png` is
the same carving with a night board and a lifted knight; `AppIcon-Tinted.png` is the same render turned to gray on a near-black board.
Credit: an "APP ICON" entry in `Shared/ThirdPartyNotices.txt` (the knight is derived from the same Cburnett art under the same licence;
the veneers are Poly Haven, CC0) with a case in `ThirdPartyNoticesTests`; the icon rows of `docs/licensing.md` and of the audit above.
No new user-facing string, no listing change. Check: the asset catalog compiles with no missing-icon warning for iOS or macOS; a contact
sheet of the four appearances and the Mac 16 and 32 px at actual size.

**Step 6. README images.** Retake `markdown/ios.png` (420 x 913) and `markdown/macos.png` (1100 x 550) from the gallery captures, same framing. **Done:** retaken from the "Game screen · Engine on" (iPhone) and "Document window · Engine on" (Mac, dark) gallery captures; no old art remains.

`planning/README.md` already has the row; its status moves when this lands.

## Tests

| Test | Where | Red until |
|---|---|---|
| `StartPositionHashIsPinned` | `BChessTests/BoardHashTests.cpp` | pin; breaks if the keys change |
| Notices load; contain "Colin M.L. Burnett", "Cburnett", "Pradyumna Kannan", the three BSD conditions, the disclaimer's upper-case opening and closing, the magicmoves conditions | `BChessTests/ThirdPartyNoticesTests.swift` (Swift Testing) | step 3 |
| `aboutItemOpensOneWindowWithTheNotices`, async, `.timeLimit(.minutes(1))`: exactly one localized "About BChess" in the app menu and none in the Window menu; firing the real item (`menu.performActionForItem(at:)`, so `GameCommands` → `openWindow(id: "about")`) opens the production `Window` scene (bounded poll of `NSApp.windows` by title); firing it again leaves one window; that window's accessibility tree, found through `.accessibilityIdentifier("about-notices")` on the notices, holds "Pradyumna Kannan" and "Colin M.L. Burnett"; the test closes the window | `BChessMacGalleryTests/MacMenuTests.swift` (hosted) | step 3 |
| Settings ▸ About BChess shows the notices | `BChessUITests` (final gate only) | step 3 |
| Every asset still resolves | gallery, full at the final gate | — |

**Recorded in step 3:** SwiftUI exposes no text to accessibility in the hosted, unfocused app (the tree holds only an empty `AppKitTextInteractionView`), and a production text view added only for a test is rejected. `aboutItemOpensOneWindowHostingAboutView` therefore proves the menu item, the one production window and that it hosts `AboutView`; the notices reaching the screen are covered by `ThirdPartyNoticesTests` (the bundled file) and the About gallery scenarios (the production view and loader, iOS and Mac).

That one hosted test is the smallest that covers the whole Mac path, menu item to bundled text, and the singleton behaviour: there is no Mac UI test target, and a test of `AboutView` alone or of the menu title alone would leave the wiring unproved. If the hosted, unfocused app shows no accessibility tree or does not open the window, the implementer stops and reports; the check is not weakened to the menu title.

## Invariants and risks

- **I1** untouched: hashes are not saved in files. **I2, I4** untouched. **I3:** step 1 is plain C++. **I5:** no `Link`, no new
  entitlement, no required-reason API (reading the bundle is not one).
- **Search behaviour** is the one engine risk; the pin and the bench signature cover it.
- **Black pieces on dark squares and the 36 pt knight** in the Games list look different: visual check.
- **A `Window` scene beside `DocumentGroup`** could disturb launch (APP-9): check a new game still opens and About opens once.
- **Strings:** the new keys contain no number or isolate; "MIT" passes `LocalizationCatalogTests`.

## Owed checks

Jean looks at the new pieces in the gallery, including their size. A run on a real device: board, promotion, About. A native reader for the new Hebrew and Arabic strings and listing lines.

## Follow-ups, not steps (nothing goes to App Store Connect from this work)

1. A new TestFlight build: the 1.0 builds so far carry the old art and the `PRNG` class.
2. App Store screenshots, all five slide sets in six locales, then the App Preview video: all show the old art.
3. Descriptions pushed by the `/release` step (`app-store metadata`), when Jean decides.
4. The answer to App Review's item 6, once step 5 has landed; `docs/licensing.md` is its source.

## Decisions

D1 to D6 are decided; D2–D6 are Jean's answers.

- **D1. Decided on 2026-11-04: a new icon** (Jean approved a carved Commons knight on two CC0 veneers; step 5). The origin of the earlier image stays unknown, so it is replaced and the new one is documented. The options considered were: (Blocks the answer to App Review, not the implementation.) Generated by an image tool
  under Jean's account: record the tool in `docs/licensing.md`, done. Stock or a found image: the licence, or a new icon.
  Nobody remembers: same case as the old pieces, so make a new one (`/app-icon`) and record how. **Recommendation:** do not submit until
  this is answered. A new icon can be a separate plan.
- **D2. Decided: keep the seed `1070372`, with runtime generation.** It is Stockfish's. A seven-digit number is not protectable and the generator is public domain, so step 1
  keeps it, with no behaviour change. Changing it removes the last trace, but changes keys, so search counts, a set of pinned tests
  and possibly a played move, for no legal gain.
- **D3. Decided: the current Commons revisions, naming the six contributors**, not Cburnett's last own one (2007-01-03). The 2007 files have a single author, but later revision comments fix invalid SVG code and asymmetries in them,
  so they differ slightly in look and may render worse. The current ones carry small technical edits by six others, under the same licences, named in the notice.
- **D4. Decided: no tappable link, URLs as selectable text.** A `Link` opens the system browser; the app itself still does no network, and needs no entitlement. Still,
  the full text is in the app, so nothing requires one, and "no network" stays literally true without it.
- **D5. Decided: leave git history as it is.** Removing them means rewriting history: new hashes for every commit, broken clones and PR references.
  They were public for years, and no claim exists.
- **D6. Decided: the `LICENSE` line becomes "Copyright (c) 2017-2026 Jean Bovet"** (step 4). It said "Copyright (c) 2021-2026 jean-bovet"; the code starts in 2017 and the app says Jean Bovet.
