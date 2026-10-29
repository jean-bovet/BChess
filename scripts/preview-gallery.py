"""Build and check BChess's screen gallery (planning/APP-5-gallery-scenarios.md).

The snapshot test (BChessGalleryTests/SnapshotGalleryTests) writes `<slug>.png`, `<slug>.dark.png` and
`manifest.json` into a directory; this script imports them into previews/ (gitignored) and builds
previews/index.html, one card per scenario with light and dark side by side, grouped as the manifest says.

    scripts/preview-gallery.py --import DIR [--partial]   # replace the gallery (--partial: only DIR's files)
    scripts/preview-gallery.py --import DIR --lang fr     # a language run: its PNGs into <platform>/fr/, nothing else
    scripts/preview-gallery.py --check                    # every scenario complete and correctly lit
    scripts/preview-gallery.py --coverage                 # view types no scenario names (informational)

The gallery folder is previews/, or $PREVIEW_GALLERY_OUT (the Duo pass uses previews/duo, the iPad pass previews/ipad). Its layout: only
index.html at the top, the images in <platform>/ (the manifest entry's `platform`, default iphone; an image the
manifest does not name in other/), the manifest and coverage.json in data/. A folder with its own data/ is another
gallery (previews/duo inside previews/), never an image folder: a full import removes only the PNGs of the folders
the manifests name (and other/), the manifest and the page; any other file or folder stays. Every command first moves a flat gallery of an earlier version into the layout
(resumable: whatever is still at the top is moved by the next command).

A language run (`--lang fr`) is not part of the gallery: its PNGs are copied into <platform>/<lang>/ (the platform from the
run's manifest, as for an English import; where `app-store-screenshots` looks for a localized capture), and no manifest, no
page and no check changes. A full English import never deletes those folders (it removes only the PNGs directly in a
platform folder), and the check ignores them.

--check rebuilds the page, then fails on: a scenario missing either image, a stray PNG no scenario expects,
a duplicate slug, a light image that is dark or a dark image that is light (mean luminance against 0.45,
scripts/preview-luminance.swift), a dark image byte-identical to its light one, a blank image (one colour
everywhere), an image that cannot be decoded, and a forced appearance or locale in a scenario file (its
`//` comments aside; a `\.locale` on a line carrying `// gallery: allowed, <why>` passes: a locale forced for its
region, not its language). Four manifest flags, written by the snapshot test from the scenario, make the check honest:
`documentCanvas: true` (a card dark in both appearances by design: the pair is judged instead of each image, the
dark image's mean luminance at least 0.05 below the light one's), `imagery: true` (full-bleed imagery that does not
darken in dark: the luminance rules are waived for the pair, the byte-identical rule still applies),
`drawsNothing: true` (a screen that draws nothing by design: its blank images pass) and `skipped: "<why>"` (a card
the pass could not render honestly: no images expected, the page says why).
"""
import argparse, glob, html, json, os, re, shutil, struct, subprocess, sys

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(REPO, os.environ.get('PREVIEW_GALLERY_OUT') or 'previews')
DATA = os.path.join(OUT, 'data')
MANIFEST = os.path.join(DATA, 'manifest.json')
DEFAULT_PLATFORM = 'iphone'
OTHER = 'other'
SCENARIO_FILES = [os.path.join(REPO, folder, name) for folder, name in (
    ('BChessGalleryTests', 'GalleryScenarios.swift'), ('BChessGalleryTests', 'GalleryFixtures.swift'),
    ('BChessMacGalleryTests', 'MacGalleryScenarios.swift'))]
LUMINANCE_THRESHOLD = 0.45
CANVAS_CONTRAST = 0.05   # documentCanvas: how much darker (mean luminance) the dark image must be than the light one
PHONE_ASPECT = 402 / 874
PASS_LABELS = {'duo': 'iPhone Duo', 'ipad': 'iPad', 'mac': 'Mac'}   # the gallery folder's name -> the device the page says


def slug(s):
    return re.sub(r'[^a-z0-9]+', '-', s.lower()).strip('-')


def load_manifest():
    if not os.path.isfile(MANIFEST):
        sys.exit(f'no {os.path.relpath(MANIFEST, REPO)}: run scripts/snapshot-gallery.sh')
    with open(MANIFEST, encoding='utf-8') as handle:
        return json.load(handle)


def platform_of(entry):
    return entry.get('platform') or DEFAULT_PLATFORM


def read_manifest(path):
    if not os.path.isfile(path):
        return []
    with open(path, encoding='utf-8') as handle:
        return json.load(handle)


def image_folders(*manifests):
    """The folders of OUT this tool owns images in: the platforms the manifests name, and other/. Never another
    directory (previews/duo is another gallery, previews/notes is somebody's); only their existing ones."""
    names = {OTHER}
    for manifest in manifests:
        names |= {platform_of(entry) for entry in manifest}
    return sorted(name for name in names if os.path.isdir(os.path.join(OUT, name)))


def image_stem(name):
    return name[:-len('.dark.png')] if name.endswith('.dark.png') else name[:-len('.png')]


def migrate():
    """Moves a flat gallery (images, manifest.json at the top) into the layout; safe to run again after a stop."""
    if not os.path.isdir(OUT):
        return
    flat_manifest = os.path.join(OUT, 'manifest.json')
    if os.path.isfile(flat_manifest):
        os.makedirs(DATA, exist_ok=True)
        os.replace(flat_manifest, MANIFEST)
    platforms = {}
    if os.path.isfile(MANIFEST):
        with open(MANIFEST, encoding='utf-8') as handle:
            platforms = {entry['slug']: platform_of(entry) for entry in json.load(handle)}
    for name in sorted(os.listdir(OUT)):
        path = os.path.join(OUT, name)
        if name.endswith('.png') and os.path.isfile(path):
            folder = platforms.get(image_stem(name), OTHER)
            os.makedirs(os.path.join(OUT, folder), exist_ok=True)
            os.replace(path, os.path.join(OUT, folder, name))


def do_import(source, partial):
    source_manifest = os.path.join(source, 'manifest.json')
    if not os.path.isfile(source_manifest):
        sys.exit(f'{source} has no manifest.json: the snapshot test did not finish')
    migrate()
    new_manifest = read_manifest(source_manifest)
    platforms = {entry['slug']: platform_of(entry) for entry in new_manifest}
    pngs = sorted(glob.glob(os.path.join(source, '*.png')))
    if not partial:
        # Only what this tool placed: the PNGs of the folders the manifests name, the manifest and the page
        for folder in image_folders(read_manifest(MANIFEST), new_manifest):
            for name in os.listdir(os.path.join(OUT, folder)):
                if name.endswith('.png'):
                    os.remove(os.path.join(OUT, folder, name))
        for stale in (MANIFEST, os.path.join(OUT, 'index.html')):
            if os.path.isfile(stale):
                os.remove(stale)
    os.makedirs(DATA, exist_ok=True)
    for png in pngs:
        folder = platforms.get(image_stem(os.path.basename(png)), OTHER)
        os.makedirs(os.path.join(OUT, folder), exist_ok=True)
        shutil.copy2(png, os.path.join(OUT, folder))
    shutil.copy2(source_manifest, MANIFEST)
    print(f'imported {len(pngs)} image(s) into {os.path.relpath(OUT, REPO)}/')


def do_import_language(source, lang):
    """A language run: the PNGs of `source` into <OUT>/<platform>/<lang>/. The gallery itself (manifest, page, English images)
    is untouched, and it need not exist yet."""
    source_manifest = os.path.join(source, 'manifest.json')
    if not os.path.isfile(source_manifest):
        sys.exit(f'{source} has no manifest.json: the snapshot test did not finish')
    platforms = {entry['slug']: platform_of(entry) for entry in read_manifest(source_manifest)}
    counts = {}
    for png in sorted(glob.glob(os.path.join(source, '*.png'))):
        folder = platforms.get(image_stem(os.path.basename(png)), OTHER)
        destination = os.path.join(OUT, folder, lang)
        os.makedirs(destination, exist_ok=True)
        shutil.copy2(png, destination)
        counts[folder] = counts.get(folder, 0) + 1
    for folder in sorted(counts):
        print(f'imported {counts[folder]} image(s) [{lang}] into {os.path.relpath(os.path.join(OUT, folder, lang), REPO)}/')


def luminances(manifest):
    """{'<folder>/<file>': (mean luminance, spread)} for every PNG of the gallery; both -1 for an undecodable one."""
    result = subprocess.run(['swift', os.path.join(REPO, 'scripts', 'preview-luminance.swift'),
                             *[os.path.join(OUT, folder) for folder in image_folders(manifest)]],
                            capture_output=True, text=True)
    values = {}
    for line in result.stdout.splitlines():
        value, spread, name = line.split(' ', 2)
        values[name] = (float(value), float(spread))
    return values, (result.stderr.strip()[:200] if result.returncode != 0 else None)


def size_ratio(entry):
    """Width / height of a scenario from the manifest's "WxH"; 0 when unreadable."""
    try:
        width, height = entry['size'].split('x')
        return int(width) / int(height)
    except (KeyError, ValueError, ZeroDivisionError):
        return 0


def build_page(manifest):
    groups = {}
    for entry in manifest:
        groups.setdefault(entry['group'], []).append(entry)

    def slot(dest, tag, label, skipped=None):
        if skipped:
            return f'<div class="missing">not rendered on this pass: {html.escape(skipped)}</div>'
        if os.path.isfile(os.path.join(OUT, dest)):
            return f'<a href="{dest}"><img src="{dest}" alt="{html.escape(label)} · {tag}" loading="lazy"></a>'
        return '<div class="missing">missing</div>'

    def figure(entry):
        label = entry['name']
        # A landscape render is drawn as tall as a phone card, so it gets proportionally wider
        ratio = size_ratio(entry) / PHONE_ASPECT
        style = f' style="--r:{ratio:.2f}"' if ratio > 1.05 else ''
        return (f'<figure id="{entry["slug"]}"{style}><figcaption>{html.escape(label)}</figcaption><div class="pair">'
                f'<div class="shot shot-light">{slot(platform_of(entry) + "/" + entry["slug"] + ".png", "Light", label, entry.get("skipped"))}<span class="tag">Light</span></div>'
                f'<div class="shot shot-dark">{slot(platform_of(entry) + "/" + entry["slug"] + ".dark.png", "Dark", label, entry.get("skipped"))}<span class="tag">Dark</span></div>'
                f'</div></figure>')

    sections, links = [], []
    for title, entries in groups.items():
        section_id = slug(title)
        sections.append(f'<section id="{section_id}"><h2>{html.escape(title)}</h2><div class="row">'
                        f'{"".join(figure(e) for e in entries)}</div></section>')
        links.append(f'<a href="#{section_id}">{html.escape(title)}</a>')
    os.makedirs(OUT, exist_ok=True)
    with open(os.path.join(OUT, 'index.html'), 'w', encoding='utf-8') as handle:
        handle.write(page(manifest, ''.join(sections), ''.join(links)))


def do_check():
    migrate()
    manifest = load_manifest()
    build_page(manifest)
    problems = []
    slugs = [e['slug'] for e in manifest]
    for dup in sorted({s for s in slugs if slugs.count(s) > 1}):
        problems.append(f'duplicate slug: {dup}')
    expected = {f'{platform_of(e)}/{e["slug"]}{suffix}' for e in manifest if not e.get('skipped')
                for suffix in ('.png', '.dark.png')}
    on_disk = {f'{folder}/{name}' for folder in image_folders(manifest)
               for name in os.listdir(os.path.join(OUT, folder)) if name.endswith('.png')}
    for name in sorted(expected - on_disk):
        problems.append(f'missing: {name}')
    for name in sorted(on_disk - expected):
        problems.append(f'stray image (no scenario): {name}')
    for e in manifest:
        if e.get('skipped'):
            continue
        s = e['slug']
        light = os.path.join(OUT, platform_of(e), s + '.png')
        dark = os.path.join(OUT, platform_of(e), s + '.dark.png')
        if os.path.isfile(light) and os.path.isfile(dark):
            with open(light, 'rb') as a, open(dark, 'rb') as b:
                if a.read() == b.read():
                    problems.append(f'dark identical to light: {s}')
    luminance, error = luminances(manifest)
    if error:
        problems.append('luminance helper failed: ' + error)
    flags = {f'{platform_of(e)}/{e["slug"]}': e for e in manifest}
    for name, (value, spread) in sorted(luminance.items()):
        is_dark_slot = name.endswith('.dark.png')
        entry = flags.get(image_stem(name), {})
        if value < 0:
            problems.append(f'undecodable image: {name}')
            continue
        if spread == 0 and not entry.get('drawsNothing'):
            problems.append(f'blank render (one colour everywhere): {name}')
        if entry.get('documentCanvas') or entry.get('imagery'):
            continue   # dark by design in both appearances (the pair is judged below), or imagery: no luminance rule
        if (value < LUMINANCE_THRESHOLD) != is_dark_slot:
            shown = 'dark' if value < LUMINANCE_THRESHOLD else 'light'
            problems.append(f'{shown} render in the {"dark" if is_dark_slot else "light"} slot: {name} (luminance {value:.6f})')
    for e in manifest:
        if not e.get('documentCanvas') or e.get('skipped'):
            continue
        stem = f'{platform_of(e)}/{e["slug"]}'
        light, dark = luminance.get(stem + '.png'), luminance.get(stem + '.dark.png')
        if light and dark and min(light[0], dark[0]) >= 0 and light[0] - dark[0] < CANVAS_CONTRAST:
            problems.append(f'document canvas not darker in dark: {stem} (luminance light {light[0]:.6f}, dark {dark[0]:.6f}, '
                            f'needs {CANVAS_CONTRAST} apart)')
    # The luminance check misses a forced locale, so the scenarios file is read for it (comments aside)
    for path in SCENARIO_FILES:
        if not os.path.isfile(path):
            continue
        with open(path, encoding='utf-8') as handle:
            for number, line in enumerate(handle, 1):
                code = line.split('//', 1)[0]
                allowed = '// gallery: allowed' in line   # a locale forced for its region (en_US: a 12-hour clock)
                if re.search(r'\.preferredColorScheme', code) or (re.search(r'\\\.locale', code) and not allowed):
                    problems.append(f'forced appearance or locale: {os.path.basename(path)}:{number}')
    if problems:
        print(f'CHECK FAILED [en] ({len(problems)}):')
        for problem in problems:
            print('  ' + problem)
        sys.exit(1)
    print(f'CHECK OK [en]: {len(manifest)} cards, light and dark complete and correctly lit')


def do_coverage():
    """View types under Shared/, iOS/ and macOS/ that no scenario file names (informational)."""
    views = set()
    for folder in ('Shared', 'iOS', 'macOS'):
        for path in glob.glob(os.path.join(REPO, folder, '**', '*.swift'), recursive=True):
            with open(path, encoding='utf-8') as handle:
                views |= set(re.findall(r'^\s*(?:private |fileprivate )?struct (\w+)\s*:\s*[^{]*\bView\b', handle.read(), re.M))
    scenarios = ''
    for path in SCENARIO_FILES:
        if os.path.isfile(path):
            with open(path, encoding='utf-8') as handle:
                scenarios += handle.read()
    missing = sorted(v for v in views if not re.search(rf'\b{v}\b', scenarios))
    print(f'{len(views) - len(missing)} of {len(views)} view types appear in a scenario; not rendered:')
    for view in missing:
        print('  ' + view)
    os.makedirs(DATA, exist_ok=True)
    with open(os.path.join(DATA, 'coverage.json'), 'w', encoding='utf-8') as handle:
        json.dump({'views': len(views), 'notRendered': missing}, handle, indent=2)


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
<p class="meta">{len(cards)} screens ({PASS_LABELS.get(os.path.basename(OUT), 'iPhone')}) · light and dark side by side.</p>
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
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument('--import', dest='source', metavar='DIR', help='replace previews/ with the renders in DIR')
    parser.add_argument('--partial', action='store_true', help='with --import: keep previews/ and replace only the files in DIR')
    parser.add_argument('--lang', metavar='LANG', help='with --import: a language run (fr, de, it, he, ar): copy the PNGs into <platform>/LANG/')
    parser.add_argument('--check', action='store_true', help='rebuild the page and check; exit 1 on any problem')
    parser.add_argument('--coverage', action='store_true', help='list the view types no scenario names')
    opts = parser.parse_args()
    if opts.lang and not opts.source:
        parser.error('--lang goes with --import')
    if opts.lang and not re.fullmatch(r'[a-z]{2,3}(-[A-Za-z]{2,4})?', opts.lang):
        parser.error(f'--lang {opts.lang!r} is not a language code')
    if opts.lang:
        do_import_language(opts.source, opts.lang)
        return
    migrate()
    if opts.source:
        do_import(opts.source, opts.partial)
        build_page(load_manifest())
    if opts.check:
        do_check()
    if opts.coverage:
        do_coverage()
    if not (opts.source or opts.check or opts.coverage):
        parser.print_help()


if __name__ == '__main__':
    main()
