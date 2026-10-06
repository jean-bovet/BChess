#!/bin/bash
#
# Plays BChess against Stockfish at one UCI_Elo level and reports the score and the Elo difference, or
# (BASE=<git ref>) plays this checkout against an earlier commit in an SPRT. See docs/elo.md. Everything
# it downloads or builds goes to the git-ignored .elo/ folder.
#
#   scripts/elo-match.sh                                  # 300 games against Stockfish at 1600, 10+0.1
#   LEVEL=1400 GAMES=100 TC=10+0.1 CONCURRENCY=4 scripts/elo-match.sh
#   BASE=2eb86d5 scripts/elo-match.sh                     # A/B: SPRT [0, 10], at most 8000 games, 5+0.05
#
# LEVEL        Stockfish's UCI_Elo (1320 is the lowest it accepts)
# GAMES        an even number: every opening is played with both colours
# TC           time control, fastchess syntax (moves/seconds+increment)
# CONCURRENCY  games played at once
# BASE         a git ref: A/B mode against that commit instead of Stockfish
# MAX_GAMES    A/B mode: the most games played, an even number (default 8000)
# ELO0, ELO1   A/B mode: the SPRT hypotheses (default 0 and 10: a gain test; -5 and 0 tests for no regression)

set -euo pipefail

ROOT=$(git -C "$(dirname "$0")" rev-parse --show-toplevel)
ELO="$ROOT/.elo"

# The tools are pinned: a tag of the match runner, and a commit and hashes of the opening book
FASTCHESS_URL=https://github.com/Disservin/fastchess
FASTCHESS_TAG=v1.8.2-alpha
FASTCHESS_COMMIT=f618e34540f94f4719ad3817950618dabe441318
BOOK_COMMIT=65815ccdbc7727cd4f6aee252ba8f67fb740e92f
BOOK_URL=https://raw.githubusercontent.com/official-stockfish/books/$BOOK_COMMIT/8moves_v3.pgn.zip
BOOK_ZIP_SHA256=7e1e9dd118b4bb97d8a8b5b8a790c86e21f8509d59a27d2883767d94477be02e
BOOK_PGN_SHA256=5835239f88cc2c7511b177c32392a69f3ede21819cf0616f80a7f907cd21d17e

BASE=${BASE:-}
LEVEL=${LEVEL:-1600}
GAMES=${GAMES:-300}
MAX_GAMES=${MAX_GAMES:-8000}
ELO0=${ELO0:-0}
ELO1=${ELO1:-10}
if [[ -n $BASE ]]; then TC=${TC:-5+0.05}; else TC=${TC:-10+0.1}; fi
CONCURRENCY=${CONCURRENCY:-4}

fail() { echo "error: $*" >&2; exit 1; }

# One pass over a fastchess PGN. Every game (it starts at its [Event] tag) must have a BChess side, exactly one
# Result and exactly one Termination, both from the allowed values, and movetext that ends with the marker of its Result. Prints, in this order:
#   games wins draws losses illegal-move-losses time-forfeits illegal-moves-by-anyone abandoned unterminated malformed
# wins, draws and losses are BChess's, and count only the games that are well formed. time-forfeit counts the
# forfeits of either engine.
pgn_summary() {
    awk '
    function finish() {
        if (!started) return
        games++
        bchess = (white == "BChess") || (black == "BChess")
        okResult = (result == "1-0" || result == "0-1" || result == "1/2-1/2")
        okTerm = (term == "normal" || term == "adjudication" || term == "time forfeit" || term == "illegal move" || term == "abandoned" || term == "unterminated")
        if (nresult != 1 || nterm != 1 || !okResult || !okTerm || !bchess || last != result) { malformed++; return }
        lost = (white == "BChess" && result == "0-1") || (black == "BChess" && result == "1-0")
        if (result == "1/2-1/2") draws++
        else if (lost) losses++
        else wins++
        if (term == "illegal move") { anyIllegal++; if (lost) illegalLosses++ }
        if (term == "time forfeit") timeouts++ # either side: a forfeit by the other engine would inflate the score
        if (term == "abandoned") abandoned++
        if (term == "unterminated") unterminated++
    }
    function tag(line, name,    v) {
        v = line; sub("^\\[" name " \"", "", v); sub("\"\\]$", "", v); return v
    }
    /^\[Event / { finish(); started = 1; white = black = result = term = last = ""; nresult = nterm = 0; next }
    /^\[White "/ { white = tag($0, "White") }
    /^\[Black "/ { black = tag($0, "Black") }
    /^\[Result "/ { result = tag($0, "Result"); nresult++ }
    /^\[Termination "/ { term = tag($0, "Termination"); nterm++ }
    # The last token of the last line of movetext is the result marker of the game
    /^[^\[ ]/ { last = $NF }
    END { finish(); print games + 0, wins + 0, draws + 0, losses + 0, illegalLosses + 0, timeouts + 0, anyIllegal + 0, abandoned + 0, unterminated + 0, malformed + 0 }' "$1"
}

# The LLR line of a fastchess SPRT log ("LLR: 2.95 (100.3%) (-2.94, 2.94) [0.00, 10.00]"): prints llr lower upper
# of the last one, or nothing when there is none.
sprt_llr() {
    grep -E '^LLR: ' "$1" | tail -1 | sed -nE 's/^LLR: (-?[0-9.]+) .*\((-?[0-9.]+), (-?[0-9.]+)\).*/\1 \2 \3/p'
}

# The SPRT's outcome: H1, H0 or none. fastchess says "completed - H1 was accepted" also when it merely ran out of
# rounds with the LLR inside its bounds, so the decision line only counts when the LLR agrees with it.
sprt_decision() {
    local said llr lower upper
    said=$(sed -nE 's/.*completed - (H[01]) was accepted.*/\1/p' "$1" | tail -1)
    read -r llr lower upper < <(sprt_llr "$1")
    if [[ -z $said || -z ${llr:-} ]]; then echo none; return; fi
    if awk -v l="$llr" -v u="$upper" 'BEGIN { exit !(l >= u) }'; then [[ $said == H1 ]] && echo H1 || echo none
    elif awk -v l="$llr" -v b="$lower" 'BEGIN { exit !(l <= b) }'; then [[ $said == H0 ]] && echo H0 || echo none
    else echo none; fi
}

# judge_run <mode: ab|sf> <expected games> <fastchess log> <pgn>
# Checks a finished run against its games and reads its result. Sets PLAYED WINS DRAWS LOSSES and the PGN's figures,
# and returns: 0 valid (sf: go on to the Elo; ab: H1 accepted), 2 invalid, 4 H0 accepted, 5 no decision at the cap.
# The games are the authority: every game must be complete, nobody may forfeit on time, and they must agree with
# the summary. In sf mode exactly the expected number is played. In ab mode an SPRT may stop earlier, but only
# with a decision; an odd count is fine because it can stop between the two games of an opening.
judge_run() {
    local mode=$1 expected=$2 log=$3 pgn=$4 line
    line=$(grep -E '^Games: ' "$log" | tail -1 || true)
    WINS=$(sed -nE 's/.*Wins: ([0-9]+).*/\1/p' <<< "$line"); WINS=${WINS:-0}
    LOSSES=$(sed -nE 's/.*Losses: ([0-9]+).*/\1/p' <<< "$line"); LOSSES=${LOSSES:-0}
    DRAWS=$(sed -nE 's/.*Draws: ([0-9]+).*/\1/p' <<< "$line"); DRAWS=${DRAWS:-0}
    SCORE=$(sed -nE 's/.*\(([0-9.]+) %\).*/\1/p' <<< "$line")
    PLAYED=$((WINS + LOSSES + DRAWS))
    read -r PGNGAMES PGNWINS PGNDRAWS PGNLOSSES ILLEGAL TIMEOUTS ANYILLEGAL ABANDONED UNTERMINATED MALFORMED < <(pgn_summary "$pgn")
    DECISION=none
    [[ $mode == ab ]] && DECISION=$(sprt_decision "$log")
    local bad=0
    (( ANYILLEGAL > 0 || ABANDONED > 0 || UNTERMINATED > 0 || MALFORMED > 0 || TIMEOUTS > 0 || PLAYED == 0 || PGNGAMES != PLAYED \
       || PGNWINS != WINS || PGNLOSSES != LOSSES || PGNDRAWS != DRAWS )) && bad=1
    if [[ $mode == sf ]]; then
        (( PLAYED != expected )) && bad=1
    else
        (( PLAYED > expected )) && bad=1
        (( PLAYED < expected )) && [[ $DECISION == none ]] && bad=1
    fi
    if (( bad )); then
        echo "PGN: $PGNGAMES games ($MALFORMED malformed), $PGNWINS/$PGNDRAWS/$PGNLOSSES (W/D/L); summary: $PLAYED games, $WINS/$DRAWS/$LOSSES; expected $expected games${DECISION:+, SPRT decision: $DECISION}; time forfeits (either engine): $TIMEOUTS" >&2
        return 2
    fi
    if [[ $mode == ab ]]; then
        case $DECISION in
            H1) return 0 ;;
            H0) return 4 ;;
            *) return 5 ;;
        esac
    fi
    return 0
}

# --self-test: the validator against small sample runs, with no tools needed
if [[ ${1:-} == --self-test ]]; then
    TMP=$(mktemp -d)
    trap 'rm -rf "$TMP"' EXIT
    # game <white> <black> <movetext-marker> [tags...]; a marker of "" leaves out the movetext
    game() {
        printf '[Event "x"]\n[White "%s"]\n[Black "%s"]\n' "$1" "$2"
        local marker=$3; shift 3
        for tag in "$@"; do printf '%s\n' "$tag"; done
        if [[ -n $marker ]]; then printf '\n1. e4 e5 %s\n\n' "$marker"; else printf '\n'; fi
    }
    check() { # name expected-output pgn-file
        local got; got=$(pgn_summary "$3")
        [[ $got == "$2" ]] && echo "ok   $1" || { echo "FAIL $1: got '$got', expected '$2'" >&2; FAILED=1; }
    }
    FAILED=0
    { game BChess SF1600 1-0 '[Result "1-0"]' '[Termination "normal"]'
      game SF1600 BChess 1-0 '[Result "1-0"]' '[Termination "time forfeit"]'
      game BChess SF1600 1/2-1/2 '[Result "1/2-1/2"]' '[Termination "adjudication"]'; } > "$TMP/good.pgn"
    check "a complete run" "3 1 1 1 0 1 0 0 0 0" "$TMP/good.pgn"
    game BChess SF1600 1-0 '[Result "1-0"]' > "$TMP/noterm.pgn"
    check "a game without a termination" "1 0 0 0 0 0 0 0 0 1" "$TMP/noterm.pgn"
    { game BChess SF1600 1-0 '[Result "1-0"]' '[Result "1-0"]' '[Termination "normal"]'
      game BChess SF1600 1-0 '[Termination "normal"]'; } > "$TMP/mixed.pgn"
    check "one game with two results, one with none" "2 0 0 0 0 0 0 0 0 2" "$TMP/mixed.pgn"
    game BChess SF1600 1-0 '[Result "1-0"]' '[Termination "mystery"]' > "$TMP/unknown.pgn"
    check "an unknown termination" "1 0 0 0 0 0 0 0 0 1" "$TMP/unknown.pgn"
    game BChess SF1600 '*' '[Result "*"]' '[Termination "unterminated"]' > "$TMP/unfinished.pgn"
    check "an unfinished game" "1 0 0 0 0 0 0 0 0 1" "$TMP/unfinished.pgn"
    game SF1600 SF1700 1-0 '[Result "1-0"]' '[Termination "normal"]' > "$TMP/strangers.pgn"
    check "a game without BChess" "1 0 0 0 0 0 0 0 0 1" "$TMP/strangers.pgn"
    { game BChess SF1600 0-1 '[Result "0-1"]' '[Termination "illegal move"]'
      game SF1600 BChess 0-1 '[Result "0-1"]' '[Termination "abandoned"]'; } > "$TMP/bad.pgn"
    check "an illegal move and an abandoned game" "2 1 0 1 1 0 1 1 0 0" "$TMP/bad.pgn"
    game BChess SF1600 "" '[Result "1-0"]' '[Termination "normal"]' > "$TMP/nomovetext.pgn"
    check "a game without movetext" "1 0 0 0 0 0 0 0 0 1" "$TMP/nomovetext.pgn"
    game BChess SF1600 '*' '[Result "1-0"]' '[Termination "normal"]' > "$TMP/truncated.pgn"
    check "movetext cut off before its result" "1 0 0 0 0 0 0 0 0 1" "$TMP/truncated.pgn"
    game BChess SF1600 0-1 '[Result "1-0"]' '[Termination "normal"]' > "$TMP/mismatch.pgn"
    check "a movetext result that differs from the tag" "1 0 0 0 0 0 0 0 0 1" "$TMP/mismatch.pgn"
    : > "$TMP/empty.pgn"
    check "an empty file" "0 0 0 0 0 0 0 0 0 0" "$TMP/empty.pgn"

    # judge_run: sample fastchess logs with their games
    # log <wins> <draws> <losses> [<llr-line> <decision-line>]
    log() {
        printf 'Results of BChess vs Base (5+0.05, NULL - 1t, NULL - 16MB, 8moves_v3.pgn):\nElo: 1.00 +/- 2.00, nElo: 1.00 +/- 2.00\n'
        printf 'Games: %d, Wins: %d, Losses: %d, Draws: %d, Points: 1.0 (50.00 %%)\n' $(($1 + $2 + $3)) "$1" "$3" "$2"
        [[ -n ${4:-} ]] && printf '%s\n' "$4"
        [[ -n ${5:-} ]] && printf '%s\n' "$5"
        return 0
    }
    LLR_H1='LLR: 2.97 (101.0%) (-2.94, 2.94) [0.00, 10.00]'
    LLR_H0='LLR: -3.01 (-102.4%) (-2.94, 2.94) [0.00, 10.00]'
    LLR_MID='LLR: 1.20 (40.8%) (-2.94, 2.94) [0.00, 10.00]'
    DEC_H1='SPRT ([0.00, 10.00]) completed - H1 was accepted'
    DEC_H0='SPRT ([0.00, 10.00]) completed - H0 was accepted'
    # pgn <wins> <draws> <losses> [<extra-game-tags...>]: BChess's games, as white
    pgn() {
        local i
        for ((i = 0; i < $1; i++)); do game BChess Base 1-0 '[Result "1-0"]' '[Termination "normal"]'; done
        for ((i = 0; i < $2; i++)); do game BChess Base 1/2-1/2 '[Result "1/2-1/2"]' '[Termination "adjudication"]'; done
        for ((i = 0; i < $3; i++)); do game BChess Base 0-1 '[Result "0-1"]' '[Termination "normal"]'; done
    }
    judge() { # name expected-code mode expected-games log pgn
        local code=0
        judge_run "$3" "$4" "$5" "$6" 2> /dev/null || code=$?
        [[ $code == "$2" ]] && echo "ok   $1" || { echo "FAIL $1: exit $code, expected $2" >&2; FAILED=1; }
    }
    log 6 2 2 "$LLR_H1" "$DEC_H1" > "$TMP/h1.log";   pgn 6 2 2 > "$TMP/h1.pgn"
    judge "an early H1 stop (fewer games than the cap, with a decision)" 0 ab 100 "$TMP/h1.log" "$TMP/h1.pgn"
    log 2 2 6 "$LLR_H0" "$DEC_H0" > "$TMP/h0.log";   pgn 2 2 6 > "$TMP/h0.pgn"
    judge "an early H0 stop" 4 ab 100 "$TMP/h0.log" "$TMP/h0.pgn"
    log 6 2 2 "$LLR_MID" > "$TMP/nodec.log"
    judge "fewer games than the cap and no decision line" 2 ab 100 "$TMP/nodec.log" "$TMP/h1.pgn"
    log 6 2 2 "$LLR_MID" "$DEC_H1" > "$TMP/quirk.log"
    judge "a decision line whose LLR is inside the bounds is no decision" 2 ab 100 "$TMP/quirk.log" "$TMP/h1.pgn"
    log 40 20 40 "$LLR_MID" "$DEC_H1" > "$TMP/cap.log"; pgn 40 20 40 > "$TMP/cap.pgn"
    judge "inconclusive at the cap" 5 ab 100 "$TMP/cap.log" "$TMP/cap.pgn"
    log 6 2 2 "$LLR_H1" "$DEC_H1" > "$TMP/differs.log"; pgn 5 2 3 > "$TMP/differs.pgn"
    judge "PGN totals that differ from the summary" 2 ab 100 "$TMP/differs.log" "$TMP/differs.pgn"
    log 6 2 3 "$LLR_H1" "$DEC_H1" > "$TMP/over.log"; pgn 6 2 3 > "$TMP/over.pgn"
    judge "more games than the cap" 2 ab 10 "$TMP/over.log" "$TMP/over.pgn"
    { pgn 5 2 2; game SF1600 BChess 1-0 '[Result "1-0"]' '[Termination "time forfeit"]'; } > "$TMP/forfeit-us.pgn"
    log 5 2 3 "$LLR_H1" "$DEC_H1" > "$TMP/forfeit-us.log"
    judge "a time forfeit lost by BChess" 2 ab 100 "$TMP/forfeit-us.log" "$TMP/forfeit-us.pgn"
    { pgn 5 2 2; game BChess Base 1-0 '[Result "1-0"]' '[Termination "time forfeit"]'; } > "$TMP/forfeit-them.pgn"
    log 6 2 2 "$LLR_H1" "$DEC_H1" > "$TMP/forfeit-them.log"
    judge "a time forfeit lost by the other engine" 2 ab 100 "$TMP/forfeit-them.log" "$TMP/forfeit-them.pgn"
    log 6 2 2 > "$TMP/sf.log"; pgn 6 2 2 > "$TMP/sf.pgn"
    judge "a Stockfish run with every game played" 0 sf 10 "$TMP/sf.log" "$TMP/sf.pgn"
    judge "a Stockfish run that stopped early is invalid" 2 sf 12 "$TMP/sf.log" "$TMP/sf.pgn"
    judge "a Stockfish run with a forfeit by the other engine" 2 sf 10 "$TMP/forfeit-them.log" "$TMP/forfeit-them.pgn"
    exit $FAILED
fi

if [[ -n $BASE ]]; then
    [[ $MAX_GAMES =~ ^[0-9]+$ ]] && (( MAX_GAMES >= 2 && MAX_GAMES % 2 == 0 )) || fail "MAX_GAMES must be an even number"
    BASE_SHA=$(git -C "$ROOT" rev-parse --verify --quiet "$BASE^{commit}") || fail "BASE '$BASE' is not a commit"
    BASE_SHORT=${BASE_SHA:0:7}
    EXPECTED=$MAX_GAMES
else
    [[ $LEVEL =~ ^[0-9]+$ ]] && (( LEVEL >= 1320 && LEVEL <= 3190 )) || fail "LEVEL must be between 1320 and 3190"
    [[ $GAMES =~ ^[0-9]+$ ]] && (( GAMES >= 2 && GAMES % 2 == 0 )) || fail "GAMES must be an even number"
    EXPECTED=$GAMES
fi
[[ $CONCURRENCY =~ ^[0-9]+$ ]] && (( CONCURRENCY >= 1 )) || fail "CONCURRENCY must be a positive number"

sha256() { shasum -a 256 "$1" | awk '{print $1}'; }

# 1. Tools
if [[ -z $BASE ]]; then
    command -v stockfish > /dev/null || fail "stockfish is missing: brew install stockfish"
    STOCKFISH=$(command -v stockfish)
    STOCKFISH_ID=$({ echo uci; sleep 0.5; echo quit; } | "$STOCKFISH" | sed -n 's/^id name //p; /^Stockfish/p' | head -1 | sed -E 's/ by .*//')
    [[ $STOCKFISH_ID == "Stockfish 19" ]] || fail "Stockfish 19 is required, found '${STOCKFISH_ID:-unknown}' at $STOCKFISH"
fi

if [[ -x "$ELO/fastchess/fastchess" ]]; then
    FASTCHESS="$ELO/fastchess/fastchess"
elif command -v fastchess > /dev/null; then
    FASTCHESS=$(command -v fastchess)
else
    echo "Building fastchess $FASTCHESS_TAG into $ELO/fastchess"
    mkdir -p "$ELO"
    git clone --quiet --depth 1 --branch "$FASTCHESS_TAG" "$FASTCHESS_URL" "$ELO/fastchess"
    [[ $(git -C "$ELO/fastchess" rev-parse HEAD) == "$FASTCHESS_COMMIT" ]] || fail "fastchess $FASTCHESS_TAG is not commit $FASTCHESS_COMMIT"
    make -C "$ELO/fastchess" -j"$(sysctl -n hw.ncpu)" > "$ELO/fastchess-build.log" 2>&1 || { tail -20 "$ELO/fastchess-build.log"; fail "fastchess did not build"; }
    FASTCHESS="$ELO/fastchess/fastchess"
fi

FASTCHESS_ID=$("$FASTCHESS" -version 2>&1 | head -1)
[[ $FASTCHESS_ID == *"-${FASTCHESS_COMMIT:0:7}" ]] || fail "fastchess at the pinned commit ${FASTCHESS_COMMIT:0:7} is required, found '$FASTCHESS_ID' at $FASTCHESS"

# 2. Opening book
BOOK="$ELO/books/8moves_v3.pgn"
if [[ ! -f "$BOOK" || $(sha256 "$BOOK") != "$BOOK_PGN_SHA256" ]]; then
    mkdir -p "$ELO/books"
    curl --fail --silent --show-error --location --output "$ELO/books/8moves_v3.pgn.zip" "$BOOK_URL"
    [[ $(sha256 "$ELO/books/8moves_v3.pgn.zip") == "$BOOK_ZIP_SHA256" ]] || fail "the opening book download does not match its sha256"
    unzip -o -q "$ELO/books/8moves_v3.pgn.zip" -d "$ELO/books"
    [[ $(sha256 "$BOOK") == "$BOOK_PGN_SHA256" ]] || fail "the opening book does not match its sha256"
fi

# 3. BChess, Release
echo "Building BChessUCI (Release)"
mkdir -p "$ELO"
xcodebuild -project "$ROOT/BChess.xcodeproj" -scheme BChessUCI -configuration Release -derivedDataPath "$ELO/dd" build > "$ELO/build.log" 2>&1 \
    || { tail -30 "$ELO/build.log"; fail "BChessUCI did not build"; }
BCHESS="$ELO/dd/Build/Products/Release/BChessUCI"
[[ -x "$BCHESS" ]] || fail "$BCHESS is missing"

# The other side of an A/B match: BChessUCI built from the committed files of BASE, cached by commit
if [[ -n $BASE ]]; then
    BASE_DIR="$ELO/base/$BASE_SHA"
    BASEBIN="$BASE_DIR/dd/Build/Products/Release/BChessUCI"
    if [[ ! -x "$BASEBIN" ]]; then
        echo "Building BChessUCI (Release) of $BASE_SHORT"
        rm -rf "$BASE_DIR"; mkdir -p "$BASE_DIR/src"
        git -C "$ROOT" archive "$BASE_SHA" | tar -x -C "$BASE_DIR/src"
        xcodebuild -project "$BASE_DIR/src/BChess.xcodeproj" -scheme BChessUCI -configuration Release -derivedDataPath "$BASE_DIR/dd" build > "$BASE_DIR/build.log" 2>&1 \
            || { tail -30 "$BASE_DIR/build.log"; rm -rf "$BASE_DIR"; fail "BChessUCI of $BASE_SHORT did not build"; }
        [[ -x "$BASEBIN" ]] || fail "$BASEBIN is missing"
    fi
fi

# 4. The match
STAMP=$(date +%Y%m%d-%H%M%S)
mkdir -p "$ELO/runs"
if [[ -n $BASE ]]; then NAME=AB-$BASE_SHORT; else NAME=SF$LEVEL; fi
PGN="$ELO/runs/$STAMP-$NAME.pgn"
LOG="$ELO/runs/$STAMP-$NAME.log"
INFO="$ELO/runs/$STAMP-$NAME.info"
SEED=${SEED:-$(( (RANDOM << 15) | RANDOM ))}
COMMIT=$(git -C "$ROOT" rev-parse --short HEAD)
[[ -z $(git -C "$ROOT" status --porcelain) ]] && TREE=clean || TREE=dirty
{
    echo "BChess:      $COMMIT ($TREE tree), BChessUCI sha256 $(sha256 "$BCHESS")"
    if [[ -n $BASE ]]; then
        echo "Base:        $BASE_SHORT, BChessUCI sha256 $(sha256 "$BASEBIN")"
    else
        echo "Stockfish:   $STOCKFISH_ID, $STOCKFISH, sha256 $(sha256 "$STOCKFISH")"
    fi
    echo "fastchess:   $FASTCHESS_ID, $FASTCHESS, sha256 $(sha256 "$FASTCHESS")"
    echo "Book:        8moves_v3.pgn sha256 $BOOK_PGN_SHA256, opening seed $SEED"
    if [[ -n $BASE ]]; then
        echo "Settings:    BASE=$BASE MAX_GAMES=$MAX_GAMES TC=$TC CONCURRENCY=$CONCURRENCY, SPRT elo0=$ELO0 elo1=$ELO1 alpha=0.05 beta=0.05 model=logistic"
    else
        echo "Settings:    LEVEL=$LEVEL GAMES=$GAMES TC=$TC CONCURRENCY=$CONCURRENCY"
    fi
} | tee "$INFO"
if [[ -n $BASE ]]; then
    echo "Playing up to $MAX_GAMES games against $BASE_SHORT (SPRT [$ELO0, $ELO1]), $TC, $CONCURRENCY at a time"
    OPPONENT=(-engine cmd="$BASEBIN" name=Base)
    SPRT=(-sprt elo0=$ELO0 elo1=$ELO1 alpha=0.05 beta=0.05 model=logistic)
else
    echo "Playing $GAMES games against Stockfish $LEVEL, $TC, $CONCURRENCY at a time"
    OPPONENT=(-engine cmd="$STOCKFISH" name=SF$LEVEL option.UCI_LimitStrength=true option.UCI_Elo=$LEVEL option.Threads=1 option.Hash=16)
    SPRT=()
fi
START=$(date +%s)
# fastchess saves its state (config.json) in the folder it runs in
cd "$ELO/runs"
"$FASTCHESS" \
    -engine cmd="$BCHESS" name=BChess \
    "${OPPONENT[@]}" \
    -each tc=$TC timemargin=100 \
    -openings file="$BOOK" format=pgn order=random -srand "$SEED" \
    -repeat -games 2 -rounds $((EXPECTED / 2)) -concurrency "$CONCURRENCY" -recover \
    -draw movenumber=40 movecount=8 score=10 \
    -resign movecount=4 score=1000 twosided=true \
    ${SPRT[@]+"${SPRT[@]}"} \
    -pgnout file="$PGN" 2>&1 | tee "$LOG"
WALL=$(( $(date +%s) - START ))

# 5. Report
read -r ELODIFF ELOERR < <(grep -E '^Elo: ' "$LOG" | tail -1 | sed -E 's/^Elo: ([^ ]+) \+\/- ([^,]+),.*/\1 \2/')
JUDGED=0
judge_run "$([[ -n $BASE ]] && echo ab || echo sf)" "$EXPECTED" "$LOG" "$PGN" || JUDGED=$?

echo
echo "Result: BChess $WINS wins, $LOSSES losses, $DRAWS draws out of $PLAYED games, score $SCORE %"
echo "BChess losses by illegal move: $ILLEGAL. Time forfeits by either engine: $TIMEOUTS. Games abandoned (disconnect or stall): $ABANDONED, unterminated: $UNTERMINATED"
echo "Wall time: $((WALL / 60)) min $((WALL % 60)) s. Games: $PGN"

if (( JUDGED == 2 )); then
    echo "INVALID RUN: an illegal move, a time forfeit, a disconnect, an unfinished game, or an SPRT that stopped without a decision, is a bug to fix, not a result. No Elo is reported." >&2
    echo "Look at the games whose Termination is not normal or adjudication in $PGN, and at $LOG" >&2
    exit 2
fi

if [[ -n $BASE ]]; then
    echo "Elo difference to $BASE_SHORT: $ELODIFF +/- $ELOERR (95 %), $(grep -E '^LLR: ' "$LOG" | tail -1)"
    case $JUDGED in
        0) echo "H1 accepted: the SPRT [$ELO0, $ELO1] ended on the upper hypothesis against $BASE_SHORT (alpha = beta = 0.05, $PLAYED games)" ;;
        4) echo "H0 accepted: the SPRT [$ELO0, $ELO1] ended on the lower hypothesis against $BASE_SHORT (alpha = beta = 0.05, $PLAYED games)" ;;
        5) echo "inconclusive at MAX_GAMES ($PLAYED games): no decision, so the change is not shown to help" ;;
    esac
    echo "| $(date +%F) | $COMMIT$([[ $TREE == dirty ]] && echo "+dirty") vs $BASE_SHORT | $TC | $PLAYED | $WINS/$DRAWS/$LOSSES | $ELODIFF ± $ELOERR | $(grep -E '^LLR: ' "$LOG" | tail -1 | sed -E 's/^LLR: (-?[0-9.]+).*/\1/') | $([[ $JUDGED == 0 ]] && echo H1 || ([[ $JUDGED == 4 ]] && echo H0 || echo none)) |"
    echo "Tools and hashes: $INFO"
    exit $JUDGED
fi

FINITE='^-?[0-9]+(\.[0-9]+)?$'
if ! [[ $ELODIFF =~ $FINITE && $ELOERR =~ $FINITE ]] || awk -v e="$ELOERR" 'BEGIN { exit !(e <= 0) }' || awk -v s="$SCORE" 'BEGIN { exit !(s < 10 || s > 90) }'; then
    if awk -v s="$SCORE" 'BEGIN { exit !(s > 50) }'; then NEXT=$((LEVEL + 300)); else NEXT=$((LEVEL - 300)); fi
    (( NEXT < 1320 )) && NEXT=1320
    echo "out of range — try LEVEL=$NEXT (the score is too far from 50 %, or there are too few games, for a useful interval). No Elo is reported."
    exit 3
fi

PERFORMANCE=$(awk -v l="$LEVEL" -v d="$ELODIFF" 'BEGIN { printf "%.0f", l + d }')
ERROR=$(awk -v e="$ELOERR" 'BEGIN { printf "%.0f", e }')
echo "Elo difference to Stockfish $LEVEL: $ELODIFF +/- $ELOERR (95 %)"
echo "Performance: $PERFORMANCE +/- $ERROR (Stockfish UCI_Elo scale, $TC)"
echo
echo "| Date | Commit | TC | Book (seed) | Stockfish level | Games | W/D/L | Performance (95 %) | Wall time |"
echo "|---|---|---|---|---|---:|---|---|---:|"
echo "| $(date +%F) | $COMMIT$([[ $TREE == dirty ]] && echo "+dirty") | $TC | 8moves_v3 ($SEED) | $LEVEL | $PLAYED | $WINS/$DRAWS/$LOSSES | $PERFORMANCE ± $ERROR | $(( (WALL + 30) / 60 )) min |"
echo "Tools and hashes: $INFO"
