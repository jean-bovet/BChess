# /develop gates — build, test, red proof, warnings

The gates every `/develop` step and landing runs, in the worktree. An implementer reads this file only
(not `SKILL.md`). The simulator pool, `buildlock`, parallel-testing and four-minute-wait rules are the
global rules; this file adds what is specific to the gates.

## Two tiers

**Step gates** run after each plan step and each fix round: the build, the warnings check and the unit
tests, never the preview gallery: a step that adds or changes scenarios only checks that they compile,
and the look is shown to Jean at the landing gate. Step gates never run the UI tests, not even for a
step that touches what they drive (navigation, titles, accessibility identifiers, launch fixtures): the
landing gate catches what they would. A brief that asks a step gate or a fix round for them is
overruled: they wait for the landing gate.

The **landing gate** runs **once per plan**, on the tree handed back, on a fresh `<dd>`: the quick tier
(build, warnings check, unit tests) plus only the UI suites the change touches, on every device or
screen size the change affects; plus, before landing, the gallery shown to Jean (the scenarios
concerned, or in full) when the look changes. The plan's test list names the suites and devices. Step
gates never replace it. It starts only once the last implementation review round and its fixes are
committed, never while a round may still change the code. A later tree (a fix round, the rebase, the
squash on `main`) reruns the landing gate when it changed anything outside the docs-only paths
(`git diff --name-only <the commit the last landing gate passed on>` answers); a docs-only change runs
the docs-only checks below.

The **full run** (every test suite on every device, coverage, the full gallery) is not part of
`/develop`: it runs only in `/testflight` § Test gate, before every build (in a repo without
`/testflight`, in `/release` § Test gate). Send test builds often, so a red full run spans few plans.

## How the gates run

- **Build folders.** Step gates reuse ONE build folder for the whole plan (`<dd>`, e.g.
  `/private/tmp/<id-slug>-dd`, created once), so every build after the first is incremental. The
  landing gate uses a fresh `<dd>`, which also re-surfaces warnings an incremental build would not
  recompile. Logs go to a new scratch directory for every gate run.
- **Build once, test without building.** Where the platform allows it, a gate builds the tests once
  for a generic destination (`xcodebuild build-for-testing`) and runs them with `test-without-building`
  on the leased simulator, so the tree compiles once and the lease is held only while tests run. Any
  later run on the same tree (another test plan, a rerun) reuses those products. An app-hosted test
  target (a test bundle that runs inside the app, on the Mac too) follows the same rule:
  `build-for-testing` once per step, every rerun and red proof through
  `test-without-building -only-testing:<Target>/<Class>`, never a plain `xcodebuild test`. **A scheme
  with several test plans** names the gate's plan on both commands (`-testPlan <Plan>`): without it
  `build-for-testing` builds every plan, and `test-without-building` can fail with "Failed to create a
  bundle instance" before any test runs.
- **Locks.** Use the repo's scripts or build wrapper when it has them; otherwise every `xcodebuild`
  runs under `buildlock` (the global rules). A `test-without-building` run takes the folder's lock but
  no build slot: `buildlock --folder <dd> --no-slot -- xcodebuild test-without-building …`. An
  app-hosted Mac test run also holds `buildlock --folder ~/Library/Containers/<bundle id> --no-slot`,
  so two worktrees never host the real app (its sandbox container) at once.
- **Simulators.** Lease one from the pool for each gate run (the global rules; or the repo's scripts
  do it) and release it in a trap that also clears the app:
  `trap 'simpool release "$udid" --app <bundle id>' EXIT`, so the next holder doesn't inherit the
  running app. Don't hold a lease across gates. Every simulator test run passes
  `-parallel-testing-enabled NO -collect-test-diagnostics never`: without the second flag every
  failing test, so every red proof, collects a simulator diagnostics report for minutes; the gates
  read the log, never that report. To debug a failure nobody can explain, rerun that one test without it.
- **Keep the Mac awake.** Every long gate run holds a *system* sleep assertion (`caffeinate -s`; `-i`
  alone is not enough, and xcodebuild's own assertion lets a sleeping Mac stall UI tests into
  "Timed out while synthesizing event"). A gate script does it itself, in either form: it re-executes
  itself once under `caffeinate -is` (a guard variable such as `<REPO>_CAFFEINATED` so it happens once;
  `"$@"` and the exit status kept; no re-exec, one notice line, when `caffeinate` is missing), or it
  starts `caffeinate -dims -w $$` in the background for its own lifetime. Where the gate is a list of
  commands rather than a script, or a script that does neither, each long command runs as
  `caffeinate -is <command>` (`caffeinate -is buildlock --folder <dd> -- xcodebuild test …`). A script
  that re-executes itself has script tests for the re-exec, argument boundaries, the missing tool and
  signals.
- **Wait in slices** (the global four-minute rule): a build, a test run, the gallery or a Codex round
  starts in the background with its output in a log, checked every four minutes at most (a `Monitor`
  until-loop with that timeout, or a background command looked at on that cadence), reading the
  summary lines only.
- **Reading results.** Read the **exit status** and the summary line of every command; an empty grep
  is clean only if the command succeeded. The number of tests run is part of the result: zero is red,
  and a count that shrinks needs an explanation (a conditionally disabled test counts as skipped).
  Swift Testing app tests run through xcodebuild print `Executed 0 tests, with 0 failures`, which means
  nothing: read `Test run with N tests in M suites passed`. Only XCTest bundles print a real
  `Executed N tests`. A gate that refuses to run (Mac UI tests on a locked screen, say) is reported as
  not run, an owed check, never as green.

## Red proof

A regression test is proven red without its fix before it goes green: commit the fix first, revert
only the fix's lines, run the test and see it fail, restore with `git checkout -- <file>` (never a
hand-written inverse), then confirm `git status` is clean and grep the tree for any temporary marker.
A red-proof run builds incrementally in the step gates' `<dd>` and runs only the test class concerned,
never the whole suite: the step and landing gates run the rest. Build once applies: an Xcode test
target is rebuilt with `build-for-testing` and run with
`test-without-building -only-testing:<Target>/<Class>`; plain `xcodebuild test -only-testing:…` only
where the platform does not allow building once; a Swift package runs `swift test --filter <Class>`.
No version bump during feature work.

## Warnings

Fix every warning the branch touches or reveals, including ones that predate it. Deprecations are
fixed, never silenced (`@available`, `#warning`, suppression flags); if the fix conflicts with a
documented decision, update that decision's comment. A build-only warnings check uses
`xcodebuild -target <target>` with its own `SYMROOT` — never a scheme, so the shared build (or a
running app the scheme drives) stays untouched — and `COMPILER_INDEX_STORE_ENABLE=NO` on the command
line: without a derived-data path Xcode emits an empty `-index-store-path` and clang's hardening flag
turns into a bare warning. Keep that flag off the project files, so Xcode still indexes.

The warnings check compiles **every platform target that compiles the changed sources**, not only the
target whose folder changed: a shared package or framework change also builds the iOS (or other)
target, because a platform-conditional member called outside its `#if` passes every Mac gate and fails
only the CI archive of the other platform.

## Docs-only changes

No code: skip the build gates. `git diff --check`, every link and citation still resolves, and the
working agreement, plans index and README stay consistent.

## String Catalogs

A repo with a String Catalog: `catalog-sync --delete-stale`, then translations via the Xcode MCP
`StringCatalogEdit` (open the worktree's project in Xcode first, not the main checkout's), then
`catalog-sync --skip-build` once (it re-sorts the keys the editor wrote) and `catalog-sync --check
--skip-build`; commit the catalog with the step. This replaces an Xcode GUI build. A repo adopts it only
after `catalog-sync --check` on its main reports "catalog unchanged"; it needs the repo's
`catalog_project`/`catalogs` registered in the repos manifest catalog-sync reads, a scheme named like the target, an iOS Simulator
destination and `SWIFT_EMIT_LOC_STRINGS = YES` on each catalog target (it refuses otherwise). `--check`
still builds, and `--skip-build` reuses a possibly stale build. catalog-sync builds into its own private
folder and takes no `buildlock` slot, but it is still a build: never run it alongside another one. A
right-to-left language (Hebrew, Arabic) also runs through `docs/right-to-left.md`, next to the tools the global
rules name (digits, the minus sign, what must not mirror, the gallery's direction-aware tests).

## This repo's gates

- **Tests first:** a failing Swift Testing test before the change; a regression test proven red
  without its fix, restored with `git checkout -- <file>`. Fixtures: the gallery's PGNs are `Fixture`
  constants in `BChessGalleryTests/GalleryScenarios.swift`; engine tests (GoogleTest cases plus Swift
  tests) live in `BChessTests/`. `xcodegen generate` committed with any `project.yml` change; never
  hand-edit `BChess.xcodeproj`. A red proof on the Mac line runs
  `-only-testing:BChessMacGalleryTests/<Class>`.
- **Docs-only paths** (a landing-gate rerun is skipped when only these changed): `planning/`,
  `AGENTS.md`, `README.md`, `docs/`, `.claude/skills/`.
- **Test gate:** all of these pass, each read by exit status **and** summary line. Each runs under
  `caffeinate -is` (the Mac stays awake) and `buildlock` on its own DerivedData folder. The Mac test
  line (the second) also holds the hosted app's container lock (the outer `buildlock`, no slot): the
  scheme's `BChessMacGalleryTests` run inside the real Mac app, on its sandbox container, so two
  worktrees never run the host at once; it opens the app's untitled game window for the seconds the
  tests take. The Mac scheme builds its tests once (`build-for-testing`), then runs them with
  `test-without-building` (no build slot: it compiles nothing), so a rerun never re-links, re-signs and
  relaunches the host for nothing. The step gate runs the first three lines (the unit tests in
  `BChessTests` with the hosted `BChessMacGalleryTests`, and the UCI build). The landing gate adds the
  last three when the change touches a UI test, with `-only-testing:BChessUITests/BChessUITests/<test>`
  (one per touched test) on the last line, once per affected device spec (`iphone`, and `ipad` for iPad
  or regular-width layout); `/testflight`'s full run runs them without `-only-testing`. The iOS
  scheme's tests are the UI tests (`BChessUITests`) and the gallery tests, built once for the generic
  simulator, then run on a simulator leased from the pool for that run and given back right after it,
  also when it fails (run the last three lines in one shell):

  ```
  caffeinate -is buildlock --folder <dd>/dd-mac -- xcodebuild build-for-testing -scheme "BChess (macOS)" -destination 'platform=macOS' -derivedDataPath <dd>/dd-mac
  caffeinate -is buildlock --folder ~/Library/Containers/ch.arizona-software.BChess --no-slot -- buildlock --folder <dd>/dd-mac --no-slot -- xcodebuild test-without-building -scheme "BChess (macOS)" -destination 'platform=macOS' -derivedDataPath <dd>/dd-mac
  caffeinate -is buildlock --folder <dd>/dd-uci -- xcodebuild -scheme BChessUCI -destination 'platform=macOS' -derivedDataPath <dd>/dd-uci build
  caffeinate -is buildlock --folder <dd>/dd-ios -- xcodebuild build-for-testing -scheme "BChess (iOS)" -destination 'generic/platform=iOS Simulator' -derivedDataPath <dd>/dd-ios
  udid=$(simpool acquire --spec iphone --pid $$); trap 'simpool release "$udid" --app ch.arizona-software.BChess' EXIT
  caffeinate -is buildlock --folder <dd>/dd-ios --no-slot -- xcodebuild test-without-building -scheme "BChess (iOS)" -destination "id=$udid" -parallel-testing-enabled NO -collect-test-diagnostics never -derivedDataPath <dd>/dd-ios
  ```

  `** TEST FAILED **`, `** BUILD FAILED **`, a Swift Testing line `✘`, or any `error:` is red. The
  engine GoogleTest cases must show up as individual Swift Testing cases and must all have run (the
  count is printed by the suite): zero executed is red, never green.
- **Landing gate:** the quick tier (the step gate's test lines and the warnings gate below) plus only
  the UI tests the change touches (the test gate above), on every device the change affects: the
  iPhone (`simpool acquire --spec iphone`) always, and `--spec ipad` too when the change touches iPad
  or regular-width layout; plus the gallery shown to Jean (the gallery gate) when the look changes.
- **Full run:** every test suite, the iOS UI and gallery tests included, and the full gallery (iPhone,
  `--device duo` and `scripts/snapshot-mac.sh`): only `/testflight` runs it.
- **Warnings gate:** zero compiler warnings in our own sources (`Shared/`, `iOS/`, `macOS/`, `BChess/`,
  `BChessTests/`, `BChessAppTests/`, `BChessUITests/`, `BChessGalleryTests/`,
  `BChessMacGalleryTests/`; vendored `Dependencies/` and `gtest-all.cc` are exempt).

  ```
  caffeinate -is buildlock --folder <dd>/build-ios -- xcodebuild -target "BChess (iOS)" -sdk iphonesimulator -configuration Debug SYMROOT=<dd>/build-ios OBJROOT=<dd>/obj-ios COMPILER_INDEX_STORE_ENABLE=NO build 2>&1 | grep -E '^/.*(warning|error):|^(warning|error):' | grep -v -e ONLY_ACTIVE_ARCH -e /Dependencies/ -e gtest-all
  caffeinate -is buildlock --folder <dd>/build-mac -- xcodebuild -target "BChess (macOS)" -configuration Debug SYMROOT=<dd>/build-mac OBJROOT=<dd>/obj-mac COMPILER_INDEX_STORE_ENABLE=NO build 2>&1 | grep -E '^/.*(warning|error):|^(warning|error):' | grep -v -e ONLY_ACTIVE_ARCH -e /Dependencies/ -e gtest-all
  caffeinate -is buildlock --folder <dd>/build-gt -- xcodebuild -target BChessGalleryTests -sdk iphonesimulator -configuration Debug SYMROOT=<dd>/build-gt OBJROOT=<dd>/obj-gt COMPILER_INDEX_STORE_ENABLE=NO build 2>&1 | grep -E '^/.*(warning|error):|^(warning|error):' | grep -v -e ONLY_ACTIVE_ARCH -e /Dependencies/ -e gtest-all
  ```

  The first two build only the app targets, so the third compiles the gallery tests (and builds their
  host app). A fourth line does the same for the Mac gallery tests on the macOS SDK:
  `caffeinate -is buildlock --folder <dd>/build-mgt -- xcodebuild -target BChessMacGalleryTests -configuration Debug SYMROOT=<dd>/build-mgt OBJROOT=<dd>/obj-mgt COMPILER_INDEX_STORE_ENABLE=NO build 2>&1 | grep …`
  (the same filter).
- **Running-app check** (the Mac line's `BChessMacGalleryTests` and `scripts/snapshot-mac.sh` run inside
  the real Mac app): `pgrep -f 'BChess.app/Contents/MacOS/BChess'` must print nothing.
- **Gallery gate** (`/preview-gallery`): every screen has a scenario in
  `BChessGalleryTests/GalleryScenarios.swift` (`AGENTS.md`), rendered by `scripts/snapshot-gallery.sh`.
  A step gate never renders it (a step that adds or changes scenarios only checks that they compile);
  when the look changes, the landing gate renders the scenarios concerned
  (`scripts/snapshot-gallery.sh --only <scenarios>`, or in full) and shows them to Jean before landing,
  plus `scripts/snapshot-mac.sh` when the change touched a Mac screen (green:
  `CHECK OK [en]: 6 cards, light and dark complete and correctly lit`; it leases nothing and runs the
  hosted app under the container lock), plus `--device duo` when the change touched a screen with an
  inner-display scenario (the group "iPhone Duo · inner display") or a layout that changes at regular
  width. Green is the line `CHECK OK [en]: <n> cards, light and dark complete and correctly lit`, and
  the new or changed cards read in both appearances with the Read tool, as `/preview-gallery` says.
  The script leases and locks itself and keeps the Mac awake (`caffeinate -dims -w $$`, as
  `snapshot-mac.sh` does; never wrap it in `simpool` or `buildlock`), writes under `previews/`
  (gitignored) and uses its own DerivedData (`BCHESS_SNAPSHOT_DD`, default
  `~/Library/Developer/Xcode/DerivedData/BChess-snapshots`). The full gallery (iPhone, `--device duo`
  and `snapshot-mac.sh`) runs only in `/testflight`.
- **String Catalog:** `Shared/Localizable.xcstrings` (one catalog for both apps), synced with
  `catalog-sync` (the commands in `AGENTS.md` § Languages): the translations go in every language of the
  catalog, and `catalog-sync --check --skip-build` must print "catalog unchanged".
  `LocalizationCatalogTests` goes red on a missing translation. A screen's translations are read with
  `scripts/snapshot-gallery.sh --only "<slugs>" --lang fr,de,it` (and `scripts/snapshot-mac.sh --lang …`;
  the review set is in `/preview-gallery`): a language run has no page and no check, and never a full
  gallery.
- **Right to left:** the catalog carries Hebrew and Arabic, so a change to the board, the notation, a
  number shown to the user or anything that mirrors runs through `AGENTS.md` § Languages, "Right to
  left" (Western digits for notation, the minus sign and the notation isolates, what never mirrors):
  the screens it touches are rendered with `scripts/snapshot-gallery.sh --only "<slugs>" --lang he,ar`
  (and `scripts/snapshot-mac.sh --lang he,ar` for a Mac screen), the board region compared with the
  English capture, and `LocaleIndependenceTests`/`MacMenuTests` run with
  `TEST_RUNNER_BCHESS_EXPECT_LANGUAGE`/`_REGION` set (the commands are in `/preview-gallery`).
