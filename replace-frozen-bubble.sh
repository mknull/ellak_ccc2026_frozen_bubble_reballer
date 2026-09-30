#!/usr/bin/env bash
# CachyOS/Arch Linux. Requires Python 3 + Pillow: sudo pacman -S --needed python-pillow
# Usage: bash replace-frozen-bubble.sh IMAGE COLOR
# COLOR: a CSS color name, '#RRGGBB', or an exact ball slot (1..8).
# Optional --assets-dir DIR overrides package discovery (also useful for testing).
set -euo pipefail
command -v python3 >/dev/null || { echo 'Python 3 is required.' >&2; exit 1; }
exec python3 - "$0" "$@" <<'PY'
import argparse
import colorsys
import collections
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile

p = argparse.ArgumentParser(
    prog=Path(sys.argv.pop(1)).name,
    description='Replace one normal Frozen Bubble ball GIF and its miniature PNG.',
    formatter_class=argparse.RawDescriptionHelpFormatter,
    epilog="""Examples:
  %(prog)s avatar.png red
  %(prog)s avatar.png '#ff0000'
  %(prog)s avatar.png 3
  %(prog)s avatar.png 3 --assets-dir ./balls

COLOR selects the existing ball; the tint is sampled from that ball's original
asset, not taken directly from COLOR. Use a number for an exact slot.

Requires Python 3 and Pillow: sudo pacman -S --needed python-pillow
Discovers CachyOS/Arch Linux assets using pacman -Qlq unless --assets-dir is supplied.
Use sudo when the game asset directory requires administrator access.
Keeps first-run backups as FILE.original. Restart the game after replacement.
""")
p.add_argument('image', metavar='IMAGE', type=Path, help='input still image; resized to fit each asset, preserving proportions')
p.add_argument('color', metavar='COLOR', help='CSS color name, #RRGGBB, or slot 1..8; names select the closest original hue')
p.add_argument('--assets-dir', metavar='DIR', type=Path, help='override automatic pacman asset discovery')
a = p.parse_args()
try:
    from PIL import Image, ImageColor, ImageOps
except ImportError:
    p.exit(1, 'Error: Install Pillow first: sudo pacman -S --needed python-pillow\n')

def original(path):
    backup = path.with_name(path.name + '.original')
    return backup if backup.is_file() else path

def read_image(path):
    with Image.open(path) as im:
        if getattr(im, 'n_frames', 1) != 1:
            raise ValueError(f'Animated images are not supported: {path}')
        return ImageOps.exif_transpose(im).convert('RGBA')

def representative(path):
    # Find the most common chromatic RGB bin, weighted by opacity and saturation.
    # This discounts transparent borders, dark outlines, and white highlights.
    pixels = read_image(original(path)).getdata()
    groups = collections.defaultdict(list)
    for r, g, b, alpha in pixels:
        h, s, v = colorsys.rgb_to_hsv(r / 255, g / 255, b / 255)
        if alpha > 0 and v > .12:
            key = (r // 32, g // 32, b // 32)
            groups[key].append(((r, g, b), (alpha / 255) * (.05 + s) * v))
    if not groups:
        raise ValueError(f'Cannot sample a visible color from {path}')
    bucket = max(groups.values(), key=lambda rows: sum(w for _, w in rows))
    total = sum(w for _, w in bucket)
    return tuple(round(sum(rgb[c] * w for rgb, w in bucket) / total) for c in range(3))

def distance(rgb, requested):
    h, s, v = colorsys.rgb_to_hsv(*(x / 255 for x in rgb))
    rh, rs, rv = colorsys.rgb_to_hsv(*(x / 255 for x in requested))
    hue = min(abs(h - rh), 1 - abs(h - rh)) * 2
    return hue * min(s, rs) + .25 * abs(s - rs) + .05 * abs(v - rv)

def render(source, size, tint):
    # Keep the whole image, its proportions and its alpha; pad with transparency.
    fitted = ImageOps.contain(source, size, Image.Resampling.LANCZOS)
    gray = ImageOps.grayscale(fitted)
    # Black shadows -> sampled original color at midtones -> white highlights.
    colored = ImageOps.colorize(gray, black='black', mid=tint, white='white')
    colored.putalpha(fitted.getchannel('A'))
    canvas = Image.new('RGBA', size, (0, 0, 0, 0))
    canvas.paste(colored, ((size[0] - fitted.width) // 2, (size[1] - fitted.height) // 2))
    return canvas

def save_image(im, path, fmt):
    if fmt == 'GIF':
        # Reserve palette index 255 for transparency; GIF has only binary alpha.
        palette = im.convert('RGB').quantize(colors=255)
        mask = im.getchannel('A').point(lambda v: 255 if v < 128 else 0)
        palette.paste(255, mask=mask)
        palette.save(path, format='GIF', transparency=255, optimize=False)
    else:
        im.save(path, format='PNG')

try:
    if a.assets_dir:
        directory = a.assets_dir.resolve(strict=True)
    else:
        result = subprocess.run(['pacman', '-Qlq', 'frozen-bubble'],
                                check=True, capture_output=True, text=True)
        dirs = {Path(line).parent for line in result.stdout.splitlines()
                if re.search(r'/balls/bubble-[1-8]\.gif$', line) and Path(line).is_file()}
        if len(dirs) != 1:
            raise ValueError('Could not identify one asset directory; use --assets-dir DIR.')
        directory = dirs.pop()
    normal = {i: directory / f'bubble-{i}.gif' for i in range(1, 9)}
    if not all(path.is_file() for path in normal.values()):
        raise ValueError('Expected bubble-1.gif through bubble-8.gif in the asset directory.')
    colors = {i: representative(path) for i, path in normal.items()}
    if a.color in [str(i) for i in range(1, 9)]:
        slot = int(a.color)
    else:
        requested = ImageColor.getrgb(a.color)
        if len(requested) != 3:
            raise ValueError('Use an opaque color name or #RRGGBB.')
        slot = min(colors, key=lambda i: distance(colors[i], requested))
    prefix = 'bubble'
    targets = [directory / f'{prefix}-{slot}.gif', directory / f'{prefix}-{slot}-mini.png']
    if not all(path.is_file() for path in targets):
        raise ValueError('Missing matching GIF or miniature PNG: ' + ', '.join(map(str, targets)))
    refs = [original(path) for path in targets]
    tint = representative(targets[0])
    print(f'Selected slot {slot}; sampled tint #{tint[0]:02x}{tint[1]:02x}{tint[2]:02x}', file=sys.stderr)
    source = read_image(a.image)
    rendered = [render(source, read_image(ref).size, tint) for ref in refs]
    if not os.access(directory, os.W_OK):
        raise PermissionError('Asset directory is not writable. Rerun with sudo.')
    # Stage both outputs before any replacement; keep first-run originals.
    with tempfile.TemporaryDirectory(prefix='.ball-edit-', dir=directory) as tmp:
        tmp = Path(tmp)
        staged = []
        for n, (im, target, fmt) in enumerate(zip(rendered, targets, ['GIF', 'PNG'])):
            dest = tmp / target.name
            save_image(im, dest, fmt)
            with Image.open(dest) as check:
                check.load()
                if check.size != im.size or check.format != fmt:
                    raise ValueError(f'Output verification failed: {dest}')
            shutil.copystat(target, dest)
            shutil.copy2(target, tmp / f'rollback-{n}')
            backup = target.with_name(target.name + '.original')
            if not backup.exists():
                shutil.copy2(target, backup)
            staged.append(dest)
        changed = []
        try:
            for n, (dest, target) in enumerate(zip(staged, targets)):
                os.replace(dest, target)
                changed.append(n)
        except BaseException:
            for n in changed:
                os.replace(tmp / f'rollback-{n}', targets[n])
            raise
    for target in targets:
        print(target)
    print('Originals retained as FILE.original. Restart Frozen Bubble to see changes.', file=sys.stderr)
except (OSError, ValueError, subprocess.CalledProcessError) as e:
    sys.exit(f'Error: {e}')
PY
