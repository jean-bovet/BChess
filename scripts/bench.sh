#!/bin/bash
#
# A fixed-depth search benchmark for Shared/Engine, built standalone at -O2 -DNDEBUG (plain C++, no Xcode).
# See planning/ENGINE-3-speed.md. Everything it builds goes to the git-ignored .bench/ folder.
#
#   scripts/bench.sh                         # depth 6, TT cut-offs off, 5 runs
#   DEPTH=5 TT=1 REPEAT=3 scripts/bench.sh
#   scripts/bench.sh > old.txt; ...; scripts/bench.sh > new.txt; scripts/bench.sh --compare old.txt new.txt
#   scripts/bench.sh --perft                 # ENGINE-1's perft harness: all six positions must say OK
#
# DEPTH   the fixed search depth (default 6)
# TT      1 turns the transposition-table cut-offs on (default 0, as shipped)
# REPEAT  runs; the output keeps the lowest figures, and every run must give the same signature (default 5)
#
# The per-position lines and the signature (nodes, score, best move) do not depend on load. Retired
# instructions barely do, so they are the speed metric. CPU time is printed but not trusted on a loaded
# machine.

set -euo pipefail

ROOT=$(git -C "$(dirname "$0")" rev-parse --show-toplevel)
OUT="$ROOT/.bench"
ENGINE="$ROOT/Shared/Engine"

fail() { echo "error: $*" >&2; exit 1; }

# --compare <old> <new>: the "pos" and "signature" lines of two outputs; names every position that differs
if [[ ${1:-} == --compare ]]; then
    [[ -f ${2:-} && -f ${3:-} ]] || fail "usage: bench.sh --compare <old-output> <new-output>"
    status=0
    while read -r line; do
        index=$(awk '{print $2}' <<< "$line")
        other=$(grep -E "^pos $index " "$3" || true)
        if [[ $line != "$other" ]]; then
            echo "DIFFERS  old: $line"
            echo "         new: ${other:-<missing>}"
            status=1
        fi
    done < <(grep -E '^pos ' "$2")
    [[ $(grep -cE '^pos ' "$2") == $(grep -cE '^pos ' "$3") ]] || { echo "DIFFERS  the number of positions"; status=1; }
    old=$(grep -E '^signature ' "$2" | awk '{print $2}'); new=$(grep -E '^signature ' "$3" | awk '{print $2}')
    oldnodes=$(grep -E '^signature ' "$2" | awk '{print $4}'); newnodes=$(grep -E '^signature ' "$3" | awk '{print $4}')
    oi=$(grep -E '^cost total' "$2" | awk '{print $4}'); ni=$(grep -E '^cost total' "$3" | awk '{print $4}')
    echo "signature: $old -> $new$([[ $old == "$new" ]] && echo " (identical)" || echo " (DIFFERENT)")"
    echo "nodes: $oldnodes -> $newnodes ($(awk -v a="$oldnodes" -v b="$newnodes" 'BEGIN { printf "%+.2f %%", (b - a) * 100 / a }'))"
    echo "instructions: $oi -> $ni ($(awk -v a="$oi" -v b="$ni" 'BEGIN { printf "%+.2f %%", (b - a) * 100 / a }'))"
    exit $status
fi

build() { # build <source.cpp> <binary>
    mkdir -p "$OUT"
    local includes sources
    includes=$(find "$ENGINE" -type d | sed 's/^/-I/')
    sources=$(find "$ENGINE" -name '*.cpp')
    # shellcheck disable=SC2086
    clang -O2 -DNDEBUG -c "$ENGINE/Helpers/magicmoves.c" -o "$OUT/magic.o" $includes
    # shellcheck disable=SC2086
    clang++ -std=c++20 -O2 -DNDEBUG -w $includes "$1" $sources "$OUT/magic.o" -o "$2"
}

if [[ ${1:-} == --perft ]]; then
    build "$ROOT/planning/assets/ENGINE-1/perft.cpp" "$OUT/perft"
    "$OUT/perft" | tee "$OUT/perft.out"
    ! grep -q MISMATCH "$OUT/perft.out" || fail "perft mismatch"
    grep -E '^start +d5 ' "$OUT/perft.out" | sed -E 's/.*, ([0-9.]+) Mnps\)/start d5: \1 Mnps/'
    exit 0
fi

REPEAT=${REPEAT:-5}
export DEPTH=${DEPTH:-6} TT=${TT:-0}
build "$ROOT/scripts/bench.cpp" "$OUT/bench"

first=""
bestInstr=0; bestCycles=0; bestCpu=0; bestRSS=0; bestPos=""
for ((run = 1; run <= REPEAT; run++)); do
    out=$("$OUT/bench") || fail "the bench failed"
    sig=$(grep -E '^(pos|signature) ' <<< "$out")
    if [[ -z $first ]]; then first=$out; firstsig=$sig; elif [[ $sig != "$firstsig" ]]; then fail "run $run gave a different signature: the search is not deterministic"; fi
    read -r instr cycles cpu rss < <(grep -E '^cost total' <<< "$out" | awk '{print $4, $6, $8, $10}')
    if (( run == 1 )) || (( instr < bestInstr )); then bestInstr=$instr; bestCycles=$cycles; bestPos=$(grep -E '^cost [0-9]' <<< "$out"); fi
    awk -v a="$cpu" -v b="$bestCpu" -v r="$run" 'BEGIN { exit !(r == 1 || a < b) }' && bestCpu=$cpu
    awk -v a="$rss" -v b="$bestRSS" 'BEGIN { exit !(a > b) }' && bestRSS=$rss
done

grep -E '^(pos|signature) ' <<< "$first"
echo "$bestPos"
echo "cost total instructions $bestInstr cycles $bestCycles cpu_ms $bestCpu max_rss_mb $bestRSS (best of $REPEAT)"
