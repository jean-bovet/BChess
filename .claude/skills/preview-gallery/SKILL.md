---
name: preview-gallery
description: Render every iOS screen of BChess in light and dark with one snapshot-test run (scripts/snapshot-gallery.sh) and assemble previews/index.html, one card per #Preview with light and dark side by side. Use when Jean asks to see the screens, to check the UI after a change to a view, or to regenerate the preview gallery. The Xcode MCP RenderPreview (last section) is for spot checks while editing a view.
argument-hint: [simulator name or id]
allowed-tools: Read, Glob, Grep, Bash, mcp__xcode__XcodeListWorkspaces, mcp__xcode__XcodeOpenWorkspace, mcp__xcode__RenderPreview
---

# /preview-gallery: every screen, rendered light and dark, on one page

## Method: `scripts/snapshot-gallery.sh`

```
scripts/snapshot-gallery.sh [--keep-booted] [--shutdown] [simulator name or id]
```

One `xcodebuild test` run of `BChessGalleryTests/SnapshotGalleryTests` renders every scenario of
`Shared/PreviewSupport/PreviewScenarios.swift` (the single place each `#Preview` is set up) in light and dark through
`UIHostingController` into a temp tree `<light|dark>/<file stem>/<name>.png` (`TEST_RUNNER_BCHESS_SNAPSHOT_DIR`;
without that variable the test is skipped, so the normal test gate writes nothing). The script then runs
`scripts/preview-gallery.py --import`, which replaces `previews/` with the renders, builds `previews/index.html` and
checks the gallery, and opens the page. DerivedData is persistent (`BCHESS_SNAPSHOT_DD`, default
`~/Library/Developer/Xcode/DerivedData/BChess-snapshots`): a warm run is an incremental `build-for-testing` plus
`test-without-building`, both with `-parallel-testing-enabled NO`. One simulator at a time: the script stops with a message
when another simulator is booted, and shuts down only a simulator it booted itself. The "BChess Agent" simulator (iPhone
17 Pro) is created if missing; pass `--keep-booted` for repeated runs and `scripts/snapshot-gallery.sh --shutdown`
(which never creates one) when finished. Its first boot can take many minutes.

- The gallery is iOS only, English only, light and dark. The macOS-only `DocumentWindow` preview is outside it.
- **Done = `CHECK OK: N cards, light and dark complete and correctly lit`.** Then read the new or changed PNGs in both
  appearances (see Report) and shut the simulator down.
- `python3 scripts/preview-gallery.py --check` rebuilds the page from `previews/` and checks it again, with no render.

## Adding or changing a view

A new `#Preview` needs a scenario:

1. Add one line-start declaration to `PreviewScenarios`, exactly
   `static let <ident> = PreviewScenario(file: "<File>.swift", name: "<Name>"` followed by the builder closure. The `file`
   is the file holding the `#Preview`, and `name` is exactly the `#Preview` name. Add it to `all`. A scenario only for iOS
   goes inside `#if os(iOS)`, in its declaration and in `all`.
   `gallery: false` after `name:` keeps the `#Preview` for Xcode but leaves the scenario out of the render and the page.
2. The `#Preview` is named, wrapped in `#if DEBUG`, and its body is exactly `PreviewScenarios.<ident>.view()`.
3. Choose a position where a human is to move and no engine readout is on, so no search starts. `view()` already points
   `@AppStorage` at a scratch suite, so stored settings never change the picture.
4. A new file goes into a section: the table `SECTIONS` in `scripts/preview-gallery.py` (a file not listed lands in "Other
   screens").

`--check` fails on: a missing or stale slot, a light render that is dark or a dark render that is light (mean luminance
against 0.45, `scripts/preview-luminance.swift`), an undecodable image, an unnamed `#Preview`, a duplicate (file, name), a
scenario without a `#Preview`, a `#Preview` that does not render its own scenario, and a forced scheme or locale in
`PreviewScenarios.swift`. Staleness is conservative: the script records the mtime of every file under `Shared/` and `iOS/` and of
`BChess/Openings.pgn` before the build, and any difference now (edited, added, deleted, also during the run) makes every
card stale. A PNG in `previews/` that no `#Preview` expects is reported as stray, and so is a `#Preview` written in a form
the script cannot read (use `#Preview("Name") {` on one line).

## Rule: previews never force an appearance or a language

A `#Preview` and a scenario must not set `.preferredColorScheme(...)` or `.environment(\.locale, ...)`: the light and dark
passes decide the scheme. A forced scheme makes a "light" card dark (and the reverse). A state that only existed as a
"dark" preview becomes a named light-and-dark scenario.

## Report

The card count, the path opened, and any scenario that would not render. Then read the new or changed screens with the
Read tool in both appearances and say what looks wrong (copy, hierarchy, colours, missing elements, truncation, contrast).
Screenshots nobody looks at are not a gate. A visual finding is reported, not fixed in passing.

## Spot checks while editing a view: Xcode MCP `RenderPreview`

For one view, while editing, `mcp__xcode__XcodeListWorkspaces` (open `BChess.xcodeproj` with `XcodeOpenWorkspace` if
needed) and `mcp__xcode__RenderPreview` with the project-relative source path and the `#Preview` index render a single
preview in a few seconds. That output has no import path into `previews/`: only the snapshot run feeds the gallery.
