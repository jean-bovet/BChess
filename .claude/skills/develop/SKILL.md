---
name: develop
description: The standard way a feature or fix is built in BChess — plan it in a worktree with a planning subagent, one Codex review of the plan (the plan goes ahead on its own when the review found no blocker and nothing is left open for Jean), implement in Sonnet subagents, one Codex review of the code, and hand back a green, pushed branch. Use for any change that touches the engine, the bridge, the game model or app logic — "add X", "fix Y", "implement planning/Z.md" — unless the user says to skip the process. Not for docs-only edits or UI-only view tweaks.
argument-hint: <what to build, or planning/<ID>.md> [--no-worktree] [--plan-only] [--execute]
allowed-tools: Read, Glob, Grep, Bash, Agent, SendMessage, AskUserQuestion, EnterWorktree, ExitWorktree
---

# /develop — plan → Codex → implement → Codex → green branch

Jean's three standing requirements:

1. **Plan first**, reviewed by Codex. The plan is written by a `general-purpose` subagent with
   `model` omitted, so it inherits the session's default model and its reading never lands in the
   parent. Aim at simplicity and correctness, not over-engineering. Check whether other parts of
   the code already implement part of the solution. Ask Jean when unsure. Default is **one** review
   round.
2. **Execute in a subagent** launched with `model: "sonnet"`, one per plan step, so file reads,
   build logs and test output never land in the main context and no implementer grows past a step's
   worth of context. Then one Codex review of the result. The implementer does not review its own
   work. Fix what the reviewer finds.
3. **Always work in a worktree** unless told otherwise.

Flags: `--no-worktree` (only when Jean said so), `--plan-only` (stop after phase 3),
`--execute` (the argument is an already-accepted plan file; start at phase 4).

## Context

- **Working agreement:** `AGENTS.md` (invariants, stack, tests, conventions, done-when).
- **Invariants:** `AGENTS.md`, I1–I5.
- **Design doc:** none beyond `AGENTS.md`; read only the code the change touches.
- **Plans:** `planning/<AREA>-<n>-<slug>.md`; index `planning/README.md`.
- **Code to search for reuse:** `Shared/`, `iOS/`, `macOS/`, `BChess/` and the test folders.
- **Docs-only paths:** `planning/`, `AGENTS.md`, a skill.
- **String Catalog:** a change to user-facing strings syncs `Shared/Localizable.xcstrings` (one catalog for both apps)
  headless with `catalog-sync` (the commands in `AGENTS.md` § Languages) instead of an Xcode GUI build: `--delete-stale`,
  then the translations in every language of the catalog (the Xcode MCP `StringCatalogEdit`, with the worktree's project
  open in Xcode, not the main checkout's), then `catalog-sync --skip-build` once (it re-sorts the keys the editor wrote),
  and `--check --skip-build` must print "catalog unchanged"; commit the catalog with the step.
  `LocalizationCatalogTests` goes red on a missing translation. A screen's translations are read with
  `scripts/snapshot-gallery.sh --only "<slugs>" --lang fr,de,it` (and `scripts/snapshot-mac.sh --lang …`; the review set is in
  `/preview-gallery`): a language run has no page and no check, and never a full gallery.
- **Plan risks to cover:** file-format compatibility, what needs a real device.
- **Owed checks:** a run on a real device, a visual check.

Do not paste the working agreement into prompts — point at the file. This skill holds the recipe.

## Codex policy

**Skip Codex** for work that is not `/develop` work:

UI-only view tweaks and docs-only edits.

**The reviewer is always a different vendor from the planner and implementer**: Codex
(`codex exec`, below).

**When Codex is unavailable** (usage limit, missing CLI, failed after one restart): do not skip the
review and do not wait for Jean. Spawn a fresh read-only subagent with `model: "opus"` that saw
neither the plan draft nor the diff being written, and give it the same prompt. Never resume the
planner or the implementer for a review, and never review in the parent. Report it as
"substitute review (Codex unavailable: <reason>)".

**Default: one Codex round per phase** (plan, then implementation). A second round runs only when
the first found a substantive issue — behaviour, correctness, an invariant, a test that would have
missed a real bug, a simpler design that meets the same goal, or:

file-format compatibility, a thread-safety hole.

A third round only if a blocker is still open. Hard cap of **three rounds per phase**. A substitute
review counts as a round. Always report how many rounds ran, who ran each, and what each changed. A
round that finds nothing is a good result, not a reason to run another.

Stop when a round yields only nits, style, restatements of points already decided with a written
rationale, or nothing.

## Gates (run in the worktree)

Two tiers. **Step gates** run after each plan step and each fix round: the build, the warnings check
and the unit tests, plus the preview gallery only when the step changes what a screen looks like — and
then only the scenarios that step changed (`--only`); the final gate renders every scenario.
Step gates never run the UI tests, not even for a step that touches what they drive (navigation,
titles, accessibility identifiers, launch fixtures): they are slow, and the final gate catches what
they would. A brief that asks a step gate or a fix round for them is overruled: they wait for the
final gate. The **final gate** runs **once per plan**, on the tree handed back: every gate
below in full, the UI tests included, plus the full gallery when the plan touched UI. Step gates never replace it. After it
passed on a commit G, every later tree (a fix round, the rebase, the squash commit) is classified
by what changed since G and reruns only what its class requires, not the final gate again:

| Class | When (tracked paths changed since G) | What reruns |
|---|---|---|
| `none` | the same tree (a no-op rebase, the squash commit), or only docs-only paths (`planning/`, `AGENTS.md`, `README.md`, `docs/`, `.claude/skills/`) | no build or test; for a docs edit, the docs-only checks below |
| `quick` | only docs-only paths and `BChessTests/` | the step gate, plus the warnings check on its logs |
| `full` | any other path (`project.yml`, `BChessUITests/`, `BChessGalleryTests/` included) | the whole final gate on a fresh `<dd>`; that tree becomes the new G |

When in doubt, the class is `full`. BChess has no classifying script: the parent reads
`git diff --name-only G` and applies the table by hand, after committing (never classify a tree with
uncommitted tracked changes or untracked files that are not ignored).

- **Build folders.** Step gates reuse ONE build folder for the whole plan (`<dd>`, e.g.
  `/private/tmp/<id-slug>-dd`, created once), so every build after the first is incremental. The final
  gate uses a fresh `<dd>`, which also re-surfaces warnings an incremental build would not recompile.
  Logs go to a new scratch directory for every gate run.
- **Build once, test without building.** Where the platform allows it, a gate builds the tests once
  for a generic destination (`xcodebuild build-for-testing`) and runs them with `test-without-building`
  on the leased simulator: a `build` followed by a `test` compiles twice (two destinations), and the
  lease is held only while tests run. Any later run on the same tree (another test plan, a rerun)
  reuses those products. An app-hosted test target (a test bundle that runs inside the app, on the Mac
  too) follows the same rule: `build-for-testing` once per step, every rerun and red proof through
  `test-without-building -only-testing:<Target>/<Class>`; a plain `xcodebuild test` re-links, re-signs
  and relaunches the host app for every single run.
- **One build at a time per build folder.** Use the repo's scripts or build wrapper when it has them
  (never call `xcodebuild` around them); otherwise `buildlock --folder <dd> -- xcodebuild …`. The host's
  build slots are shared with other sessions: wait for one, never kill another build.
- **Simulators** (the global working agreement): lease one from the machine-wide pool for each gate run
  (`simpool acquire`, or the repo's scripts do it) and release it when the run ends, also when it fails.
  Don't hold a lease across gates: the pool normally keeps a released simulator booted for the next gate. Never
  boot, shut down or touch a simulator by hand. One `-destination` per run and
  `-parallel-testing-enabled NO -collect-test-diagnostics never` on every simulator test run (without the second flag a failing test, so every red proof, makes xcodebuild collect a sysdiagnose-like simulator report for up to 10 minutes; the gates read the log, never that report. To debug a failure nobody can explain, rerun that one test without it). A repo whose scripts still boot their own
  simulator follows the global agreement's rule for those.
- **Keep the Mac awake.** A gate script that runs simulators or long builds re-executes itself once under
  `caffeinate -is` (a guard variable such as `<REPO>_CAFFEINATED` so it happens once; `"$@"` and the exit status
  kept; no re-exec, one notice line, when `caffeinate` is missing). Where the gate is a list of commands rather
  than a script, each long command runs as `caffeinate -is <command>` (`caffeinate -is buildlock --folder <dd> --
  xcodebuild test …`). xcodebuild's own "running tests" assertion is
  only `PreventUserIdleSystemSleep`, which lets a Mac in Maintenance Sleep / DarkWake drop off mid-run: a night gate
  then stalls for minutes at a time inside XCTest steps and fails with "Timed out while synthesizing event"
  (measured 2026-10-30: 2 h 45 min instead of 42 min, every gap matching `pmset -g log`). A gate script that
  re-executes itself has script tests for the re-exec, argument boundaries, the missing tool and signals.
- **Wait in slices.** A subagent's prompt cache lives five minutes (the parent's, one hour). Inside a
  subagent, no blocking call runs longer than four minutes: a build, a test run, the gallery or a Codex
  round starts in the background with its output in a log, and the agent checks that log every four
  minutes at most (a `Monitor` until-loop with that timeout, or a background command looked at on that
  cadence), reading the summary lines only. One wait that outlives the cache re-writes the agent's whole
  context at cache-write price; measured over five days, such re-writes were two thirds of everything
  subagents wrote to the cache (the token-usage notes of 2026-10-28, next to the tools the global working
  agreement names).
- **Reading results.** Read the **exit status** and the summary line of every command; an empty grep
  is clean only if the command succeeded. The number of tests run is part of the result: zero is red,
  and a count that shrinks needs an explanation (a conditionally disabled test counts as skipped).
- **Red proof.** A regression test is proven red without its fix before it goes green: commit the
  fix first, revert only the fix's lines, run the test and see it fail, restore with
  `git checkout -- <file>` (never a hand-written inverse), then confirm `git status` is clean and grep
  the tree for any temporary marker. A red-proof run builds incrementally in the step gates' `<dd>`
  (`build-for-testing`) and runs only the test class concerned (`xcodebuild test-without-building
  -only-testing:<Target>/<Class>`, e.g. `-only-testing:BChessMacGalleryTests/<Class>` on the Mac line), never the whole
  suite: the step and final gates run the rest. No version bump during feature work.
- **Warnings.** Fix every warning the branch touches or reveals, including ones that predate it.
  Deprecations are fixed, never silenced (`@available`, `#warning`, suppression flags); if the fix
  conflicts with a documented decision, update that decision's comment. A build-only warnings check uses
  `xcodebuild -target <target>` with its own `SYMROOT` — never a scheme, so the shared build (or a running
  app the scheme drives) stays untouched — and `COMPILER_INDEX_STORE_ENABLE=NO` on the command line:
  without a derived-data path Xcode emits an empty `-index-store-path` and clang's hardening flag turns
  into a bare warning. Keep that flag off the project files, so Xcode still indexes.
  The warnings check compiles **every platform target that compiles the changed sources**, not only the
  target whose folder changed: a shared package or framework change also builds the iOS (or other) target,
  because a platform-conditional member called outside its `#if` passes every Mac gate and fails only the CI
  archive of the other platform.
- **Docs-only changes** (no code) skip the build gates: `git diff --check`, every link and citation
  still resolves, and the working agreement, plans index and README stay consistent.

**Tests first:** a failing Swift Testing test before the change; a regression test proven red
without its fix, restored with `git checkout -- <file>`. Fixtures: the gallery's PGNs are `Fixture`
constants in `BChessGalleryTests/GalleryScenarios.swift`; engine tests (GoogleTest cases plus Swift
tests) live in `BChessTests/`. `xcodegen generate` committed with any `project.yml` change; never
hand-edit `BChess.xcodeproj`.

**Test gate:** all of these pass, each read by exit status **and** summary line. Each runs under
`caffeinate -is` (the Mac stays awake) and `buildlock` on its own DerivedData folder. The Mac test line (the second) also holds the hosted app's container lock (the outer `buildlock`, no slot): the scheme's `BChessMacGalleryTests` run inside the real Mac app, on its sandbox container, so two worktrees never run the host at once; it opens the app's untitled game window for the seconds the tests take. The Mac scheme builds its tests once (`build-for-testing`), then runs them with `test-without-building`
(no build slot: it compiles nothing), so a rerun never re-links, re-signs and relaunches the host for nothing. The step gate runs the first three lines (the unit tests in
`BChessTests` with the hosted `BChessMacGalleryTests`, and the UCI build). The final gate adds the last three: the iOS scheme's tests are the UI
tests (`BChessUITests`) and the gallery tests, built once for the generic simulator, then run on a
simulator leased from the pool for that run and given back right after it, also when it fails (run the
last three lines in one shell):

```
caffeinate -is buildlock --folder <dd>/dd-mac -- xcodebuild build-for-testing -scheme "BChess (macOS)" -destination 'platform=macOS' -derivedDataPath <dd>/dd-mac
caffeinate -is buildlock --folder ~/Library/Containers/ch.arizona-software.BChess --no-slot -- buildlock --folder <dd>/dd-mac --no-slot -- xcodebuild test-without-building -scheme "BChess (macOS)" -destination 'platform=macOS' -derivedDataPath <dd>/dd-mac
caffeinate -is buildlock --folder <dd>/dd-uci -- xcodebuild -scheme BChessUCI -destination 'platform=macOS' -derivedDataPath <dd>/dd-uci build
caffeinate -is buildlock --folder <dd>/dd-ios -- xcodebuild build-for-testing -scheme "BChess (iOS)" -destination 'generic/platform=iOS Simulator' -derivedDataPath <dd>/dd-ios
udid=$(simpool acquire --spec iphone --pid $$); trap 'simpool release "$udid" --app ch.arizona-software.BChess' EXIT
caffeinate -is buildlock --folder <dd>/dd-ios -- xcodebuild test-without-building -scheme "BChess (iOS)" -destination "id=$udid" -parallel-testing-enabled NO -collect-test-diagnostics never -derivedDataPath <dd>/dd-ios
```

`** TEST FAILED **`, `** BUILD FAILED **`, a Swift Testing line `✘`, or any `error:` is red. The
engine GoogleTest cases must show up as individual Swift Testing cases and must all have run (the
count is printed by the suite) — zero executed is red, never green.

**Warnings gate:** zero compiler warnings in our own sources (`Shared/`, `iOS/`, `macOS/`, `BChess/`,
`BChessTests/`, `BChessAppTests/`, `BChessUITests/`, `BChessGalleryTests/`, `BChessMacGalleryTests/`; vendored `Dependencies/`
and `gtest-all.cc` are exempt).

```
caffeinate -is buildlock --folder <dd>/build-ios -- xcodebuild -target "BChess (iOS)" -sdk iphonesimulator -configuration Debug SYMROOT=<dd>/build-ios OBJROOT=<dd>/obj-ios COMPILER_INDEX_STORE_ENABLE=NO build 2>&1 | grep -E '^/.*(warning|error):|^(warning|error):' | grep -v -e ONLY_ACTIVE_ARCH -e /Dependencies/ -e gtest-all
caffeinate -is buildlock --folder <dd>/build-mac -- xcodebuild -target "BChess (macOS)" -configuration Debug SYMROOT=<dd>/build-mac OBJROOT=<dd>/obj-mac COMPILER_INDEX_STORE_ENABLE=NO build 2>&1 | grep -E '^/.*(warning|error):|^(warning|error):' | grep -v -e ONLY_ACTIVE_ARCH -e /Dependencies/ -e gtest-all
caffeinate -is buildlock --folder <dd>/build-gt -- xcodebuild -target BChessGalleryTests -sdk iphonesimulator -configuration Debug SYMROOT=<dd>/build-gt OBJROOT=<dd>/obj-gt COMPILER_INDEX_STORE_ENABLE=NO build 2>&1 | grep -E '^/.*(warning|error):|^(warning|error):' | grep -v -e ONLY_ACTIVE_ARCH -e /Dependencies/ -e gtest-all
```

The first two build only the app targets, so the third compiles the gallery tests (and builds their host app). A fourth line does the
same for the Mac gallery tests on the macOS SDK: `caffeinate -is buildlock --folder <dd>/build-mgt -- xcodebuild -target BChessMacGalleryTests -configuration Debug
SYMROOT=<dd>/build-mgt OBJROOT=<dd>/obj-mgt COMPILER_INDEX_STORE_ENABLE=NO build 2>&1 | grep …` (the same filter).

**Gallery gate** (`/preview-gallery`): every screen has a scenario in `BChessGalleryTests/GalleryScenarios.swift`
(`AGENTS.md`), rendered by `scripts/snapshot-gallery.sh`. A step gate that changes what a screen looks like runs
`scripts/snapshot-gallery.sh --no-open --only "<the screens it touched>"`; the final gate of a plan that touched
UI runs the full gallery, `scripts/snapshot-gallery.sh --no-open`, plus `scripts/snapshot-mac.sh --no-open` when the plan touched a Mac screen (green: `CHECK OK [en]: 6 cards, light and dark complete and correctly lit`;
it leases nothing and runs the hosted app under the container lock), plus `--device duo` when the plan touched a
screen with an inner-display scenario (the group "iPhone Duo · inner display") or a layout that changes at
regular width. Green is the line `CHECK OK [en]: <n> cards, light and dark complete and correctly lit`, and the
new or changed cards read in both appearances with the Read tool, as `/preview-gallery` says. The script leases
and locks itself and keeps the Mac awake (`caffeinate -dims -w $$`, as `snapshot-mac.sh` does; never wrap it in
`simpool` or `buildlock`), writes under `previews/` (gitignored) and uses its
own DerivedData (`BCHESS_SNAPSHOT_DD`, default `~/Library/Developer/Xcode/DerivedData/BChess-snapshots`).

## Deploy (only when Jean asks)

Nothing ships from a `/develop` run, and nothing is archived, signed or uploaded from this Mac. Both apps
(`BChess (iOS)` and `BChess (macOS)`, one App Store record) reach devices through Xcode Cloud (product
`BChess (iOS)`): `/testflight` fast-forwards the `testflight` branch to `main` plus the What to Test commit
(through a pull request, since `main` is PR-only) and Xcode Cloud archives both apps for the internal
testers; `/release` publishes the tested candidate to the App Store, one version per platform. Both only
when Jean asks. Never by accident: a hand push of `testflight` (only `/testflight` moves it), a push to
`main`, a version bump (`MARKETING_VERSION` in `project.yml` is `/testflight`'s; `CURRENT_PROJECT_VERSION`
is never bumped, Xcode Cloud numbers the builds), or a `v<version>` tag (`/release` makes it).

## Phase 0 — Worktree (before anything is written)

Unless `--no-worktree`, or the change touches only the docs-only paths in Context: `git fetch`, then
create `.claude/worktrees/<id-slug>` on a new branch `<id-slug>` from `main` (`EnterWorktree` when
available, else `git worktree add`). If the session already runs in an Orca worktree (under
`~/orca/workspaces/`), use it and its branch instead of creating one. Everything below — the plan, the code, the subagent, the
reviews — happens in that path. Leave unrelated changes in the main checkout alone. The worktree
guard refuses compound Bash commands (variables, `$(…)`, heredocs): write scripts to the scratchpad
and run them.

## Phase 1 — Understand and reuse (before writing a line of plan)

Run phases 1–2 inside a `general-purpose` subagent with `model` omitted; never plan inline in the
parent, so the code and documents it reads are discarded with it. The parent only relays Jean's
request, findings Jean has already seen, and the worktree path, then reads the finished plan back.

- Read the invariants and **only** the parts of the design doc the change touches. Check the plans
  index for an overlapping proposal — never re-propose a rejected design without saying what is
  different.
- Spawn **one `Explore` agent** with the question "what in the code to search (see Context) already
  implements part of this?" — existing types, helpers, seams, tests, and the conventions they
  follow. (On an empty tree, say so and skip.) The plan must cite what it reuses by file and symbol;
  a plan that introduces a second way to do something the code already does is wrong.
- Collect every genuine uncertainty — anything where two readings of the request lead to materially
  different designs — and ask Jean in **one** `AskUserQuestion` (up to four questions). Do not ask
  what the working agreement, the design doc or the code answers; do not dribble questions one at a
  time.

## Phase 2 — Write the plan

One plan file (pattern and index in Context), in this shape: **problem with evidence** (design-doc
section, file:line), **design** (the smallest change that is correct, with what it reuses),
**alternatives rejected and why**, **test plan** (the failing tests, named, and what each proves; for every new entity or field,
the line that writes it, the screen line that shows it, and the test or gallery scenario that covers the
path between them through the production reader — not a parallel test-only path; fixtures carry
real data shapes — tombstones, empty and removed entries, multi-item records; when a data source is
replaced, the plan diffs its contents, not just its reader),
**invariants** (each one: holds / at risk and how it is held / not applicable), **risks and
rollout** (the plan risks in Context), **decision left open for Jean**. Large work is split into
numbered steps, one commit each, listed under a `## Steps` heading as `1. **<title>** — <what>`
(the status line counts those lines to show plan progress). Add its row to the plans index.

The simplicity bar: every new abstraction names its second caller or does not exist; no config knob
nobody will set; no layer that only forwards; extend existing code before adding beside it; no
speculative generality. If the honest plan is "twenty lines in one file plus two tests", write that.

## Phase 3 — Codex reviews the plan (one round by default)

Give the reviewer the plan and the invariants, not your agent's notes and not the whole design doc.
Write the prompt to a scratchpad file and start, in the background, from the worktree:

```sh
codex exec --sandbox read-only -C <worktree> -o <scratch>/<round>-result.md - < <scratch>/<round>-prompt.md > <scratch>/<round>.log 2>&1
```

The prompt comes from stdin (`-`); a background `codex exec` with an open terminal stdin blocks
forever on "Reading additional input from stdin...". Read-only always; never `--write`:

> Review `<plan file>` against the code in this worktree and the invariants (`<invariants file>`).
> Return, in order: BLOCKERS (the plan is wrong or breaks an invariant — name the input or state),
> SHOULD-FIX (a real gap in the design or the test plan — including any new entity or field
> without a traced path from the line that writes it to the screen that shows it, covered by a
> test or gallery scenario that uses the production read path), SIMPLER (a smaller design that meets the
> same goal), ALREADY-EXISTS (code the plan reimplements — file and symbol). Say "none" for an empty
> section. End with one line `substantive: yes|no`. Do not praise the plan.

**Catching a review that did not run.** A review exists only when its result file holds the four
sections and the closing `substantive:` line. Nothing else counts. Every Codex round, both phases:

1. **Liveness at 2 minutes.** `<round>.log` must be growing or `~/.codex/sessions/` must show a new
   session. If neither, `ps` for a `codex` process; if none, start it again (once). A non-zero exit,
   or a result file that is empty or lacks the sections, is the same failure.
2. **Progress every 10 minutes**, never sleep-and-hope. A log untouched for 15 minutes with the
   process alive is a stall: kill it (and a stalled broker, whose pid is in the plugin state's
   `broker.json`) and restart the round.
3. **The `codex:codex-rescue` wrapper is the fallback, not the default** — it can fork a job with an
   empty prompt and wait forever. If used, its only evidence is the job log under
   `~/.claude/plugins/data/codex-openai-codex/state/<repo-or-worktree>-*/jobs/` — check every state
   dir, a worktree gets its own. No job log within 2 minutes means it forked with an empty prompt:
   run `codex exec` directly.
4. **Never report a round that did not run as a round.** If Codex is down after one restart, run
   the same prompt through the substitute reviewer (Codex policy), label it "substitute review",
   and continue.
5. **Long results get truncated in delivery**: read the result FILE, never the message; if only a
   message exists, ask for the remainder from the last line you saw.

Fold each finding in: **accept** (edit the plan in place — the lines the finding changes, never a
rewrite of the file: a rewritten plan costs its whole length in output tokens every round — and bump
"revision N" in its header with a one-line changelog) or **reject** (write the rationale into the
plan, so the next round does not re-raise it).
Then apply the Codex policy. When it says stop, the plan **goes ahead on its own** when all three
hold: the last round found no blocker, the plan's "decision left open for Jean" is empty, and it
touches none of the plan risks in Context. Say so in one line (plan path, revision, rounds run) and
start phase 4. Otherwise present Jean with the plan, the revision history and the rejected findings,
and get a **go / adjust / stop** decision (`AskUserQuestion`). `--plan-only` ends here either way.

## Phase 4 — A Sonnet implementation subagent

The main context stays clean: it reads plan text, subagent reports and `git diff --stat`, never build
logs or the diff body. **One implementer per plan step**: spawn it with the plan path, the step number
and `git log main..HEAD --oneline`, so its context starts from the plan and the commits, not from the
previous step's build logs; it lives for that step and the fix rounds that concern it, then the next
step gets a fresh one. A plan of one step keeps one implementer throughout. The parent never
implements. (Measured over five days: implementers that lived for a whole plan ran 400 to 640 calls at
235k tokens of context each, the largest single cost of a `/develop` run.)

Before spawning, when the repo's gates host tests inside the app (an app-hosted test target or a Mac
gallery), run the repo's running-app check. If the app is running — Jean's own Xcode debug run
included — tell Jean and wait for him to quit it; never kill it. Found at the first hosted gate instead,
it costs the implementer the wait and Jean the surprise. Here: the mac line's `BChessMacGalleryTests`
and `scripts/snapshot-mac.sh` run inside the real Mac app, so `pgrep -f 'BChess.app/Contents/MacOS/BChess'`
must print nothing.

```
Agent(model: "sonnet", name: "<id-slug>-impl-<step>", prompt: …)
```

The prompt carries: the **absolute worktree path** (every command runs there — state it twice), the
plan path ("implement this plan; where it is silent, choose the smallest correct option and list it
as a deviation"), and "follow the working agreement; run the gates in
`.claude/skills/develop/SKILL.md`". Do not paste the gates. One commit per plan step, subject `<ID> step N: <summary>`, with the
session's attribution trailer. Its report must list: what was built (commit list), every deviation
from the plan and why, the test summary lines verbatim, the warnings check and its result, and
anything left unfinished. Treat "done" claims as claims: check `git log main..HEAD --oneline` and the
test summary yourself before phase 5.

## Phase 5 — Codex reviews the implementation (one round by default)

Same prompt shape as phase 3, against `git diff main...HEAD` **and the plan** — does the code do
what the plan says, do the tests prove what they claim (would each fail without its change?), which
invariant is most at risk, what is more complex than its job requires, what is duplicated, and
whether every new entity or field reaches its screen through the production read path. Do not
attach the whole design doc. Same `codex exec` command and the same "did it run" protocol.

Send each accepted finding with `SendMessage` to the implementer of the step it concerns while that
one is alive; otherwise spawn a fresh implementer with the finding, the plan and the commit. Rejected
findings get a one-line rationale in the final report, not silence. After every fix round run the step gate plus the
class from § Gates for the changes since G. Apply the Codex policy.

## Phase 6 — Hand back (landing is Jean's call)

The deliverable is a green, reviewed branch in the worktree — the final gate (fresh `<dd>`) passed
once on the tree handed back (commit G), or the class from § Gates that the last tree requires —
plus a report: G's commit, each gate class applied, what shipped (commits),
plan revisions and review rounds with what each changed, findings rejected and why, gates run (the
test summary lines, the warnings check, and each conditional gate — which ran and which did not),
and what is owed (the owed checks in Context). Before the report, push the branch to origin
(`git push -u origin <id-slug>`, the global working agreement's branch rule; never `main`). Landing
stays Jean's call. **When Jean says land, the feature lands as ONE squashed commit through a pull request** — `main` requires pull
requests (a GitHub rule): never push `main`.

1. `git fetch && git rebase origin/main` in the worktree, then classify the tree against G (§ Gates):
   the whole final gate (fresh `<dd>`) reruns only on `full`.
2. In the worktree, `git switch -c <id-slug>-pr origin/main`, `git merge --squash <id-slug>`, then ONE
   `git commit` whose subject is the plan id and a sentence and whose body carries the branch's commit
   subjects (`git log origin/main..<id-slug> --format='- %s'`), each regression test's red proof in one
   line, every gate's summary line, the plan revisions and review rounds, the plan's index-row text, and
   the attribution trailer. The same commit sets the plan's index row to "Implemented on main <date>".
   Write the message before deleting anything.
3. On `<id-slug>-pr`, classify against G again (a squash of the same tree is `none`) and run what the
   class requires, then `git push -u origin <id-slug>-pr` and
   `gh pr create --base main` with the commit message as title and body. Jean merges the PR on GitHub;
   never merge it yourself unless Jean says so.
4. After the merge: `git pull --ff-only` in the main checkout, remove the worktree, `git worktree prune`,
   `git branch -D` both branches (`-D`, because git never sees a squashed branch as merged), and
   `git push origin --delete <id-slug>-pr` if GitHub did not delete it. In an Orca worktree, leave removing
   the worktree and its branch to Orca (still delete `<id-slug>-pr`).

## Anti-patterns

- Writing the plan before the Explore pass — the plan reinvents a helper that exists.
- Asking Jean things the working agreement or design doc answers, or asking five times instead of once.
- Letting Codex see your reasoning before it forms its own.
- Attaching the whole design doc to a review prompt — the invariants plus the section in play are enough.
- Running a second review round because the first found a typo.
- Reviewing a plan or implementation with the same agent that wrote it, or in the parent.
- Reviewing with the same vendor that planned and implemented when Codex works.
- Planning inline in the parent — the planning subagent's reads must not stay in the main context.
- Reading the implementation diff or a build log into the main context.
- Spawning a fresh implementer for a fix round of the step just built instead of messaging the one
  that built it — or keeping one implementer alive across every step of a long plan.
- A blocking wait longer than four minutes inside a subagent: its prompt cache expires at five.
- Rewriting a plan file to fold in a finding instead of editing the lines concerned.
- Restating the working agreement in the implementer prompt.
- Bumping the version or landing without being asked.
- Broad Codex prompts: they make Codex read much of the repo and run commands, and often stall past 30
  minutes. Every review prompt names the exact plan section and the few source files (with line ranges) to
  read, says "read only these; no other commands, no builds or tests", and caps each section at a few
  one-line findings with a severity. A review not back within about 15 minutes is stopped and rerun
  narrower; a large diff is reviewed per commit (`git diff <sha>^ <sha>`), not in one `main...HEAD` pass.
- Counting a test run where the GoogleTest suite executed zero cases as green.
