#!/bin/bash
# Renders every preview scenario (light + dark) with one run of BChessGalleryTests/SnapshotGalleryTests on an iOS
# simulator, imports the PNGs into previews/ and checks the gallery.
#
# Usage: scripts/snapshot-gallery.sh [--keep-booted] [--shutdown] [simulator name or id]
#   (default simulator: "BChess Agent", created from the iPhone 17 Pro device type when missing)
#   --keep-booted  leave the simulator booted for the next run (default: shut it down at the end)
#   --shutdown     only shut the simulator down (after a series of --keep-booted runs) and exit
#
# DerivedData is persistent (BCHESS_SNAPSHOT_DD, default ~/Library/Developer/Xcode/DerivedData/BChess-snapshots):
# build-for-testing is incremental and test-without-building runs only the snapshot class.
set -euo pipefail
cd "$(dirname "$0")/.."

KEEP=0; ONLY_SHUTDOWN=0; SIM="BChess Agent"
for arg in "$@"; do
  case "$arg" in
    --keep-booted) KEEP=1 ;;
    --shutdown) ONLY_SHUTDOWN=1 ;;
    *) SIM="$arg" ;;
  esac
done

# The one place that may fail the run: a failing simctl must abort, never read as "nothing booted"
AVAILABLE="$(xcrun simctl list devices available)"
udid_of() { printf '%s\n' "$AVAILABLE" | grep -F "    $1 (" | head -1 | sed -E 's/.*\(([0-9A-F-]{36})\).*/\1/'; }
if [[ "$SIM" =~ ^[0-9A-F-]{36}$ ]]; then UDID="$SIM"; else UDID="$(udid_of "$SIM" || true)"; fi

DD="${BCHESS_SNAPSHOT_DD:-$HOME/Library/Developer/Xcode/DerivedData/BChess-snapshots}"
mkdir -p "$DD"
# Names the simulator this script booted, so only it shuts that one down (here, in a later --shutdown, or on exit)
MARKER="$DD/booted-by-snapshot-gallery"
owned() { [[ -n "$UDID" && -f "$MARKER" && "$(cat "$MARKER")" == "$UDID" ]]; }
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
  if owned; then release || exit 1; else echo "This script did not boot ${SIM}; leaving it alone."; fi
  exit 0
fi
if [[ -z "$UDID" ]]; then
  UDID="$(xcrun simctl create "$SIM" "iPhone 17 Pro")"
fi

# One simulator at a time on this Mac: never boot beside another one, never shut down one we did not boot.
BOOTED="$(xcrun simctl list devices booted)"
OTHERS="$(printf '%s\n' "$BOOTED" | grep -E '\([0-9A-F-]{36}\)' | grep -v -F "$UDID" || true)"
if [[ -n "$OTHERS" ]]; then
  echo "Another simulator is booted; wait for it to shut down (it is not ours to stop):" >&2
  echo "$OTHERS" >&2
  exit 1
fi
if ! printf '%s\n' "$BOOTED" | grep -q -F "$UDID"; then printf '%s' "$UDID" > "$MARKER"; fi

WORK="$(mktemp -d "${TMPDIR:-/tmp}/bchess-snapshots.XXXXXX")"
cleanup() {
  rm -rf "$WORK"
  # A simulator that was already booted when we started, or one the caller asked to keep, stays up
  if [[ $KEEP == 0 ]]; then release || true; fi
}
trap cleanup EXIT

START=$(date +%s)
# The sources the render must match: recorded before the build, compared by --check
python3 scripts/preview-gallery.py --snapshot "$WORK/sources.json"
xcrun simctl bootstatus "$UDID" -b > /dev/null 2>&1   # boots when needed, returns when ready
BUILT=$(date +%s)
xcodebuild build-for-testing -project BChess.xcodeproj -scheme "BChess (iOS)" -destination "id=$UDID" \
  -derivedDataPath "$DD" > "$WORK/build.log" 2>&1 || { tail -30 "$WORK/build.log"; exit 1; }
TESTING=$(date +%s)
TEST_RUNNER_BCHESS_SNAPSHOT_DIR="$WORK/png" xcodebuild test-without-building -project BChess.xcodeproj -scheme "BChess (iOS)" \
  -destination "id=$UDID" -derivedDataPath "$DD" -parallel-testing-enabled NO \
  -only-testing:BChessGalleryTests/SnapshotGalleryTests > "$WORK/test.log" 2>&1 || { tail -30 "$WORK/test.log"; exit 1; }
RENDERED=$(date +%s)

python3 scripts/preview-gallery.py --import "$WORK/png" --sources "$WORK/sources.json"
echo "Gallery done in $(( $(date +%s) - START )) s (boot $(( BUILT - START )) s, build $(( TESTING - BUILT )) s, render $(( RENDERED - TESTING )) s)"
open previews/index.html
