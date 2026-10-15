---
# repo-specific: identity
name: preview-gallery
description: Render every screen of the BChess iPhone app in light and dark with one snapshot-test run (scripts/snapshot-gallery.sh) and open the preview gallery, one card per scenario with light and dark side by side. The app has no #Preview: the scenario list in the test target is the only source. Use when Jean asks to see the screens, to check a branch visually, to look at one screen after a change, or to regenerate the preview gallery.
argument-hint: [--only pattern]
# /repo-specific
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

<!-- repo-specific: app -->
BChess (`BChess.xcodeproj`, scheme "BChess (iOS)"). The gallery lives in the app-hosted unit-test target
`BChessGalleryTests`: `GalleryScenarios.swift` (the scenario list and the `Fixture` PGN constants),
`SnapshotGalleryTests.swift` (the render), `GalleryScenarioTests.swift` (the list's own tests, which parse every
PGN fixture; both suites sit in the serialized parent suite `GallerySuites`). Output: `previews/index.html`
(gitignored). Groups, in page order: Game, Board, Engine, Moves, Games list, Settings, Walnut (38 cards). The
approved visual spec is the Walnut design canvas (`planning/README.md`, UI-WALNUT row).
<!-- /repo-specific -->

<!-- repo-specific: platforms-and-languages -->
iPhone 17 Pro (402x874 pt), plus one iPad-landscape card ("Game screen · Wide", 1180x820) rendered on the iPhone
simulator. English only. No Mac pass: macOS-only views (`DocumentWindow`) have no scenario until the Mac renderer is
proven in another repo.
<!-- /repo-specific -->

<!-- repo-specific: status -->
Adopted (APP-5): the app has no `#Preview` and no `#if DEBUG` preview code.
<!-- /repo-specific -->

## Run: `scripts/snapshot-gallery.sh`

```
scripts/snapshot-gallery.sh                     # every scenario, then the simulator is shut down
scripts/snapshot-gallery.sh --only "settings,list" # a subset: comma-separated substrings of names or slugs
scripts/snapshot-gallery.sh --keep-booted       # a series of runs (during a /develop plan: first gate on)
scripts/snapshot-gallery.sh --shutdown          # then shut it down (never creates a simulator)
```

- **Done = `CHECK OK [<lang>]: <n> cards, light and dark complete and correctly lit`** for every language
  rendered. Then read the new or changed PNGs in both appearances (see Report) and make sure the simulator is
  shut down.
- Costs measured on a proven repo (24 GB Mac, iOS 27 simulator): booting the simulator about **6 GB** of RAM;
  a run on a booted one about **0.25 GB**; build tools under 0.3 GB. Warm run: about 1 s per scenario plus a
  fixed 20–25 s (xcodebuild installs and launches the host app), so ~50 scenarios take 1.5–2.5 min and
  `--only` one scenario about 25 s. From a shut-down simulator add 1–3 min (a fresh boot keeps iOS busy).
  Keep it booted only for a series of runs; always end with it shut down.

<!-- repo-specific: script -->
- Snapshot test: `GallerySuites/SnapshotGalleryTests` in `BChessGalleryTests`; it runs only when
  `BCHESS_SNAPSHOT_DIR` is set (`TEST_RUNNER_BCHESS_SNAPSHOT_DIR` in xcodebuild's environment) and filters with
  `BCHESS_SNAPSHOT_ONLY` (the script's `--only`). It prints `gallery: <slug> <duration>` per scenario and
  `gallery: <n> scenario(s)`, which the script forwards.
- Simulator: "BChess Agent" (iPhone 17 Pro, latest runtime), created if missing; the marker of the one the script
  booted is `${TMPDIR:-/tmp}/bchess-snapshot-gallery.<UDID>.booted`, outside DerivedData, so any
  `BCHESS_SNAPSHOT_DD` can shut it down.
- DerivedData: `BCHESS_SNAPSHOT_DD`, default `~/Library/Developer/Xcode/DerivedData/BChess-snapshots` (one folder
  for every checkout; a plan passes its own). No SPM packages, so no package flags.
- Measured (APP-5, 3 scenarios): cold (empty DerivedData, shut-down simulator) boot 39 s, build 61 s, test 59 s,
  total 161 s; warm boot 1 s, build 10 s, test 20 s. The 38 cards of a warm run took 53 s of test, about 1.4 s
  per card (the Games list and Launch cards, with their 1 s settle, 2.6 s). Memory (`vm_stat` active + wired +
  compressed): about +2.4 GB at the simulator boot, +6 GB at the peak of build and test on a busy Mac.
<!-- /repo-specific -->

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
4. **`scripts/snapshot-gallery.sh`**:
   - `xcrun simctl list devices booted` first: one simulator at a time. Wait (up to 10 min) for another one,
     then stop with a message; never touch a simulator it did not boot. A marker file records the one it
     booted; a `trap` shuts that one down on any exit unless `--keep-booted`.
   - Its own agent simulator (created if missing), booted with `simctl boot` (no Simulator.app window).
   - Persistent DerivedData; `-skipPackageUpdates -disableAutomaticPackageResolution` once the packages are
     resolved (otherwise every run resolves remote packages: 75 s measured).
   - `build-for-testing` once, then per language one `test-without-building -only-testing:<snapshot class>
     -parallel-testing-enabled NO -enableCodeCoverage NO -testLanguage <lang>`.
   - The variables go in **xcodebuild's environment** as `TEST_RUNNER_<NAME>=… xcodebuild …`; written as
     arguments they become build settings and never reach the test.
   - Import, `--check`, open the page, print the timings (boot, build, test, total).
5. **A Mac target**: a macOS unit test renders natively (an `NSHostingView` with an `NSAppearance`), with no
   simulator at all. Not proven yet: design and measure it before relying on it.
6. **Optional passes** when the audience needs them: another language (one more test run on the same
   simulator), a largest-Dynamic-Type pass, another device family (one simulator after the other).

## The gate: `--check`

`--check` rebuilds the page from the PNGs on disk and fails on: a scenario of the manifest missing either
image, a stray PNG no scenario expects, a duplicate slug, a light image that is dark or a dark one that is light
(mean luminance against a threshold), a dark image byte-identical to its light one, an image that cannot be
decoded. An `--only` run replaces only its own images; the check still covers every scenario. The gallery is
done only when `--check` passes for every language rendered.

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

<!-- repo-specific: extras -->
Hermetic by construction: BChess has no network code (I5), so there is no stub and the report states
"network: none (I5)". Every scenario keeps a human to move or a non-play position and the engine readout off
(`@AppStorage("showEngine")` reads its default from the scratch "BChessGallery" suite), so no search starts. The
test host launches with `-uiTestingFreshLibrary` (the scheme). Every PGN a scenario loads is a `Fixture`
constant, because `GameSession.init` silently falls back to an empty game on a rejected PGN: a test parses each
one. `--check` also fails on `.preferredColorScheme` or `\.locale` in `GalleryScenarios.swift`.
<!-- /repo-specific -->

## Report

The card count (per platform and language), the check line, the timings, the network-call count, and any
scenario that failed with its error's first line. Then the one thing this skill exists for: read at least the
new or changed screens with the Read tool, **in both appearances** and on every platform rendered, compare them
with the approved spec when there is one, and say what looks wrong (copy, hierarchy, truncation, an empty state
that should not be empty, a colour or border that vanishes in dark mode, low contrast). Screenshots nobody looks
at are not a gate. A visual finding is reported, not fixed in passing.
