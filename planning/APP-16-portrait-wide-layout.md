# APP-16: the wide layout on an upright iPhone (issue #68)

**Status: proposed, 2026-11-25 (r1).** The bug is in the build testers have, 1.0 (21) = tag `v1.0`, and is **already
fixed on main** by APP-14 (`7faaf86`, #64, "step 5: the layout is chosen from the offered space"). This plan adds
tests only. No production code changes.

## Problem, with evidence

TestFlight feedback (iPhone16,2 = 430 x 932 pt, iOS 27.2.1, 2026-11-21): an upright iPhone draws the wide layout, cut off on
both sides. The newest TestFlight build then was 21, built from `32dacd9` (`v1.0`); APP-14 landed the next day and no
build has shipped since.

**Cause: a layout feedback loop** in `v1.0`'s `Shared/Views/ContentView.swift`. No landscape size is involved.

1. `content` draws `placement?.isWide ?? true` (l.211): before the first measure `placement` is nil, so the first pass
   is the **wide** layout, with a 320 pt sidebar minimum (l.178).
2. The body measures `content.frame(maxWidth: .infinity, maxHeight: .infinity)` (l.238-239). Without a `minWidth` that
   frame is at least as wide as its child, so `onGeometryChange` reports the wide layout's own width when it overflows.
3. The wide layout's minimum width is `rowsMin + 8 + 320`, `rowsMin` being the widest `PlayerRow`
   (`BoardColumn.rowsMin`). In v1.0 the captures share the name's line, 22 pt per piece and not compressible, plus the
   points and, in dark mode, 12 pt of capsule.
4. When that width exceeds the height of the content, `isWide` stays true and the wide layout keeps producing the width
   that selects it. Otherwise the second pass is tall, and the bug is invisible.

**The overflowing subview** is the `PlayerRow` capture line, not the status line and not the move list: the same probes gave
those minimum widths of 1 and 32 pt; the sidebar contributes only its fixed 320.

**Reproduced** with a hosted probe (throwaway): `ContentView` in a `NavigationStack` with a navigation and a bottom bar, in a
fixed window, `rotated: true`, two humans, each measured size and each chosen layout logged. The game has 15 captures by
White and 13 by Black. Safe area 62/34 on the 430 and 402 pt windows. At `v1.0`:

| Window | Light: measured, layout | Dark: measured, layout |
|---|---|---|
| 430 x 932 (offered 398 x 698) | 694 x 698, then 398 x 698 tall | **706 x 698, wide (latched)** |
| 440 x 956 (offered 408 x 722) | tall | tall (706 < 722) |
| 402 x 874 (offered 370 x 640) | **694 x 640, wide** | **706 x 640, wide** |
| 375 x 667 (offered 343 x 433) | **694 x 433, wide** | **706 x 433, wide** |

The 430 dark row's log is `nil g 706x75 WIDE g 706x650 WIDE g 706x698 WIDE`: a cold mount upright, no landscape size. It is
the report's case: the report's screenshot shows dark mode, a 430 pt phone and a long row of captures. Its move list starts
at about 248 pt, which is (430 - 706) / 2 + 378 + 8 = 248. In light mode the same game is 4 pt short of
latching at 430 pt (694 < 698), which is why it is rare on a large phone. On 402 pt it takes 13 captures in either appearance, on 375 x 667
as few as 8.

**Main (`e6e14fb`) does not latch.** `measuredContent` (l.402-427) measures a `Color.clear` that takes exactly the offered
space, draws the content in its overlay (an overlay never changes its base's size) and draws nothing before the first
measure. The same probes measured 398 x 698 / 370 x 640 / 343 x 433 and `tall` every time (over 200 mounts: two long games at
five phone sizes, Dynamic Type up to accessibility 5 at 430 x 932, engine on and off, with variation cards). The fix is
the measurement: with v1.0's measuring put back into main (APP-14's smaller rows kept), the latch returns on 402 x 874 dark
(642 x 640) and 375 x 667 (621 or 642 x 433).

**The issue's suggestions and other states:**

| Suspect | Verdict |
|---|---|
| Launch held sideways, stale landscape size | Not needed: an upright cold mount reproduces it, and the v1.0 iPhone is portrait only. A sideways-to-upright resize gives the same result as a cold mount |
| Scene restore | Ruled out as a cause: it only decides which game is mounted. It fits the 17 s uptime: the first pass needs a new `ContentView` (launch, or another game, `.id(url)`) |
| Sheet, keyboard | Not needed to reproduce; a keyboard inset was not probed. On main it can only change a real offered size, which the layout follows back |
| Fold regions | Not involved on this phone (no division region). On main they come from the same clear base |
| Tall content overflowing (large text, engine, variation cards) | No latch at 430 x 932 in v1.0 or main: overflowing height only favours the tall layout. On main it is clipped or centred as before, never re-measured |
| Two boards sideways, then one board upright (APP-15) | Main: tall after the turn (test below). With v1.0's measuring in main: latches at 402 dark and 375 |
| iPad, Split View | v1.0 latches when a 1180 x 820 window shrinks to 507 (`g 600x586`) or 375 wide; main is tall. A 678 x 820 window stays wide on both because the bars leave 646 x 586, really wider than tall (by design) |

## Design

No production change. Add the regression test that covers what APP-14's does not: the bars, the reported game, 430 x 932 and
the turn from a sideways friend game. It reuses `FrameBox`, `FrameProbeKey` and `SnapshotGalleryTests.mount`.

1. **Regression test for the reported screen**, `BChessGalleryTests/GalleryScenarioTests.swift`, beside
   `manyCapturesKeepTheTallLayoutOnEveryPhoneWidth`, and its PGN in `GalleryScenarios.Fixture` (so it also joins
   `allPGNs`, and `every PGN fixture parses` covers it).

## Alternatives rejected

- `frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, ...)` around the content: also cures the overflow report, but the
  first pass still draws a guessed layout. Main's version already does both; rewriting it gains nothing.
- Deciding by size class instead of width > height: would change iPad and Duo (`area.width > area.height`), out of scope.
- Porting the fix to a 1.0.x branch: the next TestFlight build from main carries it.
- Closing the issue on APP-14's test alone: that test proves the latch red (below) but not with bars, at 430 pt, or turning.

## Test plan

No pure logic to unit test: the fault is SwiftUI measuring a view, so the test hosts the screen.

`phoneUnderTheBarsIsTallUprightAndAfterTurning(size:)`, arguments 430 x 932, 402 x 874, 375 x 667; each in both `styles`, each
mounted (a) upright and (b) sideways with `faceToFace: true`, then `setFaceToFace(false)` and the window and host resized
upright (neither `column` nor `tall-column` shows before the toggle). `ContentView` sits in a `NavigationStack` with an inline
title, a principal item and a bottom-bar item. Expects: 15 captures by White; no `column` frame; a `tall-column` frame
within 15.5 pt of the window's sides. The PGN (all legal, 126 plies):

```
1. h4 g5 2. hxg5 e6 3. Rxh7 Qxg5 4. Rxf7 Qxg2 5. Rxd7 Qxg1 6. Rxc7 Qxf2+ 7. Kxf2 Rh3 8. Rxc8+ Kd7 9. Rxb8 Rxb8 10. Bxh3 Bg7 11. Bxe6+ Kxe6 12. c3 Bxc3 13. dxc3 b6 14. Qe1 a5 15. b3 Rc8 16. Bb2 Rxc3 17. Qxc3 Kd5 18. Qxa5+ bxa5 19. Nd2 Ne7 20. Kf1 Kd6 21. a3 a4 22. bxa4 Kc6 23. Ke1 Kd7 24. Bg7 Kd6 25. Nf3 Kc5 26. Bh6 Nc6 27. Ra2 Na7 28. Ng5 Nb5 29. axb5 Kxb5 30. Nh7 Ka6 31. Kf1 Kb5 32. Bf8 Ka6 33. e3 Kb6 34. a4 Kc7 35. Ra1 Kb8 36. Rd1 Ka8 37. a5 Ka7 38. Rd5 Kb7 39. Rf5 Kc8 40. Rf2 Kc7 41. Rf6 Kb7 42. Ng5 Ka8 43. Rd6 Kb8 44. Kg1 Ka8 45. Be7 Ka7 46. Nh3 Ka8 47. Rd4 Kb8 48. Bc5 Ka8 49. Kf1 Kb8 50. Ba7+ Kxa7 51. Ke1 Ka6 52. Kd1 Kxa5 53. Ng1 Kb6 54. Rf4 Kb5 55. Kd2 Ka6 56. Kd3 Kb5 57. Nf3 Ka6 58. Rf6+ Kb5 59. Ke4 Kc5 60. Ng5 Kb4 61. Ke5 Kc3 62. Rc6+ Kd3 63. Rc8 Kxe3 *
```

**Red proof, observed** by putting v1.0's measuring back (`content.frame(...).onGeometryChange` in place of the clear base):
`Test run with 1 test in 2 suites failed after 10.667 seconds with 12 issues`, e.g.

```
... recorded an issue with 1 argument size → (402.0, 874.0) at GalleryScenarioTests.swift:517:21: Expectation failed: box.frames["column"] == nil
... recorded an issue with 1 argument size → (375.0, 667.0) at GalleryScenarioTests.swift:518:21: Expectation failed: column != nil
```

430 x 932 stays green under that mutation: APP-14 already made the rows shorter (642 < 698). So the 430 pt case is proven red
at `v1.0` only (by the probe above); it stays as the reported size. The existing
`manyCapturesKeepTheTallLayoutOnEveryPhoneWidth` is also red under the mutation (2 issues, l.432 and 433). On main the new
test passed in 10.034 s.

**Landing gate:** `BChessGalleryTests` on the iPhone pool simulator; no UI suite (none is touched) and no warnings. The gallery
does not change (no view changes), so no new captures; before closing, look at the existing cards the issue names: iPhone
upright, friend game upright and sideways, iPad, Duo and Mac.

## Invariants

- I1 files: not applicable. I2 search results: not applicable (no session code). I3 portable engine, I4 UCI: not
  applicable (not touched). I5 offline: holds, no new API.

## Risks and rollout

- Test-only. The 400 ms settle follows the file's other hosted tests; safe-area insets depend on the simulator, so the test
  asserts the layout and not sizes.
- File formats unchanged. Testers keep the bug until a TestFlight build from main.
- **Owed:** on a real iPhone, with a build from main: a finished long game (12 or more captures) reopened after a relaunch,
  in dark mode; a friend game turned sideways, then Two Boards off and upright.
- The commit says `Refs #68` (the device check is owed), not `Closes`.

## Decision left open for Jean

- **D1.** Add the test (recommended) or close #68 on APP-14's test and the device check alone.
- **D2.** Send a TestFlight build soon: the only way testers lose the bug. Not part of this plan (`/testflight`).

## Steps

1. **Regression test** — the PGN fixture and `phoneUnderTheBarsIsTallUprightAndAfterTurning`, red proof as above
