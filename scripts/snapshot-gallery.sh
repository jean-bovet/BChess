#!/bin/bash
# Renders every gallery scenario (light + dark) with one run of BChessGalleryTests' SnapshotGalleryTests on an
# iOS simulator, imports the PNGs into previews/ and checks the gallery.
#
# Usage: scripts/snapshot-gallery.sh [--only PATTERN] [--keep-booted] [--no-open] [simulator name or id]
#        scripts/snapshot-gallery.sh --shutdown [simulator name or id]
#   (default simulator: "BChess Agent", created from the iPhone 17 Pro device type when missing)
#   --only PATTERN  comma-separated substrings of scenario names or slugs; renders just those and imports
#                   them over the existing previews/ (the check still covers every scenario)
#   --keep-booted   leave the simulator booted for the next run (default: shut it down at the end)
#   --no-open       do not open previews/index.html at the end
#   --shutdown      only shut the simulator down (after a series of --keep-booted runs) and exit
#
# One simulator at a time (global rule): a simulator this script did not boot is never touched; if another
# one is running, the script waits up to 10 minutes, then stops.
#
# DerivedData is persistent (BCHESS_SNAPSHOT_DD, default ~/Library/Developer/Xcode/DerivedData/BChess-snapshots):
# build-for-testing is incremental and test-without-building runs only the snapshot test.
set -euo pipefail
cd "$(dirname "$0")/.."

KEEP=0; ONLY_SHUTDOWN=0; OPEN_PAGE=1; ONLY=""; SIM="BChess Agent"
while [[ $# -gt 0 ]]; do
  case "$1" in
    --only) [[ $# -ge 2 ]] || { echo "--only needs a pattern" >&2; exit 2; }; ONLY="$2"; shift 2 ;;
    --keep-booted) KEEP=1; shift ;;
    --no-open) OPEN_PAGE=0; shift ;;
    --shutdown) ONLY_SHUTDOWN=1; shift ;;
    -*) echo "unknown option: $1" >&2; exit 2 ;;
    *) SIM="$1"; shift ;;
  esac
done

# The one place that may fail the run: a failing simctl must abort, never read as "nothing booted"
AVAILABLE="$(xcrun simctl list devices available)"
udid_of() { printf '%s\n' "$AVAILABLE" | grep -F "    $1 (" | head -1 | sed -E 's/.*\(([0-9A-F-]{36})\).*/\1/'; }
if [[ "$SIM" =~ ^[0-9A-F-]{36}$ ]]; then UDID="$SIM"; else UDID="$(udid_of "$SIM" || true)"; fi

DD="${BCHESS_SNAPSHOT_DD:-$HOME/Library/Developer/Xcode/DerivedData/BChess-snapshots}"
mkdir -p "$DD"
# Names the simulator this script booted, so only it shuts that one down (here, in a later --shutdown, or on
# exit). It lives outside DerivedData, per simulator, so ownership survives any BCHESS_SNAPSHOT_DD. Set only
# once the UDID is known (set_marker), never with an empty one.
MARKER=""
set_marker() { MARKER="${TMPDIR:-/tmp}/bchess-snapshot-gallery.$UDID.booted"; }
owned() { [[ -n "$UDID" && -n "$MARKER" && -f "$MARKER" && "$(cat "$MARKER")" == "$UDID" ]]; }
release() {
  owned || return 0
  if xcrun simctl shutdown "$UDID" 2>/dev/null; then rm -f "$MARKER"; return 0; fi
  # A device that is already shut down is also released; anything else keeps the marker
  if STATE="$(xcrun simctl list devices booted)" && ! printf '%s\n' "$STATE" | grep -q -F "$UDID"; then rm -f "$MARKER"; return 0; fi
  echo "Could not shut down $UDID; keeping $MARKER so a later --shutdown can retry." >&2
  return 1
}

if [[ $ONLY_SHUTDOWN == 1 ]]; then
  # Never creates a simulator, and stops only one this script booted
  if [[ -n "$UDID" ]]; then set_marker; fi
  if owned; then release || exit 1; else echo "This script did not boot ${SIM}; leaving it alone."; fi
  exit 0
fi
if [[ -z "$UDID" ]]; then
  UDID="$(xcrun simctl create "$SIM" "iPhone 17 Pro")"
fi
set_marker

# One simulator at a time on this Mac: never boot beside another one, never shut down one we did not boot.
# Wait up to 10 minutes for the others to go away.
# A failing listing must abort the run, never read as "nothing booted" (a command substitution hides errexit).
list_booted() {
  BOOTED="$(xcrun simctl list devices booted)" || { echo "Could not list the booted simulators; not booting anything." >&2; exit 1; }
}
others() { printf '%s\n' "$BOOTED" | grep -E '\([0-9A-F-]{36}\)' | grep -v -F "$UDID" || true; }
OTHERS=""
for _ in $(seq 1 40); do
  list_booted
  OTHERS="$(others)"
  [[ -z "$OTHERS" ]] && break
  echo "Another simulator is booted; waiting 15 s (it is not ours to stop):" >&2
  echo "$OTHERS" >&2
  sleep 15
done
if [[ -n "$OTHERS" ]]; then
  echo "Another simulator is still booted after 10 minutes; not booting a second one." >&2
  exit 1
fi

WORK="$(mktemp -d "${TMPDIR:-/tmp}/bchess-snapshots.XXXXXX")"
LOG="$WORK.log"   # outside $WORK: kept on a failure, deleted on a success
cleanup() {
  local status=$?
  rm -rf "$WORK"
  # A simulator that was already booted when we started, or one the caller asked to keep, stays up.
  # A failed shutdown keeps the marker and fails the script, also after a successful run.
  if [[ $KEEP == 0 ]] && ! release; then status=1; fi
  exit "$status"
}
trap cleanup EXIT

now() { python3 -c 'import time; print(time.time())'; }
elapsed() { python3 -c "print(f'{$2 - $1:.1f} s')"; }
fail() { echo "$1 failed (log: $LOG)" >&2; tail -30 "$LOG" >&2; exit 1; }

T0=$(now)
list_booted   # fresh: another simulator may have booted since the wait loop; never boot beside it
OTHERS="$(others)"
if [[ -n "$OTHERS" ]]; then
  echo "Another simulator booted meanwhile; not booting a second one (it is not ours to stop):" >&2
  echo "$OTHERS" >&2
  exit 1
fi
# The marker is written only for a simulator the listing shows as not booted
if ! printf '%s\n' "$BOOTED" | grep -q -F "$UDID"; then echo "$UDID" > "$MARKER"; fi
xcrun simctl bootstatus "$UDID" -b > /dev/null 2>&1   # boots when needed, returns when ready
T_BOOT=$(now)
xcodebuild build-for-testing -project BChess.xcodeproj -scheme "BChess (iOS)" -destination "id=$UDID" \
  -derivedDataPath "$DD" -enableCodeCoverage NO > "$LOG" 2>&1 || fail "build-for-testing"
T_BUILD=$(now)
# TEST_RUNNER_<name> in xcodebuild's environment reaches the test process as <name>.
set +e
TEST_RUNNER_BCHESS_SNAPSHOT_DIR="$WORK/png" TEST_RUNNER_BCHESS_SNAPSHOT_ONLY="$ONLY" \
xcodebuild test-without-building -project BChess.xcodeproj -scheme "BChess (iOS)" \
  -destination "id=$UDID" -derivedDataPath "$DD" -parallel-testing-enabled NO -enableCodeCoverage NO -testLanguage en \
  -only-testing:BChessGalleryTests/GallerySuites/SnapshotGalleryTests > "$LOG" 2>&1
STATUS=$?
set -e
T_TEST=$(now)
grep -E '^gallery: |error:|Test run with' "$LOG" | sed 's/^/  /' || true
[[ $STATUS == 0 ]] || fail "the snapshot test"
grep -q '^gallery: [0-9]* scenario' "$LOG" || fail "the snapshot test (no scenario was rendered)"

python3 scripts/preview-gallery.py --import "$WORK/png" ${ONLY:+--partial}
python3 scripts/preview-gallery.py --check
rm -f "$LOG"
echo "network: none (I5)"
echo "timings: boot $(elapsed "$T0" "$T_BOOT"), build $(elapsed "$T_BOOT" "$T_BUILD"), test $(elapsed "$T_BUILD" "$T_TEST"), total $(elapsed "$T0" "$(now)")"
if [[ $OPEN_PAGE == 1 ]]; then open previews/index.html; fi
