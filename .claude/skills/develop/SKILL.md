---
name: develop
description: "add X", "fix Y", "implement planning/Z.md": a change to BChess's engine, bridge, game model or app logic. Plan in a worktree, Codex reviews the plan, Sonnet subagents implement, Codex reviews the code, hand back a green pushed branch.
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

Next to this file: [`gates.md`](gates.md) (the build and test gates, red proof, warnings: the only
file of this skill an implementer reads) and [`codex-review.md`](codex-review.md) (the review command,
prompts and the "did it run" protocol).

## Context

- **Working agreement:** `AGENTS.md` (invariants, stack, tests, conventions, done-when).
- **Invariants:** `AGENTS.md`, I1–I5.
- **Design doc:** none beyond `AGENTS.md`; read only the code the change touches.
- **Plans:** `planning/<AREA>-<n>-<slug>.md`; index `planning/README.md`.
- **Code to search for reuse:** `Shared/`, `iOS/`, `macOS/`, `BChess/` and the test folders.
- **Docs-only paths:** `planning/`, `AGENTS.md`, a skill.
- **String Catalog and right to left:** a change to user-facing strings, the board, the notation or a number shown
  to the user follows the String Catalog and Right to left facts in `gates.md`.
- **Plan risks to cover:** file-format compatibility, what needs a real device.
- **Owed checks:** a run on a real device, a visual check.

Do not paste the working agreement into prompts — point at the file. This skill holds the recipe.

## Codex policy

**Skip Codex** for work that is not `/develop` work:

UI-only view tweaks, String Catalog translations, and docs-only edits.

**The reviewer is always a different vendor from the planner and implementer**: Codex
(`codex exec`, [`codex-review.md`](codex-review.md)).

**When Codex is unavailable** (usage limit, missing CLI, failed after one restart): do not skip the
review and do not wait for Jean. Spawn a fresh read-only subagent with `model: "opus"` that saw
neither the plan draft nor the diff being written, and give it the same prompt. Never resume the
planner or the implementer for a review, and never review in the parent. Report it as
"substitute review (Codex unavailable: <reason>)".

**Default: one Codex round per phase** (plan, then implementation). A second round runs only when
the first found a substantive issue — behaviour, correctness, an invariant, a test that would have
missed a real bug, a simpler design that meets the same goal, or:

file-format compatibility, a thread-safety hole.

**Implementation phase: a second round only for a blocker.** Should-fix, simpler and already-exists
findings are fixed and pass the step gate without another round; when round 1 found a blocker, round 2
reviews only the fix's diff.

A third round only if a blocker is still open. Hard cap of **three rounds per phase**. A substitute
review counts as a round. Always report how many rounds ran, who ran each, and what each changed. A
round that finds nothing is a good result, not a reason to run another.

Stop when a round yields only nits, style, restatements of points already decided with a written
rationale, or nothing.

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
available, else `git worktree add`); a session already in an Orca worktree works there (the global
rules). Everything below — the plan, the code, the subagent, the reviews — happens in that path.
Leave unrelated changes in the main checkout alone. The worktree guard refuses compound Bash
commands (variables, `$(…)`, heredocs): write scripts to the scratchpad and run them.

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
replaced, the plan diffs its contents, not just its reader; the UI suites and devices the landing
gate runs, `gates.md`),
**invariants** (each one: holds / at risk and how it is held / not applicable), **risks and
rollout** (the plan risks in Context), **decision left open for Jean**. Large work is split into
numbered steps, one commit each, listed under a `## Steps` heading as `1. **<title>** — <what>`
(the status line counts those lines to show plan progress). Add its row to the plans index.

The simplicity bar: every new abstraction names its second caller or does not exist; no config knob
nobody will set; no layer that only forwards; extend existing code before adding beside it; no
speculative generality. If the honest plan is "twenty lines in one file plus two tests", write that.

## Phase 3 — Codex reviews the plan (one round by default)

Give the reviewer the plan and the invariants, not your agent's notes and not the whole design doc.
Run the round as [`codex-review.md`](codex-review.md) says (the command, the plan prompt, the "did it
run" protocol).

Fold each finding in: **accept** (edit the plan in place — the lines the finding changes, never a
rewrite of the file — and bump "revision N" in its header with a one-line changelog) or **reject**
(write the rationale into the plan, so the next round does not re-raise it).
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
implements.

Before spawning, when the repo's gates host tests inside the app (an app-hosted test target or a Mac
gallery), run the repo's running-app check (a repo fact, `gates.md`). If the app is running — Jean's
own Xcode debug run included — tell Jean and wait for him to quit it; never kill it.

```
Agent(model: "sonnet", name: "<id-slug>-impl-<step>", prompt: …)
```

The prompt carries: the **absolute worktree path** (every command runs there — state it twice), the
plan path ("implement this plan; where it is silent, choose the smallest correct option and list it
as a deviation"), and "follow the working agreement; run the gates in
`.claude/skills/develop/gates.md` (read only that file of this skill)". Do not paste the gates. One
commit per plan step, subject `<ID> step N: <summary>`, with the session's attribution trailer. Its
report must list: what was built (commit list), every deviation from the plan and why, the test
summary lines verbatim, the warnings check and its result, and anything left unfinished. Treat
"done" claims as claims: check `git log main..HEAD --oneline` and the test summary yourself before
phase 5.

## Phase 5 — Codex reviews the implementation (one round by default)

The implementation prompt of [`codex-review.md`](codex-review.md), against `git diff main...HEAD`
**and the plan**. Do not attach the whole design doc. Same command and the same "did it run" protocol.

Send each accepted finding with `SendMessage` to the implementer of the step it concerns while that
one is alive; otherwise spawn a fresh implementer with the finding, the plan and the commit. Rejected
findings get a one-line rationale in the final report, not silence. After every fix round run the step
gate (plus the landing gate again when it already ran and the fix touched more than docs). Apply the
Codex policy.

## Phase 6 — Hand back (landing is Jean's call)

The deliverable is a green, reviewed branch in the worktree — the landing gate (`gates.md`, fresh
`<dd>`) passed once on the tree handed back (suites, devices, gallery shown or not needed) — plus a
report: what shipped (commits), plan revisions and review rounds with what each changed, findings
rejected and why, gates run (the test summary lines, the warnings check, and each conditional gate —
which ran and which did not), and what is owed (the owed checks in Context). Before the report, push
the branch to origin per the global rules. Landing stays Jean's call. **When Jean says land, the feature lands as ONE squashed commit through a pull request**: `main` requires
pull requests (a GitHub rule), so never push `main`.

1. `git fetch && git rebase origin/main` in the worktree, then rerun the landing gate when the rebase
   brought in more than docs.
2. In the worktree, `git switch -c <id-slug>-pr origin/main`, `git merge --squash <id-slug>`, then ONE
   `git commit` whose subject is the plan id and a sentence and whose body carries the branch's commit
   subjects (`git log origin/main..<id-slug> --format='- %s'`), each regression test's red proof in one
   line, every gate's summary line, the plan revisions and review rounds, the plan's index-row text,
   the issue line (`Closes`/`Refs`, per the global rules), and the attribution trailer. The same commit sets the plan's index
   row to "Implemented on main <date>". Write the message before deleting anything.
3. On `<id-slug>-pr`, the squash tree equals the branch's tree (`git diff <id-slug> <id-slug>-pr` empty),
   then `git push -u origin <id-slug>-pr` and `gh pr create --base main` with the commit message as
   title and body (the issue line included). Jean merges the PR on GitHub; never merge it yourself
   unless Jean says so.
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
- Rewriting a plan file to fold in a finding instead of editing the lines concerned.
- Restating the working agreement in the implementer prompt.
- Bumping the version or landing without being asked.
- Broad Codex prompts (`codex-review.md`).
- Counting a test run where the GoogleTest suite executed zero cases as green.
