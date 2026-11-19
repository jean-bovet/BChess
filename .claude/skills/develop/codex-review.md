# /develop Codex review — the command, the prompts, the "did it run" protocol

How `/develop` runs one Codex round (phase 3 on the plan, phase 5 on the implementation). The round
policy (how many, when to stop, the substitute reviewer) is in `SKILL.md` § Codex policy.

## The command

Write the prompt to a scratchpad file and start, in the background, from the worktree:

```sh
codex exec --sandbox read-only -C <worktree> -o <scratch>/<round>-result.md - < <scratch>/<round>-prompt.md > <scratch>/<round>.log 2>&1
```

The prompt comes from stdin (`-`); a background `codex exec` with an open terminal stdin blocks
forever on "Reading additional input from stdin...". Read-only always; never `--write`.

## Keep every prompt narrow

Every review prompt names the exact plan section and the few source files (with line ranges) to read,
says "read only these; no other commands, no builds or tests", and caps each section at a few one-line
findings with a severity. A broad prompt makes Codex read much of the repo and run commands, and
stalls. A review not back within about 15 minutes is stopped and rerun narrower; a large diff is
reviewed one commit at a time (`git diff <sha>^ <sha>`, or `codex exec review --commit <sha>`), not in
one `main...HEAD` pass.

## The plan prompt (phase 3)

Give the reviewer the plan and the invariants, not your agent's notes and not the whole design doc:

> Review `<plan file>` against the code in this worktree and the invariants (`<invariants file>`).
> Return, in order: BLOCKERS (the plan is wrong or breaks an invariant — name the input or state),
> SHOULD-FIX (a real gap in the design or the test plan — including any new entity or field
> without a traced path from the line that writes it to the screen that shows it, covered by a
> test or preview that uses the production read path), SIMPLER (a smaller design that meets the
> same goal), ALREADY-EXISTS (code the plan reimplements — file and symbol). Say "none" for an empty
> section. End with one line `substantive: yes|no`. Do not praise the plan.

## The implementation prompt (phase 5)

Same shape and the same four sections, against `git diff main...HEAD` (or one commit) **and the
plan**: does the code do what the plan says, do the tests prove what they claim (would each fail
without its change?), which invariant is most at risk, what is more complex than its job requires,
what is duplicated, and whether every new entity or field reaches its screen through the production
read path. Do not attach the whole design doc.

## Catching a review that did not run

A review exists only when its result file holds the four sections and the closing `substantive:`
line. Nothing else counts. Every Codex round, both phases:

1. **Liveness at 2 minutes.** `<round>.log` must be growing or `~/.codex/sessions/` must show a new
   session. If neither, `ps` for a `codex` process; if none, start it again (once). A non-zero exit,
   or a result file that is empty or lacks the sections, is the same failure.
2. **Progress every 10 minutes**, never sleep-and-hope (a subagent checks within the global
   four-minute rule). A log untouched for 15 minutes with the process alive is a stall: kill it and
   restart the round.
3. **Never report a round that did not run as a round.** If Codex is down after one restart, run
   the same prompt through the substitute reviewer (`SKILL.md` § Codex policy), label it
   "substitute review", and continue.
4. **Long results get truncated in delivery**: read the result FILE, never the message; if only a
   message exists, ask for the remainder from the last line you saw.
