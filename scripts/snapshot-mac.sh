#!/bin/bash
# Renders every Mac scenario (BChessMacGalleryTests' MacSnapshotGalleryTests: the real document window and the
# Settings window in windows that are never on screen, drawn at 2x), light and dark, imports the PNGs into
# previews/mac/ and checks the gallery.
#
# Usage: scripts/snapshot-mac.sh [--only PATTERN] [--no-open]
#   --only PATTERN  comma-separated substrings of scenario names or slugs; renders just those and imports
#                   them over the existing previews/mac/ (the check still covers every scenario)
#   --no-open       do not open previews/mac/index.html at the end
#
# The gallery is previews/mac/index.html, its images previews/mac/mac/ (gitignored). Needs a Retina display (the test
# fails by name on 1x). No simulator. The test runs hosted by the real, sandboxed Mac app, whose container macOS keeps
# other processes out of: it prints each PNG and the manifest as base64 lines, which this script decodes. The host opens
# the app's own untitled game window while it launches (the test closes it): run with BChess closed on the same
# container. Under `buildlock` (when it is on PATH) the xcodebuild run holds the DerivedData lock (with a build slot)
# inside a second lock, without a slot, on the app's container, so two worktrees never run the hosted app at once.
# DerivedData: BCHESS_SNAPSHOT_DD, as the iOS gallery (a Mac build lives beside the iOS one in it).
# The Mac stays awake for the whole run (`caffeinate -dims`, bound to this process).
set -euo pipefail
cd "$(dirname "$0")/.."
if command -v caffeinate > /dev/null; then caffeinate -dims -w $$ > /dev/null 2>&1 & fi

OPEN_PAGE=1; ONLY=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --only) ONLY="${2:?--only needs a pattern}"; shift 2 ;;
    --no-open) OPEN_PAGE=0; shift ;;
    -h|--help) sed -n '2,/^set -euo/p' "$0" | sed '$d' | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "unknown option: $1" >&2; exit 2 ;;
  esac
done

DD="${BCHESS_SNAPSHOT_DD:-$HOME/Library/Developer/Xcode/DerivedData/BChess-snapshots}"
OUT="previews/mac"
WORK="$(mktemp -d -t bchess-mac-gallery)"
LOG="$WORK/xcodebuild.log"
trap 'rm -rf "$WORK"' EXIT
now() { python3 -c 'import time; print(time.time())'; }
elapsed() { python3 -c "print(f'{$2 - $1:.1f} s')"; }
fail() { echo "FAILED: $1 (log kept at $LOG)" >&2; trap - EXIT; exit 1; }

CONTAINER="$HOME/Library/Containers/ch.arizona-software.BChess"
LOCK=()
if command -v buildlock > /dev/null; then LOCK=(buildlock --folder "$CONTAINER" --no-slot -- buildlock --folder "$DD" --); fi

T0=$(now)
# TEST_RUNNER_<name> in xcodebuild's environment reaches the test process as <name>.
STATUS=0
TEST_RUNNER_BCHESS_MAC_SNAPSHOT=1 TEST_RUNNER_BCHESS_SNAPSHOT_ONLY="$ONLY" \
${LOCK[@]+"${LOCK[@]}"} xcodebuild test -project BChess.xcodeproj -scheme "BChess (macOS)" -destination 'platform=macOS' \
  -derivedDataPath "$DD" -only-testing:BChessMacGalleryTests/MacGallerySuites/MacSnapshotGalleryTests \
  -parallel-testing-enabled NO -collect-test-diagnostics never -enableCodeCoverage NO -testLanguage en -testRegion US \
  > "$LOG" 2>&1 < /dev/null || STATUS=$?
T_TEST=$(now)
grep -E '^gallery: |error:|Test run with' "$LOG" | sed 's/^/  /' || true
[[ $STATUS == 0 ]] || fail "the snapshot test"
grep -q '^gallery: [0-9]* scenario' "$LOG" || fail "the snapshot test (no scenario was rendered)"

mkdir -p "$WORK/png"
NAMES="$(awk '$1 == "mac-gallery-file" { print $2 }' "$LOG" | sort -u)"
[[ -n "$NAMES" ]] || fail "the test printed no file"
for name in $NAMES; do
  awk -v n="$name" '$1 == "mac-gallery-file" && $2 == n { printf "%s", $3 }' "$LOG" | base64 -D > "$WORK/png/$name"
done
[[ -f "$WORK/png/manifest.json" ]] || fail "the test printed no manifest"

PREVIEW_GALLERY_OUT="$OUT" python3 scripts/preview-gallery.py --import "$WORK/png" ${ONLY:+--partial}
PREVIEW_GALLERY_OUT="$OUT" python3 scripts/preview-gallery.py --check
rm -f "$LOG"
echo "network: none (I5)"
echo "timings: build+test $(elapsed "$T0" "$T_TEST"), total $(elapsed "$T0" "$(now)")"
if [[ $OPEN_PAGE == 1 ]]; then open "$OUT/index.html"; fi
