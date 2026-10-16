#!/bin/bash
# Lifecycle checks for scripts/snapshot-gallery.sh: stub `xcrun`, `xcodebuild`, `simpool` and `buildlock` answer from
# a state file and log every call, so no real simulator or build is touched. PATH is the stubs plus the system
# directories only, so a real `simpool` / `buildlock` is never reached: the fallback cases run without them, the pool_*
# cases add stubs of both (pool_setup). The script under test runs from a scratch tree whose
# scripts/preview-gallery.py is a stub too (previews/ of the checkout is never written).
#
#   scripts/test_snapshot_gallery.sh [case ...]                 # all cases, or the named ones
#   SNAPSHOT_GALLERY_SCRIPT=/path/to/copy scripts/test_snapshot_gallery.sh   # test a mutated copy
set -u
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SCRIPT="${SNAPSHOT_GALLERY_SCRIPT:-$ROOT/scripts/snapshot-gallery.sh}"
FAILED=0
UDID="11111111-2222-3333-4444-555555555555"
POOL_UDID="77777777-0000-0000-0000-000000000000"

setup() {   # $1 = state of the "BChess Agent" simulator: Booted | Shutdown | missing
    T="$(mktemp -d)"
    mkdir -p "$T/bin"
    export TMPDIR="$T" STUB_LOG="$T/calls.log" STUB_STATE="$T/state" BCHESS_SNAPSHOT_DD="$T/dd" BCHESS_SNAPSHOT_KILL_GRACE=1 \
        STUB_UDID="$UDID"
    unset STUB_BUILD_FAIL STUB_TEST_MODE STUB_BUILD_BLOCK STUB_TEST_BLOCK STUB_ACQUIRE_FAIL STUB_ACQUIRE_BLOCK STUB_CHECK
    : > "$STUB_LOG"
    if [ "$1" = missing ]; then : > "$STUB_STATE"; else echo "$1" > "$STUB_STATE"; fi
    # The state file holds the simulator's state (Booted|Shutdown); empty = it does not exist.
    cat > "$T/bin/xcrun" <<'STUB'
#!/bin/bash
echo "$*" >> "$STUB_LOG"
[ "$1" = simctl ] || exit 99
state="$(cat "$STUB_STATE")"
case "$2" in
    list)
        echo "== Devices =="; echo "-- iOS 27.0 --"
        if [ -n "$state" ] && { [ "$3 $4" = "devices available" ] || [ "$state" = Booted ]; }; then
            echo "    BChess Agent ($STUB_UDID) ($state)"
        fi ;;
    create) echo Shutdown > "$STUB_STATE"; echo "$STUB_UDID" ;;
    bootstatus) echo Booted > "$STUB_STATE" ;;
    shutdown) echo Shutdown > "$STUB_STATE" ;;
esac
exit 0
STUB
    cat > "$T/bin/xcodebuild" <<'STUB'
#!/bin/bash
echo "xcodebuild $*" >> "$STUB_LOG"
case "$1" in
    build-for-testing)
        [ -n "${STUB_BUILD_BLOCK:-}" ] && { echo $$ > "$TMPDIR/xcb.pid"; exec sleep 60; }
        [ -n "${STUB_BUILD_FAIL:-}" ] && exit 1
        exit 0 ;;
    test-without-building)
        [ -n "${STUB_TEST_BLOCK:-}" ] && { echo $$ > "$TMPDIR/xcb.pid"; exec sleep 60; }
        [ "${STUB_TEST_MODE:-ok}" = fail ] && exit 1
        mkdir -p "$TEST_RUNNER_BCHESS_SNAPSHOT_DIR"; echo '[]' > "$TEST_RUNNER_BCHESS_SNAPSHOT_DIR/manifest.json"
        echo "gallery: 0 scenario(s) rendered"
        exit 0 ;;
esac
exit 0
STUB
    chmod +x "$T/bin/"*
    export PATH="$T/bin:/usr/bin:/bin:/usr/sbin:/sbin"
    MARKER="$T/bchess-snapshot-gallery.$UDID.booted"
    TREE="$T/tree"; mkdir -p "$TREE/scripts"
    cp "$SCRIPT" "$TREE/scripts/snapshot-gallery.sh"
    cat > "$TREE/scripts/preview-gallery.py" <<'STUB'
import os, sys
if '--import' in sys.argv:
    sys.exit(0 if os.path.isfile(os.path.join(sys.argv[sys.argv.index('--import') + 1], 'manifest.json')) else 1)
if os.environ.get('STUB_CHECK') == 'fail':
    print('CHECK FAILED [en] (1):'); sys.exit(1)
print('CHECK OK [en]: 0 cards')
STUB
}

# The pool tools: `simpool acquire` prints POOL_UDID (or fails with 75, or blocks), `buildlock` runs the command after
# `--`, its output appended to --log.
pool_setup() {
    setup Shutdown
    cat > "$T/bin/simpool" <<'STUB'
#!/bin/bash
echo "simpool $*" >> "$STUB_LOG"
case "$1" in
    acquire)
        [ -n "${STUB_ACQUIRE_FAIL:-}" ] && { echo "simpool: no simulator within the wait" >&2; exit 75; }
        [ -n "${STUB_ACQUIRE_BLOCK:-}" ] && { echo $$ > "$TMPDIR/acquire.pid"; exec sleep 60; }
        echo "77777777-0000-0000-0000-000000000000" ;;
    release) ;;
    *) exit 2 ;;
esac
STUB
    cat > "$T/bin/buildlock" <<'STUB'
#!/bin/bash
echo "buildlock $*" >> "$STUB_LOG"
log=""
while [ "$1" != -- ]; do
    case "$1" in --log) log="$2"; shift 2 ;; --folder|--wait) shift 2 ;; *) shift ;; esac
done
shift
if [ -n "$log" ]; then exec "$@" >> "$log" 2>&1; else exec "$@"; fi
STUB
    chmod +x "$T/bin/simpool" "$T/bin/buildlock"
}

expect() {   # $1 = case name, $2 = condition description, rest = test command
    local name="$1" what="$2"; shift 2
    if "$@"; then echo "ok   $name: $what"; else echo "FAIL $name: $what"; FAILED=1; fi
}
called() { grep -q -- "$1" "$STUB_LOG"; }
not_called() { ! called "$1"; }
state_is() { [ "$(cat "$STUB_STATE")" = "$1" ]; }
gallery() { "$TREE/scripts/snapshot-gallery.sh" "$@" > "$T/out.log" 2>&1; }

# --- fallback: no simpool / buildlock on PATH, the script's own simulator ---

fallback_run() {   # creates the missing simulator, boots it, renders, shuts it down; xcodebuild without buildlock
    setup missing
    gallery --no-open; local status=$?
    expect fallback_run "exits zero" [ "$status" = 0 ]
    expect fallback_run "reached CHECK OK" grep -q "CHECK OK" "$T/out.log"
    expect fallback_run "created its simulator" called "simctl create BChess Agent"
    expect fallback_run "booted it" called "simctl bootstatus $UDID -b"
    expect fallback_run "tested on it, no parallel testing" called "xcodebuild test-without-building .*-destination id=$UDID .*-parallel-testing-enabled NO"
    expect fallback_run "shut it down" called "simctl shutdown $UDID"
    expect fallback_run "left it shut down" state_is Shutdown
    expect fallback_run "no pool, no buildlock" not_called "simpool\|buildlock"
}

fallback_keep_booted() {
    setup Shutdown
    gallery --keep-booted --no-open; local status=$?
    expect fallback_keep_booted "exits zero" [ "$status" = 0 ]
    expect fallback_keep_booted "left it booted" state_is Booted
    expect fallback_keep_booted "no shutdown" not_called "simctl shutdown"
    gallery --shutdown; status=$?
    expect fallback_keep_booted "--shutdown exits zero" [ "$status" = 0 ]
    expect fallback_keep_booted "--shutdown shut it down" state_is Shutdown
}

fallback_borrowed() {   # booted by somebody else: used, never shut down
    setup Booted
    gallery --no-open; local status=$?
    expect fallback_borrowed "exits zero" [ "$status" = 0 ]
    expect fallback_borrowed "not shut down" not_called "simctl shutdown"
}

fallback_test_fails() {
    setup Shutdown
    STUB_TEST_MODE=fail gallery --no-open; local status=$?
    expect fallback_test_fails "exits non-zero" [ "$status" != 0 ]
    expect fallback_test_fails "shut its simulator down" state_is Shutdown
}

# --- the pool: a lease from simpool, builds under buildlock, never a simulator of its own ---

no_simctl_lifecycle() {   # $1 = case
    expect "$1" "no simctl create, boot, shutdown or erase" not_called "simctl \(create\|boot\|bootstatus\|shutdown\|erase\)"
    expect "$1" "no marker written" bash -c '! ls "$0"/bchess-snapshot-gallery.* >/dev/null 2>&1' "$T"
}

pool_run() {
    pool_setup
    gallery --no-open; local status=$?
    expect pool_run "exits zero" [ "$status" = 0 ]
    expect pool_run "reached CHECK OK" grep -q "CHECK OK" "$T/out.log"
    expect pool_run "leased an iphone for its own process" called "simpool acquire --spec iphone --pid "
    expect pool_run "built under buildlock on the DerivedData folder" called "buildlock --folder $T/dd --log .* -- xcodebuild build-for-testing"
    expect pool_run "tested under buildlock without a build slot" called "buildlock --folder $T/dd --log .* --no-slot -- xcodebuild test-without-building"
    expect pool_run "on the leased simulator, no parallel testing" called "xcodebuild test-without-building .*-destination id=$POOL_UDID .*-parallel-testing-enabled NO"
    expect pool_run "released the lease" called "simpool release $POOL_UDID --app ch.arizona-software.BChess"
    expect pool_run "released after the test" bash -c 'grep -n "test-without-building\|simpool release" "$0" | tail -1 | grep -q "simpool release"' "$STUB_LOG"
    no_simctl_lifecycle pool_run
}

pool_options() {   # --keep-booted and --shutdown are no-ops with the pool
    pool_setup
    gallery --keep-booted --no-open; local status=$?
    expect pool_options "--keep-booted exits zero" [ "$status" = 0 ]
    expect pool_options "--keep-booted says the pool keeps it booted" grep -q "the pool keeps its simulators booted" "$T/out.log"
    expect pool_options "released the lease" called "simpool release $POOL_UDID"
    gallery --shutdown; status=$?
    expect pool_options "--shutdown exits zero" [ "$status" = 0 ]
    expect pool_options "--shutdown says nothing done" grep -q "nothing done" "$T/out.log"
    expect pool_options "no simctl call at all" not_called "simctl"
    no_simctl_lifecycle pool_options
}

pool_acquire_fails() {   # no simulator within simpool's wait: fails with 1, nothing built, nothing released
    pool_setup
    STUB_ACQUIRE_FAIL=1 gallery --no-open; local status=$?
    expect pool_acquire_fails "exits 1 (not simpool's 75)" [ "$status" = 1 ]
    expect pool_acquire_fails "says so" grep -q "No iphone simulator from the pool" "$T/out.log"
    expect pool_acquire_fails "no build started" not_called xcodebuild
    expect pool_acquire_fails "nothing to release" not_called "simpool release"
    no_simctl_lifecycle pool_acquire_fails
}

pool_failed_expects() {   # $1 = case, $2 = status
    expect "$1" "exits non-zero" [ "$2" != 0 ]
    expect "$1" "released the lease" called "simpool release $POOL_UDID"
    no_simctl_lifecycle "$1"
}
pool_build_fails() { pool_setup; STUB_BUILD_FAIL=1 gallery --no-open; pool_failed_expects pool_build_fails $?
    expect pool_build_fails "no test started" not_called "xcodebuild test-without-building"; }
pool_test_fails() { pool_setup; STUB_TEST_MODE=fail gallery --no-open; pool_failed_expects pool_test_fails $?; }
pool_check_fails() { pool_setup; STUB_CHECK=fail gallery --no-open; pool_failed_expects pool_check_fails $?
    expect pool_check_fails "said CHECK FAILED" grep -q "CHECK FAILED" "$T/out.log"; }

pool_signalled() {   # $1 = signal, $2 = phase (acquire|build|test)
    local sig="$1" phase="$2" want block pidfile name="pool_signalled_$(echo "$1" | tr A-Z a-z)_$2"
    case "$sig" in INT) want=130 ;; TERM) want=143 ;; HUP) want=129 ;; esac
    pool_setup
    pidfile="$T/xcb.pid"
    case "$phase" in acquire) block=STUB_ACQUIRE_BLOCK; pidfile="$T/acquire.pid" ;; build) block=STUB_BUILD_BLOCK ;; test) block=STUB_TEST_BLOCK ;; esac
    # A background job ignores SIGINT: restore it, as a terminal's Ctrl-C would reach the script.
    env "$block=1" python3 -c 'import os, signal, sys; signal.signal(signal.SIGINT, signal.SIG_DFL); os.execv(sys.argv[1], sys.argv[1:])' \
        "$TREE/scripts/snapshot-gallery.sh" --no-open > "$T/out.log" 2>&1 &
    local pid=$! i
    for i in $(seq 1 100); do [ -s "$pidfile" ] && break; sleep 0.1; done
    kill -"$sig" "$pid"
    for i in $(seq 1 30); do kill -0 "$pid" 2>/dev/null || break; sleep 0.1; done
    expect "$name" "ended within 3 s of the signal" bash -c '! kill -0 "$0" 2>/dev/null' "$pid"
    expect "$name" "the blocking child was stopped" bash -c '! kill -0 "$(cat "$0")" 2>/dev/null' "$pidfile"
    kill -KILL "$pid" 2>/dev/null; [ -s "$pidfile" ] && kill -KILL "$(cat "$pidfile")" 2>/dev/null
    wait "$pid"; local status=$?
    expect "$name" "exits $want" [ "$status" = "$want" ]
    if [ "$phase" = acquire ]; then
        expect "$name" "no lease granted: nothing released" not_called "simpool release"
        expect "$name" "no build started" not_called xcodebuild
    else
        expect "$name" "released the lease" called "simpool release $POOL_UDID"
    fi
    no_simctl_lifecycle "$name"
}
pool_signalled_int_acquire() { pool_signalled INT acquire; }
pool_signalled_int_build() { pool_signalled INT build; }
pool_signalled_int_test() { pool_signalled INT test; }
pool_signalled_term_test() { pool_signalled TERM test; }
pool_signalled_hup_build() { pool_signalled HUP build; }

ALL="fallback_run fallback_keep_booted fallback_borrowed fallback_test_fails
pool_run pool_options pool_acquire_fails pool_build_fails pool_test_fails pool_check_fails
pool_signalled_int_acquire pool_signalled_int_build pool_signalled_int_test pool_signalled_term_test pool_signalled_hup_build"
for c in ${@:-$ALL}; do
    if declare -F "$c" > /dev/null; then "$c"; else echo "FAIL unknown case: $c"; FAILED=1; fi
    rm -rf "$T"
done
[ "$FAILED" = 0 ] && echo "all lifecycle checks passed"
exit "$FAILED"
