#!/bin/bash
# Renders every Mac scenario (BChessMacGalleryTests' MacSnapshotGalleryTests: the real document window and the
# Settings window in windows that are never on screen, drawn at 2x), light and dark, imports the PNGs into
# previews/mac/ and checks the gallery.
#
# Usage: scripts/snapshot-mac.sh [--only PATTERN] [--lang en,fr,he,...] [--no-open]
#   --only PATTERN  comma-separated substrings of scenario names or slugs; renders just those and imports
#                   them over the existing previews/mac/ (the check still covers every scenario)
#   --lang LIST     comma-separated languages (en, fr, de, it, he, ar; default en): one test run per language with
#                   -testLanguage <lang> -testRegion <region> (en US, fr FR, de DE, it IT, he IL, ar SA). English imports as always (and is
#                   checked); another language imports its PNGs into previews/mac/mac/<lang>/ (where the App Store renderer
#                   looks) with `preview-gallery.py --import DIR --lang <lang>`, no page, no check. The Mac gallery is six
#                   windows, so --lang needs no --only
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

OPEN_PAGE=1; ONLY=""; LANGS=en
while [[ $# -gt 0 ]]; do
  case "$1" in
    --only) ONLY="${2:?--only needs a pattern}"; shift 2 ;;
    --lang) [[ $# -ge 2 ]] || { echo "--lang needs a list of languages (en, fr, de, it, he, ar)" >&2; exit 2; }; LANGS="$2"; shift 2 ;;
    --no-open) OPEN_PAGE=0; shift ;;
    -h|--help) sed -n '2,/^set -euo/p' "$0" | sed '$d' | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "unknown option: $1" >&2; exit 2 ;;
  esac
done

# The languages: the whitelist and the region of each, shared with snapshot-gallery.sh
. scripts/languages.sh
parse_languages "$LANGS"

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
# TEST_RUNNER_<name> in xcodebuild's environment reaches the test process as <name>. One test run per language, its
# output decoded into its own folder and imported right after it.
CHECK_ENGLISH=0
for lang in "${LANG_LIST[@]}"; do
  STATUS=0
  TEST_RUNNER_BCHESS_MAC_SNAPSHOT=1 TEST_RUNNER_BCHESS_SNAPSHOT_ONLY="$ONLY" \
  ${LOCK[@]+"${LOCK[@]}"} xcodebuild test -project BChess.xcodeproj -scheme "BChess (macOS)" -destination 'platform=macOS' \
    -derivedDataPath "$DD" -only-testing:BChessMacGalleryTests/MacGallerySuites/MacSnapshotGalleryTests \
    -parallel-testing-enabled NO -collect-test-diagnostics never -enableCodeCoverage NO \
    -testLanguage "$lang" -testRegion "$(region "$lang")" \
    > "$LOG" 2>&1 < /dev/null || STATUS=$?
  T_TEST=$(now)
  [[ ${#LANG_LIST[@]} -gt 1 ]] && echo "language: $lang"
  grep -E '^gallery: |error:|Test run with' "$LOG" | sed 's/^/  /' || true
  [[ $STATUS == 0 ]] || fail "the snapshot test ($lang)"
  grep -q '^gallery: [0-9]* scenario' "$LOG" || fail "the snapshot test (no scenario was rendered, $lang)"

  PNG="$WORK/png-$lang"
  mkdir -p "$PNG"
  NAMES="$(awk '$1 == "mac-gallery-file" { print $2 }' "$LOG" | sort -u)"
  [[ -n "$NAMES" ]] || fail "the test printed no file ($lang)"
  for name in $NAMES; do
    awk -v n="$name" '$1 == "mac-gallery-file" && $2 == n { printf "%s", $3 }' "$LOG" | base64 -D > "$PNG/$name"
  done
  [[ -f "$PNG/manifest.json" ]] || fail "the test printed no manifest ($lang)"

  if [[ $lang == en ]]; then
    PREVIEW_GALLERY_OUT="$OUT" python3 scripts/preview-gallery.py --import "$PNG" ${ONLY:+--partial}
    CHECK_ENGLISH=1
  else
    PREVIEW_GALLERY_OUT="$OUT" python3 scripts/preview-gallery.py --import "$PNG" --lang "$lang"
  fi
done
if [[ $CHECK_ENGLISH == 1 ]]; then PREVIEW_GALLERY_OUT="$OUT" python3 scripts/preview-gallery.py --check; fi
rm -f "$LOG"
echo "network: none (I5)"
echo "timings: build+test $(elapsed "$T0" "$T_TEST"), total $(elapsed "$T0" "$(now)")"
if [[ $OPEN_PAGE == 1 ]]; then open "$OUT/index.html"; fi
