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
  skill, never a hand push of the branch. Never `--force`. A repository's first run creates the
  branch, the same way (§1).
- It runs in the main conversation: git, a few files, a check or two — no subagent.
- It ends when `testflight` is pushed (§10). Processing, the build report and the expiry reminder
  are Jean's to ask for later (§11); never wait on Xcode Cloud after the push.
- **The `testflight` run is the cloud check.** Never read or wait for a `main` run before the push:
  to save compute hours (one monthly pool for every app),
  `main` need not build in Xcode Cloud at all. The run the push starts tests and archives the
  commit that goes out; whether it succeeded is the §11 build report.
- Stop on the first failure, say which step failed and why, and leave the rest undone. Never fake
  a check that is Jean's to make.

## 1. Guards

```bash
git rev-parse --abbrev-ref HEAD                      # must be main (or a resume, §2)
git status --porcelain --untracked-files=all         # must be empty
git ls-remote --exit-code --heads origin testflight  # exit 2: no such branch yet, the first run (below)
git fetch origin main testflight --tags              # tags pushed from elsewhere, for §4
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
- **First run: `origin` has no `testflight` branch yet** (`git ls-remote` exits 2). Fetch with
  `git fetch origin main --tags` and skip the ancestor check: there is nothing to be an ancestor
  of. Every other guard holds. What goes out is all of `main` (§2), §8's push creates the branch at
  the release commit, and the report says so (§10). Never create the branch any other way: its
  first push starts a build.

## 2. What goes out — new, resumed or nothing

```bash
git log --no-merges --format='%h %s' origin/testflight..main
```

is exactly what the testers have not received yet (`--no-merges` drops the merge commit of the
previous run's pull request). Decide which case this is now, **before any change**, and keep the
answer:

- **Resume** if `HEAD` is this skill's own release commit (§7), on its `testflight-…` branch, and
  `origin/testflight` is behind it: an earlier run committed, then stopped before the build started.
  Keep its version and notes, skip §4–§6, and continue at §7 **after its commit**: the commit already
  exists, so never run `git add` or `git commit` again; push the branch (a no-op if already pushed),
  open the pull request if it is missing, run the companion deploy when the repo has one (§7), then §8.
- **Nothing new** if the range is empty: say "nothing new since the last build (`<sha>`)" and stop,
  unless Jean asks for a §11 step for that build (then do only that). If he
  explicitly wants the same commit rebuilt, make no empty commit: the `xcode-cloud` tool's
  `rebuild <number>` (see §11) starts it again, or "Start Build" in App Store Connect ▸ Xcode Cloud.
- Otherwise it is a **new release** of that range.

**On the first run** (§1) there is no `origin/testflight` and so no range to list: what goes out is
all of `main`. It is a new release, or a resume when `HEAD` is already this skill's release commit;
never "nothing new". §6 then writes the notes from what the app does, not from a commit list.

## 3. Preconditions

Ask the version question of §4 now, in one `AskUserQuestion` call, unless `$ARGUMENTS` gave it.
CloudKit has its own slot below.

**CloudKit Production.** TestFlight builds sync against Production, which is deployed by hand in
the CloudKit Console. When the app syncs through CloudKit (stated below), verify the Production
schema on **every** run, resumes included, before anything is committed or pushed: never only when
the range changed the model, and never on the strength of an earlier check. Where the repo can
query the Production schema through the CloudKit API (`xcrun cktool export-schema`), verify it
there, against the model of the commit that goes out, rather than asking for a yes or no;
otherwise ask Jean with `AskUserQuestion` whether Production has every record type and field that
commit needs. A missing type or field, a check that could not run, or anything but a yes: stop. The
deploy is Jean's: never initialise or deploy a schema from here. A build that reaches a device
before its schema is the one failure this skill must never automate.

**CloudKit environment of the Release build.** On the same runs, check what the archive will sign
(no build needed): `xcodebuild -showBuildSettings -scheme "<the archived scheme>" -configuration
Release` shows `PRODUCT_BUNDLE_IDENTIFIER` = the real ID (no `.debug`), `APP_ICLOUD_ENVIRONMENT` =
`Production` and `APP_APS_ENVIRONMENT` = `production`, and `SWIFT_ACTIVE_COMPILATION_CONDITIONS`
holds neither `CLOUDKIT_DEVELOPMENT` nor `CLOUDKIT_PRODUCTION_XCODE`; the environment banner's view
file and every call site sit under those conditions (`grep`), so a Release binary has no banner.
Anything else: stop. A repo not yet on the CloudKit environments standard (no such settings yet):
read the entitlements files the Release configuration uses instead and stop only if one sets
`com.apple.developer.icloud-container-environment` to `Development` (absent is fine: the export
defaults to Production). An `aps-environment` of `development` in a file shared with Debug is
expected before the standard (the export switches it): no stop. Report the standard as owed.

No CloudKit: neither app has an iCloud entitlement (`macOS/macOS.entitlements` holds only the
sandbox and user-selected files; the iOS target has none) and the app has no network access
(invariant I5), so neither check above applies and §10 has no CloudKit line. If an iCloud
entitlement ever appears in `project.yml` or an entitlements file, both apply from that run on.

## 4. Version

The version is `MARKETING_VERSION` in `project.yml` (both `iOS/Info.plist` and `macOS/Info.plist`
read `$(MARKETING_VERSION)`). A bump edits `project.yml`, then `xcodegen generate`, and commits
`project.yml` with `BChess.xcodeproj/project.pbxproj`; nothing else changes (not
`CURRENT_PROJECT_VERSION`).

Offer "keep <current>" and the next minor (e.g. 1.0 → 1.1), following the tag rule below: 1.0
shipped (tag `v1.0`), so the first build after it bumps.

When there is a version, state it in your first message, and `git tag -l "v<version>"` must be
empty.

**When the repo also ships to the App Store** (it has `/release`), the version belongs to the next
App Store release, not to one build: bump only when the current version already has its `v<version>`
tag (it shipped); otherwise keep it, so every TestFlight build until `/release` shares that version.
`/release` tags the version, never this skill.

## 5. Test gate

The full run: every `/develop` test-gate suite (no `-only-testing`), in this checkout, on a fresh build folder, with
the same command shape as `/develop`'s test gate: `caffeinate -is`, `buildlock` on each build folder, the Mac test line
under the hosted app's container lock, tests built once (`build-for-testing`) and run with `test-without-building` (run
the iOS lines in one shell, so the trap gives the simulator back also on failure):

```bash
dd=$(mktemp -d)
caffeinate -is buildlock --folder "$dd/dd-mac" -- xcodebuild build-for-testing -scheme "BChess (macOS)" -destination 'platform=macOS' -derivedDataPath "$dd/dd-mac"
caffeinate -is buildlock --folder ~/Library/Containers/ch.arizona-software.BChess --no-slot -- buildlock --folder "$dd/dd-mac" --no-slot -- xcodebuild test-without-building -scheme "BChess (macOS)" -destination 'platform=macOS' -derivedDataPath "$dd/dd-mac"
caffeinate -is buildlock --folder "$dd/dd-uci" -- xcodebuild -scheme BChessUCI -destination 'platform=macOS' -derivedDataPath "$dd/dd-uci" build
caffeinate -is buildlock --folder "$dd/dd-ios" -- xcodebuild build-for-testing -scheme "BChess (iOS)" -destination 'generic/platform=iOS Simulator' -derivedDataPath "$dd/dd-ios"
udid=$(simpool acquire --spec iphone --pid $$); trap 'simpool release "$udid" --app ch.arizona-software.BChess' EXIT
caffeinate -is buildlock --folder "$dd/dd-ios" -- xcodebuild test-without-building -scheme "BChess (iOS)" -destination "id=$udid" -parallel-testing-enabled NO -collect-test-diagnostics never -derivedDataPath "$dd/dd-ios"
```

Each test line must end with `** TEST EXECUTE SUCCEEDED **` (`** TEST BUILD SUCCEEDED **` for the `build-for-testing` lines, `** BUILD SUCCEEDED **` for BChessUCI); a Swift Testing
`✘` or any `error:` is red, and the engine GoogleTest cases must all have run (zero is red).

Then the full gallery (each script leases, locks and keeps the Mac awake itself):

```bash
scripts/snapshot-gallery.sh --no-open
scripts/snapshot-gallery.sh --device duo --no-open
scripts/snapshot-mac.sh --no-open
```

Each must end with its `CHECK OK [en]: …` line; the gallery pages are not shown unless Jean asks. BChess has no
coverage command.

This is the only full run: `/develop` lands plans on the quick tier plus the touched UI tests. On a red run, rerun
only the failing line or test (`-only-testing:<Target>/<Class>[/<test>]`, or the gallery script with `--only`);
bisect across the plans landed since the last TestFlight build (their squash commits) only when the cause is not
obvious. The fix goes through `/develop`, then this gate reruns.

Stop on failure. Never gate on an Xcode Cloud run here (see "How a build reaches TestFlight").

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

The question names everything his yes starts, since nothing asks again after it: for BChess, the
push of the `testflight-…` branch with its pull request (§7) and the push of `testflight` (§8)
that starts the archive (no tag, no companion deploy).

## 7. Commit on a branch and open the pull request

Stage only the files this skill changed — never `git add -A` — and end the commit message with
the session's attribution trailer. After the commit, `git diff --name-only HEAD~1 HEAD` must list only
those files: anything else was not covered by §5. On a resume (§2) the commit already exists: skip
straight to the push.

```bash
git switch -c testflight-<version>-<yyyymmdd>        # from main; a resume is already on it
git add TestFlight/WhatToTest.en-US.txt project.yml BChess.xcodeproj/project.pbxproj   # the version files only on a bump
git commit -m "TestFlight <version>: <one-line summary>"
git push -u origin testflight-<version>-<yyyymmdd>
gh pr create --base main --title "TestFlight <version>: <one-line summary>" --body "<the commit body>"
```

Never push `main`, and never merge the pull request yourself unless Jean says so (then
`gh pr merge <number> --merge`, never `--squash` or `--rebase`). No tag: a repo with `/release` tags at
the App Store release (§4), never here.

Push the branch and `testflight` (§8) together, right after the commit, with only the companion
deploy below between them: Jean's approval of the notes (§6) is the go. Never wait for an Xcode
Cloud run — before the commit or after the push — and never ask again before §8.

**Companion deploy** (optional): something of the repo's own that must be live before the build
exists, such as a hosted site the app's users read. It runs here, after the branch is pushed and
before §8, from the commit that goes out, on a new release and on a resume alike, and never before
the CloudKit check of §3. Jean's approval of the notes is its go too, so the §6 question names it.
If it stops for any reason, stop here: `testflight` is not pushed, and the next run resumes (§2) at
this point.

None: BChess has no companion deploy.

## 8. Start the build: fast-forward `testflight`

```bash
git push origin HEAD:refs/heads/testflight
git branch -f testflight HEAD 2>/dev/null || true   # local copy; a worktree may have it checked out
git switch main
```

The push is a fast-forward by construction of §1 (`origin/testflight` is in `main`, and `HEAD` is
`main` plus one commit); on the first run it creates `testflight` at that commit. A refused push means the branch moved since; that is Jean's to resolve.
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
- on a first run, that all of `main` went out and that this push created the `testflight` branch;
- when the app syncs through CloudKit, the §3 check of the Production schema: the commit checked,
  how (an export, or Jean's yes) and the result, and the Release environment check (or that the
  CloudKit environments standard is still owed) — none for BChess today (§3);
- the companion deploy, when there is one: what is live after it (none for BChess);
- that the build is checked only once that run finishes: its tests and archive are the check;
- how to ask for §11 later ("report Xcode Cloud build <n>", "remind me about <App>'s expiry").

Also: the pull request's URL, and that it must be merged with **Create a merge commit** before the
next `/testflight` or `/release`.

## 11. Later, only when Jean asks

**Build report** — did the `testflight` branch succeed. Read the finished run — every action,
not only the archive — with the
`xcode-cloud` tool (its path is in the global working agreement; it loads its own credentials,
never open or source them):

```bash
xcode-cloud builds "BChess (iOS)" --limit 3        # find the run the push started
xcode-cloud report "BChess (iOS)" <build number>   # warnings, errors, failed tests per action (also takes a build URL)
```

List its warnings (grouped by file) and any failed test action, even when the run says SUCCEEDED,
and offer to fix them in a follow-up commit. A failed test action on a build that reached the
testers comes first: say so plainly, so Jean can expire the build in App Store Connect.
For a failed action, `report … --logs DIR` downloads
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
