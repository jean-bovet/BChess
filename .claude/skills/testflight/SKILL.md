---
name: testflight
description: Ship main to TestFlight through Xcode Cloud — the BChess iPhone/iPad app and the Mac App Store app, for the internal testers. Use when the user asks for a TestFlight build, to ship or push to TestFlight, or to send a build to testers. A public App Store release is `/release`, not this skill.
argument-hint: "[version, e.g. 1.0 — optional; asked when omitted]"
allowed-tools: Read, Edit, Write, Bash, AskUserQuestion
---

# /testflight — ship main to TestFlight

Xcode Cloud (product `BChess (iOS)`) builds both App Store apps from this repo — `BChess (iOS)`
(iPhone/iPad) and `BChess (macOS)` (Mac App Store), one App Store record, bundle ID
`ch.arizona-software.BChess` — and hands them to the internal TestFlight testers.
`$ARGUMENTS` is the version to ship, when given (§4).

Facts this skill relies on:

- A push to `main` runs the build-only workflow (actions Build - iOS, Build - macOS). A push to
  `testflight` runs the TestFlight workflow, which archives both apps (Archive - iOS,
  Archive - macOS) for internal testing. The workflows are configured in App Store Connect.
- `BChess.xcodeproj` is generated from `project.yml` (XcodeGen) and checked in;
  `ci_scripts/ci_post_clone.sh` writes `Signing.local.xcconfig` from `$CI_TEAM_ID`.
- Xcode Cloud reads tester notes from `TestFlight/WhatToTest.en-US.txt`.
- **`main` requires pull requests** (a GitHub rule): this skill never pushes `main`. Its commit goes
  on a branch with a pull request (§7), and the same commit is what `testflight` points to (§8). Jean
  merges that pull request with **Create a merge commit** — never squash or rebase, which rewrite the
  commit and leave `testflight` outside `main`'s history (§1 then fails on the next run). The
  `testflight` branch itself is not protected.
- No git tag: this skill makes none; `/release` tags `v<version>`. The old `v0.1` tag (2021) marks
  no App Store release.

## How a build reaches TestFlight

- Xcode Cloud archives and uploads whatever the `testflight` branch points to, and takes the
  "What to Test" text from the notes files as they are at that commit. Nothing is archived,
  exported or uploaded from this Mac.
- Xcode Cloud numbers the build. `CURRENT_PROJECT_VERSION` in `project.yml` is never bumped, and a
  build number is never predicted: failed or retried builds consume numbers.
- **This skill is the only thing that moves `testflight`**, and it only ever fast-forwards it to
  the commit of §7 (`main` plus the notes). A request for a TestFlight build is a request for this
  skill, never a hand push of the branch. Never `--force`.
- It runs in the main conversation: git, a few files, a check or two — no subagent.
- It ends when `testflight` is pushed (§10). Processing, the build report and the expiry reminder
  are Jean's to ask for later (§11); never wait on Xcode Cloud after the push.
- Stop on the first failure, say which step failed and why, and leave the rest undone. Never fake
  a check that is Jean's to make.

## 1. Guards

```bash
git rev-parse --abbrev-ref HEAD                      # must be main (or a resume, §2)
git status --porcelain --untracked-files=all         # must be empty
git fetch origin main testflight
git rev-list --count main..origin/main               # must be 0 (main not behind)
git merge-base --is-ancestor origin/testflight main  # must succeed
gh pr list --state open --json number,headRefName --jq '.[] | select(.headRefName | startswith("testflight-"))'
```

- Changes you did not make (modified or untracked files): never stash, commit, discard or include
  them. Name them and ask Jean what to do.
- `origin/testflight` not an ancestor of `main`: either the last run's pull request is still open
  (the `gh` line lists it: ask Jean to merge it with a merge commit, then start again), it was
  squashed or rebased, or something else was pushed there; Jean sorts it out by hand.
- The resume case of §2 runs on the branch of the earlier run, not on `main`.

## 2. What goes out — new, resumed or nothing

```bash
git log --no-merges --format='%h %s' origin/testflight..main
```

is exactly what the testers have not received yet (`--no-merges` drops the merge commit of the
previous run's pull request). Decide which case this is now, **before any change**, and keep the
answer:

- **Resume** if `HEAD` is this skill's own release commit (§7), on its `testflight-…` branch, and
  `origin/testflight` is behind it: an earlier run committed, then stopped before the build started.
  Keep its version and notes, skip §4–§6, and continue at §7 (pushing the branch again is a no-op;
  open the pull request if it is missing).
- **Nothing new** if the range is empty: say "nothing new since the last build (`<sha>`)" and stop,
  unless Jean asks for a §11 step for that build (then do only that). If he
  explicitly wants the same commit rebuilt, make no empty commit: the `xcode-cloud` tool's
  `rebuild <number>` (see §11) starts it again, or "Start Build" in App Store Connect ▸ Xcode Cloud.
- Otherwise it is a **new release** of that range.

## 3. Preconditions

No CloudKit: the app has no iCloud entitlement (and no network access, invariant I5), so the
CloudKit gate below never fires. If an iCloud entitlement ever appears in `macOS/macOS.entitlements`
or the iOS target, apply it.

**CloudKit Production.** TestFlight builds sync against Production, which is deployed by hand in
the CloudKit Console. When the check above finds a schema change (or cannot rule one out), ask
Jean with `AskUserQuestion` whether the Production deploy is done; on anything but yes, stop. A
build that reaches a device before its schema is the one failure this skill must never automate.

Ask the version question of §4 now, in one `AskUserQuestion` call, unless `$ARGUMENTS` gave it.

## 4. Version

The version is `MARKETING_VERSION` in `project.yml` (both `iOS/Info.plist` and `macOS/Info.plist`
read `$(MARKETING_VERSION)`). A bump edits `project.yml`, then `xcodegen generate`, and commits
`project.yml` with `BChess.xcodeproj/project.pbxproj`; nothing else changes (not
`CURRENT_PROJECT_VERSION`).

Until the first App Store release (no `v1.0` tag yet), test builds carry 0.2, and the build meant
for the App Store must carry **1.0**, the version App Store Connect holds on both platforms: offer
"keep <current>" and "1.0" (the one exception to the tag rule below: 0.2 never ships). From then on, offer "keep <current>" and the next minor (e.g. 1.0 → 1.1).

When there is a version, state it in your first message, and `git tag -l "v<version>"` must be
empty.

**When the repo also ships to the App Store** (it has `/release`), the version belongs to the next
App Store release, not to one build: bump only when the current version already has its `v<version>`
tag (it shipped); otherwise keep it, so every TestFlight build until `/release` shares that version.
`/release` tags the version, never this skill.

## 5. Test gate

The `/develop` test gate, in this checkout, on a fresh build folder (run the iOS lines in one shell,
so the trap gives the simulator back also on failure):

```bash
dd=$(mktemp -d)
buildlock --folder "$dd/dd-mac" -- xcodebuild test -scheme "BChess (macOS)" -destination 'platform=macOS' -derivedDataPath "$dd/dd-mac"
buildlock --folder "$dd/dd-uci" -- xcodebuild -scheme BChessUCI -destination 'platform=macOS' -derivedDataPath "$dd/dd-uci" build
udid=$(simpool acquire --spec iphone --pid $$); trap 'simpool release "$udid" --app ch.arizona-software.BChess' EXIT
buildlock --folder "$dd/dd-ios" -- xcodebuild test -scheme "BChess (iOS)" -destination "id=$udid" -parallel-testing-enabled NO -derivedDataPath "$dd/dd-ios"
```

Each must end with `** TEST SUCCEEDED **` (`** BUILD SUCCEEDED **` for BChessUCI); a Swift Testing
`✘` or any `error:` is red, and the engine GoogleTest cases must all have run (zero is red).

Stop on failure.

## 6. What to Test

Read the subjects and bodies of the §2 range. Drop what no tester can see: docs, skills, planning,
tests, refactors, tooling, CI scripts, project and scheme churn, String Catalog housekeeping. Write
the rest from the tester's side:

- What they can do or will notice, not what was implemented. No ticket ids, no file names, no
  internal type names, no "fix for #…".
- Plain text, at most 4000 characters per file, no emoji (App Store Connect rejected a 🔒 as
  "invalid characters"; `•`, `« »` and accented letters pass).
- The What to Test file is **replaced** every build, not appended; its history is its `git log`.
- Contact addresses (the global working agreement's contacts): an address testers see — in What to
  Test, or as the TestFlight feedback email — is the `public` one; the `apple-review` address goes
  only in the Beta App Review contact. No retired domain (the global working agreement's list) in
  any link.
- If nothing in the range is visible to a tester, write one line saying so (e.g. "No visible
  changes: build and stability work.") rather than leaving the file stale or empty.

One file, English: `TestFlight/WhatToTest.en-US.txt`, read by the internal testers on iPhone, iPad
and Mac. Bullets starting with `- `, separated by a blank line (TestFlight shows the text verbatim),
then one `Please verify: ...` sentence naming the two or three behaviors to exercise. Say when an
item concerns only iPhone/iPad or only the Mac. The one-line "no visible changes" file is a bullet
too (e.g. "- No visible changes: build and stability work.").

Show Jean every notes file in full, with the commit list it came from, and ask
(`AskUserQuestion`) for a yes or his edits. Apply edits and show again until approved. **Do not
commit before that.**

## 7. Commit on a branch and open the pull request

Stage only the files this skill changed — never `git add -A` — and end the commit message with
the session's attribution trailer.

```bash
git switch -c testflight-<version>-<yyyymmdd>        # from main; a resume is already on it
git add TestFlight/WhatToTest.en-US.txt project.yml BChess.xcodeproj/project.pbxproj   # the version files only on a bump
git commit -m "TestFlight <version>: <one-line summary>"
git push -u origin testflight-<version>-<yyyymmdd>
gh pr create --base main --title "TestFlight <version>: <one-line summary>" --body "<the commit body>"
```

Never push `main`, and never merge the pull request yourself unless Jean says so (then
`gh pr merge <number> --merge`, never `--squash` or `--rebase`).

Push the branch and `testflight` (§8) together, right after the commit: Jean's approval of the
notes (§6) is the go. Never wait for an Xcode Cloud run — before the commit or after the push — and
never ask again before §8. A CI check reads the most recent **finished** run; one still in progress
is noted in the report (§10), not waited for.

## 8. Start the build: fast-forward `testflight`

```bash
git push origin HEAD:refs/heads/testflight
git branch -f testflight HEAD 2>/dev/null || true   # local copy; a worktree may have it checked out
git switch main
```

The push is a fast-forward by construction of §1 (`origin/testflight` is in `main`, and `HEAD` is
`main` plus one commit). A refused push means the branch moved since; that is Jean's to resolve.
Never `--force`, never push anything but this skill's release commit to `testflight`.

## 9. After the build starts

Jean merges the pull request with a merge commit, and installs from TestFlight on iPhone or iPad and
on the Mac. Nothing more: submitting to the App Store is `/release`, done only when he asks.

## 10. Report — and stop

The skill is **done once `testflight` is pushed**. Do not wait for Xcode Cloud: no polling, no
background watcher, no "still running" check-ins. Report right away:

- the release commit's sha, the range that went out, the version;
- that pushing `testflight` started the archive, and where to follow it: App Store Connect ▸ the
  app ▸ Xcode Cloud ▸ Builds shows the run and its build number (never predict it); the
  TestFlight group gets the build when processing ends, with the notes as "What to Test";
- if the CloudKit gate of §3 fired, that Jean confirmed the Production deploy;
- how to ask for §11 later ("report Xcode Cloud build <n>", "remind me about <App>'s expiry").

Also: the pull request's URL, and that it must be merged with **Create a merge commit** before the
next `/testflight` or `/release`.

## 11. Later, only when Jean asks

**Build report.** Read the finished run — every action, not only the archive — with the
`xcode-cloud` tool (its path is in the global working agreement; it loads its own credentials,
never open or source them):

```bash
xcode-cloud builds "BChess (iOS)" --limit 3        # find the run the push started
xcode-cloud report "BChess (iOS)" <build number>   # warnings, errors, failed tests per action (also takes a build URL)
```

List its warnings (grouped by file) and any failed test action, even when the run says SUCCEEDED,
and offer to fix them in a follow-up commit. For a failed action, `report … --logs DIR` downloads
its logs. Report the iOS and the Mac archive separately: one can upload while the other fails (the
first TestFlight run archived iOS and failed preparing the Mac build). A run still in progress: say
so and stop; do not wait for it.

**The 90-day expiry reminder.** A push resets nothing; only a processed build does. Once the build
has processed and reached the testers — every platform's build, when there are several — read each
build's actual expiry date, take the earliest, and ask Jean once whether to create the reminder:

```bash
osascript -e 'tell application "Reminders" to make new reminder with properties {name:"<App> <version or date> (<build>) TestFlight build expires on <earliest expiry> — run /<this skill>", remind me date:date "<earliest expiry − 10 days>"}'
```

Never guess a date from the push.
