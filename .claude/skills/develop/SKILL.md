---
name: develop
description: The standard way a feature or fix is built in BChess — plan it in a worktree with a planning subagent, one Codex review of the plan, get Jean's go, implement in a Sonnet subagent, one Codex review of the code, and hand back a green branch. Use for any change that touches the engine, the bridge, the game model or app logic — "add X", "fix Y", "implement planning/Z.md" — unless the user says to skip the process. Not for docs-only edits or UI-only view tweaks.
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
2. **Execute in a subagent** launched with `model: "sonnet"`, so file reads, build logs and test
   output never land in the main context. Then one Codex review of the result. The implementer does
   not review its own work. Fix what the reviewer finds.
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
and the unit tests; add the UI tests only when the step touches what they drive (navigation, titles,
accessibility identifiers, launch fixtures), and the preview gallery only when the step changes what a
screen looks like. The **final gate** runs before handing back and again after the rebase when
landing: every gate below in full, plus the full gallery when the plan touched UI. Step gates never
replace it.

- **Build folders.** Step gates reuse ONE build folder for the whole plan (`<dd>`, e.g.
  `/private/tmp/<id-slug>-dd`, created once), so every build after the first is incremental. The final
  gate uses a fresh `<dd>`, which also re-surfaces warnings an incremental build would not recompile.
  Logs go to a new scratch directory for every gate run.
- **One build at a time.** Use the repo's build-lock wrapper when it has one (never call `xcodebuild`
  around it); never start a build while another runs — wait for it.
- **Simulators** (the global working agreement): one booted at a time — check
  `xcrun simctl list devices booted` first and never touch one you did not boot; one `-destination` per
  run and `-parallel-testing-enabled NO` on every simulator test run. Keep the plan's one test simulator
  booted from the first gate to the final gate (a boot is expensive), then shut it down — also when a
  gate fails and you stop. Prefer a simulator the repo owns over Jean's own.
- **Reading results.** Read the **exit status** and the summary line of every command; an empty grep
  is clean only if the command succeeded. The number of tests run is part of the result: zero is red,
  and a count that shrinks needs an explanation (a conditionally disabled test counts as skipped).
- A regression test is proven red without its fix before it goes green. No version bump during
  feature work.
- **Docs-only changes** (no code) skip the build gates: `git diff --check`, every link and citation
  still resolves, and the working agreement, plans index and README stay consistent.

**Tests first:** a failing Swift Testing test before the change; a regression test proven red
without its fix, restored with `git checkout -- <file>`. `xcodegen generate` committed with any
`project.yml` change; never hand-edit `BChess.xcodeproj`.

**Test gate:** all of these pass, each read by exit status **and** summary line. The iOS tests run
on the repo's own `BChess Agent` simulator (create it once with
`xcrun simctl create "BChess Agent" "iPhone 17 Pro"`); shut it down after the final gate.

```
xcodebuild test -scheme "BChess (macOS)" -destination 'platform=macOS' -derivedDataPath <dd>/dd-mac
xcodebuild test -scheme "BChess (iOS)" -destination 'platform=iOS Simulator,name=BChess Agent' -parallel-testing-enabled NO -derivedDataPath <dd>/dd-ios
xcodebuild -scheme BChessUCI -destination 'platform=macOS' -derivedDataPath <dd>/dd-uci build
```

`** TEST FAILED **`, `** BUILD FAILED **`, a Swift Testing line `✘`, or any `error:` is red. The
engine GoogleTest cases must show up as individual Swift Testing cases and must all have run (the
count is printed by the suite) — zero executed is red, never green.

**Warnings gate:** zero compiler warnings in our own sources (`Shared/`, `iOS/`, `macOS/`, `BChess/`,
`BChessTests/`, `BChessAppTests/`, `BChessUITests/`, `BChessGalleryTests/`; vendored `Dependencies/`
and `gtest-all.cc` are exempt). `COMPILER_INDEX_STORE_ENABLE=NO` is required on `-target` builds.

```
xcodebuild -target "BChess (iOS)" -sdk iphonesimulator -configuration Debug SYMROOT=<dd>/build-ios OBJROOT=<dd>/obj-ios COMPILER_INDEX_STORE_ENABLE=NO build 2>&1 | grep -E '^/Users/.*(warning|error):|^(warning|error):' | grep -v -e ONLY_ACTIVE_ARCH -e /Dependencies/ -e gtest-all
xcodebuild -target "BChess (macOS)" -configuration Debug SYMROOT=<dd>/build-mac OBJROOT=<dd>/obj-mac COMPILER_INDEX_STORE_ENABLE=NO build 2>&1 | grep -E '^/Users/.*(warning|error):|^(warning|error):' | grep -v -e ONLY_ACTIVE_ARCH -e /Dependencies/ -e gtest-all
xcodebuild -target BChessGalleryTests -sdk iphonesimulator -configuration Debug SYMROOT=<dd>/build-gt OBJROOT=<dd>/obj-gt COMPILER_INDEX_STORE_ENABLE=NO build 2>&1 | grep -E '^/Users/.*(warning|error):|^(warning|error):' | grep -v -e ONLY_ACTIVE_ARCH -e /Dependencies/ -e gtest-all
```

The first two build only the app targets, so the third compiles the gallery tests (and builds their host app).

## Deploy (only when Jean asks)

Nothing ships from a `/develop` run. Signing, notarization and distribution follow Jean's Mac
release playbook, only when Jean asks.

## Phase 0 — Worktree (before anything is written)

Unless `--no-worktree`, or the change touches only the docs-only paths in Context: `git fetch`, then
create `.claude/worktrees/<id-slug>` on a new branch `<id-slug>` from `main` (`EnterWorktree` when
available, else `git worktree add`). Everything below — the plan, the code, the subagent, the
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
**alternatives rejected and why**, **test plan** (the failing tests, named, and what each proves),
**invariants** (each one: holds / at risk and how it is held / not applicable), **risks and
rollout** (the plan risks in Context), **decision left open for Jean**. Large work is split into
numbered steps, one commit each. Add its row to the plans index.

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
> SHOULD-FIX (a real gap in the design or the test plan), SIMPLER (a smaller design that meets the
> same goal), ALREADY-EXISTS (code the plan reimplements — file and symbol). Say "none" for an empty
> section. End with one line `substantive: yes|no`. Do not praise the plan.

**Catching a review that did not run.** A review exists only when its result file holds the four
sections and the closing `substantive:` line. Nothing else counts. Every Codex round, both phases:

1. **Liveness at 2 minutes.** `<round>.log` must be growing or `~/.codex/sessions/` must show a new
   session. If neither, `ps` for a `codex` process; if none, start it again (once). A non-zero exit,
   or a result file that is empty or lacks the sections, is the same failure.
2. **Progress every 10 minutes**, never sleep-and-hope. A log untouched for 15 minutes with the
   process alive is a stall: kill it and restart the round.
3. **The `codex:codex-rescue` wrapper is the fallback, not the default** — it can fork a job with an
   empty prompt and wait forever. If used, its only evidence is the job log under
   `~/.claude/plugins/data/codex-openai-codex/state/<repo-or-worktree>-*/jobs/`.
4. **Never report a round that did not run as a round.** If Codex is down after one restart, run
   the same prompt through the substitute reviewer (Codex policy), label it "substitute review",
   and continue.
5. **Long results get truncated in delivery**: read the result FILE, never the message.

Fold each finding in: **accept** (edit the plan, bump "revision N" in its header with a one-line
changelog) or **reject** (write the rationale into the plan, so the next round does not re-raise it).
Then apply the Codex policy. When it says stop, present Jean with the plan, the revision history and
the rejected findings, and get a **go / adjust / stop** decision (`AskUserQuestion`). `--plan-only`
ends here.

## Phase 4 — A Sonnet implementation subagent

The main context stays clean: it reads plan text, subagent reports and `git diff --stat`, never build
logs or the diff body. Spawn once and keep the agent alive for the fix rounds; the parent never
implements.

```
Agent(model: "sonnet", name: "<id-slug>-impl", prompt: …)
```

The prompt carries: the **absolute worktree path** (every command runs there — state it twice), the
plan path ("implement this plan; where it is silent, choose the smallest correct option and list it
as a deviation"), and "follow the working agreement; run the gates in
`.claude/skills/develop/SKILL.md`". Do not paste the gates. One commit per plan step with the
session's attribution trailer. Its report must list: what was built (commit list), every deviation
from the plan and why, the test summary lines verbatim, the warnings check and its result, and
anything left unfinished. Treat "done" claims as claims: check `git log main..HEAD --oneline` and the
test summary yourself before phase 5.

## Phase 5 — Codex reviews the implementation (one round by default)

Same prompt shape as phase 3, against `git diff main...HEAD` **and the plan** — does the code do
what the plan says, do the tests prove what they claim (would each fail without its change?), which
invariant is most at risk, what is more complex than its job requires, what is duplicated. Do not
attach the whole design doc. Same `codex exec` command and the same "did it run" protocol.

Send each accepted finding to the **same** subagent with `SendMessage`. Rejected findings get a
one-line rationale in the final report, not silence. Re-run the gates after every fix round. Apply
the Codex policy.

## Phase 6 — Hand back (landing is Jean's call)

The deliverable is a green, reviewed branch in the worktree — the final gate (fresh `<dd>`) run
last — plus a report: what shipped (commits),
plan revisions and review rounds with what each changed, findings rejected and why, gates run (the
test summary lines, the warnings check), and what is owed (the owed checks in Context). **When Jean
says land, the feature lands as ONE squashed commit:**

1. `git fetch && git rebase main` in the worktree, then the final gate (fresh `<dd>`) after the rebase.
2. On `main`: `git merge --squash <branch>` then ONE `git commit` whose subject is the plan id and a
   sentence and whose body carries the branch's commit subjects (`git log main..<branch>
   --format='- %s'`), each regression test's red proof in one line, every gate's summary line, the
   plan revisions and review rounds, and the attribution trailer.
3. The test gate once more on `main`, then `git push origin main`.
4. Remove the worktree and `git branch -D` the branch. Update the plan's index row to
   "Implemented on main <date>".

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
- Spawning a fresh implementer for each fix round instead of messaging the one that built it.
- Restating the working agreement in the implementer prompt.
- Bumping the version or landing without being asked.
- Counting a test run where the GoogleTest suite executed zero cases as green.
