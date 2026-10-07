---
name: develop
description: The standard way a feature or fix is built in BChess — plan it (in a worktree) with a reasoning model, one review of the plan by a different vendor (Codex on Cursor and Claude Code, Claude on Codex/ChatGPT; a review-only fallback agent when that is unavailable), get Jean's go, implement in a cheap subagent (Composer 2.5 on Cursor, Sonnet on Claude Code, Luna on Codex/ChatGPT), one same-shape review of the code, and hand back a green branch. Use for any change that touches the engine, the bridge, the game model or app logic — "add X", "fix Y", "implement planning/Z.md" — unless the user says to skip the process. Not for docs-only edits or UI-only view tweaks.
argument-hint: <what to build, or planning/<ID>.md> [--no-worktree] [--plan-only] [--execute]
allowed-tools: Read, Glob, Grep, Bash, Agent, SendMessage, AskUserQuestion, EnterWorktree, ExitWorktree
---

# /develop — plan → Codex → implement → Codex → green branch

Adapted from the Chorelus `/develop` skill. Jean's three standing requirements:

1. **Plan first**, reviewed by Codex (on Cursor, the `review` subagent when Codex is unavailable).
   On Claude Code, the plan is written by a `general-purpose` subagent with `model` omitted, so it
   inherits the session's default model and its reading never lands in the parent. On Cursor, the
   `plan` subagent. On Codex/ChatGPT, Astra when that id exists, otherwise the host's default
   reasoning model. Aim at simplicity and correctness, not over-engineering. Check whether other
   parts of the code already implement part of the solution. Ask Jean when unsure. Default is
   **one** review round.
2. **Execute in a subagent** so file reads, build logs and test output never land in the main
   context. On Claude Code, a subagent launched with `model: "sonnet"`. On Cursor, the `implement`
   subagent (Composer 2.5). On Codex/ChatGPT, Luna when the host exposes it, otherwise the host's
   smallest coding model — never its reasoning default. Then one review of the result by a
   different vendor: Codex on Cursor and Claude Code, Claude (`claude -p`) on Codex/ChatGPT
   (fallbacks in the Codex policy). The implementer does not review its own work. Fix what the
   reviewer finds.
3. **Always work in a worktree** unless told otherwise.

Flags: `--no-worktree` (only when Jean said so), `--plan-only` (stop after phase 3),
`--execute` (the argument is an already-accepted `planning/<ID>.md`; start at phase 4).

Session rules (invariants, stack, tests, conventions, done-when) are in `AGENTS.md`. Do not paste
them into prompts — point at that file. This skill holds the recipe.

## Codex policy

**Skip Codex** for UI-only view tweaks and docs-only edits. Those are not `/develop` work.

**The reviewer is always a different vendor from the planner and implementer.** On Cursor and
Claude Code that is Codex (`codex exec`, below). On Codex/ChatGPT it is Claude: from the worktree,
run the same prompt through
`claude -p --model opus --allowedTools Read,Glob,Grep --add-dir <worktree> "$(cat <scratch>/<round>-prompt.txt)" < /dev/null > <scratch>/<round>-result.md 2> <scratch>/<round>.log`
and apply the same "did it run" protocol to its result file (four sections plus `substantive:`).
Everywhere below, "Codex" means this vendor-crossing reviewer.

**When the reviewer is unavailable** (usage limit, missing CLI, failed after one restart): do not
skip the review and do not wait for Jean. Run the same prompt through a substitute reviewer that
is used **only** for review. On Claude Code, spawn a fresh read-only subagent with
`model: "opus"` that saw neither the plan draft nor the diff being written. On Cursor, the
`review` subagent. On Codex/ChatGPT, a fresh read-only Codex subagent that saw neither. Never
resume the planner or the implementer for a review, and never review in the parent. Report it as
"substitute review (<reviewer> unavailable: <reason>)".

**Default: one Codex round per phase** (plan, then implementation). A second round runs only when
the first found a substantive issue — behaviour, correctness, an invariant, file-format
compatibility, a thread-safety hole, a test that would have missed a real bug, a simpler design
that meets the same goal. A third round only if a blocker is still open. Hard cap of **three
rounds per phase**. A substitute review counts as a round. Always report how many rounds ran, who
ran each, and what each changed. A round that finds nothing is a good result, not a reason to run
another.

Stop when a round yields only nits, style, restatements of points already decided with a written
rationale, or nothing.

## Gates (run in the worktree)

Tests first: a failing Swift Testing test before the change; a regression test proven red without
its fix, restored with `git checkout -- <file>`. `xcodegen generate` committed with any
`project.yml` change; never hand-edit `BChess.xcodeproj`. No version bump.

Green means all of these pass, each read by exit status **and** summary line:

```
xcodebuild test -scheme "BChess (macOS)" -destination 'platform=macOS' -derivedDataPath <scratch>/dd-mac
xcodebuild test -scheme "BChess (iOS)" -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -derivedDataPath <scratch>/dd-ios
xcodebuild -scheme BChessUCI -destination 'platform=macOS' -derivedDataPath <scratch>/dd-uci build
```

`** TEST FAILED **`, `** BUILD FAILED **`, a Swift Testing line `✘`, or any `error:` is red. The
engine GoogleTest cases must show up as individual Swift Testing cases and must all have run (the
count is printed by the suite) — zero executed is red, never green.

Zero compiler warnings in our own sources (`Shared/`, `iOS/`, `macOS/`, `BChess/`, `BChessTests/`,
`BChessAppTests/`, `BChessUITests/`, `BChessGalleryTests/`; vendored `Dependencies/` and `gtest-all.cc` are exempt),
checked with **fresh** scratch directories. Read exit status as well as grep (an empty grep is
clean only if the build succeeded). `COMPILER_INDEX_STORE_ENABLE=NO` is required on `-target`
builds.

```
xcodebuild -target "BChess (iOS)" -sdk iphonesimulator -configuration Debug SYMROOT=<scratch>/build-ios OBJROOT=<scratch>/obj-ios COMPILER_INDEX_STORE_ENABLE=NO build 2>&1 | grep -E '^/Users/.*(warning|error):|^(warning|error):' | grep -v -e ONLY_ACTIVE_ARCH -e /Dependencies/ -e gtest-all
xcodebuild -target "BChess (macOS)" -configuration Debug SYMROOT=<scratch>/build-mac OBJROOT=<scratch>/obj-mac COMPILER_INDEX_STORE_ENABLE=NO build 2>&1 | grep -E '^/Users/.*(warning|error):|^(warning|error):' | grep -v -e ONLY_ACTIVE_ARCH -e /Dependencies/ -e gtest-all
xcodebuild -target BChessGalleryTests -sdk iphonesimulator -configuration Debug SYMROOT=<scratch>/build-gt OBJROOT=<scratch>/obj-gt COMPILER_INDEX_STORE_ENABLE=NO build 2>&1 | grep -E '^/Users/.*(warning|error):|^(warning|error):' | grep -v -e ONLY_ACTIVE_ARCH -e /Dependencies/ -e gtest-all
```

The first two build only the app targets, so the third compiles the gallery tests (and builds their host app).

## Deploy (only when Jean asks)

Nothing ships from a `/develop` run. Signing, notarization and distribution follow the
ArizonaSoftware release playbook (`~/GitHub/ArizonaSoftware/INSTRUCTIONS.md`) when Jean asks.

## Phase 0 — Worktree (before anything is written)

Unless `--no-worktree`, or the change is docs-only (`planning/`, `AGENTS.md`, a skill): `git fetch`,
then create `.claude/worktrees/<id-slug>` on a new branch `<id-slug>` from `main`
(`EnterWorktree` when available, else `git worktree add`). Everything below — the plan, the code,
the subagent, the reviews — happens in that path.

## Phase 1 — Understand and reuse (before writing a line of plan)

On Claude Code, run phases 1–2 inside a `general-purpose` subagent with `model` omitted (it
inherits the default model); never plan inline in the parent, so the code it reads is discarded
with it. On every host the parent only relays Jean's request, findings Jean has already seen, and
the worktree path, then reads the finished `planning/<ID>.md` back.

- Read `AGENTS.md` (invariants) and **only** the code the change touches. Check
  `planning/README.md` for an overlapping proposal — never re-propose a rejected design without
  saying what is different.
- Spawn **one `Explore` agent** with the question "what in `Shared/`, `iOS/`, `macOS/`, `BChess/`
  and the test folders already implements part of this?" — existing types, helpers, seams, tests,
  and the conventions they follow. The plan must cite what it reuses by file and symbol; a plan
  that introduces a second way to do something the code already does is wrong.
- Collect every genuine uncertainty — anything where two readings of the request lead to materially
  different designs — and ask Jean in **one** `AskUserQuestion` (up to four questions). Do not ask
  what `AGENTS.md` or the code answers; do not dribble questions one at a time.

## Phase 2 — Write the plan

One file, `planning/<AREA>-<n>-<slug>.md` (areas and the next free number: `planning/README.md`), in
this shape: **problem with evidence** (file:line), **design** (the smallest change that is correct,
with what it reuses), **alternatives rejected and why**, **test plan** (the failing tests, named,
and what each proves), **invariants** (I1–I5 from `AGENTS.md`: holds / at risk and how it is held /
not applicable), **risks and rollout** (file-format compatibility, what needs a real device),
**decision left open for Jean**. Large work is split into numbered steps, one commit each. Add its
row to the README table.

The simplicity bar: every new abstraction names its second caller or does not exist; no config knob
nobody will set; no layer that only forwards; extend existing code before adding beside it; no
speculative generality.

## Phase 3 — Codex reviews the plan (one round by default)

Give the reviewer the plan and `AGENTS.md`, not your agent's notes. **Run Codex directly**: write the
prompt to a scratchpad file and start, in the background,
`codex exec --sandbox read-only -C <worktree> -o <scratch>/<round>-result.md "$(cat <scratch>/<round>-prompt.txt)" < /dev/null > <scratch>/<round>.log 2>&1`
— the `< /dev/null` is load-bearing: without it a background `codex exec` blocks forever on
"Reading additional input from stdin...". Read-only always; never `--write`:

> Review `planning/<file>` against the code in this worktree and the invariants in `AGENTS.md`.
> Return, in order: BLOCKERS (the plan is wrong or breaks an invariant — name the input or state),
> SHOULD-FIX (a real gap in the design or the test plan), SIMPLER (a smaller design that meets the
> same goal), ALREADY-EXISTS (code the plan reimplements — file and symbol). Say "none" for an empty
> section. End with one line `substantive: yes|no`. Do not praise the plan.

**Catching a review that did not run.** A Codex review exists only when its result file holds the
four sections and the closing `substantive:` line. Nothing else counts. Every Codex round, both
phases:

1. **Liveness at 2 minutes.** `<round>.log` must be growing or `~/.codex/sessions/` must show a new
   session. If neither, `ps` for a `codex` process; if none, start it again (once). A non-zero exit,
   or a result file that is empty or lacks the sections, is the same failure.
2. **Progress every 10 minutes**, never sleep-and-hope. A log untouched for 15 minutes with the
   process alive is a stall: kill it and restart the round.
3. **The `codex:codex-rescue` wrapper is the fallback, not the default.**
4. **Never report a round that did not run as a round.** If Codex is down after one restart, run
   the same prompt through the substitute reviewer, label it "substitute review", and continue.
5. **Long results get truncated in delivery**: read the result FILE, never the message.

Fold each finding in: **accept** (edit the plan, bump "revision N" in its header with a one-line
changelog) or **reject** (write the rationale into the plan, so the next round does not re-raise it).
Then apply the Codex policy. When it says stop, present Jean with the plan, the revision history and
the rejected findings, and get a **go / adjust / stop** decision (`AskUserQuestion`). `--plan-only`
ends here.

## Phase 4 — An implementation subagent (Sonnet on Claude Code)

The main context stays clean: it reads plan text, subagent reports and `git diff --stat`, never build
logs or the diff body. Spawn once and keep the agent alive for the fix rounds
(`Agent(model: "sonnet", name: "<id-slug>-impl", …)`; on Cursor the `implement` subagent by name).

The prompt carries: the **absolute worktree path** (every command runs there — state it twice), the
plan path ("implement this plan; where it is silent, choose the smallest correct option and list it
as a deviation"), and "follow `AGENTS.md`; run the gates in `.claude/skills/develop/SKILL.md`". Do
not paste the gates. One commit per plan step with the session's attribution trailer. Its report
must list: what was built (commit list), every deviation from the plan and why, the test summary
lines verbatim, the warnings check and its result, and anything left unfinished. Treat "done" claims
as claims: check `git log main..HEAD --oneline` and the test summary yourself before phase 5.

## Phase 5 — Codex reviews the implementation (one round by default)

Same prompt and four-section shape as phase 3, against `git diff main...HEAD` **and the plan** —
does the code do what the plan says, do the tests prove what they claim (would each fail without
its change?), which invariant is most at risk, what is more complex than its job requires, what is
duplicated. **Run Codex directly** with the same `codex exec --sandbox read-only -C <worktree> -o …`
and the same "did it run" protocol.

Send each accepted finding to the **same** subagent with `SendMessage`. Rejected findings get a
one-line rationale in the final report, not silence. Re-run the gates after every fix round. Apply
the Codex policy.

## Phase 6 — Hand back (landing is Jean's call)

The deliverable is a green, reviewed branch in the worktree plus a report: what shipped (commits),
plan revisions and review rounds with what each changed, findings rejected and why, gates run (the
test summary lines, the warnings check), and what is owed (a run on a real device, a visual check).
**When Jean says land, the feature lands as ONE squashed commit:**

1. `git fetch && git rebase main` in the worktree, re-run the test gates after the rebase.
2. On `main`: `git merge --squash <branch>` then ONE `git commit` whose subject is the plan id and a
   sentence and whose body carries the branch's commit subjects (`git log main..<branch>
   --format='- %s'`), each regression test's red proof in one line, every gate's summary line, the
   plan revisions and review rounds, and the attribution trailer.
3. The macOS test gate once more on `main`, then `git push origin main`.
4. Remove the worktree and `git branch -D` the branch. Update the plan's README row to
   "Implemented on main <date>".

## Anti-patterns

- Writing the plan before the Explore pass — the plan reinvents a helper that exists.
- Asking Jean things `AGENTS.md` answers, or asking five times instead of once.
- Letting Codex see your reasoning before it forms its own.
- Running a second review round because the first found a typo.
- Reviewing a plan or implementation with the same agent that wrote it, or in the parent.
- Reviewing with the same vendor that planned and implemented when the other vendor's CLI works.
- Planning inline in the parent on Claude Code.
- Reading the implementation diff or a build log into the main context.
- Spawning a fresh implementer for each fix round instead of messaging the one that built it.
- Restating `AGENTS.md` in the implementer prompt.
- Counting a test run where the GoogleTest suite executed zero cases as green.
- Bumping the version or landing without being asked.
