#!/bin/bash
# Lifecycle checks for scripts/snapshot-gallery.sh: stub `xcrun`, `xcodebuild`, `simpool`, `buildlock` and `caffeinate`
# answer from a state file and log every call, so no real simulator or build is touched. PATH is the stubs plus the system
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
ORIG_PATH="$PATH"; ORIG_TMPDIR="${TMPDIR:-}"
UDID="11111111-2222-3333-4444-555555555555"
POOL_UDID="77777777-0000-0000-0000-000000000000"

setup() {   # $1 = state of the "BChess Agent" simulator: Booted | Shutdown | missing
    T="$(mktemp -d)"
    mkdir -p "$T/bin"
    export TMPDIR="$T" STUB_LOG="$T/calls.log" STUB_STATE="$T/state" BCHESS_SNAPSHOT_DD="$T/dd" BCHESS_SNAPSHOT_KILL_GRACE=1 \
        STUB_UDID="$UDID"
    unset SIMULATOR_UDID PREVIEW_GALLERY_OUT STUB_BUILD_FAIL STUB_TEST_MODE STUB_BUILD_BLOCK STUB_TEST_BLOCK STUB_ACQUIRE_FAIL STUB_ACQUIRE_BLOCK STUB_CHECK
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
echo "xcodebuild $* device=${TEST_RUNNER_BCHESS_SNAPSHOT_DEVICE:-}" >> "$STUB_LOG"
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
    cat > "$T/bin/caffeinate" <<'STUB'
#!/bin/bash
echo "caffeinate $*" >> "$STUB_LOG"
STUB
    chmod +x "$T/bin/"*
    export PATH="$T/bin:/usr/bin:/bin:/usr/sbin:/sbin"
    MARKER="$T/bchess-snapshot-gallery.$UDID.booted"
    TREE="$T/tree"; mkdir -p "$TREE/scripts"
    cp "$SCRIPT" "$TREE/scripts/snapshot-gallery.sh"
    cat > "$TREE/scripts/preview-gallery.py" <<'STUB'
import os, sys
if '--import' in sys.argv:
    out = os.environ.get('PREVIEW_GALLERY_OUT', 'previews')
    os.makedirs(out, exist_ok=True)
    open(os.path.join(out, 'index.html'), 'w').close()
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
    expect fallback_run "kept the Mac awake for its own lifetime" called "caffeinate -dims -w [0-9]"
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
    expect pool_run "tests in the US region, the iphone device, the snapshot test only" called "xcodebuild test-without-building .*-testRegion US .*-only-testing:BChessGalleryTests/GallerySuites/SnapshotGalleryTests device=iphone"
    expect pool_run "the page lands in previews/" test -f "$TREE/previews/index.html"
    expect pool_run "released the lease" called "simpool release $POOL_UDID --app ch.arizona-software.BChess"
    expect pool_run "released after the test" bash -c 'grep -n "test-without-building\|simpool release" "$0" | tail -1 | grep -q "simpool release"' "$STUB_LOG"
    expect pool_run "kept the Mac awake for its own lifetime" called "caffeinate -dims -w [0-9]"
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

pool_duo() {   # the Duo pass: a duo lease, device=duo, the page under previews/duo, the iPhone gallery untouched
    pool_setup
    gallery --device duo --no-open; local status=$?
    expect pool_duo "exits zero" [ "$status" = 0 ]
    expect pool_duo "leased a duo, never an iphone" called "simpool acquire --spec duo --pid "
    expect pool_duo "no iphone lease" not_called "spec iphone"
    expect pool_duo "tested with device=duo" called "xcodebuild test-without-building .*-testRegion US .*device=duo"
    expect pool_duo "the page is in previews/duo/index.html" test -f "$TREE/previews/duo/index.html"
    expect pool_duo "no page in previews/" bash -c '! test -e "$0/previews/index.html"' "$TREE"
    expect pool_duo "released the lease once" bash -c '[ "$(grep -c "simpool release" "$0")" = 1 ]' "$STUB_LOG"
    expect pool_duo "released the duo" called "simpool release $POOL_UDID"
    no_simctl_lifecycle pool_duo
}

unknown_device() {   # --device watch: exit 2 before any lease or build
    pool_setup
    gallery --device watch --no-open; local status=$?
    expect unknown_device "exits 2" [ "$status" = 2 ]
    expect unknown_device "says so" grep -q "unknown device" "$T/out.log"
    expect unknown_device "no lease" not_called "simpool"
    expect unknown_device "no build" not_called "xcodebuild"
    no_simctl_lifecycle unknown_device
}

simulator_udid() {   # SIMULATOR_UDID: used as is, never leased, never released
    pool_setup
    SIMULATOR_UDID="99999999-0000-0000-0000-000000000000" gallery --no-open; local status=$?
    expect simulator_udid "exits zero" [ "$status" = 0 ]
    expect simulator_udid "no lease" not_called "simpool acquire"
    expect simulator_udid "tested on that id" called "xcodebuild test-without-building .*-destination id=99999999-0000-0000-0000-000000000000 "
    expect simulator_udid "no release" not_called "simpool release"
    no_simctl_lifecycle simulator_udid
}

fallback_udid() {   # SIMULATOR_UDID without the pool: used as is, never marked, booted, shut down or released
    setup Booted
    echo "$UDID" > "$MARKER"   # a stale marker of an earlier run must not make it ours
    SIMULATOR_UDID="$UDID" gallery --no-open; local status=$?
    expect fallback_udid "exits zero" [ "$status" = 0 ]
    expect fallback_udid "tested on that id" called "xcodebuild test-without-building .*-destination id=$UDID "
    expect fallback_udid "no create, boot, bootstatus or shutdown" not_called "simctl \(create\|boot\|bootstatus\|shutdown\|erase\)"
    expect fallback_udid "left it booted" state_is Booted
    expect fallback_udid "the marker is untouched" test -f "$MARKER"
    expect fallback_udid "no pool call" not_called "simpool"
    setup missing
    SIMULATOR_UDID="$UDID" gallery --no-open; status=$?
    expect fallback_udid "an unknown simulator is not created either" not_called "simctl \(create\|boot\|bootstatus\|shutdown\|erase\)"
}

# --- the page script, real, on a fake manifest and real PNGs ---

png() {   # $1 = path, $2 = grey level: a 4 x 4 PNG with one pixel 16 levels off (a render); $3 = blank: one colour everywhere
    python3 -c 'import struct, sys, zlib
def chunk(kind, data):
    return struct.pack(">I", len(data)) + kind + data + struct.pack(">I", zlib.crc32(kind + data) & 0xffffffff)
level = int(sys.argv[2]); row = b"\x00" + bytes([level, level, level]) * 4
other = level - 16 if level > 127 else level + 16
last = b"\x00" + bytes([level, level, level]) * 3 + (bytes([level] * 3) if sys.argv[3:] == ["blank"] else bytes([other] * 3))
open(sys.argv[1], "wb").write(b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", 4, 4, 8, 2, 0, 0, 0)) + chunk(b"IDAT", zlib.compress(row * 3 + last)) + chunk(b"IEND", b""))' "$1" "$2" "${3:-}"
}

page_setup() {   # a scratch tree with the real page script, the luminance helper and the scenarios file
    # The real tools again (the stubs' PATH and TMPDIR of an earlier case are gone), for the swift helper
    export PATH="$ORIG_PATH"; if [ -n "$ORIG_TMPDIR" ]; then export TMPDIR="$ORIG_TMPDIR"; else unset TMPDIR; fi
    T="$(mktemp -d)"
    TREE="$T/tree"; mkdir -p "$TREE/scripts" "$TREE/BChessGalleryTests"
    cp "$ROOT/scripts/preview-gallery.py" "$ROOT/scripts/preview-luminance.swift" "$TREE/scripts/"
    cp "$ROOT/BChessGalleryTests/GalleryScenarios.swift" "$TREE/BChessGalleryTests/"
    unset PREVIEW_GALLERY_OUT
    PAGE="python3 $TREE/scripts/preview-gallery.py"
}

fake_run() {   # $1 = directory, $2... = "slug:platform" (platform empty: none in the manifest entry); a light and a dark PNG each
    local dir="$1" entry slug platform json="" sep=""; shift
    mkdir -p "$dir"
    for entry in "$@"; do
        slug="${entry%%:*}"; platform="${entry#*:}"
        png "$dir/$slug.png" 240; png "$dir/$slug.dark.png" 20
        json="$json$sep{\"name\":\"$slug\",\"group\":\"G\",\"slug\":\"$slug\",\"size\":\"402x874\"${platform:+,\"platform\":\"$platform\"}}"; sep=","
    done
    echo "[$json]" > "$dir/manifest.json"
}

layout() {   # images in <platform>/, the manifest in data/, the page at the top only
    page_setup
    cd "$TREE" || return
    fake_run "$T/run" "alpha:" "beta:duo-inner"
    png "$T/run/stray.png" 100
    $PAGE --import "$T/run" > "$T/out.log" 2>&1; local status=$?
    expect layout "the import exits zero" [ "$status" = 0 ]
    expect layout "no platform means iphone/" test -f previews/iphone/alpha.png -a -f previews/iphone/alpha.dark.png
    expect layout "the platform picks the folder" test -f previews/duo-inner/beta.png
    expect layout "an image the manifest does not name lands in other/" test -f previews/other/stray.png
    expect layout "the manifest is in data/" test -f previews/data/manifest.json
    expect layout "only the page and folders at the top" bash -c 'cd previews && [ "$(ls | sort | tr "\n" " ")" = "data duo-inner index.html iphone other " ]'
    expect layout "the page links the folder" grep -q 'href="duo-inner/beta.png"' previews/index.html
    expect layout "the page links iphone/" grep -q 'href="iphone/alpha.dark.png"' previews/index.html
    $PAGE --check > "$T/check.log" 2>&1; status=$?
    expect layout "the check names the stray image by folder" grep -q "stray image (no scenario): other/stray.png" "$T/check.log"
    rm previews/other/stray.png
    $PAGE --check > "$T/check.log" 2>&1; status=$?
    expect layout "the check passes without it" grep -q "CHECK OK \[en\]: 2 cards" "$T/check.log"
    # A flat gallery of an earlier version is migrated by the next command
    rm -rf previews; mkdir previews
    cp "$T/run/alpha.png" "$T/run/alpha.dark.png" "$T/run/beta.png" "$T/run/beta.dark.png" "$T/run/manifest.json" previews/
    $PAGE --check > "$T/check.log" 2>&1; status=$?
    expect layout "a flat gallery is migrated" test -f previews/duo-inner/beta.dark.png -a -f previews/iphone/alpha.png -a -f previews/data/manifest.json
    expect layout "the migrated gallery checks" grep -q "CHECK OK \[en\]: 2 cards" "$T/check.log"
    expect layout "nothing flat is left" bash -c '! ls previews/*.png previews/manifest.json 2>/dev/null | grep -q .'
    # Resumable: a half-moved folder (the manifest moved, an image still at the top) is finished by the next command
    mv previews/iphone/alpha.png previews/alpha.png
    $PAGE --check > "$T/check.log" 2>&1
    expect layout "a half-moved folder is finished" test -f previews/iphone/alpha.png -a ! -e previews/alpha.png
    # data/coverage.json survives a full import
    echo '{}' > previews/data/coverage.json
    $PAGE --import "$T/run" > "$T/out.log" 2>&1
    expect layout "coverage.json survives a full import" test -f previews/data/coverage.json
    cd "$ROOT" || return; rm -rf "$T"
}

preserve() {   # a full import deletes only the PNGs the gallery owns
    page_setup
    cd "$TREE" || return
    fake_run "$T/run" "alpha:" "beta:duo-inner"
    $PAGE --import "$T/run" > "$T/out.log" 2>&1
    echo notes > previews/iphone/keep.txt
    png previews/iphone/stale.png 50
    mkdir -p previews/notes previews/pending
    echo review > previews/notes/review.txt
    png previews/notes/shot.png 50
    png previews/pending/old.png 50; echo '[]' > previews/pending/manifest.json
    $PAGE --import "$T/run" >> "$T/out.log" 2>&1; local status=$?
    expect preserve "the second full import exits zero" [ "$status" = 0 ]
    expect preserve "an unrelated folder survives" test -f previews/notes/review.txt -a -f previews/notes/shot.png
    expect preserve "a nested flat gallery survives" test -f previews/pending/old.png -a -f previews/pending/manifest.json
    expect preserve "a non-PNG in an image folder survives" test -f previews/iphone/keep.txt
    expect preserve "a stale PNG of an owned folder is replaced" test ! -e previews/iphone/stale.png
    expect preserve "the new images are in place" test -f previews/iphone/alpha.png -a -f previews/duo-inner/beta.dark.png
    cd "$ROOT" || return; rm -rf "$T"
}

skipped() {   # a card the pass could not render honestly: in the manifest with its reason, no images, the check accepts only that
    page_setup
    cd "$TREE" || return
    fake_run "$T/run" "alpha:"
    python3 - "$T/run/manifest.json" <<'PY'
import json, sys
path = sys.argv[1]
manifest = json.load(open(path))
manifest.append({"name": "beta", "group": "G", "slug": "beta", "size": "678x466", "platform": "iphone", "skipped": "the Duo cannot mount it"})
json.dump(manifest, open(path, "w"))
PY
    $PAGE --import "$T/run" > "$T/out.log" 2>&1
    $PAGE --check > "$T/check.log" 2>&1; local status=$?
    expect skipped "the check passes with the skipped card's pair missing" [ "$status" = 0 ]
    expect skipped "it counts every card" grep -q "CHECK OK \[en\]: 2 cards" "$T/check.log"
    expect skipped "the page says why" grep -q "not rendered on this pass: the Duo cannot mount it" previews/index.html
    # Without the flag the same gap fails the check
    python3 - previews/data/manifest.json <<'PY'
import json, sys
path = sys.argv[1]
manifest = json.load(open(path))
for entry in manifest:
    entry.pop("skipped", None)
json.dump(manifest, open(path, "w"))
PY
    $PAGE --check > "$T/check.log" 2>&1; status=$?
    expect skipped "a missing pair without the flag fails" [ "$status" != 0 ]
    expect skipped "and names the missing image" grep -q "missing: iphone/beta.png" "$T/check.log"
    cd "$ROOT" || return; rm -rf "$T"
}

flag() {   # $1 = manifest, $2 = slug, $3 = key, $4 = JSON value (empty: remove the key)
    python3 - "$@" <<'PY'
import json, sys
path, slug, key, value = sys.argv[1:5]
manifest = json.load(open(path))
for entry in manifest:
    if entry["slug"] == slug:
        if value: entry[key] = json.loads(value)
        else: entry.pop(key, None)
json.dump(manifest, open(path, "w"))
PY
}

document_canvas() {   # a card dark in both appearances by design: the pair is judged, not each image
    page_setup
    cd "$TREE" || return
    fake_run "$T/run" "alpha:" "canvas:"
    png "$T/run/canvas.png" 60; png "$T/run/canvas.dark.png" 20
    $PAGE --import "$T/run" > "$T/out.log" 2>&1
    $PAGE --check > "$T/check.log" 2>&1; local status=$?
    expect document_canvas "without the flag a dark light image fails" [ "$status" != 0 ]
    expect document_canvas "and is named" grep -q "dark render in the light slot: iphone/canvas.png" "$T/check.log"
    flag previews/data/manifest.json canvas documentCanvas true
    $PAGE --check > "$T/check.log" 2>&1; status=$?
    expect document_canvas "with the flag the darker-in-dark pair passes" [ "$status" = 0 ]
    expect document_canvas "it counts every card" grep -q "CHECK OK \[en\]: 2 cards" "$T/check.log"
    png previews/iphone/canvas.dark.png 60
    $PAGE --check > "$T/check.log" 2>&1; status=$?
    expect document_canvas "a dark image as light as the light one fails" [ "$status" != 0 ]
    expect document_canvas "and the pair is named" grep -q "document canvas not darker in dark: iphone/canvas (luminance" "$T/check.log"
    png previews/iphone/canvas.dark.png 52   # 8 levels apart: 0.03, under the 0.05 the pair needs
    $PAGE --check > "$T/check.log" 2>&1; status=$?
    expect document_canvas "a pair less than 0.05 apart fails" grep -q "document canvas not darker in dark" "$T/check.log"
    cd "$ROOT" || return; rm -rf "$T"
}

draws_nothing() {   # a blank image (one colour everywhere) fails unless the scenario draws nothing by design
    page_setup
    cd "$TREE" || return
    fake_run "$T/run" "alpha:" "empty:"
    png "$T/run/empty.png" 240 blank; png "$T/run/empty.dark.png" 20 blank
    $PAGE --import "$T/run" > "$T/out.log" 2>&1
    $PAGE --check > "$T/check.log" 2>&1; local status=$?
    expect draws_nothing "a blank render fails" [ "$status" != 0 ]
    expect draws_nothing "both blank images are named" grep -q "blank render (one colour everywhere): iphone/empty.png" "$T/check.log"
    expect draws_nothing "the dark one too" grep -q "blank render (one colour everywhere): iphone/empty.dark.png" "$T/check.log"
    expect draws_nothing "a rendered card is not" bash -c '! grep -q "blank render.*alpha" "$0"' "$T/check.log"
    flag previews/data/manifest.json empty drawsNothing true
    $PAGE --check > "$T/check.log" 2>&1; status=$?
    expect draws_nothing "with the flag the blank pair passes" [ "$status" = 0 ]
    expect draws_nothing "it counts every card" grep -q "CHECK OK \[en\]: 2 cards" "$T/check.log"
    cd "$ROOT" || return; rm -rf "$T"
}

forced_appearance() {   # .preferredColorScheme or \.locale in the scenario file fails the check; a // comment does not
    page_setup
    cd "$TREE" || return
    fake_run "$T/run" "alpha:"
    $PAGE --import "$T/run" > "$T/out.log" 2>&1
    local file=BChessGalleryTests/GalleryScenarios.swift lines
    lines=$(wc -l < "$file" | tr -d ' ')
    printf '%s\n' '// never .preferredColorScheme(.dark) nor .environment(\.locale, Locale(identifier: "fr")) here' >> "$file"
    $PAGE --check > "$T/check.log" 2>&1; local status=$?
    expect forced_appearance "a comment naming them passes" [ "$status" = 0 ]
    printf '%s\n' '    AnyView(Text("x").preferredColorScheme(.dark))' >> "$file"
    $PAGE --check > "$T/check.log" 2>&1; status=$?
    expect forced_appearance "a forced appearance fails" [ "$status" != 0 ]
    expect forced_appearance "with its line" grep -q "forced appearance or locale: GalleryScenarios.swift:$((lines + 2))" "$T/check.log"
    printf '%s\n' '    AnyView(Text("x").environment(\.locale, Locale(identifier: "fr")))' >> "$file"
    $PAGE --check > "$T/check.log" 2>&1; status=$?
    expect forced_appearance "a forced locale fails too" grep -q "forced appearance or locale: GalleryScenarios.swift:$((lines + 3))" "$T/check.log"
    cd "$ROOT" || return; rm -rf "$T"
}

coexist() {   # iPhone import, Duo import under previews/duo, iPhone import again: both galleries intact
    page_setup
    cd "$TREE" || return
    fake_run "$T/phone" "alpha:" "beta:duo-inner"
    fake_run "$T/duo" "alpha:" "gamma:duo-inner"
    $PAGE --import "$T/phone" > "$T/out.log" 2>&1
    PREVIEW_GALLERY_OUT=previews/duo $PAGE --import "$T/duo" >> "$T/out.log" 2>&1
    expect coexist "both pages exist" test -f previews/index.html -a -f previews/duo/index.html
    $PAGE --import "$T/phone" >> "$T/out.log" 2>&1; local status=$?
    expect coexist "a second full iPhone import exits zero" [ "$status" = 0 ]
    expect coexist "both pages still exist" test -f previews/index.html -a -f previews/duo/index.html
    expect coexist "the Duo images are intact" test -f previews/duo/duo-inner/gamma.png -a -f previews/duo/iphone/alpha.dark.png
    expect coexist "the Duo manifest is intact" grep -q gamma previews/duo/data/manifest.json
    $PAGE --check > "$T/check.log" 2>&1; status=$?
    expect coexist "the iPhone check does not count the Duo images as stray" grep -q "CHECK OK \[en\]: 2 cards" "$T/check.log"
    PREVIEW_GALLERY_OUT=previews/duo $PAGE --check > "$T/check.log" 2>&1
    expect coexist "the Duo check passes on its own" grep -q "CHECK OK \[en\]: 2 cards" "$T/check.log"
    cd "$ROOT" || return; rm -rf "$T"
}

ALL="fallback_run fallback_keep_booted fallback_borrowed fallback_test_fails
pool_run pool_options pool_acquire_fails pool_build_fails pool_test_fails pool_check_fails
pool_signalled_int_acquire pool_signalled_int_build pool_signalled_int_test pool_signalled_term_test pool_signalled_hup_build
pool_duo unknown_device simulator_udid fallback_udid layout preserve skipped document_canvas draws_nothing forced_appearance coexist"
for c in ${@:-$ALL}; do
    if declare -F "$c" > /dev/null; then "$c"; else echo "FAIL unknown case: $c"; FAILED=1; fi
    rm -rf "$T"
done
[ "$FAILED" = 0 ] && echo "all lifecycle checks passed"
exit "$FAILED"
