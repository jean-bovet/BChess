#!/bin/bash
# Renders every gallery scenario (light + dark) with one run of BChessGalleryTests' SnapshotGalleryTests on an
# iOS simulator, imports the PNGs into previews/ and checks the gallery. $SIMULATOR_UDID, when set, is the
# simulator to use: it is never leased and never released (the caller's).
#
# Usage: scripts/snapshot-gallery.sh [--device iphone|duo] [--only PATTERN] [--keep-booted] [--no-open] [simulator name or id]
#        scripts/snapshot-gallery.sh --shutdown [simulator name or id]
#   --device D      iphone (default): the iPhone 17 Pro gallery in previews/. duo: the Duo pass, an iPhone Duo (iOS
#                   27.1, folded: the outer display, 466 x 678 pt) renders every card and the inner-display ones at
#                   3x into previews/duo/ (the iPhone gallery stays untouched); anything else exits 2
#   --only PATTERN  comma-separated substrings of scenario names or slugs; renders just those and imports
#                   them over the existing previews/ (the check still covers every scenario)
#   --keep-booted   fallback only: leave the simulator booted for the next run (default: shut it down at the end)
#   --no-open       do not open previews/index.html at the end
#   --shutdown      fallback only: shut the simulator down (after a series of --keep-booted runs) and exit
#
# The simulator comes from the machine-wide pool when `simpool` and `buildlock` are both on PATH: `simpool acquire
# --spec iphone` (iPhone 17 Pro, iOS 27.0) leases a booted simulator to this script, waiting when the pool is full,
# and the cleanup gives it back with `simpool release` (still booted) on success, failure and INT/TERM/HUP. The
# script then never creates, boots, shuts down or erases a simulator (a simulator name or id argument is ignored),
# and both xcodebuild commands run under `buildlock` on the DerivedData folder (the test without a build slot).
#
# Fallback, without those tools: the simulator named on the command line, by default "BChess Agent" (created
# from the iPhone 17 Pro device type when missing). One simulator at a time: a simulator this script did not
# boot is never touched; if another one is running, the script waits up to 10 minutes, then stops.
#
# DerivedData is persistent (BCHESS_SNAPSHOT_DD, default ~/Library/Developer/Xcode/DerivedData/BChess-snapshots):
# build-for-testing is incremental and test-without-building runs only the snapshot test.
#
# The Mac stays awake for the whole run (`caffeinate -dims`, bound to this process so it ends with it): a run during
# which the Mac slept took three times as long.
set -euo pipefail
cd "$(dirname "$0")/.."
if command -v caffeinate > /dev/null; then caffeinate -dims -w $$ & fi

KEEP=0; ONLY_SHUTDOWN=0; OPEN_PAGE=1; ONLY=""; SIM=""; DEVICE=iphone
while [[ $# -gt 0 ]]; do
  case "$1" in
    --device) [[ $# -ge 2 ]] || { echo "--device needs iphone or duo" >&2; exit 2; }; DEVICE="$2"; shift 2 ;;
    --only) [[ $# -ge 2 ]] || { echo "--only needs a pattern" >&2; exit 2; }; ONLY="$2"; shift 2 ;;
    --keep-booted) KEEP=1; shift ;;
    --no-open) OPEN_PAGE=0; shift ;;
    --shutdown) ONLY_SHUTDOWN=1; shift ;;
    -*) echo "unknown option: $1" >&2; exit 2 ;;
    *) SIM="$1"; shift ;;
  esac
done
case "$DEVICE" in
  iphone) DEFAULT_SIM="BChess Agent" ;;
  duo) DEFAULT_SIM="BChess Agent Duo" ;;
  *) echo "unknown device: $DEVICE (iphone or duo)" >&2; exit 2 ;;
esac
[[ -n "$SIM" ]] || SIM="$DEFAULT_SIM"
# The gallery's folder: the Duo pass has its own, inside previews/
OUT="previews"
if [[ $DEVICE == duo ]]; then OUT="previews/duo"; fi
export PREVIEW_GALLERY_OUT="$OUT"

# The machine-wide simulator pool and build lock, when both are installed.
POOL=0
if command -v simpool > /dev/null && command -v buildlock > /dev/null; then POOL=1; fi
APP_BUNDLE_ID="ch.arizona-software.BChess"
DD="${BCHESS_SNAPSHOT_DD:-$HOME/Library/Developer/Xcode/DerivedData/BChess-snapshots}"

if [[ $POOL == 1 ]]; then
  if [[ $ONLY_SHUTDOWN == 1 ]]; then
    echo "--shutdown: simulators come from the pool (simpool), which shuts them down itself; nothing done" >&2
    exit 0
  fi
  [[ $KEEP == 1 ]] && echo "--keep-booted: the pool keeps its simulators booted anyway" >&2
  [[ $SIM != "$DEFAULT_SIM" ]] && echo "$SIM: ignored, the simulator comes from the pool (spec $DEVICE)" >&2
  mkdir -p "$DD"
else
# --- fallback: the script's own simulator ---
# The one place that may fail the run: a failing simctl must abort, never read as "nothing booted"
AVAILABLE="$(xcrun simctl list devices available)"
udid_of() { printf '%s\n' "$AVAILABLE" | grep -F "    $1 (" | head -1 | sed -E 's/.*\(([0-9A-F-]{36})\).*/\1/'; }
# A caller-supplied simulator is borrowed in this mode too: never marked, created, booted, shut down or released
CALLER_SIM=0
if [[ -n "${SIMULATOR_UDID:-}" ]]; then CALLER_SIM=1; SIM="$SIMULATOR_UDID"; fi
if [[ $CALLER_SIM == 1 ]]; then UDID="$SIMULATOR_UDID"
elif [[ "$SIM" =~ ^[0-9A-F-]{36}$ ]]; then UDID="$SIM"; else UDID="$(udid_of "$SIM" || true)"; fi

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
  if [[ -n "$UDID" && $CALLER_SIM == 0 ]]; then set_marker; fi
  if owned; then release || exit 1; else echo "This script did not boot ${SIM}; leaving it alone."; fi
  exit 0
fi
if [[ -z "$UDID" ]]; then
  if [[ $DEVICE == duo ]]; then
    # The iPhone Duo device type exists on the iOS 27.1 runtime only
    UDID="$(xcrun simctl create "$SIM" "iPhone Duo" "com.apple.CoreSimulator.SimRuntime.iOS-27-1")"
  else
    UDID="$(xcrun simctl create "$SIM" "iPhone 17 Pro")"
  fi
fi
if [[ $CALLER_SIM == 0 ]]; then set_marker; fi

# One simulator at a time on this Mac: never boot beside another one, never shut down one we did not boot.
# Wait up to 10 minutes for the others to go away.
# A failing listing must abort the run, never read as "nothing booted" (a command substitution hides errexit).
list_booted() {
  BOOTED="$(xcrun simctl list devices booted)" || { echo "Could not list the booted simulators; not booting anything." >&2; exit 1; }
}
others() { printf '%s\n' "$BOOTED" | grep -E '\([0-9A-F-]{36}\)' | grep -v -F "$UDID" || true; }
OTHERS=""
for _ in $(seq 1 40); do
  [[ $CALLER_SIM == 1 ]] && break   # nothing to boot beside the caller's simulator
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
fi   # fallback

WORK="$(mktemp -d "${TMPDIR:-/tmp}/bchess-snapshots.XXXXXX")"
LOG="$WORK.log"   # outside $WORK: kept on a failure, deleted on a success
CHILD=""         # the running xcodebuild (or simpool acquire), stopped by the cleanup
LEASE_OUT=""     # the file a running `simpool acquire` prints its UDID to (read by the cleanup too)
LEASED=""        # the pool simulator to give back
cleanup() {
  local status=$?
  trap - EXIT INT TERM HUP
  if [[ -n "$CHILD" ]]; then
    # TERM first (buildlock passes it on to xcodebuild); KILL after BCHESS_SNAPSHOT_KILL_GRACE seconds (10).
    kill "$CHILD" 2>/dev/null || true
    for _ in $(seq 1 $(( ${BCHESS_SNAPSHOT_KILL_GRACE:-10} * 10 ))); do
      kill -0 "$CHILD" 2>/dev/null || break
      sleep 0.1
    done
    if kill -0 "$CHILD" 2>/dev/null; then kill -KILL "$CHILD" 2>/dev/null || true; fi
    wait "$CHILD" 2>/dev/null || true
  fi
  if [[ $POOL == 1 ]]; then
    # A lease granted while the script was being signalled is given back too.
    if [[ -n "$LEASE_OUT" ]]; then LEASED="$(cat "$LEASE_OUT" 2>/dev/null || true)"; fi
    if [[ -n "$LEASED" ]]; then
      simpool release "$LEASED" --app "$APP_BUNDLE_ID" \
        || { echo "Could not give simulator $LEASED back to the pool (simpool status)." >&2; status=1; }
    fi
  # A simulator that was already booted when we started, or one the caller asked to keep, stays up.
  # A failed shutdown keeps the marker and fails the script, also after a successful run.
  elif [[ $KEEP == 0 ]] && ! release; then status=1; fi
  rm -rf "$WORK"
  exit "$status"
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
trap 'exit 129' HUP

# xcodebuild, its output in $LOG: under buildlock on the DerivedData folder with the pool (a build takes a build
# slot, a test does not). In the background and waited for, so a signal reaches the cleanup, which stops it.
run_xcodebuild() {   # $1 = build|test, rest = xcodebuild arguments
  local kind="$1" rc=0 lock
  shift
  if [[ $POOL == 1 ]]; then
    lock=(--folder "$DD" --log "$LOG")
    [[ $kind == test ]] && lock+=(--no-slot)
    : > "$LOG"
    buildlock "${lock[@]}" -- xcodebuild "$@" < /dev/null &
  else
    xcodebuild "$@" > "$LOG" 2>&1 < /dev/null &
  fi
  CHILD=$!
  wait "$CHILD" || rc=$?
  CHILD=""
  return "$rc"
}

now() { python3 -c 'import time; print(time.time())'; }
elapsed() { python3 -c "print(f'{$2 - $1:.1f} s')"; }
fail() { echo "$1 failed (log: $LOG)" >&2; tail -30 "$LOG" >&2; exit 1; }

T0=$(now)
if [[ $POOL == 1 && -n "${SIMULATOR_UDID:-}" ]]; then
  # The caller's simulator: used as is, never leased or released
  UDID="$SIMULATOR_UDID"
  echo "using simulator $UDID (SIMULATOR_UDID)"
elif [[ $POOL == 1 ]]; then
  # Leased to this script's process ($$): waits, interruptibly, while the pool is full.
  LEASE_OUT="$WORK/lease"
  : > "$LEASE_OUT"
  rc=0
  simpool acquire --spec "$DEVICE" --pid $$ > "$LEASE_OUT" < /dev/null &
  CHILD=$!
  wait "$CHILD" || rc=$?
  CHILD=""
  LEASED="$(cat "$LEASE_OUT")"; LEASE_OUT=""
  UDID="$LEASED"
  if [[ $rc != 0 || -z "$UDID" ]]; then
    # Exit 1, not simpool's 75 (a wait that ran out): a wrapper under buildlock would read 75 as its own lock wait.
    echo "No $DEVICE simulator from the pool (simpool exit $rc; simpool status shows who holds them)." >&2
    exit 1
  fi
  echo "leased simulator $UDID from the pool"
elif [[ $CALLER_SIM == 1 ]]; then
  echo "using simulator $UDID (SIMULATOR_UDID)"
else
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
fi
T_BOOT=$(now)
run_xcodebuild build build-for-testing -project BChess.xcodeproj -scheme "BChess (iOS)" -destination "id=$UDID" \
  -derivedDataPath "$DD" -enableCodeCoverage NO || fail "build-for-testing"
T_BUILD=$(now)
# TEST_RUNNER_<name> in xcodebuild's environment reaches the test process as <name>.
STATUS=0
TEST_RUNNER_BCHESS_SNAPSHOT_DIR="$WORK/png" TEST_RUNNER_BCHESS_SNAPSHOT_ONLY="$ONLY" \
TEST_RUNNER_BCHESS_SNAPSHOT_DEVICE="$DEVICE" \
run_xcodebuild test test-without-building -project BChess.xcodeproj -scheme "BChess (iOS)" \
  -destination "id=$UDID" -derivedDataPath "$DD" -parallel-testing-enabled NO -collect-test-diagnostics never -enableCodeCoverage NO \
  -testLanguage en -testRegion US \
  -only-testing:BChessGalleryTests/GallerySuites/SnapshotGalleryTests || STATUS=$?
T_TEST=$(now)
grep -E '^gallery: |error:|Test run with' "$LOG" | sed 's/^/  /' || true
[[ $STATUS == 0 ]] || fail "the snapshot test"
grep -q '^gallery: [0-9]* scenario' "$LOG" || fail "the snapshot test (no scenario was rendered)"

python3 scripts/preview-gallery.py --import "$WORK/png" ${ONLY:+--partial}
python3 scripts/preview-gallery.py --check
rm -f "$LOG"
echo "network: none (I5)"
[[ $POOL == 1 ]] && BOOT_LABEL=lease || BOOT_LABEL=boot
echo "timings: $BOOT_LABEL $(elapsed "$T0" "$T_BOOT"), build $(elapsed "$T_BOOT" "$T_BUILD"), test $(elapsed "$T_BUILD" "$T_TEST"), total $(elapsed "$T0" "$(now)")"
if [[ $OPEN_PAGE == 1 ]]; then open "$OUT/index.html"; fi
