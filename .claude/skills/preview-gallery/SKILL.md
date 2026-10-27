---
name: preview-gallery
description: Render every screen of the BChess iPhone app in light and dark with one snapshot-test run (scripts/snapshot-gallery.sh) and open the preview gallery, one card per scenario with light and dark side by side. The app has no #Preview: the scenario list in the test target is the only source. Use when Jean asks to see the screens, to check a branch visually, to look at one screen after a change, or to regenerate the preview gallery.
argument-hint: [--only pattern]
allowed-tools: Read, Glob, Grep, Bash
---

# /preview-gallery: every screen, rendered light and dark, on one page

**The app has no `#Preview`.** Every screen is a named *scenario* in the test target, and one snapshot-test run
renders them all, light and dark, into PNGs that `scripts/preview-gallery.py` assembles into one HTML page
(gitignored, regenerated on demand): one card per scenario, light on the left, dark on the right.

Why this and nothing else: a `#Preview` duplicates the scenario, needs a pairing check to stay in step with it,
and is rendered by Xcode's canvas, the heaviest way to look at a screen (Xcode plus a preview host per file).
The scenario list is one source, ships nothing in the app, and a test run on one headless simulator renders
every screen at about one second each. Spot checks use `--only`, not the canvas.

BChess (`BChess.xcodeproj`, scheme "BChess (iOS)"). The gallery lives in the app-hosted unit-test target
`BChessGalleryTests`: `GalleryScenarios.swift` (the scenario list and the `Fixture` PGN constants),
`SnapshotGalleryTests.swift` (the render), `GalleryScenarioTests.swift` (the list's own tests, which parse every
PGN fixture, and lay the pixel oracles of the fold layout over the production render with `GalleryPixels.swift`;
both suites sit in the serialized parent suite `GallerySuites`). Output: `previews/index.html` (gitignored; the
images in `previews/iphone/` and `previews/duo-inner/`, the manifest in `previews/data/`). Groups, in page order:
Game, iPhone Duo · inner display, Board, Engine, Moves, Games list, Settings, Walnut (48 cards). The
approved visual spec is the Walnut design canvas (`planning/README.md`, UI-WALNUT row).

**English only, in every repo**, whatever languages the app ships (`-testLanguage en -testRegion US`). The gallery
checks layout and appearance; translations are checked by the repo's catalog tests, not by screenshots. Never add
a language pass to the gallery. The one exception is the App Store screenshots: a repo whose store pages show the app
in each store language keeps a `--lang` option in its gallery scripts, used only by `/app-store-screenshots` with
`--only` the slides' captures, into its own folder per language (`previews/fr/`). The gallery page stays English.

iPhone 17 Pro (402x874 pt), plus one iPad-landscape card ("Game screen · Wide", 1180x820, regular / regular) and
the iPhone Duo's inner-display cards (the group "iPhone Duo · inner display": 951x669 and 669x951 pt, regular /
regular, captured at 3x) rendered on the iPhone simulator. The iPhone app is portrait-locked (a landscape trial was
reverted: the real rotated board measured 151 pt). No iPad pass. **The iPhone Duo pass is built** (APP-8): `--device duo`
renders the 48 scenarios (one of them skipped, see below) on the pool's `duo` simulator into `previews/duo/` (see below), after the audit in
`planning/APP-8-iphone-duo.md` (the checklist of `docs/iphone-duo.md`, next to the tools the global working
agreement names). A screen whose layout changes at regular
width gets an inner-display scenario. The OS's real division region is a manual check in Xcode's Device Hub: the
fixtures use a 40 pt stand-in hinge at the centre. No Mac pass: macOS-only views (`DocumentWindow`) have no
scenario until the off-screen renderer of item 5 is brought to BChess.

Adopted (APP-5): the app has no `#Preview` and no `#if DEBUG` preview code.

## Run: `scripts/snapshot-gallery.sh`

```
scripts/snapshot-gallery.sh                     # every scenario; the simulator goes back to the pool
scripts/snapshot-gallery.sh --only "settings,list" # a subset: comma-separated substrings of names or slugs
scripts/snapshot-gallery.sh --device duo        # the iPhone Duo: outer display and fixed-size inner poses -> previews/duo/
scripts/snapshot-gallery.sh --no-open           # do not open the page (agents, scripted runs)
```

- **Done = `CHECK OK [en]: <n> cards, light and dark complete and correctly lit`**. Then read the new or changed
  PNGs in both appearances (see Report). `simpool status` shows nothing leased by the run.
- Costs measured on a proven repo (24 GB Mac, iOS 27 simulator): booting the simulator about **6 GB** of RAM;
  a run on a booted one about **0.25 GB**; build tools under 0.3 GB. Warm run: about 1 s per scenario plus a
  fixed 20–25 s (xcodebuild installs and launches the host app), so ~50 scenarios take 1.5–2.5 min and
  `--only` one scenario about 25 s. From a shut-down simulator add 1–3 min (a fresh boot keeps iOS busy). The
  pool normally keeps a released simulator warm for the next run (within the host's budget) and shuts it
  down after 30 idle minutes.
- **iPhone Duo** (`--device duo`, pool spec `duo`, iOS 27.1): `simctl` cannot fold or unfold a simulator (Xcode 27.1),
  so it stays folded. The phone-sized scenarios render on the outer display (466 x 678 pt, compact width, the status
  bar on the side); the script asserts that size before labelling the captures. The inner display's poses are
  scenarios at fixed window sizes, 951 x 669 pt (landscape, the hinge vertical at the centre) and 669 x 951 pt
  (portrait), regular size class both ways, captured at 3x. A custom control that steps off the fold takes its fold
  rectangles from a test-only hook (a 40 pt stand-in hinge at the centre); the OS's real reserved regions are a manual
  check in Xcode's Device Hub. The pass prints `gallery: duo screen 466 x 678 pt` and fails before the first
  capture on a simulator that is not folded (`duoPassProblem()`). A card the pass cannot render honestly is skipped, never captured badly: the folded Duo places the system
  bars against its own 466 x 678 screen, not the 951 x 669 window (the "Duo inner · Landscape · Shell" card), so it prints `gallery: skipped <slug>: <why>`, is listed in the
  manifest with a `skipped` reason, and the page shows "not rendered on this pass"; `--check` accepts the missing pair
  for that reason only, and the render itself fails when a mount's settled bounds differ from the requested size.
  Read those cards on the iPhone pass (see "A screen needs a scenario"). Model: xFractal. Apple's rules and the
  audit checklist: `docs/iphone-duo.md`, next to the tools the global working agreement names.

- Snapshot test: `GallerySuites/SnapshotGalleryTests` in `BChessGalleryTests`; it runs only when
  `BCHESS_SNAPSHOT_DIR` is set (`TEST_RUNNER_BCHESS_SNAPSHOT_DIR` in xcodebuild's environment) and filters with
  `BCHESS_SNAPSHOT_ONLY` (the script's `--only`). It prints `gallery: <slug> <duration>` per scenario and
  `gallery: <n> scenario(s)`, which the script forwards.
- Script options: `--device iphone|duo` (anything else exits 2 before a lease), `--only`, `--no-open`, the
  fallback's `--keep-booted` / `--shutdown` / simulator name, and `SIMULATOR_UDID` (used as is, never leased or
  released). The test runs with `-testLanguage en -testRegion US`. Not there: an iPad pass (`--device ipad`, one more
  case once wanted). The page script writes the layout of "What a repo needs" item 3 (`PREVIEW_GALLERY_OUT`, the
  Duo pass's `previews/duo`, survives a full iPhone import and the other way round).
- Simulator: a lease from the pool, `simpool acquire --spec iphone --pid $$` (iPhone 17 Pro, iOS 27.0; `--spec duo`,
  iOS 27.1, on the Duo pass), given back
  with `simpool release <udid> --app ch.arizona-software.BChess` by the exit trap on success, failure and
  INT/TERM/HUP; the script never creates, boots, shuts down or erases one. Both `xcodebuild` commands run under
  `buildlock --folder <DerivedData>` (the test with `--no-slot`). A failed `simpool acquire` exits 1.
- Fallback (public repo: `simpool` or `buildlock` not on PATH): the script's own "BChess Agent" (iPhone 17 Pro,
  latest runtime), created if missing, booted and shut down by the script, `xcodebuild` without `buildlock`; the
  marker of the one it booted is `${TMPDIR:-/tmp}/bchess-snapshot-gallery.<UDID>.booted`, outside DerivedData, so
  any `BCHESS_SNAPSHOT_DD` can shut it down. `--keep-booted`, `--shutdown` and a simulator name or id apply to it
  only (with the pool they do nothing).
- Lifecycle tests: `scripts/test_snapshot_gallery.sh` (stub `xcrun`, `xcodebuild`, `simpool`, `buildlock` and
  page script; PATH limited to the stubs and the system directories). Pool: lease released on success, failure
  and INT/TERM/HUP, an interrupted `simpool acquire` stopped, no `simctl` lifecycle call. Fallback: create, boot,
  shutdown, `--keep-booted`/`--shutdown`, a borrowed simulator left running. The Duo pass: a `duo` lease, the page in
  `previews/duo/`, an unknown `--device`, `SIMULATOR_UDID`, `caffeinate`, and the real page script on fake manifests
  (the folder layout, the migration of a flat gallery, both galleries surviving each other's import, a `skipped`
  card, a `documentCanvas` pair, a blank render with and without `drawsNothing`, a forced appearance or locale in
  the scenario file).
- DerivedData: `BCHESS_SNAPSHOT_DD`, default `~/Library/Developer/Xcode/DerivedData/BChess-snapshots` (one folder
  for every checkout; a plan passes its own). No SPM packages, so no package flags.
- Measured (APP-5, 3 scenarios): cold (empty DerivedData, shut-down simulator) boot 39 s, build 61 s, test 59 s,
  total 161 s; warm boot 1 s, build 10 s, test 20 s. The 38 cards of a warm run took 53 s of test, about 1.4 s
  per card (the Games list and Launch cards, with their 1 s settle, 2.6 s). Memory (`vm_stat` active + wired +
  compressed): about +2.4 GB at the simulator boot, +6 GB at the peak of build and test on a busy Mac.

## A screen needs a scenario

One entry in the scenario list, and nothing in the app:

- **name** (unique, the card title; the slug is derived from it: "Settings · Signed out" → `settings-signed-out`),
  **group** (the page section), **size** (the full phone screen, a short component canvas, or a widget family),
  an optional **settle** wait for a screen that loads or animates, and a builder that returns the view, seeding
  a store first when it needs one.
- **Never force an appearance or a language** (`.preferredColorScheme`, `.environment(\.locale, …)`): the light
  and dark passes and `-testLanguage` set them. A state that only existed as a "dark" variant is a plain scenario.
  Dynamic Type variants are fine, as their own scenarios.
- **Hermetic data.** A fresh in-memory store per scenario. The network is a stub that answers from committed
  fixtures (real API responses, their times shifted to now so screens look live) or fails with a given error,
  and counts its calls; the test prints the count. No scenario reaches a real API (quotas, rate limits,
  changing data). A fixed location and clock-relative data instead of real ones.
- **Shared singletons.** If a view is wired to a shared instance (a `.shared` actor or store), its scenario
  uses that instance through the same stub, resets it first, and is flagged so it renders **after** the
  others: its background work then cannot change another scenario's view through shared notifiers.
- A view that draws nothing (an invisible trigger, an empty state that is `EmptyView`) gets no scenario; name it
  in a comment in the scenario file. Live maps can be left out; say so the same way.
- **Flags for an honest `--check`.** A card that is dark in both appearances by design (a document canvas, a white
  PDF page, full-bleed imagery) sets `documentCanvas: true` on its scenario: `--check` then judges the pair instead
  of each image (the dark image's mean luminance at least 0.05 below the light one's). A screen that draws nothing
  by design sets `drawsNothing: true` (otherwise `--check` fails a blank render). A card a pass cannot render
  honestly is **skipped, never captured badly**: the test prints `gallery: skipped <slug>: <why>`, the manifest
  lists it with a `skipped` reason, the page shows "not rendered on this pass", and `--check` accepts the missing
  pair for that reason only. BChess's manifest carries all three: `skipped` (the Duo pass), and the scenario
  fields `documentCanvas` and `drawsNothing`, which no card sets yet.
- `scripts/preview-gallery.py --coverage` lists view types no scenario names (informational: most are parts
  of other screens).

## What a repo needs

1. **Scenario list and fixtures** in the app-hosted unit-test target (it has the app's window scene and
   `@testable import` of the app): no `#if DEBUG`, nothing compiled into the app. An app-extension view
   (a widget) cannot be imported by a test: compile its view file into the app target as well, and give it an
   explicit parameter for what WidgetKit normally injects (`widgetFamily` is read-only in the environment).
2. **The snapshot test**, skipped unless the snapshot-directory variable is set, so normal runs and Xcode
   Cloud skip it. It filters by the optional `ONLY` variable, renders each scenario in a `UIHostingController`
   inside a `UIWindow` on the app's scene at a fixed size, once with a light and once with a dark
   `overrideUserInterfaceStyle`, waits for `settle`, draws with `drawHierarchy` at 2x, writes `<slug>.png` and
   `<slug>.dark.png`, releases the window, and writes `manifest.json` (name, group, slug, size of **every**
   scenario) so the page script never parses Swift. It swaps the host app's own shared loader for the stub too.
3. **`scripts/preview-gallery.py`**: `--import DIR [--partial]` (replace the gallery, or only the files of an
   `--only` run), `--check`, `--coverage`; with `scripts/preview-luminance.swift` for the lit check.
   **Output layout**: only the page at the top of the output folder, everything else in subfolders:
   ```
   previews/
     index.html
     <platform>/<slug>.png, <slug>.dark.png    one folder per platform or device family (iphone/, ipad/, mac/, watch/)
     other/                                    an imported image no scenario names (--check reports it as stray)
     data/manifest.json, data/coverage.json    what the page is built from
   ```
   The folder is the manifest entry's platform field (with a default for entries without one); the page links
   `<platform>/<file>`. The snapshot test still writes one flat directory per run: only the import places the files.
   A full import clears the images of every folder but `data/`, and keeps `data/coverage.json`. `--check` lists
   the PNGs of every folder but `data/` and names files by their relative path (`ipad/x.dark.png`). The
   luminance helper prints `<folder>/<file>`. A repo moving from a flat gallery migrates it in the script (every
   command first moves what is still at the top, resumably, then rebuilds the page), and `snapshot-gallery.sh`
   reads `data/manifest.json` with a fallback to the old path. Proven in one repo's conversion; BChess's script
   carries the migration (its lifecycle tests cover it).
4. **`scripts/snapshot-gallery.sh`**:
   - The simulator from the machine-wide pool: `SIMULATOR_UDID` if the caller passes one (never released),
     else `simpool acquire --spec iphone --pid $$` (then `ipad`, `duo`, one device after the other), and
     `simpool release` in the exit trap. Every `xcodebuild` runs under `buildlock --folder <DerivedData>`.
     Never boots or shuts down a simulator itself.
   - A repo that may run without the pool (a public repo, a fresh clone): when `simpool` is not on PATH, its
     own agent simulator (created if missing, booted with `simctl boot`, no Simulator.app window) under the
     old rule: `xcrun simctl list devices booted` first, wait (up to 10 min) for another one, never touch one
     it did not boot, a `trap` shuts down the one it booted. A private repo requires the pool.
   - Persistent DerivedData; `-skipPackageUpdates -disableAutomaticPackageResolution` once the packages are
     resolved (otherwise every run resolves remote packages: 75 s measured).
   - `build-for-testing` once, then one `test-without-building -only-testing:<snapshot class>
     -parallel-testing-enabled NO -enableCodeCoverage NO -testLanguage en -testRegion US`.
   - The variables go in **xcodebuild's environment** as `TEST_RUNNER_<NAME>=… xcodebuild …`; written as
     arguments they become build settings and never reach the test.
   - Import, `--check`, open the page (`--no-open` skips that: agents, scripted runs), print the timings (boot,
     build, test, total). It keeps the Mac awake for the run (`caffeinate -dims`): a run during which the Mac
     slept took three times as long.
5. **A Mac target**: an app-hosted macOS test renders each scenario with no simulator, **off screen**: a real
   `NSWindow` with an `NSHostingController` (so `.toolbar` and `NavigationSplitView` bridge to AppKit) and an
   `NSAppearance`, never ordered on screen, whose whole layer tree `CARenderer` draws into a Metal texture at 2x.
   It works with the screen locked, flashes nothing, and draws sidebars, toolbar glass, `PDFView` and materials as
   on screen; no ScreenCaptureKit, `cacheDisplay` or unlocked-screen check. The recipe, readiness without a visible
   window, sheets, `PDFView` waits and what differs from an on-screen capture (neutral dark mode, inactive
   selection, Retina only): [`mac-offscreen-renderer.md`](mac-offscreen-renderer.md). The Mac test also holds a
   second `buildlock --folder <the host app's container or cache folder> --no-slot`, so two worktrees never run
   the hosted app at once. BChess has no Mac pass yet: `DocumentWindow` and the other macOS-only views wait for it.
6. **Optional passes** when the audience needs them: a largest-Dynamic-Type pass, another device family (one
   simulator after the other). Never another language (localized store captures belong to `/app-store-screenshots`).

## The gate: `--check`

`--check` rebuilds the page from the PNGs on disk and fails on: a scenario of the manifest missing either
image, a stray PNG no scenario expects (in any folder, or in the wrong platform's folder), a duplicate slug, a light image that is dark or a dark one that is light
(mean luminance against a threshold; a `documentCanvas` scenario is judged as a pair instead, the dark image's
mean luminance at least 0.05 below the light one's), a dark image byte-identical to its light one, a blank image
(one colour everywhere) unless its scenario sets `drawsNothing`, an image that cannot be decoded, and
`.preferredColorScheme` or `\.locale` anywhere in the scenario file (its `//` comments aside). An `--only` run replaces only its own images; the check still covers every scenario. The gallery is
done only when `--check` passes.

## Converting a repo (from `#Preview`s)

A planned change (`/develop`), in three gated steps:

1. Test, stub, fixtures and both scripts with **three** scenarios (one full screen with a store, one
   component, one widget if any). Gate: a cold and a warm run, timings and memory (`vm_stat`: active + wired +
   compressed, sampled during the run; summed RSS over-counts shared memory) recorded; the normal test run still
   passes with the gallery skipped.
2. Every `#Preview` becomes a scenario; delete every `#Preview` and `PreviewProvider`, and the preview-only data
   and helpers compiled into the app (move what the test needs into the test target; check that fixtures still
   parse with the current parser). Gate: `CHECK OK`, every target builds with 0 warnings, the tests pass, and
   every card read in both appearances.
3. This skill's repo facts and the repo's `AGENTS.md` (replace any "every view needs a `#Preview`" rule with
   "every screen needs a scenario"). Gate: Jean reviews the gallery.

Gotchas met on the first conversion: xcodebuild can stay alive after a failed test (stop the process it
started, never one it did not); a view hard-wired to a shared singleton cannot use a private store (see Shared
singletons); old fixtures may be in a format the parser no longer reads.

Hermetic by construction: BChess has no network code (I5), so there is no stub and the report states
"network: none (I5)". Every scenario keeps a human to move or a non-play position and the engine readout off
(`@AppStorage("showEngine")` reads its default from the scratch "BChessGallery" suite), so no search starts. The
test host launches with `-uiTestingFreshLibrary` (the scheme). Every PGN a scenario loads is a `Fixture`
constant, because `GameSession.init` silently falls back to an empty game on a rejected PGN: a test parses each
one. The scenario file `--check` reads for a forced appearance or locale is `GalleryScenarios.swift`.

## Report

The card count (per platform), the check line, the timings, the network-call count, and any
scenario that failed with its error's first line. Then the one thing this skill exists for: read at least the
new or changed screens with the Read tool, **in both appearances** and on every platform rendered, compare them
with the approved spec when there is one, and say what looks wrong (copy, hierarchy, truncation, an empty state
that should not be empty, a colour or border that vanishes in dark mode, low contrast). Screenshots nobody looks
at are not a gate. A visual finding is reported, not fixed in passing.
