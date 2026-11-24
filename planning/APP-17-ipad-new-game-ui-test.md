# APP-17 — The New Game UI test on the iPad

Revision 3 (2026-11-25; r3, round 2: also measure after the first field's focus, settle before the sheet-open assertion; r2, review round 1: the measurements and the overlay mutation gate the diagnosis, both drag endpoints clamped, the software-keyboard claim narrowed). Implemented (commits 8eed40b, 2d2644d on the branch). Measured: the second field lies wholly under the Start bar and one slow drag clears it, so the app is right. After the code review, the sheet-open check is `waitForNonExistence(timeout: 2)` on Start (no private focus KVC). Software keyboard: not run. GitHub issue #65. Test code only: one helper in `BChessUITests/BChessUITests.swift`.

## 1. Problem, with evidence
`testNewGameRemembersTheChoice` fails on the iPad (iPad Pro 13-inch (M5), iOS 27.0, `main` at e6e14fb), passes on the iPhone.

- It fails in `replaceText` (`BChessUITests.swift:53`, reading `field.value`) for `new-game-second-name` (call at line 93), in the
  friend half. The issue names the first name field; the reproduction does not. The computer half passes.
- The field **is** found and `tap()` synthesizes an event. Right after, the sheet is gone and the hierarchy shows the friend
  game's board: Start Game was pressed, so the next query finds no text field.
- The test video shows the iPad's short form sheet, its Start bar (`.safeAreaInset(edge: .bottom)`,
  `Shared/Views/NewGameSheet.swift`, the iOS `layout`) over the second name field and half over the first. No software
  keyboard was up. The taller iPhone sheet shows both fields.

**Hypothesis, to prove before the fix is kept:** the field is only below the fold; scrolling brings it clear of the bar, so the app is
right and the test taps a covered point. Two things must be explained by the measurements: "30 s", at about the same
height in the computer half, is tapped without trouble (XCTest scrolls an element it judges not hittable; does it
judge this field hittable?), and the first field's focus scroll could move the content between the frame read and the tap.

## 2. Design
A `scrollClear(_ field:, in app:)` helper, called first by `replaceText` (which gains `app`; its three calls follow). No
scroll helper exists in `BChessUITests`. It works from frames, since `isHittable` is what appears unreliable here:

- **Clear** = `field.frame` lies wholly between `app.buttons["Cancel"].frame.maxY` (the sheet's bar) and
  `app.buttons["new-game-start"].frame.minY - 8` (the Start bar's vertical padding). The rule is proven with the hardware
  keyboard only (what the pool simulators use); the software-keyboard geometry is run if possible, else an owed check.
- Each read first waits until two successive frames agree (0.25 s apart, at most 3 s; never settling is a failure).
- Not clear at the bottom: drag up by the missing distance plus 12 pt, with both endpoints clamped inside the scrolling
  area (12 pt below Cancel, 24 pt above the Start bar), with
  `press(forDuration:thenDragTo:withVelocity:thenHoldForDuration:)` at a slow speed and a hold, so there is no fling.
  The start point is in the content's 16 pt margin, `x = start.frame.minX - 8`, 24 pt above the bar: no button or field under it,
  never on Start. Only upward drags: they cannot start the sheet's interactive dismiss or `scrollDismissesKeyboard(.interactively)`.
- At most 5 drags. Then `XCTAssertTrue(clear, "<identifier> cannot be scrolled clear of the Start bar: <frames>")`. A
  rubber-banded field settles back and fails. A field above Cancel fails at once (no downward drag).
- After the tap, `replaceText` waits for a dismissal to have had time to finish (a bounded wait for the field's keyboard focus, `hasKeyboardFocus`, or settled frames), then asserts the Start button still exists ("the tap closed the sheet"), before reading the value.

**The diagnosis is settled only by measurement:** test plan 2 and 3 run before the fix is kept; without both, stop and report.

**Strict enough?** Yes for this class of bug: content that cannot scroll clear, a missing inset, or a sheet that closes
on the tap all fail with their own message; typing and the remembered "Ben" prove the field took focus. It does not assert
that a field is visible without scrolling; that is a look choice.

**Stop rule:** if a slow upward drag cannot clear the field, or if the field is clear and its tap still starts the game, the app
is wrong. Stop and report; change neither the app nor the assertion.

## 3. Alternatives rejected
- `swipeUp()` on the app or sheet: starts on arbitrary controls, flings, and may start on Start.
- A loop on `isHittable`: the covered field was tapped anyway.
- Skipping the iPad, or a shorter path through the sheet: loses the coverage #65 asks for.
- A taller iPad sheet (`presentationSizing`): a look change, a possible follow-up issue, not this fix.

## 4. Test plan
1. **Red (have it):** the test on `ipad` at e6e14fb, section 1. Red proof again: commit, remove only the `scrollClear` call, run on `ipad`, see it fail at the "closed the sheet" assertion, restore with `git checkout --`.
2. **Hypothesis proof:** in a temporary run, print settled frames of both fields, Start and Cancel and `isHittable`, before and after one drag on `ipad`, and also after the first
   field is focused and immediately before the second is tapped; report them. Nothing of it is committed.
3. **Strictness proof (temporary app edit, reverted):** replace `.safeAreaInset` with a bottom `.overlay`; the helper must fail with the "cannot be scrolled clear" message on `ipad`. `git status` clean after.
4. **Green:** the test on `iphone` and `ipad`, three runs each, hardware keyboard; then once on `ipad` with the software keyboard up if the leased simulator can show it without changing its settings, otherwise reported as not run.
5. **Landing gate** (fresh `<dd>`, `gates.md`): the Mac build and test lines, the UCI build, the warnings gate **plus** a line for the `BChessUITests` target (the third line's form, own `SYMROOT`/`OBJROOT`; the stock lines do not compile it), iOS `build-for-testing`, `-only-testing:BChessUITests/BChessUITests/testNewGameRemembersTheChoice` on `iphone` and `ipad`.
6. **Done-when of #65:** the whole iOS test line, unfiltered, on `ipad` (UI and gallery tests; `testLandscapeOnlyFaceToFace` skips there). Any other failure is run on `main` too and reported, not fixed here.

No gallery run: the look does not change. No new entity, string or scenario.

## 5. Invariants
I1 to I5: not applicable (no app code, no files, engine or network). Views, `ContentView.swift` and `project.yml` untouched.

## 6. Risks
- Frames of covered content are read through the accessibility tree; the settle wait and frame rule guard against stale ones.
- Simulator timing: bounded drags and settle waits fail with frames in the message.
- The unfiltered iPad line may show unrelated failures; #65 then stays open (`Refs #65`) until they are settled.

## Decision left open
None. No file-format change, nothing needs a real device. A taller iPad sheet can be its own issue if wanted.

## Steps
1. **Scroll the field clear** — measure (test plan 2), add `scrollClear` and the sheet-still-open assertion, the red and strictness proofs, green on `iphone` and `ipad`.
