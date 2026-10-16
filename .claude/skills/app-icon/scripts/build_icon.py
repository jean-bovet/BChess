#!/usr/bin/env python3
"""Build a reference-derived Icon Composer package from an explicit layer manifest."""
import argparse
import json
from pathlib import Path
import re
import shutil
import subprocess
import tempfile


def run(*args):
    subprocess.run(list(map(str, args)), check=True, capture_output=True, text=True)


def image(*args):
    run('magick', *args)


def source_path(base, name):
    p = (base / name).resolve()
    if not p.is_file() or p.suffix.lower() not in ('.png', '.svg'):
        raise ValueError(f'Expected an existing PNG/SVG: {name}')
    return p


def shade(src, dst, options):
    floor = float(options.get('shadow_floor', 0.55))
    threshold = float(options.get('threshold', 0.18))
    span = float(options.get('range', 0.65))
    if not 0 <= floor <= 1 or not 0 <= threshold <= 1 or span <= 0:
        raise ValueError('Invalid dark compression values')
    fx = f'aa=max(0,min(1,(max(r,max(g,b))-{threshold})/{span})); u*({floor}+(1-{floor})*aa*aa*(3-2*aa))'
    image(src, '-channel', 'RGB', '-fx', fx, '+channel', dst)


def build(manifest_path, output):
    manifest_path = manifest_path.resolve()
    output = output.resolve()
    cfg = json.loads(manifest_path.read_text())
    layers = cfg.get('layers', [])
    if not 1 <= len(layers) <= 4:
        raise ValueError('Provide one to four back-to-front depth groups')
    if output.exists():
        raise ValueError('Output already exists; use a fresh sibling output directory')
    if output.suffix != '.icon':
        raise ValueError('Output must end in .icon')
    if shutil.which('magick') is None:
        raise ValueError('ImageMagick is required (magick is missing)')
    base = manifest_path.parent
    names = set()
    for layer in layers:
        name = layer.get('name', '')
        if not re.fullmatch(r'[A-Za-z0-9][A-Za-z0-9_-]{0,63}', name) or name in names:
            raise ValueError(f'Layer names must be unique simple names: {name}')
        names.add(name)
        if sum(key in layer for key in ('image', 'mask', 'diffuse_background')) != 1:
            raise ValueError(f'{name}: choose exactly one image, mask, or diffuse_background')
        if layer.get('material', 'native') not in ('native', 'fidelity'):
            raise ValueError(f'{name}: unknown material mode')
        for key in ('image', 'dark_image', 'mono_image'):
            if key in layer:
                source_path(base, layer[key])
    needs_ref = any('image' not in layer for layer in layers)
    if needs_ref:
        reference = source_path(base, cfg['reference'])
        if reference.suffix.lower() != '.png':
            raise ValueError('Source extraction requires a PNG reference')
    # Build off to the side; failed generation never leaves a partial final package.
    output.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix='reference-icon-', dir=output.parent) as work:
        work = Path(work)
        package = work / 'package.icon'
        assets = package / 'Assets'
        assets.mkdir(parents=True)
        if needs_ref:
            ref = work / 'reference.png'
            image(reference, '-resize', '1024x1024^', '-gravity', 'center',
                  '-extent', '1024x1024', '-alpha', 'on', '-colorspace', 'sRGB', ref)
        groups = []
        for layer in layers:
            name = layer['name']
            if 'image' in layer:
                src = source_path(base, layer['image'])
                art = assets / f'{name}{src.suffix.lower()}'
                shutil.copyfile(src, art)
                if art.suffix == '.png':
                    size = subprocess.check_output(['magick', 'identify', '-format', '%wx%h', str(art)], text=True)
                    if size != '1024x1024':
                        raise ValueError(f'{name}: prepared PNG must use the 1024-square canvas')
            else:
                art = assets / f'{name}.png'
                if 'diffuse_background' in layer:
                    sigma = float(layer['diffuse_background'])
                    if sigma < 0:
                        raise ValueError('Blur sigma must be nonnegative')
                    image(ref, '-blur', f'0x{sigma}', art)
                else:
                    sigma = float(layer.get('feather', 0))
                    if sigma < 0:
                        raise ValueError('Mask feather must be nonnegative')
                    mask = work / f'{name}-mask.png'
                    args = ['-size', '1024x1024', 'xc:black', '-fill', 'white', '-draw', layer['mask']]
                    if sigma:
                        args += ['-blur', f'0x{sigma}']
                    image(*args, '-alpha', 'copy', mask)
                    image(ref, mask, '-compose', 'DstIn', '-composite', art)
            specs = [{'value': art.name}]
            for appearance, key, suffix in [('dark', 'dark_image', 'Dark'), ('tinted', 'mono_image', 'Mono')]:
                variant = None
                if key in layer:
                    src = source_path(base, layer[key])
                    variant = assets / f'{name}-{suffix}{src.suffix.lower()}'
                    shutil.copyfile(src, variant)
                elif art.suffix == '.png':
                    variant = assets / f'{name}-{suffix}.png'
                    if appearance == 'dark':
                        shade(art, variant, {**cfg.get('dark', {}), **layer.get('dark', {})})
                    else:
                        image(art, '-colorspace', 'gray', '-colorspace', 'sRGB', variant)
                if variant:
                    specs.append({'appearance': appearance, 'value': variant.name})
            group = {'name': name, 'layers': [{'name': name, 'image-name-specializations': specs}]}
            if layer.get('material', 'native') == 'fidelity':
                group.update({'specular': False, 'blur-material': 0.0,
                              'shadow': {'kind': 'neutral', 'opacity': 0},
                              'translucency': {'enabled': False, 'value': 0}})
            groups.append(group)
        backgrounds = {'default': 'extended-srgb:0.08,0.10,0.15,1',
                       'dark': 'extended-srgb:0.01,0.015,0.025,1',
                       'tinted': 'extended-srgb:0.02,0.02,0.02,1'}
        backgrounds.update(cfg.get('background', {}))
        fills = []
        for appearance, color in backgrounds.items():
            if appearance not in ('default', 'dark', 'tinted'):
                raise ValueError(f'Unknown background appearance: {appearance}')
            entry = {'value': {'solid': color}}
            if appearance != 'default':
                entry['appearance'] = appearance
            fills.append(entry)
        doc = {'fill-specializations': fills, 'groups': list(reversed(groups)),
               'supported-platforms': cfg.get('supported_platforms', {'squares': 'shared'})}
        (package / 'icon.json').write_text(json.dumps(doc, indent=2) + '\n')
        record = {'generator': 'app-icon', 'back_to_front': [layer['name'] for layer in layers],
                  'assets': sorted(p.name for p in assets.iterdir())}
        (package / 'build-manifest.json').write_text(json.dumps(record, indent=2) + '\n')
        # A same-filesystem rename publishes the complete package without clobbering files.
        if output.exists():
            raise ValueError('Output was created during generation; refusing to replace it')
        package.rename(output)
    print(output)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--manifest', required=True, type=Path)
    parser.add_argument('--output', required=True, type=Path)
    args = parser.parse_args()
    try:
        build(args.manifest, args.output)
    except (ValueError, KeyError, OSError, subprocess.CalledProcessError) as exc:
        detail = getattr(exc, 'stderr', '')
        parser.exit(1, f'Build failed: {exc}\n{detail or ""}')


if __name__ == '__main__':
    main()
