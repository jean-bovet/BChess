# APP-12 — Gallery script: the newer preview-gallery checks

Revision 2 (2026-11-13). GitHub issue #52.

- Revision 1: initial plan.
- Revision 2: Codex plan round 1 (1 blocker, 4 should-fix, all accepted): one rounding rule matching Swift's `.rounded()` (half away from zero) with a half-pixel test; coverage date, file table and xccov-failure tests; non-finite, zero/negative and boolean values tested.

Jean's request (issue #52): bring `scripts/preview-gallery.py` and the manifest writers in line with the shared
reference skill on two points it already describes:

- `--coverage-views` and `--coverage XCRESULT`: the script's `--coverage` (view types no scenario names) becomes
  `--coverage-views`, and `--coverage XCRESULT` adds the test run's app coverage to the gallery page.
- `points` and `scale` in the manifest: each entry records its window in points and its capture scale; the
  render-scale rule of `--check` (and through it the light/dark pair size) reads them, and `--check` fails an entry
  without them.

Each new `--check` rule is proven on a tiny PNG or a scratch manifest in the script's tests, like the existing ones.

The honest size: about 60 lines of Python, four lines of Swift in two manifest writers, one extracted function, and
the test cases. No new file besides this plan.

## 1. Problem, with evidence

- This repo's copy of the skill names exactly what is missing (`.claude/skills/preview-gallery/SKILL.md`):
  - lines 208-210: "Not yet in this repo's script: the `--coverage-views` rename and `--coverage XCRESULT`";
  - lines 222-226: the manifest should carry "the window in points and the capture scale (`points`, `scale`) of
    **every** scenario"; "Not yet in BChess's scripts: `points` and `scale` in the manifest (its manifest has `size`;
    the page script derives the scale itself)";
  - line 228: "`--coverage` (the reference's `--coverage-views`; `--coverage XCRESULT` not yet in this repo's script)";
  - lines 325-327: the render scale "the reference reads it from the entry's `points` x `scale` and fails an entry
    without them — not yet in BChess's script".
  No other rule of the skill is marked "not yet" (the only other "not yet" in `.claude/skills/` is unrelated, in
  `testflight`). The shared reference skill's `--check` also lists "a light/dark pair whose images differ in pixel
  size": BChess has no separate rule for it, and needs none once both images are judged against the same
  `points` x `scale` (proven by a test below).
- The script guesses the capture scale instead of reading it: `render_scale()` (`scripts/preview-gallery.py:175-178`)
  returns 3 for an entry flagged `duoInner`, a `duo-inner` platform, or any gallery whose folder is named `duo`, else 2;
  `do_check` (`:249-259`) multiplies the `size` string by it. The writer knows the real scale and does not record it:
  `GallerySize.scale(duoPass:)` (`BChessGalleryTests/GalleryScenarios.swift:52-55`) sets the capture scale,
  but the iOS manifest (`BChessGalleryTests/SnapshotGalleryTests.swift:64-71`) writes only `size` and a `duoInner`
  flag that exists only so the script can re-derive it (`BChessGalleryTests/GalleryFixtures.swift:44-45`). The Mac
  manifest (`BChessMacGalleryTests/MacSnapshotGalleryTests.swift:48-57`) writes `size` truncated to whole points
  (`Int(size.width)`) while `MacRenderer` captures `(frame.width * scale).rounded()` at `MacRenderer.scale = 2`
  (`BChessMacGalleryTests/MacRenderer.swift:72, 157`); the check only works because every Mac frame happens to be whole.
- `--coverage` (`scripts/preview-gallery.py:303-321, 409, 424-425`) lists view types and writes
  `data/coverage.json` as `{views, notRendered}`; nothing reads that file (the page never shows coverage), while the
  layout reserves `data/coverage.json` for the page and a full import keeps it (`scripts/test_snapshot_gallery.sh:446-449`).
  Neither gallery run produces a result bundle: both pass `-enableCodeCoverage NO` (`scripts/snapshot-gallery.sh:257, 267`,
  `scripts/snapshot-mac.sh:65`), as the skill requires (SKILL.md:260). So `--coverage XCRESULT` reads a bundle the
  caller made with a normal test run, which is the shared reference skill's design too.
- Plans index: APP-4 and APP-5 built the script and the manifest, APP-8 added the Duo scale, APP-10 the Mac writer.
  None proposed this; nothing rejected overlaps.

## 2. Design

### 2.1 `points` and `scale` in the manifest (the writers)

- `GalleryManifestEntry` (`BChessGalleryTests/GalleryFixtures.swift:31-46`, shared by both gallery targets) gains
  `let points: [Double]` (the window `[width, height]` in points) and `let scale: Double` (the capture scale), written
  for every entry, skipped ones included (the reference: "of **every** scenario"). `size` stays (the page sizes each
  card from it, `size_ratio`, `:166-172`; it is not the check's input any more).
- iOS: the manifest map moves out of the render test into
  `static func manifestEntries(screen: CGSize) -> [GalleryManifestEntry]` on `SnapshotGalleryTests` (reading
  `duoPass`/`ipadPass` as today). Second caller: the new `GalleryScenarioTests` test below, so the test checks the
  production writer, not a copy. `points` is `scenario.size.points(screen:)`, `scale` is
  `scenario.size.scale(duoPass: duoPass)` — the same two calls `render(_:style:)` uses (`:105-116`), so what is
  recorded is what was captured.
- Mac: `manifestData(rendered:)` writes `points: [size.width, size.height]` (the frame itself, not truncated) and
  `scale: Double(MacRenderer.scale)`.
- The `duoInner` field is removed from `GalleryManifestEntry` and from the iOS writer in step 2, together with the
  script code that reads it (its only reader), so no commit leaves a gallery whose `--check` is wrong.

### 2.2 The render-scale rule reads them (`--check`)

In `do_check` (`scripts/preview-gallery.py:249-259`), for **every** manifest entry (skipped ones too):

- `render_size(entry)`: `points` a list of two finite positive numbers and `scale` a finite positive number (not a
  bool) → `(floor(w * scale + 0.5), floor(h * scale + 0.5))` — Swift's `.rounded()` (half away from zero) for these
  positive values, the rule `MacRenderer` captures with (`:157`); never Python's `round()`, which rounds half to even
  (`round(90.5) == 90`, Swift gives 91); otherwise `None` (also when a product is not finite).
- `None` → problem `no render size in the manifest (points, scale): <platform>/<slug>` (the check fails; no image of
  that entry is size-checked).
- Otherwise each existing image of the pair must be exactly that size → the existing message, now from the entry:
  `wrong render scale: <platform>/<file> is WxH px, not <w>x<h> pt at <scale>x (W'xH')` (numbers printed with `:g`,
  so whole points read `402x874`).
- `render_scale()`, `RENDER_SCALE`, `DUO_SCALE` and the folder-name guess go; the `size` parse in `do_check` goes
  (the "unreadable size" problem with it). `png_size` (`:181-187`) is reused as is.
- The light/dark pair size: both images are compared with the same expected size, so a pair that differs fails with
  the dark (or light) image named. No separate rule.

### 2.3 `--coverage-views` and `--coverage XCRESULT`

- `--coverage-views` (store_true) runs today's `do_coverage` renamed `do_coverage_views`, which now **only prints**
  (it stops writing `data/coverage.json`: that file is the app coverage now, as in the shared reference skill).
- `--coverage XCRESULT` (`metavar='XCRESULT'`): `do_coverage(xcresult)` runs
  `xcrun xccov view --report --json XCRESULT`, takes the first target named `BChess.app` (both apps' product; one
  bundle holds one platform's run), and writes `data/coverage.json` as
  `{covered, executable, measured, files: [{path, covered, executable}]}` — `path` relative to the repo, files sorted
  least covered first, `measured` the bundle's modification time (`YYYY-MM-DD HH:MM`). Then it rebuilds the page when
  a manifest exists. A bundle xccov cannot read, or with no `BChess.app` target: a message on stderr, exit 2,
  `coverage.json` untouched.
- The page (`build_page`/`page`, `:190-221, 324-400`): when `data/coverage.json` has `executable`, an
  "App coverage" section after the groups (total percent, lines, the date, then a table of files) and a "Coverage"
  link in the nav; no file, or an old-shape file (`{views, notRendered}` from the old `--coverage`), adds nothing.
  The table reuses the page's tokens (`--line`, `--muted`, `--card`), so it follows the light/dark switch.
- The script's usage docstring gives the command that makes a bundle (the Mac scheme, the cheapest run with app
  code: `caffeinate -is buildlock --folder <dd> -- xcodebuild test -scheme "BChess (macOS)" -destination
  'platform=macOS' -derivedDataPath <dd> -enableCodeCoverage YES -resultBundlePath <dd>/app-coverage.xcresult`, then
  `PREVIEW_GALLERY_OUT=previews/mac scripts/preview-gallery.py --coverage <dd>/app-coverage.xcresult`). The gallery
  scripts stay at `-enableCodeCoverage NO` (no change to `snapshot-gallery.sh` or `snapshot-mac.sh`).

## 3. Alternatives rejected

- **Keep deriving the scale in the script** (duoInner flag, folder name): the guess is what the issue removes; a new
  pass or device would need a new guess. The writer already knows the scale.
- **Drop `size` from the manifest** (points carry it): the page's card sizing and every fixture read `size`; the shared
  reference skill keeps both. Not worth the churn.
- **Run the gallery with coverage on and produce the bundle in `snapshot-gallery.sh`**: the gallery test renders, it
  does not exercise the app; coverage instrumentation slows the run the skill keeps fast (`-enableCodeCoverage NO`).
- **A separate pair-size rule**: redundant with both images checked against one expected size (§2.2).
- **A hint section on the page when no coverage is stored**: noise on every page nobody asked for coverage on; the
  usage text documents the command.
- **Accept a manifest entry without `points`/`scale` by falling back to `size` x 2**: the issue and the reference
  both say an entry without them fails; a fallback would hide a writer that forgot them.

## 4. Test plan

Every case goes in `scripts/test_snapshot_gallery.sh` (the real page script in a scratch tree, `page_setup`, tiny PNGs
from `png`, manifests from `fake_run` and `flag`), and is added to `ALL`. **Red proof:** each new or changed case is
written first and run against the unchanged script (`scripts/test_snapshot_gallery.sh <case>`), its `FAIL` lines kept
in the step report; then the change, and the whole file green (`all lifecycle checks passed`).

- **Fixtures follow the writers** (step 2): `fake_run` writes `points` (`[6, 6]`, or `[4, 4]` for duo-inner / the Duo
  pass) and `scale` (2, or 3) on each entry; the hand-written entries get them too (`skipped`: `[678, 466]`, 2;
  `layout_mac`: `[144, 90]`/`[46, 38]`, 2; the stub manifests of `mac_setup` and `lang_import` are not checked by the
  real script but get them for realism).
- **`render_scale`** (rewritten, step 2), each expectation red before the change unless noted:
  1. A 6x6-pt entry with `scale: 3` whose images are 18x18 passes (red today: the script expects 2x for a non-Duo
     card) — the scale is read, not guessed.
  2. A Duo inner pose on the iPad pass (`platform: ipad`, `points [4,4]`, `scale 3`, 12x12 px) passes with no
     `duoInner` flag (red today without the flag).
  3. The same gallery imported under `previews/duo` with entries at `scale: 2` and 12x12-px images passes (red today:
     the folder name forces 3x) — no folder guess.
  4. `alpha.dark.png` at 18x18 for a `[6,6]`@2 entry fails with
     `wrong render scale: iphone/alpha.dark.png is 18x18 px, not 6x6 pt at 2x (12x12)` (the light/dark pair of
     different sizes, the dark one named; green today with the old wording, so its message changes are part of the red).
- **`render_size_missing`** (new, step 2): `flag` removes `points` from one entry → `--check` exits non-zero with
  `no render size in the manifest (points, scale): iphone/alpha`; the same for a missing `scale`, for `scale: true`
  (a bool), `scale: 0`, `scale: -2`, `scale: NaN` and `scale: Infinity` (Python's json reads both), `points: [6]`,
  `points: [6, 0]`, `points: [-6, 6]`, `points: [true, 6]`, `points: [6, NaN]`, `points: [1e309, 6]` (decodes to
  infinity) — each through `--check`, each named; a skipped entry without them fails too. Restored → `CHECK OK`. Red today
  (the check ignores the fields).
- **`mac_fraction`** (new, step 2): a `[45.25, 38]`@2 entry (90.5 px wide, the half-pixel case) with 91x76-px
  images passes and with 90x76-px images fails, named (`round()` would expect 90, Swift's `.rounded()` gives 91);
  a `[45.5, 38]`@2 entry passes at 91x76. All through the production `--check`. Red today: `size` cannot hold a
  fraction.
- **`coverage_views`** (new, step 3): a scratch `Shared/Lonely.swift` with `struct Lonely: View` → `--coverage-views`
  prints `Lonely` and writes no `data/coverage.json`; `--coverage` with no argument exits 2 (argparse). Red today
  (unknown option).
- **`coverage_app`** (new, step 3): a stub `xcrun` first on PATH answers `xccov view --report --json <bundle>` with a
  canned report (two targets, `BChessTests.xctest` and `BChess.app` with three files, one at 0 executable lines, paths
  under the scratch tree); `--import` a fake run, then `--coverage "$T/app.xcresult"` (an empty directory) → exit 0,
  `previews/data/coverage.json` has the app target's totals and files least covered first with relative paths; the
  page has `id="coverage"`, the percent (`66.7%`), a nav link, the bundle's date (the case sets it with
  `touch -t 202611131015 "$T/app.xcresult"`, the page shows `2026-11-13 10:15`), and each file row with its relative
  path, its `covered/executable` count and its percent, in the least-covered-first order. A report without
  `BChess.app` → exit 2, a message on stderr, the earlier `coverage.json` unchanged (byte compare). The stub exiting
  non-zero (xccov cannot read the bundle, no JSON on stdout) → exit 2, a message on stderr naming the bundle, the
  earlier `coverage.json` unchanged. An old-shape `{"views": 3, "notRendered": []}` file → the page builds with no coverage
  section. A later full `--import` keeps the section (the file survives, existing `layout` case). Red today.
- **Swift, iOS** (step 1), in `GallerySuites.GalleryScenarioTests`:
  `@Test("the manifest records every scenario's window in points and its capture scale")` calls
  `SnapshotGalleryTests.manifestEntries(screen: CGSize(width: 402, height: 874))` and expects, per scenario, `points`
  equal to `size.points(screen:)`, `scale` 3 for the duo-inner sizes and 2 for the others (the test runs on the
  iPhone pass), `size` the same numbers as `points`, and one entry per scenario. Red: it does not compile before the
  change.
- **Swift, Mac** (step 1): `manifestSizeIsTheMountedFrame` (`BChessMacGalleryTests/MacGalleryScenarioTests.swift:88-109`)
  also expects the rendered Settings entry to carry `points == [1234, 567]` and `scale == 2`, and every measured entry
  `scale == 2` with `points` matching its `size`. Red before the writer change (`points` missing).
- The production path is covered end to end by the landing gate's real gallery runs (§6): the writers' real
  manifests go through the real `--check`.

## 5. Invariants

- **I1** (files keep opening): not applicable — no game file format touched.
- **I2** (search results land on their position): not applicable — test and tooling code only.
- **I3** (portable engine): not applicable — `Shared/Engine/` untouched.
- **I4** (UCI tool): not applicable.
- **I5** (private and offline): holds — `xccov` reads a local bundle; no required-reason API is added to the apps
  (the changes are in test targets and scripts).

## 6. Risks and rollout

- **A gallery made before step 2** (an old `previews/data/manifest.json` without `points`) fails `--check` after it:
  intended; the next gallery run rewrites the manifest. Stated in the step report.
- **Fractional Mac frames**: points are recorded unrounded and the product rounded half away from zero
  (`floor(x + 0.5)`), matching `MacRenderer`'s `.rounded()`; the `mac_fraction` half-pixel case proves it.
- **xccov's JSON shape**: the stub mirrors `xcrun xccov view --report --json` (`targets[].name`, `coveredLines`,
  `executableLines`, `files[].path`); the landing gate runs `--coverage` once on a real bundle, so a shape mismatch
  shows before landing.
- **Step gates.** Steps 2 and 3 are Python and shell only: `scripts/test_snapshot_gallery.sh` (all cases) plus
  `git diff --check`; step 2 also edits Swift (the `duoInner` field), so it runs the build and warnings gates too.
  Step 1 changes Swift test code: the test gate's first three lines (the Mac tests include
  `BChessMacGalleryTests`), the iOS build-for-testing line and
  `test-without-building -only-testing:BChessGalleryTests/GallerySuites/GalleryScenarioTests` on a leased `iphone`,
  and the warnings gate including the two gallery-target lines. Step 4 is docs only (the docs-only gate).
- **Landing gate** (once, fresh `<dd>`): the quick tier of `/develop`, `scripts/test_snapshot_gallery.sh`, and real
  gallery runs whose `--check` must end `CHECK OK [en]` under the new rules: `scripts/snapshot-gallery.sh --no-open`,
  `--device duo --no-open`, `--device ipad --no-open` (the scale is now read on every pass), and
  `scripts/snapshot-mac.sh` (the Mac writer changed; BChess closed). Then one real coverage run: the Mac test line
  with `-enableCodeCoverage YES -resultBundlePath <dd>/app-coverage.xcresult`, and
  `PREVIEW_GALLERY_OUT=previews/mac scripts/preview-gallery.py --coverage <dd>/app-coverage.xcresult` exits 0 and
  the Mac page shows the "App coverage" section (contact sheet of the galleries unchanged; the coverage section seen
  once in the page source or a screenshot).
- Rollout: none beyond landing; no version bump, no app behaviour change.

## 7. Decision left open for Jean

None. Every choice follows the shared reference skill (field names, the failure for a missing entry, `--coverage-views`
printing only, `coverage.json` holding the app coverage). The bundle the coverage comes from (the Mac test run) is a
usage example, not a fixed pipeline: any `xcodebuild test -enableCodeCoverage YES -resultBundlePath` run works.

## Steps

1. **Manifest writers record points and scale** — `GalleryManifestEntry` gains `points` and `scale`; the iOS map
   becomes `SnapshotGalleryTests.manifestEntries(screen:)` (called by the render test and the new
   `GalleryScenarioTests` test); the Mac `manifestData(rendered:)` writes the unrounded frame and `MacRenderer.scale`;
   the Mac test extended. Red first (both tests fail to compile), then green. Gates: test gate lines 1-3, the iOS
   gallery-tests line, warnings gate.
2. **`--check` reads points x scale** — `render_size()` replaces `render_scale()` and the `size` parse; an entry without
   valid `points`/`scale` fails; `duoInner` removed from the writer, `GalleryManifestEntry` and the script; docstring
   updated; test fixtures write the fields; `render_scale` rewritten, `render_size_missing` and `mac_fraction` added,
   each shown red against the old script first. Gates: `scripts/test_snapshot_gallery.sh`, build and warnings gates
   (one Swift field removed).
3. **`--coverage-views` and `--coverage XCRESULT`** — the rename (printing only), `do_coverage(xcresult)` through
   `xcrun xccov`, the page's "App coverage" section and nav link, the usage text; `coverage_views` and `coverage_app`
   cases, red first. Gate: `scripts/test_snapshot_gallery.sh`, `git diff --check`.
4. **Skill notes** — remove the "not yet" notes from `.claude/skills/preview-gallery/SKILL.md` (lines 208-210, 225-226,
   228, 325-327) and fix what they leave stale: `--coverage` becomes `--coverage-views` plus `--coverage XCRESULT`,
   the `duoInner` mention at the render-scale rule becomes "the entry's `points` x `scale` (2x; 3x for the Duo's inner
   poses and every card of the Duo pass); an entry without them fails", and the "Run" section's coverage line if it
   names the old option. Docs-only gate.
