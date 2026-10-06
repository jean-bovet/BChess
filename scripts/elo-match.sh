#!/bin/bash
#
# Plays BChess against Stockfish at one UCI_Elo level and reports the score and the Elo difference.
# See docs/elo.md. Everything it downloads or builds goes to the git-ignored .elo/ folder.
#
#   scripts/elo-match.sh                                  # 300 games against Stockfish at 1600, 10+0.1
#   LEVEL=1400 GAMES=100 TC=10+0.1 CONCURRENCY=4 scripts/elo-match.sh
#
# LEVEL        Stockfish's UCI_Elo (1320 is the lowest it accepts)
# GAMES        an even number: every opening is played with both colours
# TC           time control, fastchess syntax (moves/seconds+increment)
# CONCURRENCY  games played at once

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

LEVEL=${LEVEL:-1600}
GAMES=${GAMES:-300}
TC=${TC:-10+0.1}
CONCURRENCY=${CONCURRENCY:-4}

fail() { echo "error: $*" >&2; exit 1; }

[[ $LEVEL =~ ^[0-9]+$ ]] && (( LEVEL >= 1320 && LEVEL <= 3190 )) || fail "LEVEL must be between 1320 and 3190"
[[ $GAMES =~ ^[0-9]+$ ]] && (( GAMES >= 2 && GAMES % 2 == 0 )) || fail "GAMES must be an even number"
[[ $CONCURRENCY =~ ^[0-9]+$ ]] && (( CONCURRENCY >= 1 )) || fail "CONCURRENCY must be a positive number"

sha256() { shasum -a 256 "$1" | awk '{print $1}'; }

# 1. Tools
command -v stockfish > /dev/null || fail "stockfish is missing: brew install stockfish"
STOCKFISH=$(command -v stockfish)
STOCKFISH_ID=$({ echo uci; sleep 0.5; echo quit; } | "$STOCKFISH" | sed -n 's/^id name //p; /^Stockfish/p' | head -1 | sed -E 's/ by .*//')
[[ $STOCKFISH_ID == "Stockfish 19" ]] || fail "Stockfish 19 is required, found '${STOCKFISH_ID:-unknown}' at $STOCKFISH"

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

# 4. The match
STAMP=$(date +%Y%m%d-%H%M%S)
mkdir -p "$ELO/runs"
PGN="$ELO/runs/$STAMP-SF$LEVEL.pgn"
LOG="$ELO/runs/$STAMP-SF$LEVEL.log"
INFO="$ELO/runs/$STAMP-SF$LEVEL.info"
SEED=${SEED:-$(( (RANDOM << 15) | RANDOM ))}
COMMIT=$(git -C "$ROOT" rev-parse --short HEAD)
[[ -z $(git -C "$ROOT" status --porcelain) ]] && TREE=clean || TREE=dirty
{
    echo "BChess:      $COMMIT ($TREE tree), BChessUCI sha256 $(sha256 "$BCHESS")"
    echo "Stockfish:   $STOCKFISH_ID, $STOCKFISH, sha256 $(sha256 "$STOCKFISH")"
    echo "fastchess:   $FASTCHESS_ID, $FASTCHESS, sha256 $(sha256 "$FASTCHESS")"
    echo "Book:        8moves_v3.pgn sha256 $BOOK_PGN_SHA256, opening seed $SEED"
    echo "Settings:    LEVEL=$LEVEL GAMES=$GAMES TC=$TC CONCURRENCY=$CONCURRENCY"
} | tee "$INFO"
echo "Playing $GAMES games against Stockfish $LEVEL, $TC, $CONCURRENCY at a time"
START=$(date +%s)
# fastchess saves its state (config.json) in the folder it runs in
cd "$ELO/runs"
"$FASTCHESS" \
    -engine cmd="$BCHESS" name=BChess \
    -engine cmd="$STOCKFISH" name=SF$LEVEL option.UCI_LimitStrength=true option.UCI_Elo=$LEVEL option.Threads=1 option.Hash=16 \
    -each tc=$TC timemargin=100 \
    -openings file="$BOOK" format=pgn order=random -srand "$SEED" \
    -repeat -games 2 -rounds $((GAMES / 2)) -concurrency "$CONCURRENCY" -recover \
    -draw movenumber=40 movecount=8 score=10 \
    -resign movecount=4 score=1000 twosided=true \
    -pgnout file="$PGN" 2>&1 | tee "$LOG"
WALL=$(( $(date +%s) - START ))

# 5. Report
read -r ELODIFF ELOERR < <(grep -E '^Elo: ' "$LOG" | tail -1 | sed -E 's/^Elo: ([^ ]+) \+\/- ([^,]+),.*/\1 \2/')
GAMELINE=$(grep -E '^Games: ' "$LOG" | tail -1)
WINS=$(sed -E 's/.*Wins: ([0-9]+).*/\1/' <<< "$GAMELINE")
LOSSES=$(sed -E 's/.*Losses: ([0-9]+).*/\1/' <<< "$GAMELINE")
DRAWS=$(sed -E 's/.*Draws: ([0-9]+).*/\1/' <<< "$GAMELINE")
SCORE=$(sed -E 's/.*\(([0-9.]+) %\).*/\1/' <<< "$GAMELINE")
PLAYED=$((WINS + LOSSES + DRAWS))

# The games themselves are the authority: exactly GAMES results, each with a termination, agreeing with the summary
read -r PGNRESULTS PGNTERMINATIONS PGNWINS PGNLOSSES PGNDRAWS < <(awk '
    /^\[White "/ { white = ($2 == "\"BChess\"]") }
    /^\[Result "/ {
        r = $2; gsub(/[\]"]/, "", r)
        if (r == "1-0" || r == "0-1" || r == "1/2-1/2") results++
        if (r == "1/2-1/2") draws++
        else if ((white && r == "1-0") || (!white && r == "0-1")) wins++
        else if (r == "1-0" || r == "0-1") losses++
    }
    /^\[Termination "/ { terminations++ }
    END { print results + 0, terminations + 0, wins + 0, losses + 0, draws + 0 }' "$PGN")

# BChess's losses by how they ended, and the games that must not happen, from the PGN's Termination tag
read -r ILLEGAL TIMEOUTS ABANDONED UNTERMINATED < <(awk '
    /^\[White "/ { white = ($2 == "\"BChess\"]") }
    /^\[Result "/ { result = $2; gsub(/[\]"]/, "", result) }
    /^\[Termination "/ {
        t = $0; sub(/^\[Termination "/, "", t); sub(/"\]$/, "", t)
        lost = (white && result == "0-1") || (!white && result == "1-0")
        if (t == "illegal move" && lost) illegal++
        if (t == "time forfeit" && lost) timeouts++
        if (t == "abandoned") abandoned++
        if (t == "unterminated") unterminated++
    }
    END { print illegal + 0, timeouts + 0, abandoned + 0, unterminated + 0 }' "$PGN")
# Whoever made an illegal move, it is a bug to look at
ANYILLEGAL=$(grep -c '^\[Termination "illegal move"\]' "$PGN" || true)

echo
echo "Result: BChess $WINS wins, $LOSSES losses, $DRAWS draws out of $PLAYED games, score $SCORE %"
echo "BChess losses by illegal move: $ILLEGAL, by time forfeit: $TIMEOUTS. Games abandoned (disconnect or stall): $ABANDONED, unterminated: $UNTERMINATED"
echo "Wall time: $((WALL / 60)) min $((WALL % 60)) s. Games: $PGN"

if (( ANYILLEGAL > 0 || ABANDONED > 0 || UNTERMINATED > 0 || PLAYED != GAMES || PGNRESULTS != GAMES || PGNTERMINATIONS != GAMES \
      || PGNWINS != WINS || PGNLOSSES != LOSSES || PGNDRAWS != DRAWS )); then
    echo "PGN: $PGNRESULTS results, $PGNTERMINATIONS terminations, $PGNWINS/$PGNDRAWS/$PGNLOSSES (W/D/L); summary: $PLAYED games, $WINS/$DRAWS/$LOSSES; expected $GAMES games" >&2
    echo "INVALID RUN: an illegal move, a disconnect or an unfinished game is a bug to fix, not a rating. No Elo is reported." >&2
    echo "Look at the games whose Termination is not normal or adjudication in $PGN, and at $LOG" >&2
    exit 2
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
