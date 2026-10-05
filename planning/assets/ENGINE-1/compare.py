import chess, subprocess, sys
def ref_divide(b, d):
    out = {}
    def perft(b, d):
        if d == 1: return b.legal_moves.count()
        n = 0
        for m in b.legal_moves:
            b.push(m); n += perft(b, d - 1); b.pop()
        return n
    for m in list(b.legal_moves):
        b.push(m); out[m.uci()] = 1 if d == 1 else perft(b, d - 1); b.pop()
    return out
def eng_divide(fen, d, path):
    r = subprocess.run(['./divide', fen, str(d)] + path, capture_output=True, text=True)
    return {l.split()[0]: int(l.split()[1]) for l in r.stdout.split('\n') if l.strip()}, r.stderr.strip()
def find(fen, d, path):
    b = chess.Board(fen)
    for m in path: b.push_uci(m)
    ref = ref_divide(b, d); eng, efen = eng_divide(fen, d, path)
    extra = sorted(set(eng) - set(ref)); missing = sorted(set(ref) - set(eng))
    if extra or missing:
        print('after', ' '.join(path)); print('  reference FEN:', b.fen()); print(' ', efen)
        print('  engine-only moves:', extra); print('  missing moves:', missing); return
    for m in ref:
        if ref[m] != eng.get(m):
            return find(fen, d - 1, path + [m])
    print('no difference')
find(sys.argv[1], int(sys.argv[2]), [])
