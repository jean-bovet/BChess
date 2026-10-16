#!/usr/bin/env python3
"""Render and inspect all six square-platform Icon Composer appearances."""
import argparse
import json
from pathlib import Path
import shutil
import subprocess

MODES = ('Default', 'Dark', 'TintedLight', 'TintedDark', 'ClearLight', 'ClearDark')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--icon', required=True, type=Path)
    parser.add_argument('--output', required=True, type=Path)
    parser.add_argument('--platform', choices=('iOS', 'macOS'), default='iOS')
    parser.add_argument('--tool', type=Path, help='Override discovered Apple ictool path')
    args = parser.parse_args()
    icon, output = args.icon.resolve(), args.output.resolve()
    try:
        doc = json.loads((icon / 'icon.json').read_text())
        if not doc.get('groups'):
            raise ValueError('Icon has no artwork groups')
        for group in doc['groups']:
            for layer in group.get('layers', []):
                for spec in layer.get('image-name-specializations', []):
                    if not (icon / 'Assets' / spec['value']).is_file():
                        raise ValueError(f'Missing asset: {spec["value"]}')
        if output.exists():
            raise ValueError('Preview output exists; use a fresh directory')
        tool = args.tool
        if tool is None:
            developer = Path(subprocess.check_output(['xcode-select', '-p'], text=True).strip())
            candidates = [developer.parent / 'Applications/Icon Composer.app/Contents/Executables/ictool',
                          Path('/Applications/Icon Composer.app/Contents/Executables/ictool')]
            tool = next((p for p in candidates if p.is_file()), None)
        if tool is None or not tool.is_file():
            raise ValueError('Apple ictool is missing; install/select Xcode or provide --tool')
        if shutil.which('magick') is None:
            raise ValueError('ImageMagick is required for size checks and the contact sheet')
        output.mkdir(parents=True)
        files = []
        for mode in MODES:
            target = output / f'{mode}.png'
            subprocess.run([str(tool), str(icon), '--export-image', '--output-file', str(target),
                            '--platform', args.platform, '--rendition', mode, '--width', '1024',
                            '--height', '1024', '--scale', '1'], check=True, capture_output=True, text=True)
            size = subprocess.check_output(['magick', 'identify', '-format', '%wx%h', str(target)], text=True)
            if size != '1024x1024':
                raise ValueError(f'{mode}: unexpected rendered size {size}')
            files.append(str(target))
        # ImageMagick on macOS may have no usable default font, even without labels.
        font = Path('/System/Library/Fonts/Helvetica.ttc')
        font_args = ['-font', str(font)] if font.is_file() else []
        subprocess.run(['magick', 'montage', *font_args, '-label', '', *files, '-background', '#555555',
                        '-tile', '3x2', '-geometry', '384x384+12+12', str(output / 'all-appearances.png')],
                       check=True, capture_output=True, text=True)
        (output / 'render-report.json').write_text(json.dumps({'platform': args.platform,
             'modes': list(MODES), 'size': '1024x1024', 'renderer': 'Apple ictool'}, indent=2) + '\n')
        print(output / 'all-appearances.png')
    except (ValueError, OSError, KeyError, subprocess.CalledProcessError) as exc:
        detail = getattr(exc, 'stderr', '')
        parser.exit(1, f'Render failed: {exc}\n{detail or ""}\n'
                       'Any partial preview output is diagnostic only; no success report was written.\n')


if __name__ == '__main__':
    main()
