"""Assemble previews/index.html from the PNGs of BChessGalleryTests and check the gallery.

Usage: python3 scripts/preview-gallery.py --snapshot FILE             # record the source files (before the build)
       python3 scripts/preview-gallery.py --import DIR --sources FILE # replace the gallery with the renders in DIR, then check
       python3 scripts/preview-gallery.py --check                     # rebuild the page from previews/ and check; exit 1 on any problem

DIR is the tree SnapshotGalleryTests writes (scripts/snapshot-gallery.sh passes it):
    <light|dark>/<file stem>/<preview name>.png
Renders are matched to previews by (file, name). The import deletes every PNG and the manifest in
previews/ first, so a slot with no render in DIR is missing, never an old PNG. Each render is copied to a
flat name, <slug(file stem)>-<slug(name)>[.dark].png.

Freshness is recorded in previews/.freshness.json: the mtime of every file under Shared/ and iOS/ and of
BChess/Openings.pgn, as snapshotted before the build (--snapshot), and each PNG's mtime. Every card is stale
when that list differs from the files now (a file edited, added or deleted, also during the run), and a
single card is stale when its PNG's mtime changed since the import.

--check reports: a missing or stale slot, a light render that is dark or a dark render that is light (mean
luminance against 0.45, scripts/preview-luminance.swift), an undecodable image, an unnamed #Preview, a
duplicate (file, name) or file basename, a slug collision, a stray PNG in previews/, a #Preview in a form this script
cannot read, a render with no #Preview (a scenario without a
preview), a #Preview that does not render its own scenario, and a forced appearance or locale in
PreviewScenarios.swift.
"""
import argparse, glob, html, json, os, re, shutil, struct, subprocess, sys, unicodedata

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(REPO, 'previews')
MANIFEST = os.path.join(OUT, '.freshness.json')
MANIFEST_VERSION = 2
SCENARIOS = os.path.join(REPO, 'Shared', 'PreviewSupport', 'PreviewScenarios.swift')
SOURCE_GLOBS = ['Shared/**/*.swift', 'iOS/**/*.swift']
FRESHNESS_ROOTS = ['Shared', 'iOS', os.path.join('BChess', 'Openings.pgn')]
LUMINANCE_THRESHOLD = 0.45
PHONE_ASPECT = 402 / 874

# Section title -> file stems, in display order. A file not listed goes to "Other screens".
SECTIONS = [
    ('Game', ['ContentView', 'PlayerRow', 'StatusLine', 'NavigationButtons']),
    ('Board', ['BoardView', 'LabelsView', 'PiecesView', 'PromotionView', 'VariationSelectionView', 'Arrow']),
    ('Engine', ['EngineView']),
    ('Moves', ['MoveStrip', 'MoveListView']),
    ('Games list', ['GameRootView', 'NewGameView_iOS', 'NewGameView']),
    ('Settings', ['SettingsView']),
    ]


def slug(s):
    s = unicodedata.normalize('NFKD', s).encode('ascii', 'ignore').decode()
    return re.sub(r'[^a-z0-9]+', '-', s.lower()).strip('-')


def base_name(stem, name):
    return f'{slug(stem)}-{slug(name)}'


def discover_previews(problems):
    """[{file, stem, name, path, line, ident}] for every #Preview under SOURCE_GLOBS, in source order.
    Reports unnamed previews and bodies that are not exactly PreviewScenarios.<ident>.view()."""
    paths = sorted({p for pattern in SOURCE_GLOBS for p in glob.glob(os.path.join(REPO, pattern), recursive=True)})
    previews = []
    for path in paths:
        with open(path, encoding='utf-8') as source:
            lines = source.read().splitlines()
        relative = os.path.relpath(path, REPO)
        for i, line in enumerate(lines):
            if '#Preview' not in line or line.lstrip().startswith('//'):
                continue
            match = re.fullmatch(r'#Preview(?:\("([^"]*)"\))? \{', line.strip())
            if not match:
                problems.append(f'unsupported #Preview form (use `#Preview("Name") {{`): {relative}:{i + 1}')
                continue
            body = []
            for following in lines[i + 1:]:
                if following.rstrip() == '}':
                    break
                body.append(following.strip())
            name = match.group(1)
            if name is None:
                problems.append(f'unnamed #Preview: {relative}:{i + 1}')
                continue
            call = re.fullmatch(r'PreviewScenarios\.(\w+)\.view\(\)', ' '.join(body))
            previews.append({'file': os.path.basename(path), 'stem': os.path.basename(path)[:-6], 'name': name,
                             'path': relative, 'line': i + 1, 'ident': call.group(1) if call else None})
    return previews


def read_scenarios(problems):
    """{ident: (file, name)} from the one-line declarations of PreviewScenarios.swift."""
    scenarios = {}
    with open(SCENARIOS, encoding='utf-8') as source:
        text = source.read()
    for number, line in enumerate(text.splitlines(), 1):
        if re.search(r'preferredColorScheme\(|\\\.locale', line):
            problems.append(f'forced appearance or locale in PreviewScenarios.swift:{number}')
        if not re.match(r'\s*static let \w+ = PreviewScenario\(', line):
            continue
        match = re.match(r'\s*static let (\w+) = PreviewScenario\(file: "([^"]+)", name: "([^"]+)"', line)
        if match:
            # (file, name, in the gallery): `gallery: false` keeps the #Preview for Xcode, with no card
            scenarios[match.group(1)] = (match.group(2), match.group(3), 'gallery: false' not in line)
        else:
            problems.append(f'scenario declaration breaks the one-line convention: PreviewScenarios.swift:{number}')
    return scenarios


def check_sources(previews, scenarios, problems):
    seen, files, slugs = {}, {}, {}
    for p in previews:
        key = (p['file'], p['name'])
        if key in seen:
            problems.append(f'duplicate #Preview (file, name): {p["file"]} / {p["name"]}')
        seen[key] = p
        if files.setdefault(p['file'], p['path']) != p['path']:
            problems.append(f'duplicate file basename: {p["file"]} ({files[p["file"]]}, {p["path"]})')
        base = base_name(p['stem'], p['name'])
        if slugs.setdefault(base, key) != key:
            problems.append(f'slug collision: {base} ({slugs[base]} and {key})')
        if p['ident'] is None:
            problems.append(f'#Preview does not call PreviewScenarios.<scenario>.view(): {p["path"]}:{p["line"]} ({p["name"]})')
        elif p['ident'] not in scenarios:
            problems.append(f'#Preview calls an unknown scenario {p["ident"]}: {p["path"]}:{p["line"]}')
        elif scenarios[p['ident']][:2] != key:
            problems.append(f'#Preview renders another scenario: {p["path"]}:{p["line"]} ({p["name"]}) calls {p["ident"]}, '
                            f'which is {scenarios[p["ident"]][0]} / {scenarios[p["ident"]][1]}')


def source_files():
    """{project-relative path: mtime} of every file whose change can change a card."""
    files = {}
    for root in FRESHNESS_ROOTS:
        path = os.path.join(REPO, root)
        if os.path.isfile(path):
            files[root] = os.path.getmtime(path)
            continue
        for directory, _, names in os.walk(path):
            for name in names:
                if name != '.DS_Store':
                    full = os.path.join(directory, name)
                    files[os.path.relpath(full, REPO)] = os.path.getmtime(full)
    return files


def do_import(source, previews, sources):
    """Replace previews/ with the renders in `source`. Returns the manifest."""
    os.makedirs(OUT, exist_ok=True)
    for name in os.listdir(OUT):
        if name.endswith('.png') or name in ('.freshness.json', 'index.html'):
            os.remove(os.path.join(OUT, name))
    known = {(p['stem'], p['name']) for p in previews}
    files, orphans = {}, []
    for appearance in ('light', 'dark'):
        for png in sorted(glob.glob(os.path.join(source, appearance, '*', '*.png'))):
            stem = os.path.basename(os.path.dirname(png))
            name = os.path.basename(png)[:-4]
            if (stem, name) not in known:
                orphans.append(f'{stem}.swift / {name} ({appearance})')
                continue
            dest = base_name(stem, name) + ('.dark.png' if appearance == 'dark' else '.png')
            shutil.copy2(png, os.path.join(OUT, dest))
            files[dest] = os.path.getmtime(os.path.join(OUT, dest))
    manifest = {'version': MANIFEST_VERSION, 'sources': sources, 'files': files, 'orphans': orphans}
    with open(MANIFEST, 'w', encoding='utf-8') as handle:
        json.dump(manifest, handle, indent=1, sort_keys=True)
    return manifest


def load_manifest():
    try:
        with open(MANIFEST, encoding='utf-8') as handle:
            loaded = json.load(handle)
        if isinstance(loaded, dict) and loaded.get('version') == MANIFEST_VERSION:
            return loaded
    except (OSError, ValueError):
        pass
    return {'version': MANIFEST_VERSION, 'sources': None, 'files': {}, 'orphans': []}


def luminances():
    result = subprocess.run(['swift', os.path.join(REPO, 'scripts', 'preview-luminance.swift'), OUT],
                            capture_output=True, text=True)
    values = {}
    for line in result.stdout.splitlines():
        value, _, name = line.partition(' ')
        values[name] = float(value)
    return values, (result.stderr.strip()[:200] if result.returncode != 0 else None)


def aspect(path):
    """Width / height of a PNG, from its header; 0 when unreadable."""
    try:
        with open(path, 'rb') as handle:
            header = handle.read(24)
        width, height = struct.unpack('>II', header[16:24])
        return width / height
    except (OSError, struct.error, ZeroDivisionError):
        return 0


def section_order(stem):
    for index, (title, stems) in enumerate(SECTIONS):
        if stem in stems:
            return index, stems.index(stem), title
    return len(SECTIONS), 0, 'Other screens'


def page(cards, sections_html, links_html):
    return f'''<!doctype html>
<html lang="en"><head>
<script>
(function(){{
  var m;
  try {{ m = localStorage.getItem('bchess-gallery-mode'); }} catch(e) {{}}
  if (m !== 'light' && m !== 'dark' && m !== 'both') {{
    m = (window.matchMedia && matchMedia('(prefers-color-scheme: dark)').matches) ? 'dark' : 'light';
  }}
  document.documentElement.setAttribute('data-mode', m);
}})();
</script>
<meta charset="utf-8"><title>BChess — screen gallery</title>
<meta name="viewport" content="width=device-width, initial-scale=1">
<style>
:root {{ --bg:#f6f4ef; --ink:#1e1d1a; --muted:#6c6a63; --card:#fff; --line:#e4e0d6; --missing-bg:#f0ede4; --accent:#7a4a24; --accent-ink:#5c3818; }}
html[data-mode="dark"] {{ --bg:#1c1b19; --ink:#eeeae2; --muted:#a39c8f; --card:#26241f; --line:#3a372f; --missing-bg:#211f1a; --accent:#c9935f; --accent-ink:#e0b283; }}
@media (prefers-color-scheme: dark) {{
  html[data-mode="both"] {{ --bg:#1c1b19; --ink:#eeeae2; --muted:#a39c8f; --card:#26241f; --line:#3a372f; --missing-bg:#211f1a; --accent:#c9935f; --accent-ink:#e0b283; }}
}}
body {{ margin:0; padding:24px 16px 48px; background:var(--bg); color:var(--ink);
  font:15px/1.4 -apple-system, "SF Pro Text", system-ui, sans-serif; }}
h1 {{ font-size:22px; margin:0 0 4px; }} p.meta {{ margin:0 0 24px; color:var(--muted); }}
h2 {{ font-size:20px; font-weight:650; margin:36px 0 16px; }}
.switch {{ display:inline-flex; gap:4px; padding:4px; margin-bottom:20px; background:var(--card); border:1px solid var(--line); border-radius:22px; }}
.switch button {{ appearance:none; border:0; background:transparent; color:var(--muted); font:inherit; font-weight:600; font-size:13px; padding:7px 16px; border-radius:18px; cursor:pointer; }}
.switch button[aria-pressed="true"] {{ background:var(--accent); color:#fff; }}
nav {{ display:flex; flex-wrap:wrap; gap:8px; margin-bottom:28px; }}
nav a {{ color:var(--ink); text-decoration:none; background:var(--card); border:1px solid var(--line); border-radius:20px; padding:7px 12px; }}
nav a:hover, nav a:focus-visible {{ border-color:var(--accent); color:var(--accent-ink); }}
section {{ scroll-margin-top:20px; }}
.row {{ display:flex; flex-wrap:wrap; gap:16px; }}
figure {{ margin:0; width:calc(310px * var(--r, 1) + 10px); }}
figcaption {{ padding:0 4px 8px; font-weight:600; }}
.pair {{ display:flex; flex-wrap:wrap; gap:8px; }}
.shot {{ width:calc(150px * var(--r, 1)); }}
.shot img, .shot .missing {{ width:calc(150px * var(--r, 1)); display:block; border:1px solid var(--line); border-radius:16px; background:var(--card); box-sizing:border-box; }}
.shot .missing {{ aspect-ratio:9/19.5; display:flex; align-items:center; justify-content:center; color:var(--muted); font-size:12px; background:var(--missing-bg); }}
.shot img.stale {{ opacity:.45; filter:grayscale(60%); }}
.shot .tag {{ display:block; text-align:center; font-size:11px; color:var(--muted); margin-top:4px; }}
html[data-mode="light"] .shot-dark, html[data-mode="dark"] .shot-light {{ display:none; }}
html[data-mode="light"] figure, html[data-mode="dark"] figure {{ width:calc(240px * var(--r, 1) + 16px); }}
html[data-mode="light"] .shot, html[data-mode="dark"] .shot {{ width:calc(240px * var(--r, 1)); }}
html[data-mode="light"] .shot img, html[data-mode="light"] .shot .missing,
html[data-mode="dark"] .shot img, html[data-mode="dark"] .shot .missing {{ width:calc(240px * var(--r, 1)); }}
</style></head><body>
<div class="switch" role="group" aria-label="Appearance">
<button type="button" data-mode-btn="light" aria-pressed="false">Light</button>
<button type="button" data-mode-btn="dark" aria-pressed="false">Dark</button>
<button type="button" data-mode-btn="both" aria-pressed="false">Both</button>
</div>
<h1>BChess — screen gallery</h1>
<p class="meta">{len(cards)} screens (iPhone) · light and dark side by side · everyday views first.</p>
<nav aria-label="Gallery sections">{links_html}</nav>
{sections_html}
<script>
(function(){{
  var root = document.documentElement;
  var btns = document.querySelectorAll('[data-mode-btn]');
  function sync(){{
    var m = root.getAttribute('data-mode');
    for (var i = 0; i < btns.length; i++) {{
      btns[i].setAttribute('aria-pressed', btns[i].getAttribute('data-mode-btn') === m ? 'true' : 'false');
    }}
  }}
  for (var i = 0; i < btns.length; i++) {{
    btns[i].addEventListener('click', function(e){{
      var m = e.currentTarget.getAttribute('data-mode-btn');
      root.setAttribute('data-mode', m);
      try {{ localStorage.setItem('bchess-gallery-mode', m); }} catch(err) {{}}
      sync();
    }});
  }}
  sync();
}})();
</script>
</body></html>'''


def main():
    args = argparse.ArgumentParser()
    mode = args.add_mutually_exclusive_group(required=True)
    mode.add_argument('--snapshot', metavar='FILE', help='record the source files in FILE (run before the build)')
    mode.add_argument('--import', dest='source', metavar='DIR', help='replace the gallery with the renders in DIR, then check')
    mode.add_argument('--check', action='store_true', help='rebuild the page from previews/ and check; exit 1 on any problem')
    args.add_argument('--sources', metavar='FILE', help='with --import: the --snapshot file made before the build')
    opts = args.parse_args()
    if opts.snapshot:
        with open(opts.snapshot, 'w', encoding='utf-8') as handle:
            json.dump(source_files(), handle, sort_keys=True)
        return
    if opts.source and not opts.sources:
        args.error('--import needs --sources')

    problems = []
    previews = discover_previews(problems)
    scenarios = read_scenarios(problems)
    check_sources(previews, scenarios, problems)
    # A scenario with `gallery: false` is known but not expected: no render, no card
    previews = [p for p in previews if scenarios.get(p['ident'], (0, 0, True))[2]]

    if opts.source:
        with open(opts.sources, encoding='utf-8') as handle:
            manifest = do_import(opts.source, previews, json.load(handle))
    else:
        manifest = load_manifest()
    os.makedirs(OUT, exist_ok=True)
    for orphan in manifest.get('orphans', []):
        problems.append(f'scenario without a preview: {orphan}')

    sources_changed = manifest.get('sources') != source_files()
    luminance, luminance_error = luminances()
    if luminance_error:
        problems.append('luminance helper failed: ' + luminance_error)

    cards = []
    for p in previews:
        base = base_name(p['stem'], p['name'])
        card = {'p': p, 'label': p['name'], 'id': base}
        for appearance, dest in (('light', base + '.png'), ('dark', base + '.dark.png')):
            path = os.path.join(OUT, dest)
            ok = os.path.isfile(path)
            recorded = manifest.get('files', {}).get(dest)
            stale = ok and (sources_changed or recorded is None or os.path.getmtime(path) != recorded)
            card[appearance] = (dest, ok, stale)
            if not ok:
                problems.append(f'missing {appearance}: {p["file"]} / {p["name"]} ({dest})')
            elif stale:
                problems.append(f'stale {appearance}: {p["file"]} / {p["name"]} ({dest})')
            elif luminance.get(dest, -1) < 0:
                problems.append(f'undecodable image: {dest}')
            elif (luminance[dest] < LUMINANCE_THRESHOLD) != (appearance == 'dark'):
                shown = 'dark' if luminance[dest] < LUMINANCE_THRESHOLD else 'light'
                problems.append(f'{shown} render in the {appearance} slot: {dest} (luminance {luminance[dest]:.6f})')
        cards.append(card)

    expected = {name for c in cards for name in (c['light'][0], c['dark'][0])}
    for name in sorted(os.listdir(OUT)):
        if name.endswith('.png') and name not in expected:
            problems.append(f'stray image: {name}')

    cards.sort(key=lambda c: (section_order(c['p']['stem'])[:2], c['p']['line']))
    sections, links = [], []
    for title in [t for t, _ in SECTIONS] + ['Other screens']:
        entries = [c for c in cards if section_order(c['p']['stem'])[2] == title]
        if not entries:
            continue

        def slot(dest, ok, stale, tag, label):
            if ok:
                cls = ' class="stale"' if stale else ''
                return f'<a href="{dest}"><img{cls} src="{dest}" alt="{html.escape(label)} · {tag}" loading="lazy"></a>'
            return '<div class="missing">missing</div>'

        def figure(c):
            (dl, lo, ls), (dd, do, ds) = c['light'], c['dark']
            label = c['label']
            # A landscape render is drawn as tall as a phone card, so it gets proportionally wider
            ratio = aspect(os.path.join(OUT, dl)) / PHONE_ASPECT
            style = f' style="--r:{ratio:.2f}"' if ratio > 1.05 else ''
            return (f'<figure id="{c["id"]}"{style}><figcaption>{html.escape(label)}</figcaption><div class="pair">'
                    f'<div class="shot shot-light">{slot(dl, lo, ls, "Light", label)}<span class="tag">Light{" · stale" if ls else ""}</span></div>'
                    f'<div class="shot shot-dark">{slot(dd, do, ds, "Dark", label)}<span class="tag">Dark{" · stale" if ds else ""}</span></div>'
                    f'</div></figure>')

        section_id = slug(title)
        sections.append(f'<section id="{section_id}"><h2>{html.escape(title)}</h2><div class="row">'
                        f'{"".join(figure(c) for c in entries)}</div></section>')
        links.append(f'<a href="#{section_id}">{html.escape(title)}</a>')
    with open(os.path.join(OUT, 'index.html'), 'w', encoding='utf-8') as handle:
        handle.write(page(cards, ''.join(sections), ''.join(links)))

    if problems:
        print(f'CHECK FAILED ({len(problems)}):')
        for problem in problems:
            print('  ' + problem)
        sys.exit(1)
    print(f'CHECK OK: {len(cards)} cards, light and dark complete and correctly lit')


if __name__ == '__main__':
    main()
