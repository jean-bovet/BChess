# /develop review round — the command, the prompts, the "did it run" protocol

How `/develop` runs one outside review round (phase 3 on the plan, phase 5 on the implementation).
The round policy (how many, when to stop, the substitute reviewer) is in `SKILL.md` § Codex policy.

## The command

Write the prompt to a scratchpad file and start, in the background, from the worktree:

```sh
peer-review -C <worktree> -o <scratch>/<round>-result.md < <scratch>/<round>-prompt.md
```

`peer-review` (on PATH) tries Codex, then Cursor GPT, then Cursor Composer, read-only, within each
plan's included usage: a reviewer out of credit is skipped until it resets, a crash or a 15-minute
stall restarts it once, then the next one runs. Exit 0: the result file's first line names the
reviewer (`reviewer: cursor/composer-2.5 (skipped codex: out of credit)`), then the review. Exit 3: no
outside reviewer could review; run the substitute (`SKILL.md` § Codex policy). Its log is
`<result>.log`; `peer-review status` lists who is out of credit until when.

## Keep every prompt narrow

Every review prompt names the exact plan section and the few source files (with line ranges) to read,
says "read only these; no other commands, no builds or tests", and caps each section at a few one-line
findings with a severity. A broad prompt makes Codex read much of the repo and run commands, and
stalls. A large diff is reviewed one commit at a time (the prompt names `git diff <sha>^ <sha>`), not
in one `main...HEAD` pass.

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
line; `peer-review` checks that before it writes the file, and restarts or moves on by itself.

1. **Wait for the command to finish**: check on it at most every four minutes (the global subagent
   rule), never sleep-and-hope. Nothing else to watch: liveness and stalls are the script's.
2. **Quote the result file's `reviewer:` line** in the report. A Cursor review is reported as
   such, never as a Codex review.
3. **Exit 3**: run the same prompt through the substitute reviewer (`SKILL.md` § Codex policy) and
   continue. Never report a round that did not run as a round.
4. **Long results get truncated in delivery**: read the result FILE, never the message.
