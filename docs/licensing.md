# Licensing record

Every third-party item in the repository and what BChess owes for it. It is a reading of the licences and the history, not legal
advice. Rule (see `AGENTS.md`): a new asset, font, sound or copied code gets a line here, and in `Shared/ThirdPartyNotices.txt`
when it ships. No code copied from GPL engines.

What ships: the two apps. `BChessUCI` is built but not distributed; test targets, `Dependencies/`, `scripts/` and `planning/` never ship.
The shipped notices are `Shared/ThirdPartyNotices.txt`, shown by About BChess; the piece license sits beside the sources in
`Art/pieces/LICENSE.txt`. Plan and history: `planning/LEGAL-1-piece-artwork.md`.

## Audit

Ours = written for BChess. OK = third party, terms met. Risk = needs a fix or an answer.

| Item | Origin and licence | Ships | Class | Action |
|---|---|---|---|---|
| `Shared/Assets.xcassets/pieces/*.pdf` | Rendered from the 12 Commons SVGs below by `scripts/render-pieces.swift`; BSD, full text in About | Yes | OK | Credited in About, listing, README |
| `Art/pieces/*.svg` | Wikimedia Commons, Cburnett, BSD (below); unmodified | No | OK | License text beside them |
| `markdown/ios.png`, `markdown/macos.png` | README screenshots, retaken from gallery captures with the Commons pieces | No (public) | OK | Retaken in LEGAL-1 step 6 |
| `ChessBoardHash.cpp` random numbers | Own xorshift64* function (Sebastiano Vigna, 2014, public domain), written from the paper's description; same generator and seed as before, so the same keys | Yes | Ours | Replaced in LEGAL-1 step 1; see the record below |
| `AppIcon.appiconset` | Replaced on 2026-11-04 (the earlier image had no recorded origin): the Commons knight (Cburnett, BSD) carved by `scripts/render-icon.swift` over two Poly Haven CC0 veneers (okoume_veneer, teak_veneer, by Jenelle van Heerden), all rendered by that script; all PNGs, light, dark, tinted, Mac | Yes | OK | Credited in About and `Shared/ThirdPartyNotices.txt`; sources and SHA-1 in `Art/icon/SOURCES.txt` |
| `Art/icon/*.jpg` | Poly Haven, CC0 ([license](https://polyhaven.com/license)), Diffuse 2k, unmodified | No | OK | None needed; credited anyway |
| `Shared/Engine/Helpers/magicmoves.{c,h}` | Pradyumna Kannan, 2007, zlib-style. Notice kept; acknowledgment appreciated. History since the 2017 import shows one whitespace-only change to the `.c` and none to the `.h`, so nothing to mark as altered (condition 2) | Yes | OK | Credited in About, listing, README |
| `ChessEvaluater.cpp` piece-square tables | Michniewski's Simplified Evaluation Function, via the chessprogramming wiki (the comment says so). Numeric parameters; the wiki's license could not be confirmed | Yes | OK (low) | Kept and credited; known residual, see below |
| Bishop-pair, SEE, futility, null move, fifty-move heuristics | Ideas from the literature; comments cite sources. A full similarity scan against other engines was not done | Yes | OK | None |
| Remaining `Shared/Engine`, `Shared/Bridge`, Swift | Ours | Yes | Ours | None |
| `BChess/Openings.pgn` | Opening names and moves (facts); scores ours | Yes | Ours | None |
| Fonts | None bundled; `.system(design: .serif)` is the system's New York | System | OK | None |
| Sounds | None | n/a | Ours | None |
| Colours, `*.colorset` | Numbers, ours | Yes | Ours | None |
| `Dependencies/gtest`, `BChessTests/Helper/gtest-all.cc` | Google Test, BSD-3, `LICENSE` and headers kept; compiled into `BChessTests` only. `build-aux/`, `m4/` and `configure` carry GPL autotools files, source only and never compiled | No | OK | None |
| `BChessTests` fixtures | FEN and PGN positions, perft numbers (published facts) | No | Ours | None |
| `scripts/elo-match.sh` | Downloads fastchess, Stockfish and a book into git-ignored `.elo/`; nothing redistributed. Stockfish is a measuring tool; its name is not in the UI, strings or listing | No | OK | None |
| `planning/assets/*` | Our mock-ups, scripts and patches; one link to Google Fonts in a review page | No | Ours | None |
| `.claude/skills/*` | Our tooling | No | Ours | None |
| App Store screenshots and previews | Not tracked (`AppStore/*.json` hold layouts only); phones drawn in CSS, headlines in the system font. They still show the earlier art until retaken | Listing | OK | Owed follow-up |
| Listing and UI text | No third-party marks | Yes | Ours | None |
| `LICENSE` (MIT) | `Copyright (c) 2017-2026 Jean Bovet`, matching the oldest file headers | Repo | OK | None |
| File headers "All rights reserved", `NSHumanReadableCopyright` | Xcode boilerplate beside the MIT `LICENSE` | Yes | OK | None |

## Chess pieces

Source: Wikimedia Commons, files `Chess_{k,q,r,b,n,p}{lt,dt}45.svg`, by Colin M.L. Burnett (Commons user Cburnett), 2006-12-27.
The current revisions include technical edits by Antonsusi, TomFryers, Apathor, Cyco130, Smasongarrison and Edemaine. The
files carry the tags `{{self|GFDL|migration=relicense|BSD|GPL}}` ("You may select the license of your choice"); the page histories
show the author adding the BSD and GPL licenses himself (2007-01-12 and 2007-12-12). BChess chooses BSD. The name Colin M.L. Burnett
comes from Lichess's `COPYING.md`; Commons shows the user name only.

SHA-1 of the committed files (current revision, checked 2026-11-04; `shasum Art/pieces/*.svg`):

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

Download URL pattern: `https://commons.wikimedia.org/wiki/Special:FilePath/Chess_klt45.svg`. The SVGs are converted to PDF for the
asset catalog, a modification the license permits; the notice says so.

BSD text, as Commons renders it on the file pages (the template shows the disclaimer in upper case; the placeholder "The author" is
as on the page):

> Copyright © The author
>
> Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:
>
> 1. Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
> 2. Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
> 3. Neither the name of The author nor the names of its contributors may be used to endorse or promote products derived from this software without specific prior written permission.
>
> THIS SOFTWARE IS PROVIDED BY THE AUTHOR AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE AUTHOR AND CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

## Record of earlier sources and builds

Facts only, as of 2026-11-04; no conclusion is drawn here.

- The `PRNG` class in `Shared/Engine/Helpers/ChessBoardHash.cpp` was in the engine source from 2018-02-04 until LEGAL-1 step 1. Its
  comment said it was taken from the Stockfish source code (GPLv3). Earlier revisions in the repository's history contain it, and so
  do the TestFlight builds made before the fix.
- The piece artwork replaced in LEGAL-1 step 2 had no recorded origin or license. Earlier revisions in the repository's history
  contain it, and so do the TestFlight builds made before the replacement.
- No earlier build went public on the App Store: iOS 1.0 is `REJECTED` and Mac 1.0 is `DEVELOPER_REJECTED` in App Store Connect
  (confirmed 2026-11-04).

## Known residual

The piece-square tables in `ChessEvaluater.cpp` come from Tomasz Michniewski's Simplified Evaluation Function as published on the
chessprogramming wiki. They are numeric search parameters; the license of the wiki page could not be confirmed. They are kept and
credited in About and in `Shared/ThirdPartyNotices.txt`. Replacing them would mean retuning the engine and measuring its strength
again.
